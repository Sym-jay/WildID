
import 'dart:io';
import 'package:flutter/material.dart' hide Badge;
import '../shared/models/index.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class UploadDetailSheet extends StatelessWidget {
  final UploadRecord record;

  const UploadDetailSheet({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(record.imagePath),
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, size: 50),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Upload ID', record.id),
              _buildDetailRow('Timestamp', _formatDateTime(record.timestamp)),
              _buildDetailRow(
                'AI Identification',
                record.identifiedSpecies ?? 'Not identified',
              ),
              if (record.confidence != null)
                _buildDetailRow(
                  'Confidence',
                  '${(record.confidence! * 100).toStringAsFixed(2)}%',
                ),
              _buildDetailRow('Status', record.status.toUpperCase()),
              if (record.verifiedSpecies != null) ...[
                const Divider(height: 32),
                const Text(
                  'Expert Verification',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Verified Species', record.verifiedSpecies!),
                if (record.verifiedAt != null)
                  _buildDetailRow('Verified At', _formatDateTime(record.verifiedAt!)),
                if (record.adminNotes != null)
                  _buildDetailRow('Expert Notes', record.adminNotes!),
              ],
              if (record.location != null) ...[
                const Divider(height: 32),
                const Text(
                  'Location Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Coordinates',
                  'Lat: ${record.location!.latitude?.toStringAsFixed(6)}, '
                  'Lng: ${record.location!.longitude?.toStringAsFixed(6)}',
                ),
                if (record.location!.accuracy != null)
                  _buildDetailRow(
                    'Accuracy',
                    '±${record.location!.accuracy!.toStringAsFixed(1)}m',
                  ),
                if (record.location!.address != null)
                  _buildDetailRow('Address', record.location!.address!),
              ],
              const SizedBox(height: 24),

            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

