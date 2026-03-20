#!/usr/bin/env python3
"""
ZSI Wildlife - Ensemble Model Training (Simple Version)
Trains 3 models with actual dataset
"""

import os
import sys
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset, random_split
import torchvision.models as models
from torchvision import transforms
import json
from pathlib import Path
from datetime import datetime
import zipfile
from PIL import Image
import numpy as np
from tqdm import tqdm
import gc

print("\n" + "="*80)
print("ZSI WILDLIFE - ENSEMBLE MODEL TRAINING")
print("="*80)

# ============================================================================
# CONFIGURATION
# ============================================================================

CONFIG = {
    'batch_size': 16,
    'epochs': 20,  # Full training epochs
    'learning_rate': 0.001,
    'num_classes': 7,  # 7 species in extracted dataset
    'device': 'cuda' if torch.cuda.is_available() else 'cpu',
    'num_workers': 2,
    'augmentation_factor': 150,  # 150x augmentation like original
    'use_extracted_dataset': True  # Use already-extracted dataset
}

print(f"\n📊 Configuration:")
print(f"   Device: {CONFIG['device']}")
print(f"   Batch size: {CONFIG['batch_size']}")
print(f"   Epochs: {CONFIG['epochs']}")
print(f"   Learning rate: {CONFIG['learning_rate']}")

# ============================================================================
# DATASET CLASS
# ============================================================================

class ZSIDataset(Dataset):
    """Load ZSI wildlife images with augmentation support"""
    
    def __init__(self, image_paths, labels, transform=None, augment_count=1):
        self.image_paths = image_paths
        self.labels = labels
        self.transform = transform
        self.augment_count = augment_count  # How many augmentations per image
        
        # Additional augmentation transforms for training
        self.augment_transform = transforms.Compose([
            transforms.RandomRotation(45),
            transforms.RandomHorizontalFlip(p=0.7),
            transforms.RandomVerticalFlip(p=0.2),
            transforms.RandomAffine(degrees=0, translate=(0.15, 0.15), scale=(0.85, 1.1)),
            transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
            transforms.RandomResizedCrop(224, scale=(0.8, 1.0)),
            transforms.RandomPerspective(p=0.2),
        ])
    
    def __len__(self):
        return len(self.image_paths) * self.augment_count
    
    def __getitem__(self, idx):
        img_idx = idx // self.augment_count
        try:
            img = Image.open(self.image_paths[img_idx]).convert('RGB')
        except Exception as e:
            # Return black image on error
            return torch.zeros(3, 224, 224), self.labels[img_idx]
        
        # Apply augmentation during training
        if self.augment_count > 1:
            img = self.augment_transform(img)
        
        if self.transform:
            img = self.transform(img)
        
        return img, self.labels[img_idx]

# ============================================================================
# DATASET LOADING
# ============================================================================

def extract_and_load_dataset():
    """Load images from already-extracted dataset"""
    print("\n📦 Loading Dataset")
    print("-" * 80)
    
    # Use pre-extracted dataset
    dataset_dir = Path('dataset_extracted')
    
    if not dataset_dir.exists():
        print(f"   ⚠️  Dataset not extracted. Using ZIP...")
        zip_path = Path('ZSI_Backend/zsi_dataset.zip')
        if not zip_path.exists():
            print(f"   ❌ ZIP file not found: {zip_path}")
            return None, None
        print(f"   Extracting {zip_path.name}...")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(dataset_dir)
        print(f"   ✓ Extracted to {dataset_dir}")
    
    # Find all images
    print("\n   Scanning images...")
    image_paths = []
    labels = []
    class_id = 0
    species_names = {}
    
    # Navigate to ZSI/Wildlife Datasets structure
    base_path = dataset_dir / 'ZSI' / 'Wildlife Datasets' / 'Schedule_2'
    
    if not base_path.exists():
        print(f"   ⚠️  Base path not found: {base_path}")
        print(f"   Available: {list(dataset_dir.glob('*'))}")
        return None, None
    
    for species_dir in sorted(base_path.glob('*')):
        if not species_dir.is_dir():
            continue
        
        species_name = species_dir.name
        species_names[class_id] = species_name
        
        # Find images in subdirectories
        images = []
        for subdir in species_dir.glob('*'):
            if subdir.is_dir():
                # Find all image types (case insensitive)
                for ext in ['*.jpg', '*.JPG', '*.jpeg', '*.JPEG', '*.png', '*.PNG']:
                    images.extend(list(subdir.glob(ext)))
        
        if len(images) > 0:
            # Use ALL images for full training
            for img_path in images:
                try:
                    # Verify image can be opened
                    with Image.open(img_path) as img:
                        if img.size[0] >= 50 and img.size[1] >= 50:
                            image_paths.append(str(img_path))
                            labels.append(class_id)
                except:
                    pass
            
            print(f"   ✓ {species_name:40s} : {sum(1 for l in labels if l == class_id):3d} images (class {class_id})")
            class_id += 1
    
    total_images = len(image_paths)
    total_with_augmentation = total_images * CONFIG['augmentation_factor']
    print(f"\n   Total: {total_images} images across {class_id} classes")
    print(f"   With {CONFIG['augmentation_factor']}x augmentation: {total_with_augmentation} training samples")
    
    if total_images == 0:
        print("   ❌ No images found!")
        return None, None
    
    return image_paths, labels

