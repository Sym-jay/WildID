import 'package:fish_id_india/core/services/ensemble_ai_service.dart';
import 'package:fish_id_india/core/services/prediction_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PredictionParser', () {
    test('parses legacy list payload', () {
      final payload = [
        {'label': 'Whale Shark', 'confidence': 0.92},
        {'label': 'Manta Ray', 'confidence': 0.06},
      ];

      final results = PredictionParser.parsePredictionResults(payload);

      expect(results, hasLength(2));
      expect(results.first.label, 'Whale Shark');
      expect(results.first.confidence, closeTo(0.92, 0.0001));
    });

    test('parses envelope payload with predictions key', () {
      final payload = {
        'success': true,
        'predictions': [
          {'label': 'Whale Shark', 'confidence': 0.88},
        ],
      };

      final results = PredictionParser.parsePredictionResults(payload);

      expect(results, hasLength(1));
      expect(results.first.label, 'Whale Shark');
      expect(results.first.confidence, closeTo(0.88, 0.0001));
    });
  });

  group('EnsembleIdentificationResult', () {
    test('parses extended backend format', () {
      final payload = {
        'success': true,
        'ensemble': {'species': 'Whale Shark', 'confidence': 0.91},
        'individual_models': {
          'efficientnet': {
            'species': 'Whale Shark',
            'confidence': 0.93,
            'top_5': [
              {'species': 'Whale Shark', 'confidence': 0.93},
              {'species': 'Manta Ray', 'confidence': 0.04},
            ],
          },
          'resnet': {
            'species': 'Whale Shark',
            'confidence': 0.88,
            'top_5': [
              {'species': 'Whale Shark', 'confidence': 0.88},
            ],
          },
          'mobilenet': {
            'species': 'Manta Ray',
            'confidence': 0.61,
            'top_5': [
              {'species': 'Manta Ray', 'confidence': 0.61},
            ],
          },
        },
      };

      final result = EnsembleIdentificationResult.fromJson(payload);

      expect(result.ensembleResult?.label, 'Whale Shark');
      expect(result.efficientnetResults, isNotEmpty);
      expect(result.resnetResults, isNotEmpty);
      expect(result.mobilenetResults, isNotEmpty);
      expect(
        result.getIndividualTopPredictions()['efficientnet']?.label,
        'Whale Shark',
      );
    });

    test('parses normalized format with per-model arrays', () {
      final payload = {
        'ensemble': {'label': 'Manta Ray', 'confidence': 0.85},
        'efficientnet': [
          {'label': 'Manta Ray', 'confidence': 0.83},
        ],
        'resnet': [
          {'label': 'Manta Ray', 'confidence': 0.81},
        ],
        'mobilenet': [
          {'label': 'Whale Shark', 'confidence': 0.55},
        ],
      };

      final result = EnsembleIdentificationResult.fromJson(payload);

      expect(result.ensembleResult?.label, 'Manta Ray');
      expect(result.efficientnetResults.first.label, 'Manta Ray');
      expect(result.resnetResults.first.label, 'Manta Ray');
      expect(result.mobilenetResults.first.label, 'Whale Shark');
    });
  });
}
