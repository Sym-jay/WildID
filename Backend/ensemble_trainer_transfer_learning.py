#!/usr/bin/env python3
"""
Ensemble Model Trainer with Transfer Learning
Uses ImageNet pre-trained weights for better accuracy on limited datasets
Expected accuracy: 85-92% (vs 75% without transfer learning)
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from torchvision import models, transforms
from PIL import Image
from pathlib import Path
import json
import numpy as np
from tqdm import tqdm
import logging
from datetime import datetime
import os

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ensemble_training_transfer_learning.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class CombinedDataset(Dataset):
    """Dataset combining images from multiple schedules."""
    def __init__(self, images, labels, transform=None):
        self.images = images
        self.labels = labels
        self.transform = transform
        self.class_to_idx = {cls: idx for idx, cls in enumerate(sorted(set(labels)))}
    
    def __len__(self):
        return len(self.images)
    
    def __getitem__(self, idx):
        img_path = self.images[idx]
        label = self.labels[idx]
        
        img = Image.open(img_path).convert('RGB')
        if self.transform:
            img = self.transform(img)
        
        return img, self.class_to_idx[label]

class AugmentedDataset(Dataset):
    """Dataset with aggressive augmentation for limited data"""
    
    def __init__(self, root_dir, transform=None, augmentation_factor=150):
        self.root_dir = Path(root_dir)
        self.augmentation_factor = augmentation_factor
        self.transform = transform
        self.images = []
        self.labels = []
        self.class_to_idx = {}
        
        # Discover classes and images
        species_dirs = sorted([d for d in self.root_dir.iterdir() if d.is_dir()])
        
        for idx, species_dir in enumerate(species_dirs):
            self.class_to_idx[species_dir.name] = idx
            
            # Find all images in species directory
            for img_path in species_dir.rglob('*'):
                if img_path.suffix.lower() in ['.jpg', '.jpeg', '.png']:
                    self.images.append(img_path)
                    self.labels.append(idx)
        
        self.num_classes = len(species_dirs)
        logger.info(f"Dataset loaded: {len(self.images)} images, {self.num_classes} species")
    
    def __len__(self):
        return len(self.images) * self.augmentation_factor
    
    def __getitem__(self, idx):
        # Use modulo to repeat images with different augmentations
        actual_idx = idx % len(self.images)
        img_path = self.images[actual_idx]
        label = self.labels[actual_idx]
        
        from PIL import Image
        try:
            image = Image.open(img_path).convert('RGB')
        except Exception as e:
            logger.warning(f"Failed to load {img_path}: {e}")
            # Return a blank image on failure
            image = Image.new('RGB', (224, 224))
        
        if self.transform:
            image = self.transform(image)
        
        return image, label


def create_transfer_learning_model(num_classes, model_name='efficientnet_b0', pretrained=True):
    """Create model with ImageNet pre-trained weights"""
    
    logger.info(f"Creating {model_name} with transfer learning (pretrained={pretrained})")
    
    if model_name == 'efficientnet_b0':
        model = models.efficientnet_b0(weights='IMAGENET1K_V1' if pretrained else None)
        # Modify final layer for our number of classes
        num_ftrs = model.classifier[1].in_features
        model.classifier[1] = nn.Linear(num_ftrs, num_classes)
        
    elif model_name == 'resnet50':
        model = models.resnet50(weights='IMAGENET1K_V2' if pretrained else None)
        num_ftrs = model.fc.in_features
        model.fc = nn.Linear(num_ftrs, num_classes)
        
    elif model_name == 'mobilenet_v3_small':
        model = models.mobilenet_v3_small(weights='IMAGENET1K_V1' if pretrained else None)
        num_ftrs = model.classifier[3].in_features
        model.classifier[3] = nn.Linear(num_ftrs, num_classes)
    
    return model


def train_model(model, train_loader, val_loader, num_epochs=20, device='cuda'):
    """Train model with transfer learning"""
    
    model = model.to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', factor=0.5, patience=3)
    
    best_acc = 0
    patience_counter = 0
    max_patience = 5
    
    results = {
        'train_loss': [],
        'train_acc': [],
        'val_loss': [],
        'val_acc': []
    }
    
    for epoch in range(num_epochs):
        # Training phase
        model.train()
        train_loss = 0.0
        train_correct = 0
        train_total = 0
        
        pbar = tqdm(train_loader, desc=f"Epoch {epoch+1}/{num_epochs} [Train]")
        for images, labels in pbar:
            images = images.to(device)
            labels = labels.to(device)
            
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
            _, predicted = torch.max(outputs.data, 1)
            train_total += labels.size(0)
            train_correct += (predicted == labels).sum().item()
            
            pbar.set_postfix({'loss': f'{loss.item():.4f}'})
        
        train_loss /= len(train_loader)
        train_acc = 100 * train_correct / train_total
        results['train_loss'].append(train_loss)
        results['train_acc'].append(train_acc)
        
        # Validation phase
        model.eval()
        val_loss = 0.0
        val_correct = 0
        val_total = 0
        
        with torch.no_grad():
            pbar = tqdm(val_loader, desc=f"Epoch {epoch+1}/{num_epochs} [Val]")
            for images, labels in pbar:
                images = images.to(device)
                labels = labels.to(device)
                
                outputs = model(images)
                loss = criterion(outputs, labels)
                
                val_loss += loss.item()
                _, predicted = torch.max(outputs.data, 1)
                val_total += labels.size(0)
                val_correct += (predicted == labels).sum().item()
        
        val_loss /= len(val_loader)
        val_acc = 100 * val_correct / val_total
        results['val_loss'].append(val_loss)
        results['val_acc'].append(val_acc)
        
        logger.info(
            f"Epoch {epoch+1}/{num_epochs} | "
            f"Train Loss: {train_loss:.4f}, Acc: {train_acc:.2f}% | "
            f"Val Loss: {val_loss:.4f}, Acc: {val_acc:.2f}%"
        )
        
        # Early stopping
        scheduler.step(val_acc)
        
        if val_acc > best_acc:
            best_acc = val_acc
            patience_counter = 0
            logger.info(f"✓ Best accuracy improved to {val_acc:.2f}%")
        else:
            patience_counter += 1
            if patience_counter >= max_patience:
                logger.info(f"Early stopping triggered after {epoch+1} epochs")
                break
    
    return model, results


def main():
    logger.info("=" * 80)
    logger.info("ENSEMBLE TRANSFER LEARNING TRAINER")
    logger.info("=" * 80)
    
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    logger.info(f"Using device: {device}")
    
    # Data augmentation pipelines
    train_transform = transforms.Compose([
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.RandomVerticalFlip(p=0.2),
        transforms.RandomRotation(degrees=15),
        transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
        transforms.RandomAffine(degrees=0, translate=(0.1, 0.1), scale=(0.9, 1.1)),
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    val_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    # Load datasets from BOTH schedules
    schedule1_path = Path('./zsi_dataset_extracted/ZSI/Wildlife Datasets/Schedule_1')
    schedule2_path = Path('./zsi_dataset_extracted/ZSI/Wildlife Datasets/Schedule_2')
    
    if not schedule1_path.exists() or not schedule2_path.exists():
        logger.error(f"Dataset not found")
        return
    
    logger.info(f"Loading datasets from both schedules")
    
    # Load both datasets and combine them
    dataset1 = AugmentedDataset(schedule1_path, transform=train_transform, augmentation_factor=1)
    dataset2 = AugmentedDataset(schedule2_path, transform=train_transform, augmentation_factor=1)
    
    # Combine images and labels
    all_images = dataset1.images + dataset2.images
    all_labels = dataset1.labels + dataset2.labels
    
    logger.info(f"Total images: {len(all_images)} ({len(dataset1.images)} from Schedule_1, {len(dataset2.images)} from Schedule_2)")
    
    # Create combined dataset for clean train/val split
    combined_dataset = CombinedDataset(all_images, all_labels, transform=train_transform)
    num_classes = len(combined_dataset.class_to_idx)
    
    # Split into train/val (85/15)
    total_size = len(combined_dataset)
    train_size = int(0.85 * total_size)
    val_size = total_size - train_size
    
    from torch.utils.data import random_split
    train_dataset, val_dataset = random_split(combined_dataset, [train_size, val_size])
    
    # Update val_dataset transform to no augmentation
    val_dataset.dataset.transform = val_transform
    
    logger.info(f"Train/Val split: {train_size}/{val_size} images")
    logger.info(f"Number of classes: {num_classes}")
    
    train_loader = DataLoader(train_dataset, batch_size=16, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_dataset, batch_size=16, shuffle=False, num_workers=0)
    
    logger.info(f"Loaded {len(train_loader)} train batches, {len(val_loader)} val batches")
    
    # Train ensemble models
    models_to_train = [
        ('efficientnet_b0', 20),
        ('resnet50', 20),
        ('mobilenet_v3_small', 20),
    ]
    
    all_results = {}
    
    for model_name, num_epochs in models_to_train:
        logger.info(f"\n{'='*80}")
        logger.info(f"Training {model_name} with Transfer Learning")
        logger.info(f"{'='*80}")
        
        # Create model with transfer learning
        model = create_transfer_learning_model(
            num_classes=num_classes,
            model_name=model_name,
            pretrained=True  # ← KEY DIFFERENCE: Using ImageNet weights!
        )
        
        # Train
        model, results = train_model(
            model,
            train_loader,
            val_loader,
            num_epochs=num_epochs,
            device=device
        )
        
        # Save model
        model_path = Path(f'ensemble_models/model_{model_name}_transfer_learning.pth')
        model_path.parent.mkdir(parents=True, exist_ok=True)
        torch.save(model.state_dict(), model_path)
        logger.info(f"Saved model to {model_path}")
        
        # Store results
        all_results[model_name] = {
            'accuracy': max(results['val_acc']),
            'history': results,
        }
    
    # Summary
    logger.info(f"\n{'='*80}")
    logger.info("TRANSFER LEARNING TRAINING COMPLETE")
    logger.info(f"{'='*80}")
    
    for model_name, result in all_results.items():
        logger.info(f"{model_name}: {result['accuracy']:.2f}% accuracy")
    
    # Save results
    results_path = Path('ensemble_models/training_results_transfer_learning.json')
    with open(results_path, 'w') as f:
        json.dump({
            'models': all_results,
            'timestamp': datetime.now().isoformat(),
            'config': {
                'dataset_size': len(dataset.images),
                'augmentation_factor': 150,
                'learning_rate': 0.001,
                'batch_size': 16,
                'device': device,
                'transfer_learning': True,
                'notes': 'Using ImageNet pre-trained weights for improved accuracy'
            }
        }, f, indent=2)
    
    logger.info(f"Saved results to {results_path}")


if __name__ == '__main__':
    main()
