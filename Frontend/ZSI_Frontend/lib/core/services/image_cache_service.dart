import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager with intelligent caching and fallback
class SpeciesImageCacheManager {
  static final _cacheManager = CacheManager(
    Config(
      'zsi_species_images',
      stalePeriod: const Duration(days: 30),  // Cache for 30 days
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: 'zsi_species_images'),
    ),
  );

  /// Widget for displaying species images with smart fallback and retry
  static Widget speciesImage({
    required String imageUrl,
    String? localAssetPath,
    double width = 80,
    double height = 80,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    // Try local asset first if available
    if (localAssetPath != null && localAssetPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: Image.asset(
          localAssetPath,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorImage(width, height),
        ),
      );
    }

    // Validate URL format
    if (!_isValidImageUrl(imageUrl)) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: _buildErrorImage(width, height),
      );
    }

    // Use cached network image with smart fallback
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        cacheManager: _cacheManager,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildLoadingImage(width, height),
        errorWidget: (context, url, error) {
          debugPrint('Image load failed: $url - Error: $error');
          return _buildErrorImage(width, height);
        },
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ),
    );
  }

  /// Validate URL format
  static bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }

  /// Loading placeholder with smooth animation
  static Widget _buildLoadingImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[200]!,
            Colors.grey[100]!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image,
          size: width * 0.35,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  /// Error fallback with gradient
  static Widget _buildErrorImage(double width, double height) {
    // Create a colorful gradient fallback instead of gray
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[300]!,
            Colors.cyan[300]!,
          ],
        ),
      ),
      child: Icon(
        Icons.aquarium,
        size: width * 0.4,
        color: Colors.white,
      ),
    );
  }
}
