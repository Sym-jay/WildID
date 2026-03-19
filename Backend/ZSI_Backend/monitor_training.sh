#!/bin/bash

# ZSI GPU Training Monitor Script
# Usage: bash monitor_training.sh

cd /home/sym/ZSI/Backend/ZSI_Backend

echo "========================================"
echo "ZSI GPU TRAINING MONITOR"
echo "========================================"
echo ""

# Check if training is running
if ps aux | grep -q "[p]ython train.py"; then
    echo "✅ Training is RUNNING"
    echo ""
    echo "Process Info:"
    ps aux | grep "[p]ython train.py" | awk '{print "  PID: " $2 "\n  CPU: " $3 "%\n  MEM: " $4 "%"}'
    echo ""
else
    echo "❌ Training is NOT running"
    echo ""
fi

# Show latest metrics
echo "📊 Latest Training Metrics:"
echo "================================"
if [ -f training_run.log ]; then
    tail -30 training_run.log
else
    echo "No training log found yet"
fi

echo ""
echo "================================"
echo "📁 Model Files:"
ls -lh zsi_wildlife_model.pth zsi_class_mapping.json 2>/dev/null || echo "Model files not yet generated"

echo ""
echo "🔍 To watch real-time training:"
echo "  tail -f training_run.log"
echo ""
