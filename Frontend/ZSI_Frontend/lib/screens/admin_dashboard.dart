
import 'dart:io';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../shared/models/index.dart';
// New feature imports
import '../shared/widgets/user_profile_card.dart' as profile_widgets;
import '../core/services/index.dart';
import '../utils/app_utils.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final pendingRecords = ArchiveService.getNeedsVerification();
    final stats = ArchiveService.getStatistics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCards(stats),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pending Verifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(pendingRecords.length.toString()),
                backgroundColor: Colors.orange,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingRecords.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No pending verifications',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ...pendingRecords.map((record) => _buildVerificationCard(record)),
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total', stats['total'], Icons.upload_file, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Pending', stats['pending'], Icons.pending, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Verified', stats['verified'], Icons.check_circle, Colors.green)),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard(UploadRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(record.imagePath),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI: ${record.identifiedSpecies ?? "Unknown"}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (record.confidence != null)
                        Text('Confidence: ${(record.confidence! * 100).toStringAsFixed(1)}%'),
                      Text('User: ${record.userEmail ?? "Guest"}'),
                      Text(_formatDateTime(record.timestamp)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showVerificationDialog(record),
                    icon: const Icon(Icons.check),
                    label: const Text('Verify'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectionDialog(record),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationDialog(UploadRecord record) {
    final speciesController = TextEditingController(text: record.identifiedSpecies);
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Species'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: speciesController,
              decoration: const InputDecoration(
                labelText: 'Species Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ArchiveService.verifyUpload(
                record.id,
                speciesController.text,
                notesController.text,
              );
              
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  AppUtils.showSuccess(context, 'Species verified successfully');
                  setState(() {});
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog(UploadRecord record) {
    // Implement rejection logic
    AppUtils.showError(context, 'Rejection feature to be implemented');
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// BROWSE SPECIES SCREEN
// ============================================================================

