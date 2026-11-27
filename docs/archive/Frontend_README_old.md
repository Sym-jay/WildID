# ZSI Wildlife Identifier

A modern Flutter application for wildlife species identification, developed by the Zoological Survey of India (ZSI). This app leverages machine learning and community verification to accurately identify Indian wildlife species from photographs.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

### Core Functionality
- **Image-Based Species Identification**: Upload wildlife photos for automatic species identification using ML models
- **Community Verification**: Community voting system for identifying unverified specimens
- **Expert Review**: Expert verification queue for scientific validation of identifications
- **Offline Support**: Full offline capability with SQLite local storage and automatic sync when online
- **Multi-Platform**: Runs on Android, iOS, Web, Windows, Linux, and macOS

### Scientific Features
- **Rich Metadata**: Capture habitat type, water temperature, depth, turbidity, and observed behaviors
- **Geolocation**: Automatic location capture (latitude, longitude, accuracy, address)
- **IUCN Integration**: Links to IUCN RedList data for conservation status
- **Multiple Reference Images**: Support for multiple wildlife reference images from Wikimedia and iNaturalist

### Data Management
- **Upload History**: Complete tracking of all sightings with verification status
- **Export Functionality**: CSV export of sighting records for analysis
- **Database Persistence**: SQLite database for reliable local and cloud storage
- **Admin Dashboard**: Administrative panel for managing identifications and verifications

## Project Structure

The app uses a **feature-based modular architecture** with **Riverpod** for reactive state management, similar to React hooks pattern.

```
lib/
├── main.dart                           # App entry point with ProviderScope wrapper
├── main_app_screens.dart               # Temporary monolithic screens file (being refactored)
├── core/                               # Shared core functionality
│   ├── services/                       # Business logic services
│   │   ├── database_service.dart       # SQLite persistence
│   │   ├── auth_service.dart           # Authentication
│   │   ├── ai_service.dart             # ML inference
│   │   ├── archive_service.dart        # Upload history and archival
│   │   └── sms_service.dart            # SMS notifications
│   ├── providers/                      # Service-level Riverpod providers
│   │   ├── services_provider.dart      # Dependency injection
│   │   └── app_providers.dart          # App-level state
│   └── theme/
│       └── app_theme.dart              # Material Design 3 theme
├── shared/                             # Reusable across all features
│   ├── models/
│   │   └── index.dart                  # Data models (Animal, UploadRecord, etc.)
│   ├── providers/                      # Global state providers
│   │   ├── app_state_provider.dart     # Navigation, loading, errors
│   │   ├── auth_user_provider.dart     # Current user state
│   │   └── database_provider.dart      # Database access
│   ├── widgets/                        # Reusable UI components
│   │   ├── loading_indicator.dart
│   │   ├── error_dialog.dart
│   │   ├── confirmation_dialog.dart
│   │   └── custom_button.dart
│   └── utils/                          # Shared utilities
│       ├── constants.dart              # Magic strings, API URLs, limits
│       ├── validators.dart             # Email, phone validators
│       └── formatters.dart             # Date, number formatting
└── features/                           # Feature modules (planned)
    ├── auth/                           # Authentication feature
    ├── identification/                 # ML species identification
    ├── metadata/                       # Habitat and behavior capture
    ├── verification/                   # Community voting, expert review
    ├── history/                        # Upload history and browsing
    └── admin/                          # Admin dashboard and management

test/
├── widget_test.dart                    # Theme and widget tests
└── ... (other tests to be added)
```

### Architecture Benefits

- **Reactive State**: Riverpod's `StateProvider` and `FutureProvider` enable automatic UI updates
- **Dependency Injection**: Service providers eliminate tight coupling
- **Testability**: Pure functions and isolated providers are easy to mock
- **Scalability**: Feature-based modules can be developed and tested independently
- **Code Reuse**: Shared components and utilities reduce duplication

## Getting Started

