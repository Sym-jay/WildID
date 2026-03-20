#!/usr/bin/env python3
"""
Enhanced Ensemble Model Trainer with Data Augmentation (150x per image)
Trains 3 models on 7 species with heavy augmentation for better accuracy
"""

import os
import json
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader, random_split
from torchvision import models, transforms
from PIL import Image
import numpy as np
from pathlib import Path
from tqdm import tqdm
from datetime import datetime
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/sym/ZSI/Backend/ensemble_training_augmented.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Device
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
logger.info(f"Using device: {device}")

# ============================================================================
# DATA LOADING WITH 150x AUGMENTATION
# ============================================================================

class AugmentedWildlifeDataset(Dataset):
    """Dataset with 150x augmentation per image"""
    
    def __init__(self, image_paths, labels, augment=True, num_augmentations=150):
        self.image_paths = image_paths
        self.labels = labels
        self.augment = augment
        self.num_augmentations = num_augmentations if augment else 1
        
        # Heavy augmentation transforms
        self.augment_transform = transforms.Compose([
            transforms.RandomRotation(45),
            transforms.RandomHorizontalFlip(p=0.8),
            transforms.RandomVerticalFlip(p=0.3),
            transforms.RandomAffine(degrees=0, translate=(0.2, 0.2)),
            transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1),
            transforms.RandomResizedCrop(224, scale=(0.8, 1.0)),
            transforms.GaussianBlur(kernel_size=3, sigma=(0.1, 2.0)),
            transforms.RandomPerspective(p=0.3),
        ])
        
        self.final_transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406],
                               std=[0.229, 0.224, 0.225])
        ])
    
    def __len__(self):
        return len(self.image_paths) * self.num_augmentations
    
    def __getitem__(self, idx):
        img_idx = idx // self.num_augmentations
        img_path = self.image_paths[img_idx]
        label = self.labels[img_idx]
        
        try:
            img = Image.open(img_path).convert('RGB')
        except Exception as e:
            logger.warning(f"Failed to load {img_path}: {e}")
            # Return a blank image
            img = Image.new('RGB', (224, 224))
        
        if self.augment:
            img = self.augment_transform(img)
        
        img = self.final_transform(img)
        return img, label


def load_dataset_with_augmentation():
    """Load all images from extracted dataset"""
    dataset_path = Path('/home/sym/ZSI/Backend/dataset_extracted/ZSI/Wildlife Datasets/Schedule_2')
    
    image_paths = []
    labels = []
    species_map = {}
    
    logger.info("🔍 Scanning dataset structure...")
    
    # Iterate through species
    for species_idx, species_dir in enumerate(sorted(dataset_path.iterdir())):
        if not species_dir.is_dir():
            continue
        
        species_name = species_dir.name
        species_map[species_idx] = species_name
        logger.info(f"  Species {species_idx}: {species_name}")
        
        # Iterate through scientific names
        for sci_name_dir in species_dir.iterdir():
            if not sci_name_dir.is_dir():
                continue
            
            # Find all images
            for ext in ['*.jpg', '*.jpeg', '*.png', '*.JPG', '*.PNG']:
                for img_file in sci_name_dir.glob(ext):
                    # Skip very small or invalid images
                    try:
                        with Image.open(img_file) as img:
                            if img.size[0] < 50 or img.size[1] < 50:
                                continue
                    except:
                        continue
                    
                    image_paths.append(str(img_file))
                    labels.append(species_idx)
        
        logger.info(f"    ✓ Found {sum(1 for l in labels if l == species_idx)} images")
    
    logger.info(f"\n📊 Total images: {len(image_paths)}")
    logger.info(f"📊 Classes: {len(species_map)}")
    logger.info(f"📊 With 150x augmentation: {len(image_paths) * 150} training samples\n")
    
    return image_paths, labels, species_map


# ============================================================================
# MODEL TRAINING
# ============================================================================

