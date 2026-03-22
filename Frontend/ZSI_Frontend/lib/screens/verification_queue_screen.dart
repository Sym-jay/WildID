
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


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class VerificationQueueScreen extends StatefulWidget {
  const VerificationQueueScreen({super.key});

  @override
  State<VerificationQueueScreen> createState() => _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends State<VerificationQueueScreen> {
  final String _filterStatus = 'pending'; // 'pending', 'all'
  bool _isVerifying = false;
  final Set<String> _rejectedRecordIds = {};

  List<UploadRecord> get _pendingRecords {
    final all = ArchiveService.getUploadHistory();
    // Filter out rejected records
    final filtered = all.where((r) => !_rejectedRecordIds.contains(r.id)).toList();
    if (_filterStatus == 'pending') {
      return filtered.where((r) => r.status == 'pending').toList();
    }
    return filtered;
  }

  Future<void> _verifyRecord(UploadRecord record, String verifiedSpecies, String notes, int confidence) async {
    setState(() => _isVerifying = true);
    try {
      // Create verification record
      final verification = ExpertVerification(
        verificationId: DateTime.now().millisecondsSinceEpoch.toString(),
        recordId: record.id,
        expertId: AuthService.currentUser ?? 'system',
        verifiedSpecies: verifiedSpecies,
        confidenceScore: confidence,
        notes: notes,
        alternativeSpecies: [],
        verifiedAt: DateTime.now(),
        status: 'accepted',
      );

      // Save verification
      await DatabaseService.saveVerification(verification);

      // Update record with verification
      final updatedRecord = record.copyWith(
        status: 'verified',
        verifiedSpecies: verifiedSpecies,
        verifiedAt: DateTime.now(),
        adminNotes: notes,
        expertConfidenceScore: confidence,
      );

      // Save updated record
      await DatabaseService.saveSighting(updatedRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Verified: $verifiedSpecies')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _showVerificationDialog(UploadRecord record) {
    String? selectedSpecies = record.identifiedSpecies;
    String notes = '';
    int confidence = 80;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Expert Verification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display image thumbnail
                if (File(record.imagePath).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(record.imagePath),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),

                // AI Suggestion
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Suggestion',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.identifiedSpecies} (${((record.confidence ?? 0) * 100).toStringAsFixed(1)}% confidence)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Verified Species Dropdown
                const Text(
                  'Verified Species *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedSpecies,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: AnimalDataset.animals
                      .map<DropdownMenuItem<String>>((a) => DropdownMenuItem<String>(value: a.name ?? '', child: Text(a.name ?? 'Unknown')))
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedSpecies = value),
                ),
                const SizedBox(height: 16),

                // Confidence Score Slider
                Text(
                  'Expert Confidence: $confidence%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: confidence.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  onChanged: (value) => setDialogState(() => confidence = value.toInt()),
                ),
                const SizedBox(height: 16),

                // Notes
                const Text(
                  'Verification Notes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g., Clear marking pattern, habitat consistent with species...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (value) => notes = value,
                ),
                const SizedBox(height: 16),

                // Metadata Display
                if (record.habitatType != null || record.waterTemperature != null)
                  Card(
                    color: AppTheme.backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Field Data',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          if (record.habitatType != null)
                            Text('Habitat: ${record.habitatType}', style: const TextStyle(fontSize: 12)),
                          if (record.waterTemperature != null)
                            Text('Temperature: ${record.waterTemperature}°C', style: const TextStyle(fontSize: 12)),
                          if (record.waterDepth != null)
                            Text('Depth: ${record.waterDepth}m', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isVerifying || selectedSpecies == null
                  ? null
                  : () {
                      _verifyRecord(record, selectedSpecies!, notes, confidence);
                      Navigator.pop(context);
                    },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }

  void _rejectRecord(UploadRecord record, String reason) {
    // Mark record as rejected - it will be filtered out
    setState(() {
      _rejectedRecordIds.add(record.id);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.block, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('Record rejected and removed from queue')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _pendingRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Queue'),
        elevation: 0,
      ),
      body: records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending records',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All identifications have been verified',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      if (File(record.imagePath).existsSync())
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: Image.file(
                            File(record.imagePath),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // AI Identification
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('AI Identification', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                                      const SizedBox(height: 4),
                                      Text(
                                        record.identifiedSpecies ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (record.confidence ?? 0) > 0.7 ? Colors.green[100] : Colors.orange[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${((record.confidence ?? 0) * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: (record.confidence ?? 0) > 0.7 ? Colors.green[700] : Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Metadata
                            if (record.habitatType != null || record.location != null)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (record.habitatType != null)
                                    Chip(
                                      label: Text(record.habitatType!),
                                      avatar: const Icon(Icons.location_on, size: 16),
                                      backgroundColor: AppTheme.backgroundColor,
                                    ),
                                  if (record.waterTemperature != null)
                                    Chip(
                                      label: Text('${record.waterTemperature}°C'),
                                      avatar: const Icon(Icons.thermostat, size: 16),
                                      backgroundColor: AppTheme.backgroundColor,
                                    ),
                                  if (record.waterDepth != null)
                                    Chip(
                                      label: Text('${record.waterDepth}m depth'),
                                      avatar: const Icon(Icons.water_drop, size: 16),
                                      backgroundColor: AppTheme.backgroundColor,
                                    ),
                                ],
                              ),
                            const SizedBox(height: 12),

                            // Actions
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _rejectRecord(record, 'Rejected by expert'),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: _isVerifying ? null : () => _showVerificationDialog(record),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Verify'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// UPLOAD HISTORY SCREEN
// ============================================================================

