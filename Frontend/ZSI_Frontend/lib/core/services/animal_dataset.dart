/// Legacy AnimalDataset stub
/// This was used in older versions. Modern code fetches species data from backend.
class AnimalDataset {
  static dynamic findAnimalByName(String name) {
    // Legacy method - no longer used in refactored code
    return null;
  }

  static Future<void> loadAnimals() async {
    // Legacy method - no longer used in refactored code
    // Modern code fetches species data from backend
  }

  static List<dynamic> searchAnimals(String query) {
    // Legacy method - no longer used in refactored code
    return [];
  }

  static List<dynamic> get animals {
    // Legacy method - no longer used in refactored code
    return [];
  }
}