# ============================================================================
# TRAINING FUNCTION
# ============================================================================

def train_model(model, model_name, train_loader, val_loader, device, epochs=CONFIG['epochs']):
    """Train a single model"""
    print(f"\n🚀 Training {model_name}")
    print("-" * 80)
    
    model = model.to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=CONFIG['learning_rate'])
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=2, gamma=0.5)
    
    best_val_acc = 0
    history = {'train_loss': [], 'val_acc': []}
    
    for epoch in range(epochs):
        # Training phase
        model.train()
        train_loss = 0
        for batch_idx, (images, labels) in enumerate(tqdm(train_loader, desc=f"  Epoch {epoch+1}/{epochs}")):
            images, labels = images.to(device), labels.to(device)
            
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
        
        avg_train_loss = train_loss / len(train_loader)
        history['train_loss'].append(avg_train_loss)
        
        # Validation phase
        model.eval()
        correct = 0
        total = 0
        with torch.no_grad():
            for images, labels in val_loader:
                images, labels = images.to(device), labels.to(device)
                outputs = model(images)
                _, predicted = torch.max(outputs.data, 1)
                total += labels.size(0)
                correct += (predicted == labels).sum().item()
        
        val_acc = correct / total
        history['val_acc'].append(val_acc)
        scheduler.step()
        
        print(f"  Loss: {avg_train_loss:.4f} | Val Acc: {val_acc*100:.2f}%", end="")
        
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            print(" ✓ (best)", end="")
        print()
    
    print(f"  ✅ {model_name} - Best Val Acc: {best_val_acc*100:.2f}%")
    return model, best_val_acc, history

# ============================================================================
# ENSEMBLE EVALUATION
# ============================================================================

