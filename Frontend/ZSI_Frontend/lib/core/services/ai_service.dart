import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../shared/models/index.dart';
import '../config/image_compression.dart';
import '../config/error_handler.dart';

class AIService {
  AIService._();

  static const String apiUrl = 'https://zsi-wildlife-api-173142698667.us-central1.run.app/predict';
  static const String apiKey = String.fromEnvironment('ZSI_API_KEY', defaultValue: 'dev-key');

  static Future<List<IdentificationResult>> identifySpecies(File imageFile) async {
    try {
      // Compress image before sending
      final compressedImage = await ImageCompression.compressImage(imageFile);
      
      var uri = Uri.parse(apiUrl);
      var request = http.MultipartRequest('POST', uri)
        ..headers['X-API-Key'] = apiKey
        ..files.add(await http.MultipartFile.fromPath('file', compressedImage.path));

      late http.StreamedResponse response;
      try {
        response = await request.send().timeout(const Duration(seconds: 30));
      } on TimeoutException catch (e) {
        AppLogger.logError('API request timeout', e, StackTrace.current);
        throw NetworkException(
          'Request timed out. Please check your connection and try again.',
          originalError: e,
          stackTrace: StackTrace.current,
        );
      } on SocketException catch (e) {
        AppLogger.logError('Network socket error', e, StackTrace.current);
        throw NetworkException(
          'Network error. Please check your internet connection.',
          originalError: e,
          stackTrace: StackTrace.current,
        );
      }

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final List<dynamic> jsonList = json.decode(responseBody);

        AppLogger.logInfo('Species identified successfully: ${jsonList.length} results');
        
        return jsonList.map((jsonItem) => IdentificationResult(
          label: jsonItem['label'],
          confidence: (jsonItem['confidence'] as num).toDouble(),
        )).toList();
      } else if (response.statusCode == 401) {
        AppLogger.logError('API authentication failed', 'Status 401', StackTrace.current);
        throw AuthException(
          'API authentication failed. Please contact support.',
          stackTrace: StackTrace.current,
        );
      } else if (response.statusCode == 413) {
        AppLogger.logError('File too large', 'Status 413', StackTrace.current);
        throw ValidationException(
          'Image file is too large (maximum 10MB allowed)',
          stackTrace: StackTrace.current,
        );
      } else if (response.statusCode == 400) {
        final errorBody = await response.stream.bytesToString();
        AppLogger.logError('Bad request', errorBody, StackTrace.current);
        throw ValidationException(
          'Invalid image format. Please use JPG or PNG.',
          stackTrace: StackTrace.current,
        );
      } else {
        final errorBody = await response.stream.bytesToString();
        AppLogger.logError('API error', errorBody, StackTrace.current);
        throw AppError(
          'Failed to identify species (Error ${response.statusCode}). Please try again.',
          originalError: errorBody,
          stackTrace: StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      if (e is AppException) {
        rethrow;
      }
      AppLogger.logError('Unexpected error in AIService', e, stackTrace);
      throw AppError(
        'An unexpected error occurred. Please try again.',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}
