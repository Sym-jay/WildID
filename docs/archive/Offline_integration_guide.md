# ZSI Wildlife Identifier - Offline Model Integration Guide

## Overview
This guide enables offline species identification in the Flutter app using the trained PyTorch model.

## Current Architecture
- **Current**: Cloud API (`https://zsi-wildlife-api-173142698667.us-central1.run.app/predict`)
- **Target**: Hybrid (Cloud fallback + Local offline inference)

## Integration Steps

### Option A: Hybrid Approach (Recommended) ✅
1. **Keep API as primary** (when network available)
2. **Add offline fallback** (when offline)
3. **Bundle model with app** (16MB .pth file)
4. **Use Dart FFI** to call Python inference via native code

### Option B: Pure Offline (Advanced)
1. Convert PyTorch → ONNX → TensorFlow Lite
2. Bundle .tflite file (smaller ~8MB)
3. Use `tflite_flutter` package (faster, native Android/iOS)

### Option C: Hybrid with Dart-PyTorch (Simple)
1. Use `pytorch_mobile` package
2. Bundle .pth directly
3. Pure Dart/Flutter, no native code

## Quick Checklist

- [ ] Copy `zsi_wildlife_model.pth` to Flutter assets
- [ ] Copy `zsi_class_mapping.json` to Flutter assets
- [ ] Create `offline_ai_service.dart` 
- [ ] Update `pubspec.yaml` with offline dependencies
- [ ] Modify `ai_service.dart` to use offline fallback
- [ ] Test on device without network
- [ ] Update git with new files

## Files to Integrate
- Source: `/home/sym/ZSI/Backend/ZSI_Backend/zsi_wildlife_model.pth` (16 MB)
- Source: `/home/sym/ZSI/Backend/ZSI_Backend/zsi_class_mapping.json` (11 KB)
- Destination: `/home/sym/ZSI/Frontend/ZSI_Frontend/assets/ml/`

## Recommended Next Steps
1. **Immediate**: Update pubspec.yaml and integrate class mapping (2 hrs)
2. **Short-term**: Implement local API server fallback (4 hrs)
3. **Medium-term**: Convert to TFLite for true offline (8 hrs)

---

**Status**: Ready to proceed with Option A or B
**Estimated Time**: 2-4 hours for full integration
**Risk Level**: Low (API still primary, fallback only)