def evaluate_ensemble(models, test_loader, device):
    """Evaluate ensemble voting"""
    print(f"\n📊 Evaluating Ensemble")
    print("-" * 80)
    
    correct = 0
    total = 0
    
    for images, labels in tqdm(test_loader, desc="  Evaluating"):
        images, labels = images.to(device), labels.to(device)
        
        ensemble_pred = torch.zeros(images.size(0), CONFIG['num_classes']).to(device)
        
        with torch.no_grad():
            for model in models:
                model.eval()
                outputs = model(images)
                probs = torch.softmax(outputs, dim=1)
                ensemble_pred += probs / len(models)
        
        _, predicted = torch.max(ensemble_pred, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()
    
    ensemble_acc = correct / total
    print(f"  ✅ Ensemble Test Accuracy: {ensemble_acc*100:.2f}%")
    return ensemble_acc

# ============================================================================
# MAIN
# ============================================================================

def main():
    device = CONFIG['device']
    print(f"\n✓ Using device: {device}")
    
    # Load dataset
    image_paths, labels = extract_and_load_dataset()
    if image_paths is None:
        print("❌ Failed to load dataset!")
        return 1
    
    # Data transforms (final normalization only, augmentation is in dataset)
    print("\n🔄 Creating data transforms...")
    final_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406],
                           std=[0.229, 0.224, 0.225])
    ])
    
    # Split data indices FIRST
    print("\n📂 Splitting data...")
    total_images = len(image_paths)
    train_size = int(0.7 * total_images)
    val_size = int(0.15 * total_images)
    test_size = total_images - train_size - val_size
    
    train_indices = list(range(0, train_size))
    val_indices = list(range(train_size, train_size + val_size))
    test_indices = list(range(train_size + val_size, total_images))
    
    train_paths = [image_paths[i] for i in train_indices]
    train_labels = [labels[i] for i in train_indices]
    val_paths = [image_paths[i] for i in val_indices]
    val_labels = [labels[i] for i in val_indices]
    test_paths = [image_paths[i] for i in test_indices]
    test_labels = [labels[i] for i in test_indices]
    
    # Create datasets with augmentation
    print("   Creating augmented training dataset...")
    train_dataset = ZSIDataset(train_paths, train_labels, transform=final_transform, 
                               augment_count=CONFIG['augmentation_factor'])
    val_dataset = ZSIDataset(val_paths, val_labels, transform=final_transform, augment_count=1)
    test_dataset = ZSIDataset(test_paths, test_labels, transform=final_transform, augment_count=1)
    
    print(f"   Train: {len(train_paths)} images × {CONFIG['augmentation_factor']} = {len(train_dataset)} samples")
    print(f"   Val:   {len(val_paths)} images × 1 = {len(val_dataset)} samples")
    print(f"   Test:  {len(test_paths)} images × 1 = {len(test_dataset)} samples")
    
    train_loader = DataLoader(train_dataset, batch_size=CONFIG['batch_size'], 
                            shuffle=True, num_workers=CONFIG['num_workers'])
    val_loader = DataLoader(val_dataset, batch_size=CONFIG['batch_size'], 
                          shuffle=False, num_workers=CONFIG['num_workers'])
    test_loader = DataLoader(test_dataset, batch_size=CONFIG['batch_size'], 
                           shuffle=False, num_workers=CONFIG['num_workers'])
    
    # Train models
    trained_models = []
    results = {}
    
    # Model 1: EfficientNet-B0
    print("\n" + "="*80)
    model1 = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.IMAGENET1K_V1)
    model1.classifier[1] = nn.Linear(1280, CONFIG['num_classes'])
    model1, acc1, hist1 = train_model(model1, "EfficientNet-B0", train_loader, val_loader, device)
    trained_models.append(model1)
    results['efficientnet_b0'] = {'accuracy': acc1, 'history': hist1}
    
    # Save
    os.makedirs('ensemble_models', exist_ok=True)
    torch.save(model1.state_dict(), 'ensemble_models/model_efficientnet_b0_v2.pth')
    print("   ✓ Saved to ensemble_models/model_efficientnet_b0_v2.pth")
    
    # Model 2: ResNet-50
    print("\n" + "="*80)
    model2 = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V1)
    model2.fc = nn.Linear(2048, CONFIG['num_classes'])
    model2, acc2, hist2 = train_model(model2, "ResNet-50", train_loader, val_loader, device)
    trained_models.append(model2)
    results['resnet50'] = {'accuracy': acc2, 'history': hist2}
    
    # Save
    torch.save(model2.state_dict(), 'ensemble_models/model_resnet50_v2.pth')
    print("   ✓ Saved to ensemble_models/model_resnet50_v2.pth")
    
    # Model 3: MobileNet-V3
    print("\n" + "="*80)
    model3 = models.mobilenet_v3_small(weights=models.MobileNet_V3_Small_Weights.IMAGENET1K_V1)
    model3.classifier[3] = nn.Linear(1024, CONFIG['num_classes'])
    model3, acc3, hist3 = train_model(model3, "MobileNet-V3", train_loader, val_loader, device)
    trained_models.append(model3)
    results['mobilenet_v3'] = {'accuracy': acc3, 'history': hist3}
    
    # Save
    torch.save(model3.state_dict(), 'ensemble_models/model_mobilenet_v3_v2.pth')
    print("   ✓ Saved to ensemble_models/model_mobilenet_v3_v2.pth")
    
    # Evaluate ensemble
    print("\n" + "="*80)
    ensemble_acc = evaluate_ensemble(trained_models, test_loader, device)
    results['ensemble'] = ensemble_acc
    
    # Save results
    results['timestamp'] = datetime.now().isoformat()
    results['config'] = CONFIG
    
    with open('ensemble_models/training_results_v2.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    # Final summary
    print("\n" + "="*80)
    print("✅ ENSEMBLE TRAINING COMPLETE")
    print("="*80)
    print(f"\n📊 Results:")
    print(f"   EfficientNet-B0: {results['efficientnet_b0']['accuracy']*100:.2f}%")
    print(f"   ResNet-50:       {results['resnet50']['accuracy']*100:.2f}%")
    print(f"   MobileNet-V3:    {results['mobilenet_v3']['accuracy']*100:.2f}%")
    print(f"   Ensemble:        {results['ensemble']*100:.2f}%")
    print(f"\n💾 Models saved to: ensemble_models/")
    print(f"📄 Results saved to: ensemble_models/training_results_v2.json")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
