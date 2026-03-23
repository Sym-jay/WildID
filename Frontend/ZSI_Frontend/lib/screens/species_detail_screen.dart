
import 'package:flutter/material.dart' hide Badge;
import '../core/theme/app_theme.dart';
import '../shared/models/index.dart';
// New feature imports
import '../utils/app_utils.dart';
import '../core/services/image_cache_service.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


class SpeciesDetailScreen extends StatelessWidget {
  final Animal animal;

  const SpeciesDetailScreen({super.key, required this.animal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(animal.name),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            if (animal.imageUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 300,
                child: SpeciesImageCacheManager.speciesImage(
                  imageUrl: animal.imageUrl,
                  localAssetPath: animal.imageUrl.startsWith('assets/') ? animal.imageUrl : null,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                ),
                child: const Icon(Icons.pets, size: 100, color: Colors.white),
              ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    animal.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    animal.scientificName,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Conservation Status: ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppUtils.getStatusColor(animal.conservationStatus),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          animal.conservationStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    animal.description,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  if (animal.iucnUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => AppUtils.launchURL(context, animal.iucnUrl),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View on IUCN Red List'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

