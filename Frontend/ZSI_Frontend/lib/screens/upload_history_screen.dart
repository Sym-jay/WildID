
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
import '../utils/app_utils.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class UploadHistoryScreen extends StatefulWidget {
  const UploadHistoryScreen({super.key});

  @override
  State<UploadHistoryScreen> createState() => _UploadHistoryScreenState();
}

class _UploadHistoryScreenState extends State<UploadHistoryScreen> {
  String _filter = 'all'; // 'all', 'pending', 'verified', 'needsVerification'
  late ObservationFilters _advancedFilters;

  @override
  void initState() {
    super.initState();
    _advancedFilters = ObservationFilters();
  }

  @override
  Widget build(BuildContext context) {
    final uploads = _getFilteredUploads();
    final stats = ArchiveService.getStatistics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Advanced Filters',
            onPressed: () => _showAdvancedFilters(),
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Statistics',
            onPressed: () => _showStatistics(stats),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Data',
            onPressed: _exportData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          _buildStatsBar(stats),
          Expanded(
            child: uploads.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: uploads.length,
                    itemBuilder: (context, index) {
                      return _buildUploadCard(uploads[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: FilterPanel(
          filters: _advancedFilters,
          onFiltersChanged: (newFilters) {
            setState(() => _advancedFilters = newFilters);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  List<UploadRecord> _getFilteredUploads() {
    final all = ArchiveService.getUploadHistory();
    
    // First apply simple filter
    List<UploadRecord> filtered;
    switch (_filter) {
      case 'pending':
        filtered = all.where((r) => r.status == 'pending').toList();
        break;
      case 'verified':
        filtered = all.where((r) => r.status == 'verified').toList();
        break;
      case 'needsVerification':
        filtered = all.where((r) => r.needsVerification).toList();
        break;
      default:
        filtered = all;
    }
    
    // Then apply advanced filters
    filtered = filtered.where((r) => _advancedFilters.matches(r)).toList();
    
    return filtered;
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('All', 'all'),
            const SizedBox(width: 8),
            _buildChip('Pending', 'pending'),
            const SizedBox(width: 8),
            _buildChip('Verified', 'verified'),
            const SizedBox(width: 8),
            _buildChip('Needs Verification', 'needsVerification'),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filter = value),
      selectedColor: const Color.fromARGB(255, 46, 125, 50),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatsBar(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', stats['total'].toString(), Icons.upload_file),
          _buildStatItem('Pending', stats['pending'].toString(), Icons.pending),
          _buildStatItem('Verified', stats['verified'].toString(), Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildUploadCard(UploadRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showUploadDetails(record),
        borderRadius: BorderRadius.circular(12),
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
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.verifiedSpecies ?? record.identifiedSpecies ?? 'Unidentified',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(record.timestamp),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (record.confidence != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Confidence: ${(record.confidence! * 100).toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation(record);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    child: _buildStatusBadge(record.status),
                  ),
                ],
              ),
              if (record.location != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Lat: ${record.location!.latitude?.toStringAsFixed(4)}, '
                      'Lng: ${record.location!.longitude?.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (record.needsVerification) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Awaiting expert verification',
                        style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'verified':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No uploads yet',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start identifying wildlife to see your history',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showUploadDetails(UploadRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => UploadDetailSheet(record: record),
    );
  }

  void _showStatistics(Map<String, dynamic> stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Statistics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('Total Uploads', stats['total'].toString()),
              _buildStatRow('Pending', stats['pending'].toString()),
              _buildStatRow('Verified', stats['verified'].toString()),
              _buildStatRow('Needs Verification', stats['needsVerification'].toString()),
              const Divider(height: 24),
              const Text(
                'Species Distribution',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...(stats['speciesDistribution'] as Map<String, int>).entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(entry.key)),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final csvData = await ArchiveService.exportToCSV();
      
      // In production, save to file or share
      // For now, show confirmation
      if (mounted) {
        AppUtils.showSuccess(context, 'Data exported successfully (${csvData.length} bytes)');
        
        // You can use share_plus package to share the CSV
        // await Share.share(csvData, subject: 'ZSI Wildlife Data Export');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'Export failed: $e');
      }
    }
  }

  void _showDeleteConfirmation(UploadRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this upload record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService.deleteSighting(record.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Record deleted successfully'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {});
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

