// lib/main.dart - Phase 1: Riverpod Integration
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  // Configure image cache limits to prevent memory bloat
  imageCache.maximumSize = 100;
  imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  runApp(
    const ProviderScope(
      child: ZSIWildlifeApp(),
    ),
  );
}
