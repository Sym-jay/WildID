// lib/core/config/cache_config.dart
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache configuration for network images.
/// Limits: max 100 images cached, 7-day expiry
class ImageCacheConfig {
  static const String _customCacheName = 'zsi_image_cache';
  static const int _maxNrOfCacheObjects = 100;
  static const Duration _stalePeriod = Duration(days: 7);

  static CacheManager get customCacheManager => CacheManager(
    Config(
      _customCacheName,
      stalePeriod: _stalePeriod,
      maxNrOfCacheObjects: _maxNrOfCacheObjects,
    ),
  );
}
