import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Enhanced image loading with exponential backoff retry
class ImageRetryService {
  static final _cacheManager = CacheManager(
    Config(
      'zsi_species_images_v2',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 150,
      repo: JsonCacheInfoRepository(databaseName: 'zsi_species_images_v2'),
    ),
  );

  /// Load image with automatic retry on failure
  /// Retries up to 3 times with exponential backoff
  static Future<ImageProvider> loadImageWithRetry(
    String imageUrl, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Try to load from cache first
        final cachedFile = await _cacheManager.getSingleFile(imageUrl);
        if (cachedFile.existsSync()) {
          return FileImage(cachedFile);
        }
      } catch (e) {
        // Cache miss or error, continue
        if (attempt < maxRetries - 1) {
          // Exponential backoff: 500ms, 1s, 2s
          final delay = initialDelay * (attempt + 1);
          await Future.delayed(delay);
        }
      }
    }

    // Return network image provider as fallback
    return CachedNetworkImageProvider(
      imageUrl,
      cacheManager: _cacheManager,
      maxWidth: 600,
      maxHeight: 600,
    );
  }

  /// Pre-cache images in background (useful for browse screen)
  static Future<void> precacheImage(String imageUrl) async {
    try {
      await _cacheManager.getSingleFile(imageUrl);
    } catch (e) {
      debugPrint('Failed to precache $imageUrl: $e');
    }
  }

  /// Precache multiple images
  static Future<void> precacheImages(List<String> urls) async {
    await Future.wait(
      urls.map((url) => precacheImage(url)),
      eagerError: false, // Don't fail if one image fails
    );
  }
}
