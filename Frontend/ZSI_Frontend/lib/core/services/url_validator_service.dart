import 'package:http/http.dart' as http;

/// Service for validating and testing image URLs before display
class URLValidatorService {
  static final URLValidatorService _instance = URLValidatorService._internal();
  static final Map<String, bool> _validationCache = {};

  factory URLValidatorService() {
    return _instance;
  }

  URLValidatorService._internal();

  /// Check if a URL is accessible without downloading the full image
  /// Returns true if URL is valid and accessible
  static Future<bool> isUrlValid(String url) async {
    // Check cache first
    if (_validationCache.containsKey(url)) {
      return _validationCache[url]!;
    }

    try {
      final response = await http.head(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 5));

      final isValid = response.statusCode >= 200 && response.statusCode < 400;
      _validationCache[url] = isValid;
      return isValid;
    } catch (e) {
      // Network error or timeout - consider invalid
      _validationCache[url] = false;
      return false;
    }
  }

  /// Validate a list of URLs and return only valid ones
  static Future<List<String>> filterValidUrls(List<String> urls) async {
    final results = await Future.wait(
      urls.map((url) => isUrlValid(url)),
    );

    return [
      for (int i = 0; i < urls.length; i++)
        if (results[i]) urls[i],
    ];
  }

  /// Clear validation cache (useful for testing)
  static void clearCache() {
    _validationCache.clear();
  }
}
