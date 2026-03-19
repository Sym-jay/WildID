// lib/shared/utils/constants.dart

/// API and network constants
class ApiConstants {
  ApiConstants._();
  
  static const String aiServiceUrl = 'https://zsi-wildlife-api-173142698667.us-central1.run.app/predict';
  static const String govServerUrl = 'https://your-goi-server.gov.in/api';
  static const String smsApiUrl = 'https://sms.gov.in/api/send';
}

/// UI/UX constants
class UiConstants {
  UiConstants._();
  
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const double borderRadius = 12.0;
  static const double cardElevation = 3.0;
  // Standard padding moved to individual widgets
}

/// Database constants
class DatabaseConstants {
  DatabaseConstants._();
  
  static const String dbName = 'zsi_wildlife.db';
  static const int dbVersion = 1;
  static const String uploadRecordsTable = 'upload_records';
  static const String expertVerificationsTable = 'expert_verifications';
  static const String communityVotesTable = 'community_votes';
}

/// Authentication constants
class AuthConstants {
  AuthConstants._();
  
  static const int otpLength = 6;
  static const Duration otpTimeout = Duration(minutes: 10);
  static const int maxLoginAttempts = 5;
}

/// File upload constants
class FileConstants {
  FileConstants._();
  
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedImageFormats = ['jpg', 'jpeg', 'png', 'webp'];
}

/// Error messages
class ErrorMessages {
  ErrorMessages._();
  
  static const String networkError = 'Network error. Please check your connection.';
  static const String databaseError = 'Database error. Please try again.';
  static const String authenticationFailed = 'Authentication failed. Please try again.';
  static const String uploadFailed = 'Upload failed. Please try again.';
  static const String serverError = 'Server error. Please try again later.';
  static const String fileTooBig = 'File size exceeds 10 MB limit.';
  static const String invalidFormat = 'Invalid file format. Use JPG, PNG, or WebP.';
}
