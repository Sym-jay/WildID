import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../shared/models/index.dart';
import '../config/error_handler.dart';
import 'ensemble_ai_service.dart' show EnsembleIdentificationResult;
import 'prediction_parser.dart';

/// What the identification produced, already cleaned up for display.
class IdentificationOutcome {
  const IdentificationOutcome({required this.results, required this.source});

  /// Best first, at most three, confidence > 0. Empty means "not recognised".
  final List<IdentificationResult> results;

  /// 'ensemble', 'single' or 'demo'.
  final String source;

  bool get recognized => results.isNotEmpty;
  IdentificationResult? get top => results.isEmpty ? null : results.first;
  bool get isDemo => source == 'demo';
}

/// Sends a photo to the WildID API and returns ranked matches.
///
/// Works on Android, iOS and web (uploads bytes, never a file path). Tries the
/// ensemble endpoint first and falls back to the single model, so an older
/// server without /predict-ensemble still works.
class IdentificationService {
  IdentificationService._();

  static const String baseUrl = String.fromEnvironment(
    'ZSI_API_BASE_URL',
    defaultValue: 'https://zsi-wildlife-api-173142698667.us-central1.run.app',
  );
  static const String _apiKey = String.fromEnvironment('ZSI_API_KEY');

  /// Build with --dart-define=ZSI_DEMO=true to get a canned result without a
  /// server (presentations, UI testing). The result screen labels it.
  static const bool demoMode = bool.fromEnvironment('ZSI_DEMO');

  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxResults = 3;

  static Future<IdentificationOutcome> identify(XFile image) async {
    if (demoMode) return _demo();
    if (_apiKey.isEmpty) {
      throw AppError(
        'Identification is not set up in this build. '
        'Rebuild with --dart-define=ZSI_API_KEY=<key>.',
      );
    }

    final bytes = await _prepare(image);
    try {
      final ensemble = await _post('/predict-ensemble', bytes);
      final results = _fromEnsemble(ensemble);
      return IdentificationOutcome(results: results, source: 'ensemble');
    } on AuthException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      debugPrint('Ensemble unavailable, using single model: $e');
    }

    final single = await _post('/predict', bytes);
    return IdentificationOutcome(
      results: clean(PredictionParser.parsePredictionResults(single)),
      source: 'single',
    );
  }

  /// Shrink the photo before upload; fall back to the original bytes.
  static Future<Uint8List> _prepare(XFile image) async {
    final original = await image.readAsBytes();
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        original,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
      );
      if (compressed.isNotEmpty && compressed.length < original.length) {
        return compressed;
      }
    } catch (e) {
      debugPrint('Compression skipped: $e');
    }
    return original;
  }

  static Future<dynamic> _post(String path, Uint8List bytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers['X-API-Key'] = _apiKey
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'photo.jpg'),
      );

    late http.Response response;
    try {
      response = await http.Response.fromStream(
        await request.send().timeout(_timeout),
      );
    } on TimeoutException catch (e, st) {
      throw NetworkException(
        'The server took too long to answer. Check your signal and try again.',
        originalError: e,
        stackTrace: st,
      );
    } on http.ClientException catch (e, st) {
      throw NetworkException(
        'No connection to the server. Check your internet and try again.',
        originalError: e,
        stackTrace: st,
      );
    }

    switch (response.statusCode) {
      case 200:
        return json.decode(response.body);
      case 401:
        throw AuthException('This app version is not authorised to use the server.');
      case 413:
        throw ValidationException('The photo is too large. Try again with a smaller one.');
      case 400:
        throw ValidationException('The photo could not be read. Use a JPG or PNG.');
      default:
        throw AppError('Server error (${response.statusCode}).');
    }
  }

  static List<IdentificationResult> _fromEnsemble(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Unexpected ensemble response');
    }
    final parsed = EnsembleIdentificationResult.fromJson(payload);
    final others = clean([
      ...parsed.efficientnetResults,
      ...parsed.resnetResults,
      ...parsed.mobilenetResults,
    ]);
    final top = parsed.ensembleResult;
    if (top == null) {
      if (others.isEmpty) throw const FormatException('Empty ensemble response');
      return others;
    }
    // The ensemble's vote is the answer; individual models only supply
    // alternatives, since their scores are not on the same scale.
    final cleanedTop = clean([top]);
    if (cleanedTop.isEmpty) return const [];
    final topKey = cleanedTop.first.label.toLowerCase();
    return [
      cleanedTop.first,
      ...others.where((r) => r.label.toLowerCase() != topKey),
    ].take(_maxResults).toList();
  }

  /// Drop "not recognised" placeholders and zero scores, keep the best score
  /// per label, rank, and cap at three. Public for tests.
  static List<IdentificationResult> clean(List<IdentificationResult> raw) {
    final best = <String, IdentificationResult>{};
    for (final r in raw) {
      final label = r.label.trim();
      if (label.isEmpty || r.confidence <= 0) continue;
      final lower = label.toLowerCase();
      if (lower.contains('not recognized') || lower.contains('not recognised') ||
          lower == 'unknown') {
        continue;
      }
      final key = lower;
      final existing = best[key];
      if (existing == null || r.confidence > existing.confidence) {
        best[key] = IdentificationResult(
          label: label,
          confidence: r.confidence.clamp(0.0, 1.0),
        );
      }
    }
    final list = best.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return list.take(_maxResults).toList();
  }

  static Future<IdentificationOutcome> _demo() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    return IdentificationOutcome(
      source: 'demo',
      results: [
        IdentificationResult(label: 'Reef Manta Ray', confidence: 0.91),
        IdentificationResult(label: 'Giant Oceanic Manta Ray', confidence: 0.06),
        IdentificationResult(label: 'Mobula mobular', confidence: 0.02),
      ],
    );
  }
}
