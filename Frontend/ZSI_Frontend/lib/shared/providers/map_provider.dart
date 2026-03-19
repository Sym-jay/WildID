import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../models/index.dart';

/// Selected location for map view and filtering
final selectedLocationProvider = Provider<LocationData?>((ref) {
  return null;
});

/// Search radius in kilometers for location-based queries
final locationSearchRadiusProvider = Provider<double>((ref) {
  return 10.0; // Default 10km
});

/// Whether to show map view or list view
final mapViewEnabledProvider = Provider<bool>((ref) {
  return false;
});

/// Filter records by location radius
final recordsByLocationProvider = Provider.family<List<UploadRecord>, List<UploadRecord>>((ref, records) {
  final selectedLocation = ref.watch(selectedLocationProvider);
  final radius = ref.watch(locationSearchRadiusProvider);

  if (selectedLocation == null || selectedLocation.latitude == null || selectedLocation.longitude == null) {
    return records;
  }

  return records.where((record) {
    if (record.location?.latitude == null || record.location?.longitude == null) {
      return false;
    }

    final distance = _calculateDistance(
      selectedLocation.latitude!,
      selectedLocation.longitude!,
      record.location!.latitude!,
      record.location!.longitude!,
    );

    return distance <= radius;
  }).toList();
});

/// Calculate distance between two coordinates (Haversine formula)
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusKm = 6371;

  double dLat = _degreesToRadians(lat2 - lat1);
  double dLon = _degreesToRadians(lon2 - lon1);

  double a = 
    (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
    (Math.cos(_degreesToRadians(lat1)) * 
     Math.cos(_degreesToRadians(lat2)) * 
     Math.sin(dLon / 2) * 
     Math.sin(dLon / 2));

  double c = 2 * Math.asin(Math.sqrt(a));
  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) {
  return degrees * (3.14159265359 / 180);
}

// Helper class for Math functions
class Math {
  static double sin(double x) => math.sin(x);
  static double cos(double x) => math.cos(x);
  static double asin(double x) => math.asin(x);
  static double sqrt(double x) => x >= 0 ? math.sqrt(x) : 0;
}

/// Species distribution - count observations by species and location
final speciesDistributionProvider = Provider<Map<String, int>>((ref) {
  return {};
});

/// Map markers for observations (simplified for display)
final mapMarkersProvider = Provider.family<List<MapMarker>, List<UploadRecord>>((ref, records) {
  return records
    .where((r) => r.location?.latitude != null && r.location?.longitude != null)
    .map((r) => MapMarker(
      latitude: r.location!.latitude!,
      longitude: r.location!.longitude!,
      recordId: r.id,
      species: r.identifiedSpecies ?? 'Unknown',
      confidence: r.confidence ?? 0,
    ))
    .toList();
});

class MapMarker {
  final double latitude;
  final double longitude;
  final String recordId;
  final String species;
  final double confidence;

  MapMarker({
    required this.latitude,
    required this.longitude,
    required this.recordId,
    required this.species,
    required this.confidence,
  });
}