### Prerequisites
- Flutter 3.8.1 or higher
- Dart 3.8.1 or higher
- Android SDK (for Android development)
- Xcode (for iOS development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ZSI-India/ZSI_Frontend.git
   cd ZSI_Frontend
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # Development
   flutter run
   
   # Release build
   flutter run --release
   ```

### Platform-Specific Setup

#### Android
```bash
cd android
./gradlew build
cd ..
flutter run
```

#### iOS
```bash
cd ios
pod install
cd ..
flutter run
```

#### Web
```bash
flutter run -d chrome
```

#### Windows/Linux/macOS
```bash
flutter run -d windows  # or linux, macos
```

## Dependencies

### State Management & Architecture
- `flutter_riverpod`: Reactive state management with hooks-like pattern
- `flutter`: UI framework
- `flutter_test`: Testing framework

### Networking & Storage
- `http`: HTTP client for API requests
- `sqflite`: SQLite database
- `path_provider`: Platform-specific file access
- `shared_preferences`: Persistent key-value storage

### Media & Location
- `image_picker`: Camera/gallery image selection
- `cached_network_image`: Efficient image loading and caching
- `geolocator`: GPS location services
- `geocoding`: Convert coordinates to addresses
- `permission_handler`: Runtime permission handling

### UI & Design
- `google_fonts`: Modern typography
- `flutter_launcher_icons`: App icon management
- `share_plus`: Share functionality

### Utilities
- `intl`: Date formatting and localization
- `url_launcher`: Open URLs

## Riverpod State Management

The app uses **Riverpod** for reactive state management - a modern, hooks-like pattern for Flutter inspired by React.

### Provider Types Used

- **`StateProvider`**: Simple mutable state (loading, error messages)
  ```dart
  final loadingProvider = StateProvider<bool>((ref) => false);
  ```

- **`Provider`**: Computed/derived state (read-only)
  ```dart
  final databaseServiceProvider = Provider((ref) => DatabaseService);
  ```

- **`FutureProvider`**: Async operations (API calls, database queries)
  ```dart
  final speciesProvider = FutureProvider<List<Animal>>((ref) async {
    return AnimalDataset.loadAnimals();
  });
  ```

- **`StateNotifierProvider`**: Complex mutable state (feature state machines)
  ```dart
  // Future: for feature-level state
  final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
    return AuthNotifier(ref.watch(authServiceProvider));
  });
  ```

### Accessing Providers in Widgets

```dart
// In StatelessWidget with ConsumerWidget
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loadingProvider);
    final animals = ref.watch(speciesProvider);
    
    return animals.when(
      data: (animalList) => ListView(...),
      loading: () => LoadingIndicator(),
      error: (err, stack) => ErrorDialog(message: err.toString()),
    );
  }
}

// In StatefulWidget
final container = ProviderContainer();
final value = container.read(loadingProvider);
```

### Key Benefits Over Previous Architecture

| Aspect | Before | With Riverpod |
|--------|--------|---------------|
| State Management | setState, inherited widgets | Reactive providers with auto-updates |
| Dependency Injection | Service locator pattern | Provider hierarchy with ref.watch |
| Testability | Global singletons | Pure functions, easy mocking |
| Code Reuse | Manual widget composition | Composable providers |
| Performance | Manual optimization | Built-in memoization and caching |

## Testing

## Usage

### Taking a Photograph
1. Tap **"Select Image"** on the home screen
2. Choose from camera or gallery
3. The app will automatically identify the species

### Viewing Identification Results
- See the identified species with confidence score
- View IUCN conservation status and links
- See additional reference images for verification

### Submitting Metadata
1. Complete the optional metadata form (habitat, water conditions, behaviors)
2. The data is automatically saved locally
3. When online, data syncs to the government server

### Verifying Identifications
1. Go to **"Verification Queue"**
2. Review unverified sightings
3. Community votes and expert verifications are tracked
4. Admin can approve or reject identifications

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models_test.dart
flutter test test/database_test.dart
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

## Code Quality

```bash
# Analyze code for issues
flutter analyze

# Format code
dart format lib test

# Run linter
flutter analyze --no-pub
```

## Database Schema

### upload_records
Stores all sighting records with species identification, metadata, and verification status.

**Key fields:**
- `id`: Unique record identifier
- `imagePath`: Path to stored image
- `timestamp`: When the record was created
- `identifiedSpecies`: ML-identified species name
- `confidence`: Confidence score (0-1)
- `status`: 'pending', 'verified', or 'rejected'
- `habitatType`: Habitat classification
- `waterTemperature`, `waterDepth`, `waterTurbidity`: Aquatic metadata
- `behaviors`: Observable behaviors

### expert_verifications
Tracks expert review and verification of identifications.

**Key fields:**
- `verificationId`: Unique verification identifier
- `recordId`: Foreign key to upload_records
- `verifiedSpecies`: Expert-verified species
- `confidenceScore`: Expert confidence (0-100)
- `status`: 'accepted', 'rejected', or 'needs_clarification'

### community_votes
Records community voting for species identification.

**Key fields:**
- `recordId`: Foreign key to upload_records
- `suggestedSpecies`: Species suggested by community
- `voteCount`: Number of votes received
- `voters`: List of user IDs who voted

## API Integration

The app communicates with a government backend server for:
- Uploading sighting data
- Fetching species information
- Syncing verifications
- Exporting historical data

**API Base URL**: `https://your-goi-server.gov.in/api`

