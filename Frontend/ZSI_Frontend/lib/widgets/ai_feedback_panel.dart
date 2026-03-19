import 'package:flutter/material.dart';
import '../core/services/feedback_service.dart';
import '../utils/app_utils.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

/// Collapsible feedback panel for incorrect AI predictions
class AIFeedbackPanel extends StatefulWidget {
  final File imageFile;
  final String predictedSpecies;
  final double confidence;
  final VoidCallback? onFeedbackSubmitted;

  const AIFeedbackPanel({
    super.key,
    required this.imageFile,
    required this.predictedSpecies,
    required this.confidence,
    this.onFeedbackSubmitted,
  });

  @override
  State<AIFeedbackPanel> createState() => _AIFeedbackPanelState();
}

class _AIFeedbackPanelState extends State<AIFeedbackPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  bool _isExpanded = false;
  bool _isSubmitting = false;

  final _actualSpeciesController = TextEditingController();
  final _featuresController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _actualSpeciesController.dispose();
    _featuresController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  Future<void> _submitFeedback() async {
    if (_actualSpeciesController.text.isEmpty) {
      AppUtils.showError(context, 'Please enter the correct species name');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final feedback = AIFeedback(
        id: const Uuid().v4(),
        predictedSpecies: widget.predictedSpecies,
        actualSpecies: _actualSpeciesController.text.trim(),
        aiConfidence: widget.confidence,
        identifyingFeatures: _featuresController.text.isNotEmpty
            ? _featuresController.text.trim()
            : null,
        difficultyRating: _selectedDifficulty,
        additionalNotes: _notesController.text.isNotEmpty
            ? _notesController.text.trim()
            : null,
        imagePath: widget.imageFile.path,
        timestamp: DateTime.now(),
      );

      final success = await FeedbackService.submitFeedback(feedback);

      if (mounted) {
        if (success) {
          AppUtils.showSuccess(
            context,
            'Thank you! Your feedback helps improve the AI model.',
          );
          _clearForm();
          _toggleExpand();
          widget.onFeedbackSubmitted?.call();
        } else {
          AppUtils.showError(context, 'Failed to save feedback. Try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearForm() {
    _actualSpeciesController.clear();
    _featuresController.clear();
    _notesController.clear();
    setState(() => _selectedDifficulty = null);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.amber[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber[300]!, width: 2),
      ),
      child: Column(
        children: [
          // Header - Always visible
          InkWell(
            onTap: _toggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.report_problem, color: Colors.amber[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Was this identification wrong?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          SizeTransition(
            sizeFactor: CurvedAnimation(
              parent: _expandController,
              curve: Curves.easeInOut,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help improve the AI by providing corrections:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[800],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Correct species name (required)
                  TextField(
                    controller: _actualSpeciesController,
                    decoration: InputDecoration(
                      labelText: 'Correct species name *',
                      hintText: 'e.g., Mobula alfredi',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.info),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Identifying features
                  TextField(
                    controller: _featuresController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Identifying features (optional)',
                      hintText:
                          'e.g., White spots on wings, forked tail, size...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Difficulty rating
                  DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    decoration: InputDecoration(
                      labelText: 'How difficult was this? (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.grade),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'easy',
                        child: Text('Easy - Very different'),
                      ),
                      const DropdownMenuItem(
                        value: 'moderate',
                        child: Text('Moderate - Similar species'),
                      ),
                      const DropdownMenuItem(
                        value: 'hard',
                        child: Text('Hard - Nearly identical'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedDifficulty = value);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Additional notes
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Additional notes (optional)',
                      hintText:
                          'Any other observations or context...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.note),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                _clearForm();
                                _toggleExpand();
                              },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitFeedback,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit Feedback',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '✓ Feedback is saved locally and used to improve the AI model',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
