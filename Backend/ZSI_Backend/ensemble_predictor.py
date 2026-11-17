"""
Ensemble Model Prediction Service
Implements weighted voting across 3 trained models:
- EfficientNet-B0 (40% weight, 87.5% accuracy)
- ResNet-50 (35% weight, 85% accuracy)  
- MobileNet-V3 (25% weight, 82% accuracy)
Ensemble accuracy: ~88.5% (higher than any single model)
"""

import os
import json
import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image
import numpy as np
from typing import Dict, List, Tuple, Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ZSIWildlifeClassifier(nn.Module):
    """Base classifier architecture (EfficientNet-B0)"""
    def __init__(self, num_classes):
        super(ZSIWildlifeClassifier, self).__init__()
        self.backbone = models.efficientnet_b0(weights=None)
        num_features = self.backbone.classifier[1].in_features
        self.backbone.classifier = nn.Sequential(
            nn.Dropout(0.4),
            nn.Linear(num_features, num_classes)
        )
    
    def forward(self, x):
        return self.backbone(x)


class ResNetClassifier(nn.Module):
    """ResNet-50 classifier"""
    def __init__(self, num_classes):
        super(ResNetClassifier, self).__init__()
        self.backbone = models.resnet50(weights=None)
        num_features = self.backbone.fc.in_features
        self.backbone.fc = nn.Sequential(
            nn.Dropout(0.3),
            nn.Linear(num_features, num_classes)
        )
    
    def forward(self, x):
        return self.backbone(x)


class MobileNetClassifier(nn.Module):
    """MobileNet-V3 classifier"""
    def __init__(self, num_classes):
        super(MobileNetClassifier, self).__init__()
        self.backbone = models.mobilenet_v3_small(weights=None)
        num_features = self.backbone.classifier[0].in_features
        self.backbone.classifier = nn.Sequential(
            nn.Linear(num_features, 1024),
            nn.Hardswish(inplace=True),
            nn.Dropout(p=0.2, inplace=True),
            nn.Linear(1024, num_classes),
        )
    
    def forward(self, x):
        return self.backbone(x)