## Security

- ✅ All data is encrypted in transit (HTTPS)
- ✅ User credentials are stored securely with SharedPreferences
- ✅ Local database is encrypted when possible
- ✅ No sensitive data in logs
- ✅ API authentication via tokens

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Dart style guide (dart analyze)
- Write tests for new features
- Update documentation
- Use meaningful commit messages

## Troubleshooting

### App won't build
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Database errors
- Delete app and reinstall to reset database
- Check SQLite plugin is properly installed: `flutter pub list`

### Location permissions denied
- Grant permissions in app settings
- For testing, use device location mocking

### Image loading issues
- Check internet connectivity for remote images
- Cached images are stored locally

## Performance

- Database queries are indexed for fast lookups
- Images are cached locally to reduce bandwidth
- Lazy loading of images in lists
- Minimal memory footprint on older devices

## Roadmap

### Current Phase: Riverpod Refactoring (In Progress)
- [x] Phase 1: Setup Riverpod and core services architecture
- [x] Phase 2: Create shared components, models, providers, and utilities
- [ ] Phase 3: Extract Authentication feature (login, register, OTP)
- [ ] Phase 4: Extract Home and Image Selection feature
- [ ] Phase 5: Extract ML Identification feature
- [ ] Phase 6: Extract Metadata capture feature
- [ ] Phase 7: Extract Verification and voting feature
- [ ] Phase 8: Extract History browsing feature
- [ ] Phase 9: Extract Species database feature
- [ ] Phase 10: Extract Admin dashboard
- [ ] Phase 11: Extract remaining utilities and helpers
- [ ] Phase 12: Final cleanup and test suite
- [ ] Phase 13: Responsive design and performance optimization

### Future Features
- [ ] Multi-language support (Hindi, Tamil, Bengali)
- [ ] Offline ML inference
- [ ] Advanced analytics dashboard
- [ ] Photo filtering and enhancement tools
- [ ] AR visualization of identified species
- [ ] Mobile-native performance optimization

## Known Issues

- `flutter analyze` reports false positives on Riverpod StateProvider (build works correctly)
- Database sync may be slow on poor network connections
- Some deprecation warnings in older Flutter versions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For questions or support, please contact:
- **ZSI**: https://www.zsi.gov.in
- **Email**: wildlife-identifier@zsi.gov.in
- **Issues**: GitHub Issues

## Acknowledgments

- Zoological Survey of India (ZSI)
- Flutter and Dart teams
- Contributing developers and wildlife enthusiasts
- Wikimedia Commons for reference images
- iNaturalist for species data

## Version History

### v1.1.0 (Current - In Development)
**Riverpod Refactoring Complete: Phases 1 & 2**

- ✅ Added `flutter_riverpod` dependency
- ✅ Created modular folder structure (core/, shared/)
- ✅ Extracted 5 services to core/services/ with Riverpod providers
- ✅ Extracted 6 data models to shared/models/
- ✅ Created 3 reusable shared providers (database, auth_user, app_state)
- ✅ Created 4 reusable shared widgets (loading, error dialog, confirmation dialog, custom button)
- ✅ Created shared utilities (constants, validators, formatters)
- ✅ Minimized main.dart from 4,868 lines to 14 lines (just ProviderScope wrapper)
- ✅ App builds and runs successfully on all platforms
- ✅ All existing functionality preserved (100% compatible)
- ✅ 28 existing tests passing
- ✅ Ready for Phase 3: Feature extraction

**Files Created: 19 new Dart files**
- Folder structure: lib/core/ and lib/shared/ complete
- All imports updated and verified
- Theme, services, and models organized by concern

### v1.0.0 (Previous)
- Initial monolithic architecture with 4,868 lines in main.dart
- Full feature set implemented
- 28 tests
- Production-ready on all platforms

## Last Updated

**Date**: March 14, 2026  
**Version**: 1.1.0-dev (Riverpod refactoring in progress)  
**Maintained by**: ZSI Development Team

---
