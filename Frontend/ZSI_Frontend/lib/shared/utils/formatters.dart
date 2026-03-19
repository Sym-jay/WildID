// lib/shared/utils/formatters.dart

import 'package:intl/intl.dart';

/// Format utilities for displaying data
class Formatters {
  Formatters._();

  /// Format date to readable string
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format date and time
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  /// Format confidence as percentage
  static String formatConfidence(double confidence) {
    return '${(confidence * 100).toStringAsFixed(1)}%';
  }

  /// Format species status color
  static String formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'critically endangered':
        return 'Critically Endangered 🔴';
      case 'endangered':
        return 'Endangered 🟠';
      case 'vulnerable':
        return 'Vulnerable 🟡';
      case 'near threatened':
        return 'Near Threatened 🟢';
      case 'least concern':
        return 'Least Concern ✅';
      default:
        return status;
    }
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Format phone number
  static String formatPhoneNumber(String phone) {
    if (phone.length != 10) return phone;
    return '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';
  }

  /// Format verification status
  static String formatVerificationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return '✅ Verified';
      case 'pending':
        return '⏳ Pending';
      case 'rejected':
        return '❌ Rejected';
      default:
        return status;
    }
  }
}
