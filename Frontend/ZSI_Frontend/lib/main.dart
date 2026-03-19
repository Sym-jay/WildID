// lib/main.dart - Phase 1: Riverpod Integration
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/feedback_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure image cache limits to prevent memory bloat
  imageCache.maximumSize = 100;
  imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  // Initialize feedback service
  await FeedbackService.initialize();

  runApp(
    const ProviderScope(
      child: ZSIWildlifeApp(),
    ),
  );
}
