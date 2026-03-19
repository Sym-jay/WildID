# 🔧 ZSI Setup Instructions

## ⚠️ Environment Setup Required

### Backend Setup (First Time)

**Option 1: Using Virtual Environment (Recommended)**
```bash
cd /home/sym/ZSI/Backend/ZSI_Backend

# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Verify installation
python -c "import torch, flask; print('✅ All dependencies ready')"
```

**Option 2: Direct Installation**
```bash
cd /home/sym/ZSI/Backend/ZSI_Backend
pip3 install -r requirements.txt
```

### Frontend Setup (First Time)

```bash
cd /home/sym/ZSI/Frontend/ZSI_Frontend

# Get dependencies
flutter pub get

# Run on device/emulator
flutter run
```

## ✅ Verification Checklist

### Backend
- [ ] Navigate to Backend/ZSI_Backend
- [ ] Activate virtual environment (if using venv)
- [ ] Python can import torch, flask
- [ ] Start Flask: `python api.py`
- [ ] Health check: `curl http://localhost:5000/health`

### Frontend
- [ ] Navigate to Frontend/ZSI_Frontend
- [ ] Run: `flutter run`
- [ ] App launches on device/emulator
- [ ] Can take photo and see identification

### Integration
- [ ] Flask API running (localhost:5000)
- [ ] Flutter app can identify species (cloud mode)
- [ ] Disconnect WiFi, still works (offline mode)

## 🚀 Quick Start (After Setup)

### Terminal 1: Start Backend
```bash
cd /home/sym/ZSI/Backend/ZSI_Backend
source venv/bin/activate  # if using venv
python api.py
```

### Terminal 2: Start Frontend
```bash
cd /home/sym/ZSI/Frontend/ZSI_Frontend
flutter run
```

### Test
1. Take a photo
2. See identification in real-time
3. Works both online and offline!

## 📋 File Structure

```
/home/sym/ZSI/
├── Backend/ZSI_Backend/
│   ├── api.py                    ← Flask REST API
│   ├── train.py                  ← Training script
│   ├── zsi_wildlife_model.pth    ← Trained model (16 MB)
│   ├── zsi_class_mapping.json    ← Species labels
│   ├── requirements.txt           ← Python dependencies
│   └── README_TRAINING.md        ← Training guide
│
├── Frontend/ZSI_Frontend/
│   ├── lib/core/services/
│   │   ├── ai_service.dart       ← Hybrid mode
│   │   └── offline_ai_service.dart ← Offline support
│   ├── assets/ml/
│   │   └── zsi_class_mapping.json ← Species labels
│   ├── pubspec.yaml              ← Flutter dependencies
│   └── OFFLINE_MODE_SETUP.md     ← Integration guide
│
├── DEPLOYMENT_READY.md           ← Production checklist
├── README_INTEGRATION.md         ← Navigation hub
└── SETUP_INSTRUCTIONS.md         ← This file
```

## 🛠️ Troubleshooting

### "ModuleNotFoundError: No module named 'flask'"
```bash
# Solution: Install dependencies in venv
cd Backend/ZSI_Backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### "Flutter not found"
```bash
# Solution: Install Flutter SDK
# See: https://flutter.dev/docs/get-started/install
```

### "Connection refused (localhost:5000)"
```bash
# Solution: Start Flask API first
cd Backend/ZSI_Backend
source venv/bin/activate
python api.py
```

### "ModuleNotFoundError: No module named 'torch'"
```bash
# Solution: Install PyTorch
pip install torch torchvision
# OR
pip install -r requirements.txt
```

## 📚 Documentation

- **DEPLOYMENT_READY.md** - Quick start & testing
- **README_INTEGRATION.md** - Navigation hub
- **OFFLINE_MODE_SETUP.md** - Offline setup details
- **Backend/README_TRAINING.md** - Model training info

---

**Status**: Setup instructions provided
**Next Step**: Run setup commands above
