import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Model for AI feedback
class AIFeedback {
  final String id;
  final String predictedSpecies;
  final String actualSpecies;
  final double aiConfidence;
  final String? identifyingFeatures;
  final String? difficultyRating; // 'easy', 'moderate', 'hard'
  final String? additionalNotes;
  final String imagePath;
  final DateTime timestamp;

  AIFeedback({
    required this.id,
    required this.predictedSpecies,
    required this.actualSpecies,
    required this.aiConfidence,
    this.identifyingFeatures,
    this.difficultyRating,
    this.additionalNotes,
    required this.imagePath,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'predicted_species': predictedSpecies,
    'actual_species': actualSpecies,
    'ai_confidence': aiConfidence,
    'identifying_features': identifyingFeatures,
    'difficulty_rating': difficultyRating,
    'additional_notes': additionalNotes,
    'image_path': imagePath,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AIFeedback.fromJson(Map<String, dynamic> json) => AIFeedback(
    id: json['id'],
    predictedSpecies: json['predicted_species'],
    actualSpecies: json['actual_species'],
    aiConfidence: json['ai_confidence'],
    identifyingFeatures: json['identifying_features'],
    difficultyRating: json['difficulty_rating'],
    additionalNotes: json['additional_notes'],
    imagePath: json['image_path'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

/// Service for managing AI feedback and storing corrections
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  static List<AIFeedback> _feedbackCache = [];
  static String? _feedbackFilePath;

  factory FeedbackService() {
    return _instance;
  }

  FeedbackService._internal();

  /// Initialize feedback service and load existing feedback
  static Future<void> initialize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _feedbackFilePath = '${dir.path}/ai_feedback.json';
      await _loadFeedback();
    } catch (e) {
      debugPrint('Failed to initialize feedback service: $e');
    }
  }

  /// Save feedback when user reports wrong identification
  static Future<bool> submitFeedback(AIFeedback feedback) async {
    try {
      _feedbackCache.add(feedback);
      await _saveFeedback();
      debugPrint('Feedback saved: ${feedback.id}');
      return true;
    } catch (e) {
      debugPrint('Failed to save feedback: $e');
      return false;
    }
  }

  /// Load all previous feedback from storage
  static Future<void> _loadFeedback() async {
    try {
      if (_feedbackFilePath == null) return;
      
      final file = File(_feedbackFilePath!);
      if (!file.existsSync()) {
        _feedbackCache = [];
        return;
      }

      final contents = await file.readAsString();
      final jsonData = json.decode(contents) as List<dynamic>;
      _feedbackCache = jsonData
          .map((item) => AIFeedback.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load feedback: $e');
      _feedbackCache = [];
    }
  }

  /// Save feedback to local storage
  static Future<void> _saveFeedback() async {
    try {
      if (_feedbackFilePath == null) return;
      
      final file = File(_feedbackFilePath!);
      final jsonData = _feedbackCache.map((f) => f.toJson()).toList();
      await file.writeAsString(json.encode(jsonData), flush: true);
    } catch (e) {
      debugPrint('Failed to save feedback file: $e');
    }
  }

  /// Get all stored feedback
  static List<AIFeedback> getAllFeedback() {
    return List.from(_feedbackCache);
  }

  /// Get feedback count
  static int getFeedbackCount() {
    return _feedbackCache.length;
  }

  /// Get feedback for specific species (corrections)
  static List<AIFeedback> getFeedbackForSpecies(String speciesName) {
    return _feedbackCache
        .where((f) => f.actualSpecies.toLowerCase() == speciesName.toLowerCase())
        .toList();
  }

  /// Get common misidentifications
  static Map<String, int> getMisidentificationStats() {
    final stats = <String, int>{};
    for (var feedback in _feedbackCache) {
      final key = '${feedback.predictedSpecies} → ${feedback.actualSpecies}';
      stats[key] = (stats[key] ?? 0) + 1;
    }
    return stats;
  }

  /// Clear all feedback (for testing)
  static void clearFeedback() {
    _feedbackCache = [];
  }

  /// Export feedback for model retraining
  static Future<String> exportFeedbackJSON() async {
    return json.encode(_feedbackCache.map((f) => f.toJson()).toList());
  }
}
