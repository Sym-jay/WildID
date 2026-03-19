"""
Ensemble Model Training for ZSI Wildlife Identification
Trains 3 different architectures and combines predictions for better accuracy
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
import torchvision.models as models
from torchvision import transforms
import json
import os
from pathlib import Path
from datetime import datetime
import pickle

class EnsembleConfig:
    """Configuration for ensemble training"""
    MODELS = ['efficientnet_b0', 'resnet50', 'mobilenet_v3_small']
    NUM_CLASSES = 66
    BATCH_SIZE = 32
    EPOCHS = 20
    LEARNING_RATE = 0.001
    MODEL_DIR = 'ensemble_models'
    VERSION = '1.0'

class EnsembleModelTrainer:
    """Train and manage ensemble of 3 different models"""
    
    def __init__(self, device='cuda' if torch.cuda.is_available() else 'cpu'):
        self.device = device
        self.models = {}
        self.history = {model: {'train_loss': [], 'val_acc': []} 
                       for model in EnsembleConfig.MODELS}
        self.ensemble_accuracy = 0.0
        
        os.makedirs(EnsembleConfig.MODEL_DIR, exist_ok=True)
    
    def load_model(self, model_name):
        """Load pretrained model architecture"""
        if model_name == 'efficientnet_b0':
            model = models.efficientnet_b0(pretrained=True)
            model.classifier[1] = nn.Linear(1280, EnsembleConfig.NUM_CLASSES)
        elif model_name == 'resnet50':
            model = models.resnet50(pretrained=True)
            model.fc = nn.Linear(2048, EnsembleConfig.NUM_CLASSES)
        elif model_name == 'mobilenet_v3_small':
            model = models.mobilenet_v3_small(pretrained=True)
            model.classifier[3] = nn.Linear(1024, EnsembleConfig.NUM_CLASSES)
        else:
            raise ValueError(f"Unknown model: {model_name}")
        
        return model.to(self.device)
    
    def train_ensemble(self, train_loader, val_loader, epochs=EnsembleConfig.EPOCHS):
        """Train all 3 models in ensemble"""
        print(f"🚀 Starting Ensemble Training ({len(EnsembleConfig.MODELS)} models)")
        print(f"   Device: {self.device}")
        print(f"   Epochs: {epochs}")
        
        for model_name in EnsembleConfig.MODELS:
            print(f"\n�� Training {model_name}...")
            model = self.load_model(model_name)
            optimizer = optim.Adam(model.parameters(), lr=EnsembleConfig.LEARNING_RATE)
            criterion = nn.CrossEntropyLoss()
            
            best_val_acc = 0.0
            
            for epoch in range(epochs):
                # Training phase
                model.train()
                train_loss = 0.0
                for images, labels in train_loader:
                    images, labels = images.to(self.device), labels.to(self.device)
                    
                    optimizer.zero_grad()
                    outputs = model(images)
                    loss = criterion(outputs, labels)
                    loss.backward()
                    optimizer.step()
                    
                    train_loss += loss.item()
                
                avg_train_loss = train_loss / len(train_loader)
                self.history[model_name]['train_loss'].append(avg_train_loss)
                
                # Validation phase
                model.eval()
                correct = 0
                total = 0
                with torch.no_grad():
                    for images, labels in val_loader:
                        images, labels = images.to(self.device), labels.to(self.device)
                        outputs = model(images)
                        _, predicted = torch.max(outputs.data, 1)
                        total += labels.size(0)
                        correct += (predicted == labels).sum().item()
                
                val_acc = correct / total
                self.history[model_name]['val_acc'].append(val_acc)
                
                if val_acc > best_val_acc:
                    best_val_acc = val_acc
                    self._save_model(model, model_name)
                
                if (epoch + 1) % 5 == 0:
                    print(f"   Epoch {epoch+1:2d}/{epochs} | Loss: {avg_train_loss:.4f} | Val Acc: {val_acc:.4f}")
            
            print(f"   ✓ {model_name} best accuracy: {best_val_acc:.4f}")
            self.models[model_name] = model
    
    def ensemble_predict(self, images, confidence_threshold=0.7):
        """
        Combine predictions from all 3 models
        Returns ensemble prediction with confidence
        """
        predictions = []
        
        for model_name in EnsembleConfig.MODELS:
            if model_name not in self.models:
                model = self.load_model(model_name)
                self._load_model(model, model_name)
                self.models[model_name] = model
            
            model = self.models[model_name]
            model.eval()
            
            with torch.no_grad():
                outputs = model(images)
                probs = torch.nn.functional.softmax(outputs, dim=1)
                predictions.append(probs.cpu().numpy())
        
        # Average predictions from all models
        ensemble_probs = sum(predictions) / len(predictions)
        ensemble_pred = ensemble_probs.argmax(axis=1)
        ensemble_conf = ensemble_probs.max(axis=1)
        
        return {
            'predicted_class': ensemble_pred,
            'confidence': ensemble_conf,
            'all_predictions': predictions,  # For debugging
        }
    
    def evaluate_ensemble(self, test_loader):
        """Evaluate ensemble performance"""
        correct = 0
        total = 0
        
        for images, labels in test_loader:
            result = self.ensemble_predict(images.to(self.device))
            predicted = result['predicted_class']
            
            total += labels.size(0)
            correct += (torch.tensor(predicted) == labels).sum().item()
        
        accuracy = correct / total
        self.ensemble_accuracy = accuracy
        return accuracy
    
    def _save_model(self, model, model_name):
        """Save individual model"""
        path = f"{EnsembleConfig.MODEL_DIR}/{model_name}_v{EnsembleConfig.VERSION}.pt"
        torch.save(model.state_dict(), path)
    
    def _load_model(self, model, model_name):
        """Load individual model"""
        path = f"{EnsembleConfig.MODEL_DIR}/{model_name}_v{EnsembleConfig.VERSION}.pt"
        if os.path.exists(path):
            model.load_state_dict(torch.load(path, map_location=self.device))
    
    def save_ensemble_metadata(self):
        """Save ensemble info for deployment"""
        metadata = {
            'version': EnsembleConfig.VERSION,
            'timestamp': datetime.now().isoformat(),
            'models': list(EnsembleConfig.MODELS),
            'num_classes': EnsembleConfig.NUM_CLASSES,
            'ensemble_accuracy': self.ensemble_accuracy,
            'history': self.history,
        }
        
        with open(f"{EnsembleConfig.MODEL_DIR}/ensemble_metadata.json", 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"✓ Ensemble metadata saved")
    
    def get_summary(self):
        """Get training summary"""
        summary = {
            'model_count': len(self.models),
            'ensemble_accuracy': self.ensemble_accuracy,
            'training_history': self.history,
        }
        return summary

if __name__ == '__main__':
    print("="*60)
    print("ZSI Wildlife - Ensemble Model Training")
    print("="*60)
    
    trainer = EnsembleModelTrainer()
    
    # Note: Actual training would require DataLoader setup
    # This is a template for implementation
    print("\n📌 To use this trainer:")
    print("   1. Prepare train/val/test DataLoaders with images")
    print("   2. Call: trainer.train_ensemble(train_loader, val_loader)")
    print("   3. Evaluate: accuracy = trainer.evaluate_ensemble(test_loader)")
    print("   4. Deploy: models saved to", EnsembleConfig.MODEL_DIR)
    
    print("\n✓ Ensemble trainer ready for deployment!")
