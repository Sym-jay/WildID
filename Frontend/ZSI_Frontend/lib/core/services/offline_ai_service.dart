import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../shared/models/index.dart';
import '../config/image_compression.dart';
import '../config/error_handler.dart';
import 'prediction_parser.dart';

class OfflineAIService {
  OfflineAIService._();

  // Local Flask API running on device
  static const String localApiUrl = 'http://localhost:5000/predict';
  static const Duration localApiTimeout = Duration(seconds: 60);

  /// Check if local API is available (device has running Flask server)
  static Future<bool> isLocalAPIAvailable() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://localhost:5000/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Identify species using local Flask API
  /// Returns list of IdentificationResult with highest confidence first
  static Future<List<IdentificationResult>> identifySpeciesOffline(
    File imageFile,
  ) async {
    try {
      // Check if local API is available
      final isAvailable = await isLocalAPIAvailable();
      if (!isAvailable) {
        throw OfflineException(
          'Local AI service not available. Ensure Flask server is running on device.',
          stackTrace: StackTrace.current,
        );
      }

      // Compress image before sending
      final compressedImage = await ImageCompression.compressImage(imageFile);

      var uri = Uri.parse(localApiUrl);
      var request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath('file', compressedImage.path),
        );

      late http.StreamedResponse response;
      try {
        response = await request.send().timeout(localApiTimeout);
      } on TimeoutException catch (e) {
        AppLogger.logError('Local API request timeout', e, StackTrace.current);
        throw OfflineException(
          'Local inference timed out. Try with a smaller image.',
          originalError: e,
          stackTrace: StackTrace.current,
        );
      } on SocketException catch (e) {
        AppLogger.logError('Local API socket error', e, StackTrace.current);
        throw OfflineException(
          'Local API connection failed.',
          originalError: e,
          stackTrace: StackTrace.current,
        );
      }

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final dynamic jsonResponse = json.decode(responseBody);
        final results = PredictionParser.parsePredictionResults(jsonResponse);

        AppLogger.logInfo(
          'Species identified offline: ${results.length} results',
        );

        return results;
      } else if (response.statusCode == 400) {
        final errorBody = await response.stream.bytesToString();
        AppLogger.logError(
          'Bad request to local API',
          errorBody,
          StackTrace.current,
        );
        throw ValidationException(
          'Invalid image format. Please use JPG or PNG.',
          stackTrace: StackTrace.current,
        );
      } else {
        final errorBody = await response.stream.bytesToString();
        AppLogger.logError('Local API error', errorBody, StackTrace.current);
        throw OfflineException(
          'Local inference failed (Error ${response.statusCode}). Try again.',
          originalError: errorBody,
          stackTrace: StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      if (e is AppException) {
        rethrow;
      }
      AppLogger.logError('Unexpected error in OfflineAIService', e, stackTrace);
      throw OfflineException(
        'An unexpected error occurred during offline inference.',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get list of available species from local API
  static Future<List<String>> getAvailableSpecies() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:5000/classes'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonList = json.decode(response.body) as List<dynamic>;
        return jsonList.map((item) => item as String).toList();
      }
      return [];
    } catch (e) {
      AppLogger.logError('Failed to fetch species list', e, StackTrace.current);
      return [];
    }
  }
}

/// Exception for offline AI service errors
class OfflineException extends AppException {
  OfflineException(super.message, {super.originalError, super.stackTrace});
}
