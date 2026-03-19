import 'dart:convert';
import 'package:flutter/services.dart';
import '../../shared/models/index.dart';

/// Service for looking up species data from species_data.json
class SpeciesLookupService {
  static final SpeciesLookupService _instance = SpeciesLookupService._internal();
  static List<Animal>? _cachedSpecies;

  factory SpeciesLookupService() {
    return _instance;
  }

  SpeciesLookupService._internal();

  /// Load all species data from JSON
  static Future<List<Animal>> loadSpecies() async {
    if (_cachedSpecies != null) {
      return _cachedSpecies!;
    }

    final jsonString = await rootBundle.loadString('assets/species_data.json');
    final jsonData = json.decode(jsonString) as List<dynamic>;

    _cachedSpecies = jsonData
        .map((json) => Animal(
              name: json['name'] ?? '',
              scientificName: json['scientificName'] ?? '',
              description: json['description'] ?? '',
              conservationStatus: json['conservationStatus'] ?? 'Data Deficient',
              iucnUrl: json['iucnUrl'] ?? '',
              imageUrl: json['imageUrl'] ?? '',
              additionalImageUrls: json['additionalImageUrls'] != null
                  ? List<String>.from(json['additionalImageUrls'])
                  : [],
            ))
        .toList();

    return _cachedSpecies!;
  }

  /// Find species by common name (case-insensitive)
  static Future<Animal?> findByCommonName(String name) async {
    final species = await loadSpecies();
    try {
      return species.firstWhere(
        (s) => s.name.toLowerCase() == name.toLowerCase(),
        orElse: () => null as Animal,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find species by scientific name (case-insensitive)
  static Future<Animal?> findByScientificName(String name) async {
    final species = await loadSpecies();
    try {
      return species.firstWhere(
        (s) => s.scientificName.toLowerCase() == name.toLowerCase(),
        orElse: () => null as Animal,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find species by partial name match
  static Future<Animal?> findByPartialName(String query) async {
    final species = await loadSpecies();
    try {
      return species.firstWhere(
        (s) =>
            s.name.toLowerCase().contains(query.toLowerCase()) ||
            s.scientificName.toLowerCase().contains(query.toLowerCase()),
        orElse: () => null as Animal,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all species (cached after first load)
  static Future<List<Animal>> getAllSpecies() async {
    return loadSpecies();
  }

  /// Clear cache (useful for testing)
  static void clearCache() {
    _cachedSpecies = null;
  }
}
