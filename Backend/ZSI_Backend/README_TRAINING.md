# ZSI GPU Training - Complete Guide

## 🚀 Quick Start

Your **EfficientNet-B0 model is currently training** on your RTX 4060 Ti GPU!

### Status Right Now
- ✅ **Training Active**: Epoch 1/200
- 📊 **Loss**: 1.2037 | **Accuracy**: 77.61%
- 🔥 **GPU**: 55°C (safe)
- ⏱️ **ETA**: ~5-6 hours to completion

---

## 📋 Files in This Directory

### Training Scripts
| File | Purpose |
|------|---------|
| `train.py` | Main training script (do not modify while training) |
| `api.py` | Flask API for inference (run after training) |

### Model & Checkpoints
| File | Purpose |
|------|---------|
| `zsi_wildlife_model.pth` | Best model weights (16 MB) - auto-updated |
| `zsi_class_mapping.json` | 66-class species mapping |

### Logs & Data
| File | Purpose |
|------|---------|
| `training_run.log` | Real-time training metrics |
| `training_progress.png` | Loss/accuracy curves (generated at end) |
| `ZSI/` | Dataset directory (621 base images) |

### Utilities
| File | Purpose |
|------|---------|
| `monitor_training.sh` | Quick status check script |
| `TRAINING_QUICK_REFERENCE.txt` | One-page quick reference |
| `README_TRAINING.md` | This file |

---

## 🔍 Monitor Your Training

### Option 1: Real-Time Stream (Recommended)
```bash
tail -f training_run.log
```

### Option 2: Latest Metrics
```bash
tail -20 training_run.log
```

### Option 3: GPU Dashboard
```bash
nvidia-smi
```

### Option 4: Automated Script
```bash
bash monitor_training.sh
```

---

## 📊 What's Being Trained?

**Model**: EfficientNet-B0
- **Input**: 224x224 RGB images
- **Output**: 66 CITES-protected species
- **Architecture**: 40 layers, frozen backbone (efficient transfer learning)

**Dataset**: 621 endangered wildlife images
- **Augmentation**: 150x on-the-fly (flip, rotate, color jitter)
- **Per Epoch**: 99,150 samples
- **Classes**: Bengal Tigers, Sharks, Snakeheads, etc.

**Training Setup**:
- **Optimizer**: AdamW (lr=0.0001)
- **Loss**: CrossEntropyLoss
- **Batch Size**: 64
- **Mixed Precision**: Enabled (FP32 + FP16)
- **Early Stopping**: Active (patience=5)

---

## After Training Completes

### 1. Check Results
```bash
tail -10 training_run.log  # View final metrics
```

### 2. View Training Curves
```bash
# Open training_progress.png to see loss/accuracy plots
```

### 3. Deploy API Server
```bash
python api.py
# Server runs on http://localhost:5000
```

### 4. Test Inference
```bash
curl -X POST -F "image=@test_image.jpg" \
  http://localhost:5000/predict
```

---

**Training Started**: 2026-03-19 @ 06:04:44 UTC  
**Status**: ACTIVE  
**GPU**: NVIDIA RTX 4060 Ti  

Your model is training! Let it complete. 🚀

