
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
import '../widgets/index.dart';
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
  bool _isProcessing = true;
  bool _smsSent = false;

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
    _processImage(); // FIXED: Removed location stuff
  }

  @override
  void dispose() {
    _slideController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _processImage() async {
    setState(() => _isProcessing = true);
    try {
      final results = await AIService.identifySpecies(widget.imageFile);
      
      if (mounted) {
        setState(() {
          _results = results;
          _isProcessing = false;
        });
        _resultController.forward();
        
        await _archiveUpload();
        await _handleSMSAlert();
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
    
    final animal = AnimalDataset.findAnimalByName(topResult.label);
    if (animal == null || !animal.isEndangered || AuthService.currentUserPhone == null) return;
    
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
    final isHighConfidence = topResult.confidence > 0.6;
    final animal = AnimalDataset.findAnimalByName(topResult.label);

    return ScaleTransition(
      scale: _resultAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Identification Results',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16),
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
                          color: isHighConfidence ? Colors.green : Colors.orange,
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
                    valueColor: AlwaysStoppedAnimation<Color>(isHighConfidence ? Colors.green : Colors.orange),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        isHighConfidence ? Icons.check_circle : Icons.info,
                        color: isHighConfidence ? Colors.green[700] : Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHighConfidence 
                            ? 'High confidence - reliable match!' 
                            : 'Moderate confidence - upload saved for expert verification.',
                          style: TextStyle(
                            color: isHighConfidence ? Colors.green[700] : Colors.orange[700],
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
              final otherAnimal = AnimalDataset.findAnimalByName(result.label);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: otherAnimal != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: otherAnimal.imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[200],
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[300],
                              child: const Icon(Icons.pets, size: 24),
                            ),
                          ),
                        )
                      : const Icon(Icons.pets, size: 40),
                  title: Text(result.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('${(result.confidence * 100).toStringAsFixed(1)}% confidence'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: otherAnimal != null
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => SpeciesDetailScreen(animal: otherAnimal)),
                          );
                        }
                      : null,
                ),
              );
            }),
          ],
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