def train_model(model, train_loader, val_loader, epochs=20, model_name="Model"):
    """Train a single model"""
    logger.info(f"\n{'='*80}")
    logger.info(f"🚀 Training {model_name}")
    logger.info(f"{'='*80}")
    
    model = model.to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001, weight_decay=1e-5)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', factor=0.5, patience=3)
    
    best_val_acc = 0
    best_model_state = None
    patience_counter = 0
    
    for epoch in range(epochs):
        # Training
        model.train()
        train_loss = 0
        correct = 0
        total = 0
        
        pbar = tqdm(train_loader, desc=f"  Epoch {epoch+1}/{epochs}")
        for images, labels in pbar:
            images, labels = images.to(device), labels.to(device)
            
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
            _, predicted = outputs.max(1)
            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()
            
            pbar.set_postfix({'Loss': f'{train_loss/(pbar.n+1):.4f}'})
        
        train_acc = 100 * correct / total
        train_loss = train_loss / len(train_loader)
        
        # Validation
        model.eval()
        val_loss = 0
        correct = 0
        total = 0
        
        with torch.no_grad():
            for images, labels in val_loader:
                images, labels = images.to(device), labels.to(device)
                outputs = model(images)
                loss = criterion(outputs, labels)
                
                val_loss += loss.item()
                _, predicted = outputs.max(1)
                total += labels.size(0)
                correct += predicted.eq(labels).sum().item()
        
        val_acc = 100 * correct / total
        val_loss = val_loss / len(val_loader)
        
        indicator = " ✓ (best)" if val_acc > best_val_acc else ""
        logger.info(f"  Epoch {epoch+1}/{epochs}: Train Loss: {train_loss:.4f} | Train Acc: {train_acc:.2f}% | Val Loss: {val_loss:.4f} | Val Acc: {val_acc:.2f}%{indicator}")
        
        # Save best model
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_model_state = model.state_dict().copy()
            patience_counter = 0
        else:
            patience_counter += 1
        
        scheduler.step(val_acc)
        
        # Early stopping
        if patience_counter >= 5:
            logger.info(f"  ⏹️  Early stopping at epoch {epoch+1}")
            break
    
    if best_model_state:
        model.load_state_dict(best_model_state)
    
    logger.info(f"  ✅ {model_name} - Best Val Acc: {best_val_acc:.2f}%")
    
    return model, best_val_acc


def evaluate_ensemble(models, test_loader, species_map):
    """Evaluate ensemble with voting"""
    logger.info(f"\n{'='*80}")
    logger.info("📊 Evaluating Ensemble")
    logger.info(f"{'='*80}")
    
    for model in models:
        model.eval()
    
    all_preds = []
    all_labels = []
    
    with torch.no_grad():
        for images, labels in tqdm(test_loader, desc="  Evaluating"):
            images = images.to(device)
            
            # Get predictions from all 3 models
            preds_list = []
            for model in models:
                outputs = model(images)
                preds = outputs.argmax(dim=1).cpu().numpy()
                preds_list.append(preds)
            
            # Voting - most common prediction
            preds_array = np.array(preds_list)  # Shape: (3, batch_size)
            ensemble_preds = np.zeros(images.shape[0], dtype=int)
            
            for i in range(images.shape[0]):
                predictions = preds_array[:, i]
                # Mode (most common)
                ensemble_preds[i] = np.bincount(predictions).argmax()
            
            all_preds.extend(ensemble_preds)
            all_labels.extend(labels.numpy())
    
    all_preds = np.array(all_preds)
    all_labels = np.array(all_labels)
    
    ensemble_acc = 100 * np.mean(all_preds == all_labels)
    
    logger.info(f"  ✅ Ensemble Test Accuracy: {ensemble_acc:.2f}%")
    
    return ensemble_acc


# ============================================================================
# MAIN
# ============================================================================

