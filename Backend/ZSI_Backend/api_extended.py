# Filename: api_extended.py
# Extended API with Ensemble Predictions and SMS Alerts
# Backwards compatible with existing /predict endpoint

import os
import sys
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image
import json
from functools import wraps
import torch

# Import ensemble predictor
try:
    from ensemble_predictor import get_ensemble_predictor
    ENSEMBLE_AVAILABLE = True
except ImportError:
    ENSEMBLE_AVAILABLE = False
    print("Warning: ensemble_predictor not found, ensemble mode disabled")

# Import SMS service
try:
    from sms_service import get_sms_service
    SMS_AVAILABLE = True
except ImportError:
    SMS_AVAILABLE = False
    print("Warning: sms_service not found, SMS disabled")

# Import original API components
from api import (
    ZSIWildlifeClassifier, device, class_mapping, model, 
    transform, MAX_FILE_SIZE, ALLOWED_EXTENSIONS, require_api_key, allowed_file
)

# --- Configuration ---
API_KEY = os.getenv('ZSI_API_KEY', 'default-dev-key-change-in-production')
SMS_PROVIDER = os.getenv('SMS_PROVIDER', 'goi')

# --- Initialize Flask App ---
app = Flask(__name__)
CORS(app)

# --- Initialize Services ---
ensemble_predictor = None
sms_service = None

if ENSEMBLE_AVAILABLE:
    try:
        ensemble_predictor = get_ensemble_predictor(num_classes=len(class_mapping.get('idx_to_info', {})))
        ensemble_predictor.load_models('ensemble_models')
        print("✓ Ensemble predictor loaded")
    except Exception as e:
        print(f"✗ Failed to load ensemble: {str(e)}")
        ENSEMBLE_AVAILABLE = False

if SMS_AVAILABLE:
    try:
        sms_service = get_sms_service(SMS_PROVIDER)
        print("✓ SMS service loaded")
    except Exception as e:
        print(f"✗ Failed to load SMS service: {str(e)}")
        SMS_AVAILABLE = False


def _normalize_prediction_entry(entry):
    """Normalize prediction entry into {label, confidence} format."""
    if not isinstance(entry, dict):
        return None

    label = entry.get('label') or entry.get('species') or entry.get('common_name')
    confidence = entry.get('confidence')

    if not isinstance(label, str) or confidence is None:
        return None

    try:
        confidence_value = float(confidence)
    except (TypeError, ValueError):
        return None

    return {
        'label': label,
        'confidence': confidence_value
    }


def _normalize_ensemble_response(result):
    """
    Normalize ensemble predictor output into a stable contract used by Flutter.
    Preserves legacy keys while adding normalized keys.
    """
    ensemble_raw = result.get('ensemble', {}) if isinstance(result, dict) else {}
    ensemble_entry = _normalize_prediction_entry(ensemble_raw) if isinstance(ensemble_raw, dict) else None

    individual = result.get('individual_models', {}) if isinstance(result, dict) else {}

    normalized = {
        'success': True,
        'contract_version': '2.0',
        'model_type': 'ensemble',
        'ensemble_accuracy': result.get('ensemble_accuracy', 0.0),
        'ensemble': ensemble_entry,
        'efficientnet': [],
        'resnet': [],
        'mobilenet': [],
        # Keep legacy/debug fields for backwards compatibility
        'individual_models': individual,
        'model_count': result.get('model_count'),
        'weights': result.get('weights', {}),
    }

    for model_name in ['efficientnet', 'resnet', 'mobilenet']:
        model_data = individual.get(model_name)
        if not isinstance(model_data, dict):
            continue

        top_k = model_data.get('top_5', [])
        if isinstance(top_k, list):
            normalized[model_name] = [
                entry for entry in (_normalize_prediction_entry(item) for item in top_k) if entry is not None
            ]

        # Fallback to single top prediction when top_5 is absent/invalid
        if not normalized[model_name]:
            single_entry = _normalize_prediction_entry(model_data)
            if single_entry:
                normalized[model_name] = [single_entry]

    return normalized


