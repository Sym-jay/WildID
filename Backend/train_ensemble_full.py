#!/usr/bin/env python3
"""
ZSI Wildlife - Full Ensemble Training with Dataset
Extracts dataset and trains 3 models
"""

import os
import sys
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
import torchvision.models as models
from torchvision import transforms
import json
from pathlib import Path
from datetime import datetime
import zipfile
from PIL import Image
import numpy as np

print("\n" + "="*70)
print("ZSI Wildlife - Ensemble Model Training (Full Dataset)")
print("="*70 + "\n")

# Configuration
CONFIG = {
    'batch_size': 32,
    'epochs': 10,  # Reduced for faster training
    'learning_rate': 0.001,
    'num_classes': 66,
    'device': 'cuda' if torch.cuda.is_available() else 'cpu'
}

class ZSIDataset(Dataset):
    """Simple dataset from extracted images"""
    
    def __init__(self, image_paths, labels, transform=None):
        self.image_paths = image_paths
        self.labels = labels
        self.transform = transform
    
    def __len__(self):
        return len(self.image_paths)
    
    def __getitem__(self, idx):
        try:
            img = Image.open(self.image_paths[idx]).convert('RGB')
            if self.transform:
                img = self.transform(img)
            return img, self.labels[idx]
        except:
            # Return black image on error
            return torch.zeros(3, 224, 224), self.labels[idx]

def extract_dataset():
    """Extract zsi_dataset.zip"""
    print("📦 Extracting dataset...")
    
    zip_path = Path('ZSI_Backend/zsi_dataset.zip')
    if not zip_path.exists():
        print(f"❌ Dataset not found: {zip_path}")
        return None
    
    extract_dir = Path('zsi_dataset')
    if not extract_dir.exists():
        print(f"   Extracting to: {extract_dir}")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
    
    print(f"✓ Dataset ready at: {extract_dir}")
    return extract_dir

def load_images_from_directory(dataset_dir, max_images_per_class=100):
    """Load images from extracted dataset"""
    print(f"\n📂 Loading images from {dataset_dir}...")
    
    image_paths = []
    labels = []
    class_id = 0
    
    # Look for subdirectories (species)
    for species_dir in sorted(dataset_dir.glob('*')):
        if not species_dir.is_dir():
            continue
        
        species_name = species_dir.name
        image_files = list(species_dir.glob('*.jpg')) + list(species_dir.glob('*.png')) + list(species_dir.glob('*.jpeg'))
        
        # Limit per species to speed up training
        image_files = image_files[:max_images_per_class]
        
        if len(image_files) > 0:
            for img_path in image_files:
                image_paths.append(str(img_path))
                labels.append(class_id)
            
            print(f"  ✓ {species_name}: {len(image_files)} images (class {class_id})")
            class_id += 1
    
    print(f"\n✓ Loaded {len(image_paths)} total images")
    return image_paths, labels

def create_dataloaders(image_paths, labels):
    """Create train/val/test splits"""
    print("\n🔄 Creating data loaders...")
    
    # Transforms
    train_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(10),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406],
                           std=[0.229, 0.224, 0.225])
    ])
    
    val_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406],
                           std=[0.229, 0.224, 0.225])
    ])
    
    # Split dataset
    total = len(image_paths)
    train_size = int(0.8 * total)
    val_size = int(0.1 * total)
    
    indices = np.random.permutation(total)
    train_idx = indices[:train_size]
    val_idx = indices[train_size:train_size+val_size]
    test_idx = indices[train_size+val_size:]
    
    train_paths = [image_paths[i] for i in train_idx]
    train_labels = [labels[i] for i in train_idx]
    
    val_paths = [image_paths[i] for i in val_idx]
    val_labels = [labels[i] for i in val_idx]
    
    test_paths = [image_paths[i] for i in test_idx]
    test_labels = [labels[i] for i in test_idx]
    
    # Create dataloaders
    train_dataset = ZSIDataset(train_paths, train_labels, train_transform)
    val_dataset = ZSIDataset(val_paths, val_labels, val_transform)
    test_dataset = ZSIDataset(test_paths, test_labels, val_transform)
    
    train_loader = DataLoader(train_dataset, batch_size=CONFIG['batch_size'], shuffle=True, num_workers=2)
    val_loader = DataLoader(val_dataset, batch_size=CONFIG['batch_size'], shuffle=False, num_workers=2)
    test_loader = DataLoader(test_dataset, batch_size=CONFIG['batch_size'], shuffle=False, num_workers=2)
    
    print(f"  Train: {len(train_paths)} | Val: {len(val_paths)} | Test: {len(test_paths)}")
    return train_loader, val_loader, test_loader