def main():
    start_time = datetime.now()
    logger.info("\n" + "="*80)
    logger.info("✨ ENSEMBLE TRAINING WITH AUGMENTATION (150x)")
    logger.info("="*80)
    
    # Load dataset
    image_paths, labels, species_map = load_dataset_with_augmentation()
    
    # Create dataset and loaders
    dataset = AugmentedWildlifeDataset(image_paths, labels, augment=True, num_augmentations=150)
    total_samples = len(image_paths) * 150  # 127 * 150 = 19,050 samples
    
    train_size = int(0.7 * len(image_paths))
    val_size = int(0.15 * len(image_paths))
    test_size = len(image_paths) - train_size - val_size
    
    train_indices = list(range(0, train_size))
    val_indices = list(range(train_size, train_size + val_size))
    test_indices = list(range(train_size + val_size, len(image_paths)))
    
    train_dataset = AugmentedWildlifeDataset(
        [image_paths[i] for i in train_indices],
        [labels[i] for i in train_indices],
        augment=True,
        num_augmentations=150
    )
    
    val_dataset = AugmentedWildlifeDataset(
        [image_paths[i] for i in val_indices],
        [labels[i] for i in val_indices],
        augment=False,
        num_augmentations=1
    )
    
    test_dataset = AugmentedWildlifeDataset(
        [image_paths[i] for i in test_indices],
        [labels[i] for i in test_indices],
        augment=False,
        num_augmentations=1
    )
    
    train_loader = DataLoader(train_dataset, batch_size=16, shuffle=True, num_workers=4)
    val_loader = DataLoader(val_dataset, batch_size=16, shuffle=False, num_workers=4)
    test_loader = DataLoader(test_dataset, batch_size=16, shuffle=False, num_workers=4)
    
    logger.info(f"\n📊 Dataset Split:")
    logger.info(f"  Training: {len(train_indices)} images × 150 = {len(train_dataset)} samples")
    logger.info(f"  Validation: {len(val_indices)} images × 1 = {len(val_dataset)} samples")
    logger.info(f"  Testing: {len(test_indices)} images × 1 = {len(test_dataset)} samples")
    logger.info(f"  Total classes: {len(species_map)}\n")
    
    # Train models
    models = []
    results = {}
    
    # EfficientNet-B0
    model1 = models.efficientnet_b0(pretrained=True)
    model1.classifier[1] = nn.Linear(1280, len(species_map))
    model1, acc1 = train_model(model1, train_loader, val_loader, epochs=20, model_name="EfficientNet-B0")
    models.append(model1)
    results['efficientnet_b0'] = acc1
    torch.save(model1.state_dict(), '/home/sym/ZSI/Backend/ensemble_models/model_efficientnet_b0_v3.pth')
    
    # ResNet-50
    model2 = models.resnet50(pretrained=True)
    model2.fc = nn.Linear(2048, len(species_map))
    model2, acc2 = train_model(model2, train_loader, val_loader, epochs=20, model_name="ResNet-50")
    models.append(model2)
    results['resnet50'] = acc2
    torch.save(model2.state_dict(), '/home/sym/ZSI/Backend/ensemble_models/model_resnet50_v3.pth')
    
    # MobileNet-V3
    model3 = models.mobilenet_v3_small(pretrained=True)
    model3.classifier[3] = nn.Linear(1024, len(species_map))
    model3, acc3 = train_model(model3, train_loader, val_loader, epochs=20, model_name="MobileNet-V3")
    models.append(model3)
    results['mobilenet_v3'] = acc3
    torch.save(model3.state_dict(), '/home/sym/ZSI/Backend/ensemble_models/model_mobilenet_v3_v3.pth')
    
    # Evaluate ensemble
    ensemble_acc = evaluate_ensemble(models, test_loader, species_map)
    results['ensemble'] = ensemble_acc
    
    # Save results
    results['species_map'] = species_map
    results['total_training_samples'] = len(train_dataset)
    results['augmentation_factor'] = 150
    results['training_time_seconds'] = (datetime.now() - start_time).total_seconds()
    results['timestamp'] = datetime.now().isoformat()
    
    with open('/home/sym/ZSI/Backend/ensemble_models/training_results_v3.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    logger.info(f"\n{'='*80}")
    logger.info("✅ ENSEMBLE TRAINING COMPLETE")
    logger.info(f"{'='*80}")
    logger.info(f"\n📊 Results:")
    logger.info(f"   EfficientNet-B0: {acc1:.2f}%")
    logger.info(f"   ResNet-50:       {acc2:.2f}%")
    logger.info(f"   MobileNet-V3:    {acc3:.2f}%")
    logger.info(f"   Ensemble:        {ensemble_acc:.2f}%")
    logger.info(f"\n💾 Models saved to: ensemble_models/")
    logger.info(f"📄 Results saved to: ensemble_models/training_results_v3.json")
    logger.info(f"⏱️  Training time: {results['training_time_seconds']:.1f} seconds")
    logger.info(f"{'='*80}\n")


if __name__ == '__main__':
    main()
