
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../core/services/database_service.dart';
// New feature imports
import '../shared/widgets/user_profile_card.dart' as profile_widgets;
import '../shared/widgets/filter_panel.dart';
import '../core/services/index.dart';
import '../core/services/ensemble_ai_service.dart';
import '../core/services/image_cache_service.dart';
import '../core/services/species_lookup_service.dart';
import '../core/services/feedback_service.dart';
import '../widgets/index.dart';
import '../widgets/ai_feedback_panel.dart';
import 'species_detail_screen.dart';
import '../utils/app_utils.dart';
import 'metadata_form_screen.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class IdentificationScreen extends StatefulWidget {
  final File imageFile;

  const IdentificationScreen({super.key, required this.imageFile});

  @override
  State<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends State<IdentificationScreen> with TickerProviderStateMixin {
  List<IdentificationResult>? _results;
  EnsembleIdentificationResult? _ensembleResults;
  bool _isProcessing = true;
  bool _smsSent = false;
  bool _useEnsemble = true; // Toggle between single & ensemble models
  Map<String, Animal> _speciesCache = {}; // Cache species data

  late AnimationController _slideController;
  late AnimationController _resultController;
  late Animation<double> _slideAnimation;
  late Animation<double> _resultAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _resultController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    
    _slideAnimation = CurvedAnimation(parent: _slideController, curve: Curves.easeInOut);
    _resultAnimation = CurvedAnimation(parent: _resultController, curve: Curves.easeOutBack);
    
    _slideController.forward();
    
    // Load species data before processing
    _loadSpeciesData();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  /// Load species data from JSON and cache it
  Future<void> _loadSpeciesData() async {
    try {
      final species = await SpeciesLookupService.getAllSpecies();
      if (mounted) {
        setState(() {
          for (var animal in species) {
            _speciesCache[animal.name.toLowerCase()] = animal;
          }
        });
        // Start processing after species are loaded
        _processImage();
      }
    } catch (e) {
      debugPrint('Failed to load species data: $e');
      // Still process image even if species loading fails
      if (mounted) {
        _processImage();
      }
    }
  }

  /// Get animal by name from cache (or return null)
  Animal? _getAnimalFromCache(String name) {
    return _speciesCache[name.toLowerCase()];
  }

  Future<void> _processImage() async {
    setState(() => _isProcessing = true);
    try {
      if (_useEnsemble) {
        // Use ensemble prediction (3 models with weighted voting)
        final ensembleResult = await EnsembleAIService.identifyWithEnsemble(widget.imageFile);
        
        if (mounted) {
          setState(() {
            _ensembleResults = ensembleResult;
            // Convert ensemble result to results list for compatibility
            _results = [
              if (ensembleResult.ensembleResult != null)
                ensembleResult.ensembleResult!
            ];
            _isProcessing = false;
          });
          _resultController.forward();
          
          await _archiveUpload();
          await _handleSMSAlert();
        }
      } else {
        // Use single model prediction (original behavior)
        final results = await AIService.identifySpecies(widget.imageFile);
        
        if (mounted) {
          setState(() {
            _results = results;
            _ensembleResults = null;
            _isProcessing = false;
          });
          _resultController.forward();
          
          await _archiveUpload();
          await _handleSMSAlert();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      await _archiveUpload();
      if (mounted) {
        AppUtils.showError(context, 'Error processing image: ${e.toString()}');
      }
    }
  }

  Future<void> _archiveUpload() async {
    try {
      final topResult = _results?.isNotEmpty == true ? _results!.first : null;
      
      await ArchiveService.archiveUpload(
        imageFile: widget.imageFile,
        identifiedSpecies: topResult?.label,
        confidence: topResult?.confidence,
      );
      
      if (mounted && (_results == null || topResult == null || (topResult.confidence < 0.6))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_upload, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Upload archived for expert verification'),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to archive upload: $e');
    }
  }

  Future<void> _handleSMSAlert() async {
    if (_results == null || _results!.isEmpty || !AuthService.isLoggedIn || _smsSent) return;
    
    final topResult = _results!.first;
    if (topResult.confidence < 0.6) return;
    
    final animal = await SpeciesLookupService.findByCommonName(topResult.label);
    if (animal == null || AuthService.currentUserPhone == null) return;
    
    setState(() => _smsSent = true);
    final success = await SMSService.sendEndangeredSpeciesAlert(
      AuthService.currentUserPhone!,
      animal.name,
    );
    
    if (mounted && success) {
      AppUtils.showSuccess(context, 'SMS alert sent to ${AuthService.currentUserPhone}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identification Result'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_slideAnimation),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 6,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: RepaintBoundary(
                  child: Stack(
                    children: [
                      Image.file(
                        widget.imageFile,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        cacheHeight: 400,
                        cacheWidth: 1000,
                      ),
                      if (_isProcessing)
                        Container(
                          width: double.infinity,
                          height: 300,
                          color: Colors.black38,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                SizedBox(height: 16),
                                Text('Analyzing with AI...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Model Selector
              _buildModelSelector(),
              const SizedBox(height: 24),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else if (_results != null && _results!.isNotEmpty)
                _buildResults()
              else
                _buildErrorState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.primaryColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Model Selection',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _useEnsemble ? AppTheme.primaryColor : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: !_isProcessing
                          ? () {
                              if (_useEnsemble != true) {
                                setState(() {
                                  _useEnsemble = true;
                                  _results = null;
                                  _ensembleResults = null;
                                  _processImage();
                                });
                              }
                            }
                          : null,
                      child: Text(
                        '⭐ Ensemble (3 Models)\nAccuracy: 75%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _useEnsemble ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: !_useEnsemble ? AppTheme.primaryColor : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: !_isProcessing
                          ? () {
                              if (_useEnsemble != false) {
                                setState(() {
                                  _useEnsemble = false;
                                  _results = null;
                                  _ensembleResults = null;
                                  _processImage();
                                });
                              }
                            }
                          : null,
                      child: Text(
                        '🔷 Single Model\nFast Processing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_useEnsemble ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_useEnsemble && _ensembleResults != null) ...[
              const SizedBox(height: 12),
              Text(
                'Model Confidence Breakdown:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 8),
              ..._buildEnsembleBreakdown(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEnsembleBreakdown() {
    if (_ensembleResults == null) return [];
    
    final individual = _ensembleResults!.getIndividualTopPredictions();
    return [
      _buildModelConfidenceRow('EfficientNet', individual['efficientnet'], '40%'),
      const SizedBox(height: 6),
      _buildModelConfidenceRow('ResNet-50', individual['resnet'], '35%'),
      const SizedBox(height: 6),
      _buildModelConfidenceRow('MobileNet', individual['mobilenet'], '25%'),
    ];
  }

  Widget _buildModelConfidenceRow(String modelName, IdentificationResult? result, String weight) {
    final confidence = result?.confidence ?? 0.0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            modelName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: confidence,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              confidence >= 0.7 ? Colors.green : confidence >= 0.5 ? Colors.orange : Colors.red,
            ),
            minHeight: 4,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 45,
          child: Text(
            '${(confidence * 100).toStringAsFixed(0)}% (${weight})',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Unable to process image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Your upload has been saved for expert review.'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final topResult = _results!.first;
    final isHighConfidence = topResult.confidence >= 0.90;
    final isModerateConfidence = topResult.confidence >= 0.70;
    final animal = _getAnimalFromCache(topResult.label);

    return ScaleTransition(
      scale: _resultAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Low confidence warning banner
          if (!isHighConfidence) ...[
            Card(
              color: Colors.orange[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lower Confidence Detected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The AI is less certain about this identification. Please review the suggested species carefully and verify manually if possible, especially with similar-looking species like eagle rays and manta rays.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          const Text(
            'Identification Results',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16),
          
          // Top result card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          topResult.label,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isHighConfidence
                              ? Colors.green
                              : isModerateConfidence
                                  ? Colors.orange
                                  : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(topResult.confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: topResult.confidence,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isHighConfidence
                          ? Colors.green
                          : isModerateConfidence
                              ? Colors.orange
                              : Colors.red,
                    ),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        isHighConfidence
                            ? Icons.check_circle
                            : isModerateConfidence
                                ? Icons.info
                                : Icons.error_outline,
                        color: isHighConfidence
                            ? Colors.green[700]
                            : isModerateConfidence
                                ? Colors.orange[700]
                                : Colors.red[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHighConfidence
                              ? '✓ High confidence - reliable match!'
                              : isModerateConfidence
                                  ? '⚠ Moderate confidence - verify manually'
                                  : '✗ Low confidence - expert verification needed',
                          style: TextStyle(
                            color: isHighConfidence
                                ? Colors.green[700]
                                : isModerateConfidence
                                    ? Colors.orange[700]
                                    : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (animal != null && animal.isEndangered) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _smsSent && AuthService.isLoggedIn
                                  ? 'Endangered Species! SMS alert sent.'
                                  : 'Endangered Species! Login to receive alerts.',
                              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (animal != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => SpeciesDetailScreen(animal: animal)),
                          );
                        },
                        icon: const Icon(Icons.info_outline),
                        label: const Text('View Species Details'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_results!.length > 1) ...[
            const SizedBox(height: 20),
            const Text(
              'Other Possible Matches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 12),
            ..._results!.skip(1).map((result) {
              final otherAnimal = _getAnimalFromCache(result.label);
              final confidence = result.confidence;
              final isGood = confidence >= 0.70;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isGood ? Colors.green[50] : Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: otherAnimal != null && otherAnimal.imageUrl.isNotEmpty
                            ? SpeciesImageCacheManager.speciesImage(
                                imageUrl: otherAnimal.imageUrl,
                                width: 60,
                                height: 60,
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[300],
                                child: const Icon(Icons.pets, size: 28),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: confidence,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isGood ? Colors.green : Colors.orange,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isGood ? Colors.green : Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${(confidence * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (otherAnimal != null)
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => SpeciesDetailScreen(animal: otherAnimal)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          
          // Feedback panel for wrong identifications
          AIFeedbackPanel(
            imageFile: widget.imageFile,
            predictedSpecies: topResult.label,
            confidence: topResult.confidence,
            onFeedbackSubmitted: () {
              // Optional: Show confirmation or update UI after feedback
              debugPrint('User submitted feedback for: ${topResult.label}');
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MetadataFormScreen(
                      imageFile: widget.imageFile,
                      identifiedSpecies: _results!.isNotEmpty ? _results!.first.label : null,
                      confidence: _results!.isNotEmpty ? _results!.first.confidence : null,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('Add Scientific Details'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Another Image'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PHASE 3: METADATA FORM SCREEN
// ============================================================================

