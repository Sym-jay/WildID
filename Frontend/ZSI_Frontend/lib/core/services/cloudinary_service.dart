/// Cloudinary CDN Service for image hosting
/// 
/// This service provides methods to upload species images to Cloudinary
/// and retrieve optimized URLs for fast, reliable image delivery.
/// 
/// Setup:
/// 1. Create free account at https://cloudinary.com
/// 2. Get your cloud name from the dashboard
/// 3. Set environment variable: CLOUDINARY_CLOUD_NAME
/// 
/// Usage:
/// ```dart
/// final service = CloudinaryService(cloudName: 'your-cloud-name');
/// final url = service.getImageUrl(publicId, width: 500, quality: 'auto');
/// ```

class CloudinaryService {
  final String cloudName;
  
  CloudinaryService({required this.cloudName});
  
  /// Generate optimized Cloudinary URL for species images
  /// 
  /// Parameters:
  /// - publicId: Image identifier in Cloudinary
  /// - width: Image width (auto-scales)
  /// - quality: 'auto' for intelligent compression
  /// - format: Image format ('webp', 'jpg', 'png')
  String getImageUrl(
    String publicId, {
    int width = 500,
    String quality = 'auto',
    String format = 'webp',
  }) {
    return 'https://res.cloudinary.com/$cloudName/image/upload/'
        'w_$width,q_$quality,f_$format,c_fill,ar_1:1/'
        '$publicId';
  }
  
  /// Generate thumbnail URL (for browse screen)
  String getThumbnailUrl(String publicId) {
    return getImageUrl(publicId, width: 200, format: 'webp');
  }
  
  /// Generate full-screen URL (for detail screen)
  String getFullImageUrl(String publicId) {
    return getImageUrl(publicId, width: 800, format: 'webp');
  }
}
