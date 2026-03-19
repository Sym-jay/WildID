import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

class SpeciesData {
  final String commonName;
  final String scientificName;
  final String description;
  final String conservationStatus;
  final String iucnUrl;
  final String imageUrl;
  final List<String> additionalImageUrls;

  SpeciesData({
    required this.commonName,
    required this.scientificName,
    required this.description,
    required this.conservationStatus,
    required this.iucnUrl,
    required this.imageUrl,
    this.additionalImageUrls = const [],
  });

  factory SpeciesData.fromJson(Map<String, dynamic> json) {
    return SpeciesData(
      commonName: json['name'] ?? '',
      scientificName: json['scientificName'] ?? '',
      description: json['description'] ?? '',
      conservationStatus: json['conservationStatus'] ?? 'Not Evaluated',
      iucnUrl: json['iucnUrl'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      additionalImageUrls: (json['additionalImageUrls'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }
}

// Provider to load species from JSON asset
final speciesProvider = FutureProvider<List<SpeciesData>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/species_data.json');
  final jsonList = jsonDecode(jsonString) as List;
  
  final species = jsonList
      .map((item) => SpeciesData.fromJson(item as Map<String, dynamic>))
      .toList();
  
  // Sort by common name for easier browsing
  species.sort((a, b) => a.commonName.compareTo(b.commonName));
  
  return species;
});