# --- Original Health Check ---
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for monitoring"""
    return jsonify({
        'status': 'healthy',
        'model': 'EfficientNet-B0 (Primary)',
        'ensemble_available': ENSEMBLE_AVAILABLE,
        'sms_available': SMS_AVAILABLE,
        'device': str(device),
        'species_count': len(class_mapping.get('idx_to_info', {}))
    }), 200


# --- Original Single Model Prediction ---
@app.route('/predict', methods=['POST'])
@require_api_key
def predict():
    """
    Identify wildlife species from image using single EfficientNet-B0 model
    Endpoint: POST /predict
    Returns: Top 3 predictions with confidence scores
    """
    if 'file' not in request.files:
        return jsonify({'error': 'No file part in request'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    if not allowed_file(file.filename):
        return jsonify({'error': f'Invalid file type. Allowed: {", ".join(ALLOWED_EXTENSIONS)}'}), 400

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
        idx_to_info = class_mapping.get('idx_to_info', {})
        for i in range(top3_indices.size(1)):
            idx = str(top3_indices[0][i].item())
            info = idx_to_info.get(idx, {"common_name": "Unknown"})
            results.append({
                'label': info['common_name'],
                'confidence': float(top3_probs[0][i].item()),
                'confidence_percent': f"{float(top3_probs[0][i].item())*100:.2f}%"
            })

        return jsonify({
            'success': True,
            'model': 'EfficientNet-B0',
            'predictions': results,
            'device': str(device)
        }), 200

    except Exception as e:
        return jsonify({'error': 'Failed to process image. Please try again.'}), 500


# --- NEW: Ensemble Model Prediction ---
@app.route('/predict-ensemble', methods=['POST'])
@require_api_key
def predict_ensemble():
    """
    Identify wildlife species using ensemble voting (3 models)
    Endpoint: POST /predict-ensemble
    Returns: Ensemble prediction + individual model predictions
    
    Ensemble composition:
    - EfficientNet-B0: 40% weight (87.5% accuracy)
    - ResNet-50: 35% weight (85% accuracy)
    - MobileNet-V3: 25% weight (82% accuracy)
    Ensemble accuracy: ~88.5%
    """
    
    if not ENSEMBLE_AVAILABLE:
        return jsonify({
            'error': 'Ensemble models not loaded',
            'fallback': 'Use /predict endpoint for single model'
        }), 503

    if 'file' not in request.files:
        return jsonify({'error': 'No file part in request'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    if not allowed_file(file.filename):
        return jsonify({'error': f'Invalid file type. Allowed: {", ".join(ALLOWED_EXTENSIONS)}'}), 400

    file.seek(0, os.SEEK_END)
    file_size = file.tell()
    file.seek(0)
    if file_size > MAX_FILE_SIZE:
        return jsonify({'error': f'File too large. Max size: {MAX_FILE_SIZE / 1024 / 1024:.0f}MB'}), 413

    try:
        # Save temporary file for ensemble predictor
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp:
            file.save(tmp.name)
            tmp_path = tmp.name

        # Get ensemble prediction
        result = ensemble_predictor.predict(tmp_path)
        
        # Clean up temp file
        os.remove(tmp_path)

        if result.get('success'):
            return jsonify(_normalize_ensemble_response(result)), 200
        else:
            return jsonify({'error': result.get('error', 'Prediction failed')}), 500

    except Exception as e:
        return jsonify({'error': f'Ensemble prediction failed: {str(e)}'}), 500


# --- NEW: SMS OTP Endpoint ---
@app.route('/api/sms/send-otp', methods=['POST'])
@require_api_key
def send_otp():
    """
    Send OTP via SMS for 2FA
    Endpoint: POST /api/sms/send-otp
    Body: {
        "phone": "+919876543210",
        "otp_code": "123456"
    }
    """
    
    if not SMS_AVAILABLE:
        return jsonify({'error': 'SMS service not available'}), 503

    data = request.get_json()
    if not data or 'phone' not in data or 'otp_code' not in data:
        return jsonify({'error': 'Missing phone or otp_code'}), 400

    result = sms_service.send_otp(data['phone'], data['otp_code'])
    
    if result.get('success'):
        return jsonify({
            'success': True,
            'message': 'OTP sent successfully',
            'cost_inr': sms_service.sms_cost_per_message
        }), 200
    else:
        return jsonify({
            'success': False,
            'error': result.get('message', 'Failed to send OTP')
        }), 500


# --- NEW: Send Endangered Species Alert ---
@app.route('/api/sms/endangered-alert', methods=['POST'])
@require_api_key
def send_endangered_alert():
    """
    Send SMS alert when endangered species is identified
    Endpoint: POST /api/sms/endangered-alert
    Body: {
        "expert_phone": "+919876543210",
        "species_name": "Bengal Tiger",
        "user_name": "user_john",
        "location": "Kaziranga NP"
    }
    """
    
    if not SMS_AVAILABLE:
        return jsonify({'error': 'SMS service not available'}), 503

    data = request.get_json()
    required_fields = ['expert_phone', 'species_name', 'user_name', 'location']
    if not data or not all(field in data for field in required_fields):
        return jsonify({'error': f'Missing required fields: {required_fields}'}), 400

    result = sms_service.send_endangered_alert(
        data['expert_phone'],
        data['species_name'],
        data['user_name'],
        data['location']
    )
    
    if result.get('success'):
        return jsonify({
            'success': True,
            'message': 'Alert sent successfully',
            'cost_inr': sms_service.sms_cost_per_message
        }), 200
    else:
        return jsonify({
            'success': False,
            'error': result.get('message', 'Failed to send alert')
        }), 500


# --- NEW: Send Verification Alert ---
@app.route('/api/sms/verification-alert', methods=['POST'])
@require_api_key
def send_verification_alert():
    """
    Notify user when their identification is verified
    Endpoint: POST /api/sms/verification-alert
    Body: {
        "user_phone": "+919876543210",
        "species_name": "Bengal Tiger",
        "verified": true,
        "expert_note": "Excellent photo!"
    }
    """
    
    if not SMS_AVAILABLE:
        return jsonify({'error': 'SMS service not available'}), 503

    data = request.get_json()
    if not data or 'user_phone' not in data or 'species_name' not in data:
        return jsonify({'error': 'Missing user_phone or species_name'}), 400

    result = sms_service.send_verification_alert(
        data['user_phone'],
        data['species_name'],
        data.get('verified', False),
        data.get('expert_note', '')
    )
    
    if result.get('success'):
        return jsonify({
            'success': True,
            'message': 'Verification alert sent',
            'cost_inr': sms_service.sms_cost_per_message
        }), 200
    else:
        return jsonify({
            'success': False,
            'error': result.get('message', 'Failed to send alert')
        }), 500


# --- NEW: SMS Status and Logs ---
@app.route('/api/sms/status', methods=['GET'])
@require_api_key
def sms_status():
    """
    Get SMS service status and cost info
    Endpoint: GET /api/sms/status
    """
    
    if not SMS_AVAILABLE:
        return jsonify({'status': 'unavailable'}), 503

    cost_info = sms_service.get_monthly_cost()
    
    return jsonify({
        'status': 'available',
        'provider': SMS_PROVIDER,
        'sms_stats': cost_info,
        'cost_per_message_inr': sms_service.sms_cost_per_message
    }), 200


# --- NEW: Ensemble Model Info ---
@app.route('/api/ensemble/info', methods=['GET'])
@require_api_key
def ensemble_info():
    """
    Get ensemble model information
    Endpoint: GET /api/ensemble/info
    """
    
    if not ENSEMBLE_AVAILABLE:
        return jsonify({
            'status': 'unavailable',
            'message': 'Ensemble models not loaded'
        }), 503

    return jsonify(ensemble_predictor.get_model_info()), 200


# --- Error Handlers ---
@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'error': 'Endpoint not found',
        'available_endpoints': [
            'GET /health',
            'POST /predict (single model)',
            'POST /predict-ensemble (ensemble voting)',
            'POST /api/sms/send-otp',
            'POST /api/sms/endangered-alert',
            'POST /api/sms/verification-alert',
            'GET /api/sms/status',
            'GET /api/ensemble/info'
        ]
    }), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    print("="*60)
    print("ZSI Wildlife Identifier - Extended API")
    print("="*60)
    print(f"Ensemble Available: {ENSEMBLE_AVAILABLE}")
    print(f"SMS Available: {SMS_AVAILABLE}")
    print("="*60)
    
    # Run with security hardening
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=False,
        threaded=True
    )
