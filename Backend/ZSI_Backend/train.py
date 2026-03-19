# Filename: train.py

import torch
import torch.amp
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
from torchvision import models, transforms
from PIL import Image
import os
import zipfile
import json
import random
import matplotlib.pyplot as plt
from collections import defaultdict
import warnings

# Suppress PIL and other non-critical warnings
warnings.filterwarnings('ignore', category=UserWarning)
warnings.filterwarnings('ignore', message='.*DecompressionBomb.*')
Image.MAX_IMAGE_PIXELS = 500000000  # Allow large images

# --- 1. ROBUST DATASET CLASS ---
class OnTheFlyDataset(Dataset):
    def __init__(self, image_paths, labels, augment_factor=150):
        self.image_paths = image_paths
        self.labels = labels
        self.num_original_images = len(image_paths)
        self.total_samples = self.num_original_images * augment_factor
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(15),
            transforms.ColorJitter(brightness=0.2, contrast=0.2),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ])

    def __len__(self):
        return self.total_samples

    def __getitem__(self, idx):
        # This robust loop prevents a crash if an image is corrupt
        while True:
            try:
                original_idx = idx % self.num_original_images
                image_path = self.image_paths[original_idx]
                label = self.labels[original_idx]
                image = Image.open(image_path).convert('RGB')
                return self.transform(image), label
            except Exception as e:
                print(f"Warning: Skipping corrupted image {image_path}. Error: {e}")
                idx += 1 # Try the next image

# --- 2. UPDATED MODEL CLASS ---
class ZSIWildlifeClassifier(nn.Module):
    def __init__(self, num_classes):
        super(ZSIWildlifeClassifier, self).__init__()
        # Use pretrained weights if available, otherwise initialize randomly
        try:
            self.backbone = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
        except:
            # Fallback if download fails
            self.backbone = models.efficientnet_b0(weights=None)
        
        for param in list(self.backbone.parameters())[:-15]:
            param.requires_grad = False
            
        num_features = self.backbone.classifier[1].in_features
        self.backbone.classifier = nn.Sequential(
            nn.Dropout(0.4),
            nn.Linear(num_features, num_classes)
        )

    def forward(self, x):
        return self.backbone(x)

# --- 3. DATA PREPARATION FUNCTION ---
def prepare_zsi_nested_dataset(dataset_root, min_images=2):
    image_paths, labels, scientific_to_idx, idx_to_info = [], [], {}, {}
    current_idx = 0
    species_data = defaultdict(lambda: {'images': [], 'common_name': ''})

    for schedule in ['Schedule_1', 'Schedule_2']:
        schedule_path = os.path.join(dataset_root, schedule)
        if not os.path.exists(schedule_path): continue
        for common_name in os.listdir(schedule_path):
            common_path = os.path.join(schedule_path, common_name)
            if not os.path.isdir(common_path): continue
            for scientific_name in os.listdir(common_path):
                scientific_path = os.path.join(common_path, scientific_name)
                if not os.path.isdir(scientific_path): continue
                for img_file in os.listdir(scientific_path):
                    if img_file.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp')):
                        img_path = os.path.join(scientific_path, img_file)
                        species_data[scientific_name]['images'].append(img_path)
                        species_data[scientific_name]['common_name'] = common_name
    
    for scientific_name, data in sorted(species_data.items()):
        if len(data['images']) >= min_images:
            scientific_to_idx[scientific_name] = current_idx
            idx_to_info[current_idx] = {
                'scientific_name': scientific_name, 'common_name': data['common_name'],
                'image_count': len(data['images'])
            }
            for img_path in data['images']:
                image_paths.append(img_path)
                labels.append(current_idx)
            current_idx += 1
    
    print(f"✓ Prepared dataset with {len(idx_to_info)} species and {len(image_paths)} total images.")
    return image_paths, labels, scientific_to_idx, idx_to_info