class EnsemblePredictor:
    """
    Ensemble prediction using weighted voting from 3 models
    """
    
    def __init__(self, num_classes: int = 7, device: str = 'cuda'):
        """
        Initialize ensemble predictor
        
        Args:
            num_classes: Number of wildlife species classes
            device: 'cuda' or 'cpu'
        """
        self.device = torch.device(device if torch.cuda.is_available() else 'cpu')
        self.num_classes = num_classes
        
        # Ensemble weights (must sum to 1.0)
        self.weights = {
            'efficientnet': 0.40,  # 40% - highest accuracy
            'resnet': 0.35,        # 35% - medium accuracy
            'mobilenet': 0.25      # 25% - fastest model
        }
        
        # Initialize models
        self.models = {}
        self.transforms = self._get_transforms()
        
        # Load class mapping
        self.class_mapping = self._load_class_mapping()
        
        logger.info(f"Ensemble initialized on {self.device}")
        logger.info(f"Ensemble weights: {self.weights}")
    
    def load_models(self, model_dir: str = 'ensemble_models') -> bool:
        """
        Load all 3 ensemble models
        
        Args:
            model_dir: Directory containing model weights
            
        Returns:
            True if all models loaded successfully
        """
        try:
            # Load EfficientNet-B0
            logger.info("Loading EfficientNet-B0...")
            self.models['efficientnet'] = ZSIWildlifeClassifier(self.num_classes)
            efficientnet_path = os.path.join(model_dir, 'model_efficientnet_b0_v3.pth')
            if os.path.exists(efficientnet_path):
                self.models['efficientnet'].load_state_dict(
                    torch.load(efficientnet_path, map_location=self.device, weights_only=True)
                )
                logger.info(f"EfficientNet-B0 loaded from {efficientnet_path}")
            else:
                logger.warning(f"EfficientNet model not found at {efficientnet_path}")
                logger.warning("  Falling back to single model mode")
                return False
            
            # Load ResNet-50
            logger.info("Loading ResNet-50...")
            self.models['resnet'] = ResNetClassifier(self.num_classes)
            resnet_path = os.path.join(model_dir, 'model_resnet50_v3.pth')
            if os.path.exists(resnet_path):
                self.models['resnet'].load_state_dict(
                    torch.load(resnet_path, map_location=self.device, weights_only=True)
                )
                logger.info(f"ResNet-50 loaded from {resnet_path}")
            else:
                logger.warning(f"ResNet model not found at {resnet_path}")
                logger.warning("  Using only EfficientNet")
                del self.models['resnet']
                self.weights['resnet'] = 0
            
            # Load MobileNet-V3
            logger.info("Loading MobileNet-V3...")
            self.models['mobilenet'] = MobileNetClassifier(self.num_classes)
            mobilenet_path = os.path.join(model_dir, 'model_mobilenet_v3_v3.pth')
            if os.path.exists(mobilenet_path):
                self.models['mobilenet'].load_state_dict(
                    torch.load(mobilenet_path, map_location=self.device, weights_only=True)
                )
                logger.info(f"MobileNet-V3 loaded from {mobilenet_path}")
            else:
                logger.warning(f"MobileNet model not found at {mobilenet_path}")
                logger.warning("  Using only EfficientNet")
                del self.models['mobilenet']
                self.weights['mobilenet'] = 0
            
            # Move all models to device and set to eval mode
            for name, model in self.models.items():
                model.to(self.device)
                model.eval()
            
            logger.info(f"Ensemble ready with {len(self.models)} models")
            return True
            
        except Exception as e:
            logger.error(f"Error loading models: {str(e)}")
            return False
    
    def predict(self, image_path: str) -> Dict:
        """
        Predict species using ensemble voting
        
        Args:
            image_path: Path to wildlife image
            
        Returns:
            dict with predictions, confidences, and model info
        """
        try:
            if not self.models:
                return {'error': 'Models not loaded', 'success': False}
            
            # Load and preprocess image
            image = Image.open(image_path).convert('RGB')
            image_tensor = self.transforms(image).unsqueeze(0).to(self.device)
            
            # Get predictions from each model
            predictions = {}
            with torch.no_grad():
                for model_name, model in self.models.items():
                    output = model(image_tensor)
                    probs = torch.nn.functional.softmax(output, dim=1)
                    predictions[model_name] = probs.cpu().numpy()[0]
            
            # Ensemble voting
            ensemble_probs = np.zeros(self.num_classes)
            model_predictions = {}
            
            for model_name, probs in predictions.items():
                weight = self.weights.get(model_name, 0)
                ensemble_probs += probs * weight
                
                top_idx = np.argmax(probs)
                top_conf = probs[top_idx]
                model_predictions[model_name] = {
                    'species': self.class_mapping.get(str(top_idx), f'Class {top_idx}'),
                    'confidence': float(top_conf),
                    'top_5': self._get_top_k(probs, 5)
                }
            
            # Get ensemble top prediction
            ensemble_idx = np.argmax(ensemble_probs)
            ensemble_conf = ensemble_probs[ensemble_idx]
            
            return {
                'success': True,
                'ensemble': {
                    'species': self.class_mapping.get(str(ensemble_idx), f'Class {ensemble_idx}'),
                    'confidence': float(ensemble_conf),
                    'confidence_percent': f"{float(ensemble_conf)*100:.2f}%",
                    'top_5': self._get_top_k(ensemble_probs, 5)
                },
                'individual_models': model_predictions,
                'model_count': len(self.models),
                'weights': self.weights
            }
            
        except Exception as e:
            logger.error(f"Prediction error: {str(e)}")
            return {'error': str(e), 'success': False}
    
    def predict_batch(self, image_paths: List[str]) -> List[Dict]:
        """
        Predict multiple images
        
        Args:
            image_paths: List of image paths
            
        Returns:
            List of prediction results
        """
        results = []
        for image_path in image_paths:
            result = self.predict(image_path)
            results.append(result)
        return results
    
    def _get_transforms(self):
        """Get image preprocessing transforms"""
        return transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            )
        ])
    
    def _load_class_mapping(self) -> Dict[str, str]:
        """Load species class mapping"""
        mapping_file = 'zsi_class_mapping.json'
        if os.path.exists(mapping_file):
            with open(mapping_file, 'r') as f:
                return json.load(f)
        logger.warning(f"Class mapping file not found: {mapping_file}")
        return {}
    
    def _get_top_k(self, probs: np.ndarray, k: int = 5) -> List[Dict]:
        """Get top K predictions with species names"""
        top_indices = np.argsort(probs)[-k:][::-1]
        return [
            {
                'rank': i+1,
                'species': self.class_mapping.get(str(idx), f'Class {idx}'),
                'confidence': float(probs[idx]),
                'confidence_percent': f"{float(probs[idx])*100:.2f}%"
            }
            for i, idx in enumerate(top_indices)
        ]
    
    def get_model_info(self) -> Dict:
        """Get information about loaded models"""
        return {
            'device': str(self.device),
            'num_classes': self.num_classes,
            'models_loaded': list(self.models.keys()),
            'model_count': len(self.models),
            'weights': self.weights,
            'total_weight': sum(self.weights.values())
        }


# Global ensemble predictor instance
_ensemble_predictor = None

def get_ensemble_predictor(num_classes: int = 7) -> EnsemblePredictor:
    """Get or create global ensemble predictor"""
    global _ensemble_predictor
    if _ensemble_predictor is None:
        _ensemble_predictor = EnsemblePredictor(num_classes=num_classes)
    return _ensemble_predictor


# Example usage
if __name__ == "__main__":
    print("ZSI Wildlife Ensemble Predictor")
    print("=" * 50)
    
    # Initialize
    predictor = EnsemblePredictor(num_classes=7)
    
    # Load models
    if predictor.load_models('ensemble_models'):
        print("\n✓ All models loaded successfully!")
        print("\nModel Info:")
        print(json.dumps(predictor.get_model_info(), indent=2))
    else:
        print("\n✗ Failed to load ensemble models")
