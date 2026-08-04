import '../../shared/models/index.dart';

class PredictionParser {
  PredictionParser._();

  static List<IdentificationResult> parsePredictionResults(dynamic payload) {
    if (payload is List) {
      return _parseResultList(payload);
    }

    if (payload is Map<String, dynamic>) {
      final rawPredictions = payload['predictions'] ?? payload['results'];
      if (rawPredictions is List) {
        return _parseResultList(rawPredictions);
      }
    }

    throw const FormatException(
      'Unsupported prediction response format: expected a list or a map with predictions',
    );
  }

  static List<IdentificationResult> _parseResultList(
    List<dynamic> predictions,
  ) {
    return predictions.map((dynamic item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid prediction item: expected object');
      }

      final label = _extractLabel(item);
      final confidence = _extractConfidence(item);

      return IdentificationResult(label: label, confidence: confidence);
    }).toList();
  }

  static String _extractLabel(Map<String, dynamic> item) {
    final dynamic rawLabel =
        item['label'] ?? item['species'] ?? item['common_name'];
    if (rawLabel is String && rawLabel.trim().isNotEmpty) {
      return rawLabel.trim();
    }
    throw const FormatException('Prediction item is missing a valid label');
  }

  static double _extractConfidence(Map<String, dynamic> item) {
    final dynamic rawConfidence = item['confidence'] ?? item['score'];
    if (rawConfidence is num) {
      return rawConfidence.toDouble();
    }

    if (rawConfidence is String) {
      final normalized = rawConfidence.trim().replaceAll('%', '');
      final parsed = double.tryParse(normalized);
      if (parsed != null) {
        return rawConfidence.contains('%') ? parsed / 100 : parsed;
      }
    }

    final dynamic confidencePercent = item['confidence_percent'];
    if (confidencePercent is String) {
      final normalized = confidencePercent.trim().replaceAll('%', '');
      final parsed = double.tryParse(normalized);
      if (parsed != null) {
        return parsed / 100;
      }
    }

    throw const FormatException(
      'Prediction item is missing a valid confidence score',
    );
  }
}
