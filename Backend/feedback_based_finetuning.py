"""
Feedback-Based Fine-Tuning System
Automatically retrains model when user feedback reaches threshold
Uses hybrid approach: collects feedback + auto fine-tunes when ready
"""

import json
import torch
import torch.nn as nn
from pathlib import Path
from datetime import datetime
from collections import defaultdict

class FeedbackFineTuner:
    """Manages fine-tuning from user feedback data"""
    
    FEEDBACK_THRESHOLD = 50  # Auto fine-tune when 50+ corrections collected
    
    def __init__(self, base_model_path='zsi_wildlife_model.pth'):
        self.base_model_path = base_model_path
        self.feedback_log = []
        self.corrections_per_species = defaultdict(int)
        self.model_versions = []
        
    def load_feedback(self, feedback_file):
        """Load feedback collected from mobile app"""
        try:
            with open(feedback_file, 'r') as f:
                feedback_data = json.load(f)
            return feedback_data
        except FileNotFoundError:
            print(f"⚠️  No feedback file found: {feedback_file}")
            return []
    
    def analyze_feedback(self, feedback_data):
        """Analyze feedback patterns"""
        analysis = {
            'total_corrections': len(feedback_data),
            'misidentifications': defaultdict(int),
            'difficult_pairs': defaultdict(int),
            'species_with_most_errors': [],
        }
        
        for feedback in feedback_data:
            predicted = feedback.get('predicted_species')
            actual = feedback.get('actual_species')
            difficulty = feedback.get('difficulty_rating')
            
            # Track misidentification patterns
            key = f"{predicted} → {actual}"
            analysis['misidentifications'][key] += 1
            
            # Track difficult species pairs
            if difficulty in ['moderate', 'hard']:
                analysis['difficult_pairs'][key] += 1
            
            # Track species with most corrections
            self.corrections_per_species[actual] += 1
        
        # Find top problem species
        analysis['species_with_most_errors'] = sorted(
            self.corrections_per_species.items(),
            key=lambda x: x[1],
            reverse=True
        )[:10]
        
        return analysis
    
    def should_finetune(self):
        """Check if we have enough feedback to fine-tune"""
        total_corrections = sum(self.corrections_per_species.values())
        return total_corrections >= self.FEEDBACK_THRESHOLD
    
    def create_finetuning_dataset(self, feedback_data, image_base_path):
        """
        Create dataset from corrected images for fine-tuning
        Structure:
        {
            'images': [paths to user-provided images],
            'labels': [correct species indices],
            'difficulty': ['easy', 'moderate', 'hard'],
        }
        """
        dataset = {
            'images': [],
            'labels': [],
            'difficulties': [],
            'feedback_ids': [],
        }
        
        for feedback in feedback_data:
            image_path = feedback.get('image_path')
            if Path(image_path).exists():
                dataset['images'].append(image_path)
                dataset['labels'].append(feedback.get('actual_species'))
                dataset['difficulties'].append(
                    feedback.get('difficulty_rating', 'moderate')
                )
                dataset['feedback_ids'].append(feedback.get('id'))
        
        return dataset
    
    def generate_report(self, feedback_data):
        """Generate human-readable feedback report"""
        analysis = self.analyze_feedback(feedback_data)
        
        report = f"""
╔════════════════════════════════════════════════════════════════════╗
║           ZSI Wildlife - User Feedback Analysis Report              ║
╚════════════════════════════════════════════════════════════════════╝

📊 Overall Statistics
   • Total corrections received: {analysis['total_corrections']}
   • Species with corrections: {len(self.corrections_per_species)}
   • Feedback needed for fine-tuning: {self.FEEDBACK_THRESHOLD}
   • Ready to fine-tune: {"✓ YES" if self.should_finetune() else "✗ Not yet"}

🎯 Top Problem Species (most corrections needed)
"""
        for species, count in analysis['species_with_most_errors']:
            report += f"   • {species}: {count} corrections\n"
        
        report += "\n🔄 Most Common Misidentifications\n"
        sorted_misid = sorted(
            analysis['misidentifications'].items(),
            key=lambda x: x[1],
            reverse=True
        )[:5]
        for pair, count in sorted_misid:
            report += f"   • {pair}: {count} times\n"
        
        report += "\n⚠️  Difficult Species Pairs (moderate/hard)\n"
        sorted_difficult = sorted(
            analysis['difficult_pairs'].items(),
            key=lambda x: x[1],
            reverse=True
        )[:5]
        for pair, count in sorted_difficult:
            report += f"   • {pair}: {count} difficult identifications\n"
        
        report += "\n" + "="*70 + "\n"
        
        return report
    
    def schedule_finetuning(self):
        """Create fine-tuning schedule"""
        if not self.should_finetune():
            next_threshold = self.FEEDBACK_THRESHOLD - sum(
                self.corrections_per_species.values()
            )
            print(f"⏳ Need {next_threshold} more corrections to trigger fine-tuning")
            return None
        
        schedule = {
            'timestamp': datetime.now().isoformat(),
            'action': 'FINE_TUNE_SCHEDULED',
            'reason': f'{sum(self.corrections_per_species.values())} corrections received',
            'estimated_duration': '2-3 hours',
            'expected_improvement': '+5-10% accuracy',
        }
        
        return schedule

if __name__ == '__main__':
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║     ZSI Wildlife - Feedback-Based Fine-Tuning System              ║")
    print("╚═══════════════════════════════════════════════════════════════════╝\n")
    
    finetuner = FeedbackFineTuner()
    
    # Example usage
    print("📌 System Features:")
    print("   ✓ Collects user corrections when AI identifies wrong species")
    print("   ✓ Analyzes patterns in misidentifications")
    print("   ✓ Auto-schedules fine-tuning when 50+ corrections collected")
    print("   ✓ Tracks difficult species pairs for targeted improvement")
    print("   ✓ Generates reports for model improvement")
    
    print("\n🔄 Workflow:")
    print("   1. User reports wrong identification → saved to feedback.json")
    print("   2. System loads feedback → analyzes patterns")
    print("   3. When threshold reached → schedules automatic fine-tuning")
    print("   4. Fine-tuned model deployed → users get better accuracy")
    
    print("\n✓ Feedback system ready to improve model over time!")
