import 'dart:convert';

import 'package:flutter/services.dart';

import '../../shared/models/index.dart';

/// Looks up species from assets/species_data.json.
///
/// The model returns a common name for some classes and a scientific name for
/// others (35 of its 66 labels are scientific names), and a few labels use old
/// or misspelt names, so [findByLabel] matches the common name, the scientific
/// name or any alias.
class SpeciesLookupService {
  SpeciesLookupService._();

  static List<Animal>? _cachedSpecies;
  static Map<String, Animal>? _index;

  static Animal _fromJson(Map<String, dynamic> json) => Animal(
        name: json['name'] as String? ?? '',
        scientificName: json['scientificName'] as String? ?? '',
        description: json['description'] as String? ?? '',
        schedule: json['schedule'] as int?,
        iucnUrl: json['iucnUrl'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        additionalImageUrls: json['additionalImageUrls'] != null
            ? List<String>.from(json['additionalImageUrls'] as List)
            : const [],
        aliases: json['aliases'] != null
            ? List<String>.from(json['aliases'] as List)
            : const [],
      );

  /// Parse a species_data.json payload. Public for tests.
  static List<Animal> parse(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return list
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Normalise a name for matching: lower case, single spaces, letters only.
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Future<List<Animal>> loadSpecies() async {
    if (_cachedSpecies != null) return _cachedSpecies!;
    final jsonString = await rootBundle.loadString('assets/species_data.json');
    useSpecies(parse(jsonString));
    return _cachedSpecies!;
  }

  /// Replace the cached list (used by tests and after loading).
  static void useSpecies(List<Animal> species) {
    _cachedSpecies = species;
    _index = {
      for (final s in species) ...{
        normalize(s.name): s,
        normalize(s.scientificName): s,
        for (final alias in s.aliases) normalize(alias): s,
      },
    };
  }

  /// Synchronous lookup once [loadSpecies] has run.
  static Animal? lookupLoaded(String label) {
    final index = _index;
    if (index == null) return null;
    return index[normalize(label)];
  }

  /// Find a species by a model label: common or scientific name.
  static Future<Animal?> findByLabel(String label) async {
    await loadSpecies();
    return lookupLoaded(label);
  }

  static Future<Animal?> findByCommonName(String name) => findByLabel(name);

  static Future<Animal?> findByScientificName(String name) => findByLabel(name);

  static Future<List<Animal>> getAllSpecies() => loadSpecies();

  static void clearCache() {
    _cachedSpecies = null;
    _index = null;
  }
}