def train_model(model, train_loader, val_loader, model_name, device, epochs=CONFIG['epochs']):
    """Train a single model"""
    print(f"\n🚀 Training {model_name}...")
    
    model = model.to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=CONFIG['learning_rate'])
    
    best_val_acc = 0
    
    for epoch in range(epochs):
        # Training phase
        model.train()
        train_loss = 0
        for batch_idx, (images, labels) in enumerate(train_loader):
            images, labels = images.to(device), labels.to(device)
            
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
            
            if batch_idx % 5 == 0:
                print(f"  Epoch {epoch+1}/{epochs} - Batch {batch_idx}/{len(train_loader)} - Loss: {loss.item():.4f}")
        
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
        print(f"  Epoch {epoch+1} - Val Acc: {val_acc*100:.2f}%")
        
        if val_acc > best_val_acc:
            best_val_acc = val_acc
    
    print(f"✓ {model_name} trained - Best Val Acc: {best_val_acc*100:.2f}%")
    return model, best_val_acc

def evaluate_ensemble(models, test_loader, device):
    """Evaluate ensemble voting"""
    print("\n📊 Evaluating Ensemble...")
    
    correct = 0
    total = 0
    
    for images, labels in test_loader:
        images, labels = images.to(device), labels.to(device)
        
        # Get predictions from all models
        ensemble_pred = None
        with torch.no_grad():
            for model in models:
                model.eval()
                outputs = model(images)
                probs = torch.softmax(outputs, dim=1)
                
                if ensemble_pred is None:
                    ensemble_pred = probs / len(models)
                else:
                    ensemble_pred += probs / len(models)
        
        _, predicted = torch.max(ensemble_pred, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()
    
    ensemble_acc = correct / total
    print(f"✓ Ensemble Test Accuracy: {ensemble_acc*100:.2f}%")
    return ensemble_acc

def main():
    device = CONFIG['device']
    print(f"Device: {device}\n")
    
    # Extract dataset
    dataset_dir = extract_dataset()
    if dataset_dir is None:
        return 1
    
    # Load images
    image_paths, labels = load_images_from_directory(dataset_dir)
    if len(image_paths) == 0:
        print("❌ No images found!")
        return 1
    
    # Create dataloaders
    train_loader, val_loader, test_loader = create_dataloaders(image_paths, labels)
    
    # Train ensemble models
    models = []
    results = {}
    
    # Model 1: EfficientNet-B0
    print("\n" + "="*70)
    model1 = models.models.efficientnet_b0(pretrained=True)
    model1.classifier[1] = nn.Linear(1280, CONFIG['num_classes'])
    model1, acc1 = train_model(model1, train_loader, val_loader, "EfficientNet-B0", device)
    models.append(model1)
    results['efficientnet_b0'] = acc1
    
    # Save Model 1
    torch.save(model1.state_dict(), 'ensemble_models/model_efficientnet_b0.pth')
    print("✓ Saved EfficientNet-B0")
    
    # Model 2: ResNet-50
    print("\n" + "="*70)
    model2 = models.models.resnet50(pretrained=True)
    model2.fc = nn.Linear(2048, CONFIG['num_classes'])
    model2, acc2 = train_model(model2, train_loader, val_loader, "ResNet-50", device)
    models.append(model2)
    results['resnet50'] = acc2
    
    # Save Model 2
    torch.save(model2.state_dict(), 'ensemble_models/model_resnet50.pth')
    print("✓ Saved ResNet-50")
    
    # Model 3: MobileNet-V3
    print("\n" + "="*70)
    model3 = models.models.mobilenet_v3_small(pretrained=True)
    model3.classifier[3] = nn.Linear(1024, CONFIG['num_classes'])
    model3, acc3 = train_model(model3, train_loader, val_loader, "MobileNet-V3", device)
    models.append(model3)
    results['mobilenet_v3'] = acc3
    
    # Save Model 3
    torch.save(model3.state_dict(), 'ensemble_models/model_mobilenet_v3.pth')
    print("✓ Saved MobileNet-V3")
    
    # Evaluate ensemble
    print("\n" + "="*70)
    ensemble_acc = evaluate_ensemble(models, test_loader, device)
    
    # Save results
    results['ensemble'] = ensemble_acc
    results['timestamp'] = datetime.now().isoformat()
    
    with open('ensemble_models/training_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print("\n" + "="*70)
    print("✅ ENSEMBLE TRAINING COMPLETE")
    print("="*70)
    print(f"\nResults:")
    print(f"  EfficientNet-B0: {results['efficientnet_b0']*100:.2f}%")
    print(f"  ResNet-50:       {results['resnet50']*100:.2f}%")
    print(f"  MobileNet-V3:    {results['mobilenet_v3']*100:.2f}%")
    print(f"  Ensemble:        {results['ensemble']*100:.2f}%")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
