# Filename: api.py

import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image
import torch
import torch.nn as nn
from torchvision import models, transforms
import json
from functools import wraps

# --- Configuration from Environment Variables ---
API_KEY = os.getenv('ZSI_API_KEY', 'default-dev-key-change-in-production')
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png'}
ALLOWED_ORIGINS = os.getenv('ALLOWED_ORIGINS', 'http://localhost:*').split(',')

# --- API Key Authentication Decorator ---
def require_api_key(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get('X-API-Key')
        if not api_key or api_key != API_KEY:
            return jsonify({'error': 'Unauthorized: Invalid or missing API key'}), 401
        return f(*args, **kwargs)
    return decorated_function

# --- Helper Function ---
def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# --- Re-define your model class ---
class ZSIWildlifeClassifier(nn.Module):
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

# --- Load Model and Mappings ---
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

with open('zsi_class_mapping.json', 'r') as f:
    class_mapping = json.load(f)
idx_to_info = class_mapping['idx_to_info']

model = ZSIWildlifeClassifier(num_classes=len(idx_to_info))
model.load_state_dict(torch.load('zsi_wildlife_model.pth', map_location=device))
model.to(device)
model.eval()

# --- Define Image Transformations ---
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# --- Initialize Flask App ---
app = Flask(__name__)
CORS(app, origins=ALLOWED_ORIGINS)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for monitoring"""
    return jsonify({
        'status': 'healthy',
        'model': 'EfficientNet-B0',
        'device': str(device),
        'species_count': len(idx_to_info)
    }), 200

@app.route('/predict', methods=['POST'])
@require_api_key
def predict():
    """Identify wildlife species from image"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file part in request'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    # Validate file extension
    if not allowed_file(file.filename):
        return jsonify({'error': f'Invalid file type. Allowed: {", ".join(ALLOWED_EXTENSIONS)}'}), 400

    # Check file size
    file.seek(0, os.SEEK_END)
    file_size = file.tell()
    file.seek(0)
    if file_size > MAX_FILE_SIZE:
        return jsonify({'error': f'File too large. Max size: {MAX_FILE_SIZE / 1024 / 1024:.0f}MB'}), 413

    try:
        img = Image.open(file.stream).convert('RGB')
        img_tensor = transform(img).unsqueeze(0).to(device)

        with torch.no_grad():
            outputs = model(img_tensor)
            probabilities = torch.nn.functional.softmax(outputs, dim=1)
            top3_probs, top3_indices = torch.topk(probabilities, 3)

        results = []
        confidence_threshold = 0.55
        
        for i in range(top3_indices.size(1)):
            idx = str(top3_indices[0][i].item())
            confidence = float(top3_probs[0][i].item())
            
            # Only include results above threshold
            if confidence >= confidence_threshold:
                info = idx_to_info.get(idx, {"common_name": "Unknown"})
                results.append({
                    'label': info['common_name'],
                    'confidence': confidence
                })

        # If no results above threshold, return unidentified message
        if not results:
            return jsonify([{
                'label': 'Image Not Recognized',
                'confidence': 0.0,
                'message': 'The image does not clearly match any wildlife species in our database. Please try a clearer or different image.'
            }]), 200

        return jsonify(results), 200

    except Exception as e:
        # Don't expose internal error details in production
        return jsonify({'error': 'Failed to process image. Please try again.'}), 500

if __name__ == '__main__':
    # Run with security hardening
    # In production, use a WSGI server like Gunicorn instead of Flask's built-in server
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=False,  # CRITICAL: Disable debug mode in production
        threaded=True
    )
