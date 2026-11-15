import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../shared/models/index.dart';
import '../config/image_compression.dart';
import '../config/error_handler.dart';
import 'offline_ai_service.dart';

/// Ensemble AI Service - Uses 3 trained models with weighted voting
/// Models: EfficientNet-B0 (40%), ResNet-50 (35%), MobileNet-V3 (25%)
/// Combined ensemble accuracy: 75%
class EnsembleAIService {
  EnsembleAIService._();

  static const String ensembleApiUrl =
      'https://zsi-wildlife-api-173142698667.us-central1.run.app/predict-ensemble';
  static const String apiKey = String.fromEnvironment('ZSI_API_KEY');

  // Hybrid mode: try cloud first, fall back to local offline if needed
  static bool enableHybridMode = true;

  // Model weights for ensemble voting (must sum to 100)
  static const double efficientnetWeight = 0.40; // 40% - highest accuracy
  static const double resnetWeight = 0.35; // 35% - medium accuracy
  static const double mobilenetWeight = 0.25; // 25% - baseline

  /// Ensemble identification with 3-model voting
  /// Returns: Ensemble result + individual model predictions
  static Future<EnsembleIdentificationResult> identifyWithEnsemble(
    File imageFile, {
    bool forceOffline = false,
  }) async {
    if (forceOffline) {
      return identifyWithEnsembleOffline(imageFile);
    }

    try {
      return await identifyWithEnsembleCloud(imageFile);
    } catch (e) {
      // Cloud failed, try offline if available
      if (enableHybridMode) {
        AppLogger.logInfo(
          'Ensemble cloud API failed, attempting offline ensemble...',
        );
        try {
          return await identifyWithEnsembleOffline(imageFile);
        } catch (offlineError) {
          // Both failed, show cloud error (primary)
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Cloud-based ensemble identification
  /// Calls /predict-ensemble endpoint on backend
  static Future<EnsembleIdentificationResult> identifyWithEnsembleCloud(
    File imageFile,
  ) async {
    try {
      // Compress image before sending
      final compressedImage = await ImageCompression.compressImage(imageFile);

      var uri = Uri.parse(ensembleApiUrl);
      var request = http.MultipartRequest('POST', uri)
        ..headers['X-API-Key'] = apiKey
        ..files.add(
          await http.MultipartFile.fromPath('file', compressedImage.path),
        );

      late http.StreamedResponse response;
      try {
        response = await request.send().timeout(const Duration(seconds: 30));
      } on TimeoutException catch (e) {
        AppLogger.logError(
          'Ensemble API request timeout',
          e,
          StackTrace.current,
        );
        throw NetworkException(
          'Request timed out. Please check your connection and try again.',
          originalError: e,
          stackTrace: StackTrace.current,
        );
      } on SocketException catch (e) {
        AppLogger.logError(
          'Network socket error in ensemble',
          e,
          StackTrace.current,
        );
        throw NetworkException(
          'Network error. Please check your internet connection.',
          originalError: e,
          stackTrace: StackTrace.current,
        );
      }

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> jsonData = json.decode(responseBody);

        AppLogger.logInfo('Ensemble prediction successful');

        return EnsembleIdentificationResult.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        AppLogger.logError(
          'Ensemble API authentication failed',
          'Status 401',
          StackTrace.current,
        );
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
        AppLogger.logError('Ensemble API error', errorBody, StackTrace.current);
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
      AppLogger.logError(
        'Unexpected error in EnsembleAIService',
        e,
        stackTrace,
      );
      throw AppError(
        'An unexpected error occurred. Please try again.',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Offline ensemble identification using local models
  static Future<EnsembleIdentificationResult> identifyWithEnsembleOffline(
    File imageFile,
  ) async {
    try {
      // Try to get predictions from offline service
      final offlinePredictions = await OfflineAIService.identifySpeciesOffline(
        imageFile,
      );

      // Fallback: If offline service works, wrap in ensemble format
      // In production, this would use local ensemble models
      return EnsembleIdentificationResult(
        ensembleResult: offlinePredictions.isNotEmpty
            ? offlinePredictions.first
            : null,
        efficientnetResults: offlinePredictions,
        resnetResults: const [],
        mobilenetResults: const [],
        modelType: 'offline-single', // Local model doesn't have ensemble
        ensembleAccuracy: 0.65,
      );
    } catch (e, stackTrace) {
      AppLogger.logError(
        'Offline ensemble identification failed',
        e,
        stackTrace,
      );
      throw AppError(
        'Offline mode unavailable. Please check your Flask server.',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get ensemble model information
  static Map<String, dynamic> getEnsembleInfo() {
    return {
      'modelType': 'ensemble',
      'version': '1.0.0',
      'accuracy': 0.75, // 75% ensemble accuracy
      'models': [
        {
          'name': 'EfficientNet-B0',
          'weight': efficientnetWeight,
          'accuracy': 0.6667,
          'parameters': '5.3M',
        },
        {
          'name': 'ResNet-50',
          'weight': resnetWeight,
          'accuracy': 0.3333,
          'parameters': '25.6M',
        },
        {
          'name': 'MobileNet-V3',
          'weight': mobilenetWeight,
          'accuracy': 0.6667,
          'parameters': '5.4M',
        },
      ],
      'votingStrategy': 'weighted',
      'description':
          'Three-model ensemble using weighted voting for robust species identification',
    };
  }
}

/// Result from ensemble prediction with all 3 models
class EnsembleIdentificationResult {
  final IdentificationResult? ensembleResult;
  final List<IdentificationResult> efficientnetResults;
  final List<IdentificationResult> resnetResults;
  final List<IdentificationResult> mobilenetResults;
  final String modelType; // 'ensemble', 'single', 'offline-single'
  final double ensembleAccuracy; // Overall ensemble accuracy %

  EnsembleIdentificationResult({
    required this.ensembleResult,
    required this.efficientnetResults,
    required this.resnetResults,
    required this.mobilenetResults,
    required this.modelType,
    required this.ensembleAccuracy,
  });

  /// Get top prediction from ensemble
  String? getTopPrediction() => ensembleResult?.label;

  /// Get ensemble confidence
  double getEnsembleConfidence() => ensembleResult?.confidence ?? 0.0;

  /// Get model with highest confidence from each model
  Map<String, IdentificationResult?> getIndividualTopPredictions() {
    return {
      'efficientnet': efficientnetResults.isNotEmpty
          ? efficientnetResults.first
          : null,
      'resnet': resnetResults.isNotEmpty ? resnetResults.first : null,
      'mobilenet': mobilenetResults.isNotEmpty ? mobilenetResults.first : null,
    };
  }

  /// Check if ensemble prediction matches individual models
  bool isModelConsensus() {
    final ensemble = ensembleResult?.label;
    if (ensemble == null) return false;

    int matches = 0;
    if (efficientnetResults.isNotEmpty &&
        efficientnetResults.first.label == ensemble) {
      matches++;
    }
    if (resnetResults.isNotEmpty && resnetResults.first.label == ensemble) {
      matches++;
    }
    if (mobilenetResults.isNotEmpty &&
        mobilenetResults.first.label == ensemble) {
      matches++;
    }

    return matches >= 2; // At least 2 models agree
  }

  /// Create from JSON response
  factory EnsembleIdentificationResult.fromJson(Map<String, dynamic> json) {
    final ensembleData = _normalizeEnsembleData(json['ensemble']);
    final individualModels = _normalizeMap(json['individual_models']);

    final efficientnetResults = _parseModelResults(
      json['efficientnet'],
      individualModels?['efficientnet'],
    );
    final resnetResults = _parseModelResults(
      json['resnet'],
      individualModels?['resnet'],
    );
    final mobilenetResults = _parseModelResults(
      json['mobilenet'],
      individualModels?['mobilenet'],
    );

    return EnsembleIdentificationResult(
      ensembleResult: ensembleData != null ? _toResult(ensembleData) : null,
      efficientnetResults: efficientnetResults,
      resnetResults: resnetResults,
      mobilenetResults: mobilenetResults,
      modelType: json['model_type'] as String? ?? 'ensemble',
      ensembleAccuracy: (json['ensemble_accuracy'] as num?)?.toDouble() ?? 0.75,
    );
  }

  static Map<String, dynamic>? _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  static Map<String, dynamic>? _normalizeEnsembleData(dynamic ensemble) {
    final data = _normalizeMap(ensemble);
    if (data == null) return null;
    if (!data.containsKey('label') && data.containsKey('species')) {
      data['label'] = data['species'];
    }
    return data;
  }

  static List<IdentificationResult> _parseModelResults(
    dynamic directResults,
    dynamic individualModelPayload,
  ) {
    final normalizedDirect = _parseResultList(directResults);
    if (normalizedDirect.isNotEmpty) {
      return normalizedDirect;
    }

    final modelData = _normalizeMap(individualModelPayload);
    if (modelData == null) {
      return const [];
    }

    final topK = _parseResultList(modelData['top_5']);
    if (topK.isNotEmpty) {
      return topK;
    }

    final species = modelData['species'];
    final confidence = modelData['confidence'];
    if (species is String && confidence != null) {
      return [
        _toResult({'label': species, 'confidence': confidence}),
      ];
    }

    return const [];
  }

  static List<IdentificationResult> _parseResultList(dynamic payload) {
    if (payload is! List) return const [];

    return payload
        .whereType<Map>()
        .map(
          (item) => _toResult(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  static IdentificationResult _toResult(Map<String, dynamic> data) {
    final labelValue = data['label'] ?? data['species'];
    final confidenceValue = data['confidence'];

    if (labelValue is! String || labelValue.trim().isEmpty) {
      throw const FormatException('Missing label/species in ensemble response');
    }

    if (confidenceValue is! num) {
      throw const FormatException('Missing confidence in ensemble response');
    }

    return IdentificationResult(
      label: labelValue.trim(),
      confidence: confidenceValue.toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'ensemble': ensembleResult != null
        ? {
            'label': ensembleResult!.label,
            'confidence': ensembleResult!.confidence,
          }
        : null,
    'efficientnet': efficientnetResults
        .map((r) => {'label': r.label, 'confidence': r.confidence})
        .toList(),
    'resnet': resnetResults
        .map((r) => {'label': r.label, 'confidence': r.confidence})
        .toList(),
    'mobilenet': mobilenetResults
        .map((r) => {'label': r.label, 'confidence': r.confidence})
        .toList(),
    'model_type': modelType,
    'ensemble_accuracy': ensembleAccuracy,
  };
}
