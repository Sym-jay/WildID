// lib/core/config/error_handler.dart

/// Base exception class for the application
abstract class AppException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => message;

  /// Get user-friendly error message
  String getUserMessage() => message;

  /// Log error details
  void log() {
    AppLogger.logError(message, originalError, stackTrace);
  }
}

/// Network-related errors (API calls, timeouts, connection)
class NetworkException extends AppException {
  NetworkException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(message, originalError: originalError, stackTrace: stackTrace);

  @override
  String getUserMessage() =>
      'Connection error. Please check your internet and try again.';
}

/// Validation errors (invalid input, file too large)
class ValidationException extends AppException {
  ValidationException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(message, originalError: originalError, stackTrace: stackTrace);

  @override
  String getUserMessage() => message;
}

/// Database operation errors
class AppDatabaseException extends AppException {
  AppDatabaseException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(message, originalError: originalError, stackTrace: stackTrace);

  @override
  String getUserMessage() =>
      'Database error. Please try again or restart the app.';
}

/// Authentication/authorization errors
class AuthException extends AppException {
  AuthException(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(message, originalError: originalError, stackTrace: stackTrace);

  @override
  String getUserMessage() => 'Authentication failed. Please log in again.';
}

/// Generic application errors
class AppError extends AppException {
  AppError(
    String message, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(message, originalError: originalError, stackTrace: stackTrace);

  @override
  String getUserMessage() => 'An error occurred. Please try again.';
}

/// Error logging service
class AppLogger {
  static final List<String> _errorLogs = [];
  static const int _maxLogSize = 1000; // Keep last 1000 errors

  /// Log an error
  static void logError(String message, dynamic error, StackTrace? stackTrace) {
    final timestamp = DateTime.now().toIso8601String();
    final errorMsg = '''
[$timestamp] ERROR: $message
Error Type: ${error.runtimeType}
Details: $error
StackTrace: $stackTrace
''';

    // Store in memory (for future Firebase/Sentry integration)
    _errorLogs.add(errorMsg);
    if (_errorLogs.length > _maxLogSize) {
      _errorLogs.removeAt(0);
    }

    // Print to console in debug mode only
    assert(() {
      print(errorMsg);
      return true;
    }());
  }

  /// Log an info message
  static void logInfo(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final log = '[$timestamp] INFO: $message';
    assert(() {
      print(log);
      return true;
    }());
  }

  /// Log a warning message
  static void logWarning(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final log = '[$timestamp] WARNING: $message';
    assert(() {
      print(log);
      return true;
    }());
  }

  /// Get all logged errors
  static List<String> getErrorLogs() => List.from(_errorLogs);

  /// Clear logs
  static void clearLogs() => _errorLogs.clear();

  /// Export logs as string
  static String exportLogs() => _errorLogs.join('\n\n');
}
