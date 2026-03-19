#!/usr/bin/env python3
"""
ZSI Wildlife - Full Ensemble Training Script
Loads actual dataset and trains ensemble models
"""

import os
import sys
import torch
import json
from pathlib import Path
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms
from PIL import Image
import random

# Import the trainer
from model_ensemble_trainer import EnsembleModelTrainer, EnsembleConfig


class ZSIDataset(Dataset):
    """Load ZSI wildlife images from directory structure"""
    
    def __init__(self, image_dir, class_mapping, transform=None, limit_per_class=None):
        self.image_dir = Path(image_dir)
        self.class_mapping = class_mapping
        self.transform = transform
        self.images = []
        self.labels = []
        
        # Load image paths and labels
        for class_id, class_name in class_mapping.items():
            class_path = self.image_dir / class_name
            if not class_path.exists():
                print(f"⚠️  Class directory not found: {class_path}")
                continue
            
            image_files = list(class_path.glob('*.jpg')) + list(class_path.glob('*.png')) + list(class_path.glob('*.jpeg'))
            
            # Limit per class if specified
            if limit_per_class:
                image_files = image_files[:limit_per_class]
            
            for img_path in image_files:
                self.images.append(str(img_path))
                self.labels.append(int(class_id))
        
        print(f"✓ Loaded {len(self.images)} images for dataset")
    
    def __len__(self):
        return len(self.images)
    
    def __getitem__(self, idx):
        try:
            img_path = self.images[idx]
            label = self.labels[idx]
            
            # Load image
            image = Image.open(img_path).convert('RGB')
            
            if self.transform:
                image = self.transform(image)
            
            return image, label
        except Exception as e:
            print(f"⚠️  Error loading {img_path}: {e}")
            # Return a black image on error
            image = torch.zeros(3, 224, 224)
            label = self.labels[idx]
            return image, label


def main():
    print("\n" + "="*60)
    print(" ZSI Wildlife - Ensemble Model Training")
    print("="*60 + "\n")
    
    # Configuration
    DATA_DIR = Path('ZSI/Species')
    CLASS_MAPPING_FILE = 'zsi_class_mapping.json'
    
    # Check if data directory exists
    if not DATA_DIR.exists():
        print(f"❌ Data directory not found: {DATA_DIR}")
        print("\nExpected structure:")
        print("  ZSI/")
        print("    Species/")
        print("      Species1/")
        print("        image1.jpg")
        print("        image2.jpg")
        print("      Species2/")
        print("        ...")
        sys.exit(1)
    
    # Load class mapping
    if not Path(CLASS_MAPPING_FILE).exists():
        print(f"❌ Class mapping file not found: {CLASS_MAPPING_FILE}")
        print("\nCreating default mapping for 66 species...")
        # Create default mapping
        class_mapping = {str(i): f"species_{i:02d}" for i in range(66)}
    else:
        with open(CLASS_MAPPING_FILE, 'r') as f:
            class_mapping = json.load(f)
    
    print(f"📊 Found {len(class_mapping)} species in class mapping")
    print(f"📂 Data directory: {DATA_DIR}")
    
    # Data transforms
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(10),
        transforms.ColorJitter(brightness=0.2, contrast=0.2),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        )
    ])
    
    val_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        )
    ])
    
    print("\n📥 Loading dataset...")
    
    # Load dataset - try to use all available data
    full_dataset = ZSIDataset(DATA_DIR, class_mapping, transform=val_transform)
    
    if len(full_dataset) == 0:
        print("❌ No images found in dataset!")
        print(f"\nChecking {DATA_DIR}:")
        for item in DATA_DIR.iterdir():
            print(f"  - {item.name}")
        sys.exit(1)
    
    # Split into train (80%), val (10%), test (10%)
    train_size = int(0.8 * len(full_dataset))
    val_size = int(0.1 * len(full_dataset))
    test_size = len(full_dataset) - train_size - val_size
    
    train_dataset, val_dataset, test_dataset = torch.utils.data.random_split(
        full_dataset, 
        [train_size, val_size, test_size]
    )
    
    print(f"  ✓ Train: {len(train_dataset)} images")
    print(f"  ✓ Val:   {len(val_dataset)} images")
    print(f"  ✓ Test:  {len(test_dataset)} images")
    
    # Create data loaders
    train_loader = DataLoader(
        train_dataset,
        batch_size=EnsembleConfig.BATCH_SIZE,
        shuffle=True,
        num_workers=4,
        pin_memory=True
    )
    
    val_loader = DataLoader(
        val_dataset,
        batch_size=EnsembleConfig.BATCH_SIZE,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )
    
    test_loader = DataLoader(
        test_dataset,
        batch_size=EnsembleConfig.BATCH_SIZE,
        shuffle=False,
        num_workers=4,
        pin_memory=True
    )
    
    print(f"\n🚀 Starting Training")
    print(f"  Device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'}")
    print(f"  Models: {', '.join(EnsembleConfig.MODELS)}")
    print(f"  Epochs: {EnsembleConfig.EPOCHS}")
    print(f"  Batch size: {EnsembleConfig.BATCH_SIZE}")
    print(f"  Learning rate: {EnsembleConfig.LEARNING_RATE}\n")
    
    # Initialize trainer
    trainer = EnsembleModelTrainer(
        device='cuda' if torch.cuda.is_available() else 'cpu'
    )
    
    # Train ensemble
    trainer.train_ensemble(train_loader, val_loader, epochs=EnsembleConfig.EPOCHS)
    
    # Evaluate on test set
    print("\n📊 Evaluating on test set...")
    test_accuracy = trainer.evaluate_ensemble(test_loader)
    print(f"   Test Accuracy: {test_accuracy*100:.2f}%")
    
    # Save ensemble
    print("\n💾 Saving ensemble models...")
    trainer.save_ensemble()
    
    # Save metadata
    metadata = {
        'timestamp': str(Path(EnsembleConfig.MODEL_DIR) / 'metadata.json'),
        'models': EnsembleConfig.MODELS,
        'num_classes': EnsembleConfig.NUM_CLASSES,
        'ensemble_accuracy': test_accuracy,
        'training_samples': len(train_dataset),
        'validation_samples': len(val_dataset),
        'test_samples': len(test_dataset),
        'batch_size': EnsembleConfig.BATCH_SIZE,
        'epochs': EnsembleConfig.EPOCHS,
        'device': str(trainer.device)
    }
    
    with open(Path(EnsembleConfig.MODEL_DIR) / 'metadata.json', 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"✅ Training complete!")
    print(f"\n📂 Models saved to: {EnsembleConfig.MODEL_DIR}/")
    print(f"📊 Test Accuracy: {test_accuracy*100:.2f}%")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
