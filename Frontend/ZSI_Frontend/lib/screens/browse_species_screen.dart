
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
import '../core/services/database_service.dart';
// New feature imports
import '../shared/widgets/user_profile_card.dart' as profile_widgets;
import '../shared/widgets/filter_panel.dart';
import '../core/services/index.dart';
import '../core/providers/species_provider.dart';
import '../widgets/index.dart';
import '../core/utils/responsive_helper.dart';
import 'species_detail_screen.dart';
import '../utils/app_utils.dart';
import '../core/services/image_cache_service.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class BrowseSpeciesScreen extends StatefulWidget {
  const BrowseSpeciesScreen({super.key});

  @override
  State<BrowseSpeciesScreen> createState() => _BrowseSpeciesScreenState();
}

class _BrowseSpeciesScreenState extends State<BrowseSpeciesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  static List<SpeciesData>? _staticCache;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Species'),
        elevation: 2,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryColor,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search species...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _buildSpeciesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesList() {
    return FutureBuilder<List<SpeciesData>>(
      future: _loadSpecies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text('Error loading species: ${snapshot.error}'),
              ],
            ),
          );
        }

        final species = snapshot.data ?? [];
        final filtered = species
            .where((s) =>
                s.commonName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.scientificName.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No species found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Use responsive layout: List on mobile, Grid on tablet
        if (ResponsiveHelper.isMobile(context)) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final speciesData = filtered[index];
              return _buildSpeciesCard(context, speciesData);
            },
          );
        } else {
          // Tablet/Desktop: Show as grid
          final crossAxisCount = ResponsiveHelper.getResponsiveCrossAxisCount(context);
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final speciesData = filtered[index];
              return _buildSpeciesGridCard(context, speciesData);
            },
          );
        }
      },
    );
  }

  Future<List<SpeciesData>> _loadSpecies() async {
    // Return cached data if available
    if (_staticCache != null) {
      return _staticCache!;
    }
    
    final jsonString = await rootBundle.loadString('assets/species_data.json');
    final jsonList = jsonDecode(jsonString) as List;
    
    final species = jsonList
        .map((item) => SpeciesData.fromJson(item as Map<String, dynamic>))
        .toList();
    
    // Sort by common name for easier browsing
    species.sort((a, b) => a.commonName.compareTo(b.commonName));
    
    // Cache the result
    _staticCache = species;
    return species;
  }

  Widget _buildSpeciesCard(BuildContext context, SpeciesData speciesData) {
    // Create Animal object for navigation to detail screen
    final animal = Animal(
      name: speciesData.commonName,
      scientificName: speciesData.scientificName,
      description: speciesData.description,
      conservationStatus: speciesData.conservationStatus,
      iucnUrl: speciesData.iucnUrl,
      imageUrl: speciesData.imageUrl,
      additionalImageUrls: speciesData.additionalImageUrls,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SpeciesDetailScreen(animal: animal),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Species Thumbnail with fade-in animation
                Hero(
                  tag: 'species_${speciesData.commonName}',
                  child: SpeciesImageCacheManager.speciesImage(
                    imageUrl: speciesData.imageUrl,
                    width: 80,
                    height: 80,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speciesData.commonName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      speciesData.scientificName,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppUtils.getStatusColor(speciesData.conservationStatus),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        speciesData.conservationStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.pets,
        size: 40,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildLoadingImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildSpeciesGridCard(BuildContext context, SpeciesData speciesData) {
    // Create Animal object for navigation to detail screen
    final animal = Animal(
      name: speciesData.commonName,
      scientificName: speciesData.scientificName,
      description: speciesData.description,
      conservationStatus: speciesData.conservationStatus,
      iucnUrl: speciesData.iucnUrl,
      imageUrl: speciesData.imageUrl,
      additionalImageUrls: speciesData.additionalImageUrls,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SpeciesDetailScreen(animal: animal),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: SpeciesImageCacheManager.speciesImage(
                  imageUrl: speciesData.imageUrl,
                  width: double.infinity,
                  height: 150,
                ),
              ),
            ),
            // Text Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    speciesData.commonName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    speciesData.scientificName,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(speciesData.conservationStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      speciesData.conservationStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(speciesData.conservationStatus),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICALLY ENDANGERED':
        return Colors.red;
      case 'ENDANGERED':
        return Colors.orange;
      case 'VULNERABLE':
        return Colors.yellow[700]!;
      case 'NEAR THREATENED':
        return Colors.yellow[600]!;
      default:
        return Colors.green;
    }
  }
}

// ============================================================================
// SPECIES DETAIL SCREEN
// ============================================================================