# --- 4. OPTIMIZED TRAINING FUNCTION WITH EARLY STOPPING ---
def train_model(image_paths, labels, idx_to_info, num_epochs=200, batch_size=64, patience=5):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print("\n" + "="*70)
    print("STARTING OPTIMIZED TRAINING WITH EARLY STOPPING")
    print("="*70)
    print(f"Device: {device}")
    print(f"Early stopping patience: {patience} epochs")
    
    dataset = OnTheFlyDataset(image_paths, labels, augment_factor=150)
    # Use num_workers > 0 for faster data loading on your multi-core CPU
    train_loader = DataLoader(dataset, batch_size=batch_size, shuffle=True, num_workers=4, pin_memory=True)

    model = ZSIWildlifeClassifier(len(idx_to_info)).to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.AdamW(model.parameters(), lr=0.0001, weight_decay=0.01)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=num_epochs)
    scaler = torch.amp.GradScaler(device='cuda')
    losses, accs = [], []
    
    best_acc = 0.0
    epochs_without_improvement = 0

    print("\nTraining started...")
    for epoch in range(num_epochs):
        model.train()
        running_loss, correct, total = 0.0, 0, 0
        for images, batch_labels in train_loader:
            images, batch_labels = images.to(device, non_blocking=True), batch_labels.to(device, non_blocking=True)
            optimizer.zero_grad(set_to_none=True)
            with torch.amp.autocast(device_type='cuda'):
                outputs = model(images)
                loss = criterion(outputs, batch_labels)
            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
            running_loss += loss.item()
            _, predicted = torch.max(outputs.data, 1)
            total += batch_labels.size(0)
            correct += (predicted == batch_labels).sum().item()
        
        epoch_loss = running_loss / len(train_loader)
        epoch_acc = correct / total
        losses.append(epoch_loss)
        accs.append(epoch_acc)
        scheduler.step()
        print(f"Epoch [{epoch+1}/{num_epochs}] Loss: {epoch_loss:.4f} Acc: {epoch_acc:.4f}")
        
        if epoch_acc > best_acc:
            best_acc = epoch_acc
            epochs_without_improvement = 0
        else:
            epochs_without_improvement += 1
            if epochs_without_improvement >= patience:
                print(f"\n⚠️  Early stopping triggered: No improvement for {patience} epochs")
                print(f"✓ Training complete! Final Acc: {epoch_acc:.4f}")
                return model, losses, accs

    print(f"\n✓ Training complete! Final Acc: {accs[-1]:.4f}")
    return model, losses, accs

# --- 5. MAIN EXECUTION BLOCK (FOR LOCAL MACHINE) ---
if __name__ == '__main__':
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")

    zip_path = 'zsi_dataset.zip'
    if not os.path.exists(zip_path):
        print(f"\n❌ ERROR: '{zip_path}' not found.")
        print("Please make sure your 'ZSI.zip' dataset is in the same directory as this script.")
    else:
        print(f"\nFound '{zip_path}', extracting...")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall('.')
        print("✓ Extracted.")

        dataset_root = './ZSI/Wildlife Datasets'
        if not os.path.exists(dataset_root):
             print(f"❌ ERROR: Could not find '{dataset_root}' after extraction.")
             print("Please check the folder structure inside your zip file.")
        else:
            paths, labels, sci_to_idx, idx_to_info = prepare_zsi_nested_dataset(dataset_root, min_images=2)
            model, losses, accs = train_model(paths, labels, idx_to_info)
            
            # --- Save all outputs ---
            plt.figure(figsize=(14, 5))
            plt.subplot(1, 2, 1); plt.plot(losses); plt.title('Training Loss'); plt.grid(True)
            plt.subplot(1, 2, 2); plt.plot(accs, color='green'); plt.title('Training Accuracy'); plt.grid(True)
            plt.tight_layout()
            plt.savefig('training_progress.png')
            print("\n✓ Saved training plot to 'training_progress.png'")
            
            torch.save(model.state_dict(), 'zsi_wildlife_model.pth')
            print("✓ Saved model weights to 'zsi_wildlife_model.pth'")
            
            mapping = {'scientific_to_idx': sci_to_idx, 'idx_to_info': idx_to_info}
            with open('zsi_class_mapping.json', 'w') as f: json.dump(mapping, f, indent=2)
            print("✓ Saved class mapping to 'zsi_class_mapping.json'")
