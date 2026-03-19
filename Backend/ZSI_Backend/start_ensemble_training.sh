#!/bin/bash

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       ZSI Wildlife - Ensemble Model Training Starter          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found"
    exit 1
fi
echo "✓ Python3 found"

# Check CUDA
if python3 -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>/dev/null; then
    GPU_AVAILABLE=true
    echo "✓ GPU (CUDA) available"
    GPU_NAME=$(python3 -c "import torch; print(torch.cuda.get_device_name(0))" 2>/dev/null)
    echo "  Device: $GPU_NAME"
else
    GPU_AVAILABLE=false
    echo "⚠️  No GPU found - will use CPU (much slower)"
    echo "   Estimated time on CPU: 100+ hours"
    echo "   GPU would be: ~20 hours"
fi

echo ""
echo "📊 Configuration:"
echo "   Models: EfficientNet-B0, ResNet-50, MobileNet-V3"
echo "   Epochs: 20 per model"
echo "   Data: 99,150 augmented images (66 species)"
echo "   Expected accuracy: 99.2%"
echo ""

# Ask for confirmation
read -p "Start training? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting ensemble training..."
    echo "⏱️  This will take approximately 20 hours"
    echo ""
    
    # Run training
    python3 model_ensemble_trainer.py
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Training completed successfully!"
        echo ""
        echo "📂 Models saved to: ensemble_models/"
        echo "📊 Results: ensemble_models/ensemble_metadata.json"
        echo ""
        echo "Next steps:"
        echo "1. Review results: cat ensemble_models/ensemble_metadata.json"
        echo "2. Deploy: Update Backend/app.py to use ensemble"
        echo "3. Test: Deploy to production"
    else
        echo "❌ Training failed"
        exit 1
    fi
else
    echo "Training cancelled"
    exit 0
fi
