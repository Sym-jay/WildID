# ZSI Wildlife Model - Retraining Report

**Date:** March 13, 2026  
**Trigger:** New image set (Set-2 CITES) added to dataset  
**Action:** Full model retraining on combined dataset

---

## 📊 Dataset Changes

### Previous State (Set-1)
- Species: 27
- Total Images: 127
- Structure: Schedule_1 & Schedule_2

### New Images (Set-2)
- Species: 42 new species (mostly CITES-listed sharks, rays)
- New Images: 497 images
- Structure: Flat folder structure (reorganized into Schedule_2)

### Current State (Combined)
- **Total Species: 69** (42 from Set-1 + 27 new from Set-2)
- **Total Images: 624** (127 + 497)
- **Average Images/Species: 9.0**
- **Range: 1-21 images per species**

⚠️ **Note:** 3 species have <2 images and will be excluded during training
- Corythoichthys spp (1)
- Trachyrhamphus spp (1)
- Glucostegus younholeei (1)

**Effective Training Species: 66** (qualifying species with ≥2 images)
**Effective Training Images: 621**

---

## 🎯 Training Strategy

### Selected Approach: **Full Retraining**

**Rationale:**
1. ✅ Better model generalization (sees all data together)
2. ✅ Prevents catastrophic forgetting from incremental training
3. ✅ Produces more robust species identification
4. ✅ New species properly integrated into feature space
5. ✅ Periodic retraining is acceptable for production

**Configuration:**
```
Model: EfficientNet-B0 (pre-trained)
Optimizer: AdamW (lr=0.0001, weight_decay=0.01)
Scheduler: CosineAnnealingLR (T_max=200)
Batch Size: 64
Epochs: 200
Augmentation Factor: 150x
Loss Function: CrossEntropyLoss
Device: CUDA (if available), else CPU
```

---

## 📅 Execution Timeline

| Phase | Task | Status |
|-------|------|--------|
| ✅ | Extract Set-2 images | DONE |
| ✅ | Organize into dataset structure | DONE |
| ✅ | Verify dataset integrity | DONE |
| ⏳ | **Run training script** | PENDING |
| ⏳ | **Monitor training progress** | PENDING |
| ⏳ | **Evaluate model performance** | PENDING |
| ⏳ | **Backup new model** | PENDING |
| ⏳ | **Deploy to Flutter app** | PENDING |

---

## 🔧 Training Commands

### Option 1: Run with GPU (Recommended)
```bash
cd /home/sym/ZSI/Backend/ZSI_Backend
python3 train.py
```

**Expected Duration:** 1-2 hours with NVIDIA GPU
**Expected Output:**
- `zsi_wildlife_model_v2.pth` - Trained model weights
- `training_progress_v2.png` - Loss/accuracy plot
- `zsi_class_mapping_v2.json` - Updated class mappings

### Option 2: Run with CPU (Slower)
```bash
cd /home/sym/ZSI/Backend/ZSI_Backend
python3 train.py
```

**Expected Duration:** 6-10 hours with CPU
**Note:** Consider using `nohup` or `screen` for background execution

---

## 📈 Expected Improvements

### Compared to Set-1 Model
- **More Species:** 69 classes (vs 27) → Better coverage of CITES species
- **More Images:** 624 total (vs 127) → Better per-species variation
- **Better Recognition:** More diverse visual examples
- **Robustness:** Handles various lighting, angles, water conditions

### Performance Metrics (Expected)
- Training Accuracy: 85-95% (higher than before due to more data)
- Inference Speed: <100ms per image (EfficientNet-B0)
- Model Size: ~20MB (unchanged)

---

## 🚀 Deployment Steps

After successful training:

1. **Backup Old Model**
   ```bash
   cp zsi_wildlife_model.pth zsi_wildlife_model_backup_set1.pth
   cp zsi_class_mapping.json zsi_class_mapping_backup_set1.json
   ```

2. **Replace with New Model**
   ```bash
   cp zsi_wildlife_model_v2.pth zsi_wildlife_model.pth
   cp zsi_class_mapping_v2.json zsi_class_mapping.json
   ```

3. **Verify Model Loads**
   ```bash
   python3 -c "import torch; m = torch.load('zsi_wildlife_model.pth'); print(f'✓ Model loaded: {len(m)} parameters')"
   ```

4. **Sync to Flutter App**
   - Copy updated `zsi_wildlife_model.pth` to Flutter assets
   - Update `pubspec.yaml` with new model version
   - Rebuild and test Flutter app

5. **Commit Changes**
   ```bash
   git add -A
   git commit -m "feat: retrain model with Set-2 CITES images (66 species, 621 images)"
   ```

---

## 📝 Notes

- **Incremental Training:** Not recommended for this case due to class distribution changes
- **Class Imbalance:** Manual inspection recommended for species with <5 images
- **Test Set:** Consider manually testing on known species for validation
- **Version Control:** Keep both model versions for rollback capability

---

## 🔗 Related Files

- Training Script: `train.py`
- Current Model: `zsi_wildlife_model.pth`
- Class Mapping: `zsi_class_mapping.json`
- Training Progress Plot: `training_progress.png`
- API Server: `api.py` (uses model for inference)

---

Generated: 2026-03-13
