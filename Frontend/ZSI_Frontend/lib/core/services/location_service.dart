import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../shared/models/index.dart';

/// Best-effort GPS fix for a sighting. Never throws and never blocks for long:
/// a report without coordinates is better than no report.
class LocationService {
  LocationService._();

  static Future<LocationData?> currentLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      debugPrint('Location unavailable: $e');
      return null;
    }
  }

  /// "9.96° N, 76.27° E"
  static String format(LocationData location) {
    final lat = location.latitude;
    final lon = location.longitude;
    if (lat == null || lon == null) return 'Location unknown';
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(2)}° $ns, ${lon.abs().toStringAsFixed(2)}° $ew';
  }
}
