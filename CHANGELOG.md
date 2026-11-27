# Changelog

All notable changes to the ZSI Wildlife Identifier project are documented in this file.

## [Unreleased]

### Changed
- New "Sea-warning" design: colour-coded protection verdict (Schedule I, Schedule II, unsure,
  not listed), bottom navigation (Identify, Species, History, Profile), light and dark themes,
  bundled Anek Latin font.
- Species data: protection schedule for every species from the ZSI dataset; corrected common
  and scientific names; duplicate oceanic whitetip entry merged (65 species).
- Android build updated to Gradle 9.5, AGP 9.3.1, Kotlin 2.4 and Java 17 (current Flutter).
- Backend deployable on Cloud Run: CPU-only image, `api_extended:app`, weights from `models/`.

### Fixed
- Species information was missing for 35 of the model's labels.
- Reports were lost on restart, duplicated when details were added, and verify/delete did not
  update the list.
- Ensemble failures did not fall back to the single model.
- Expert review screen crashed; status bar and screen-reader issues; unbuildable Android project.

### Security
- Salted PBKDF2 password hashing; OTP codes generated and checked by the server; no default
  API keys.

### Added
- Tests: Playwright phone-size tests for the web build, Patrol native Android test, backend
  server smoke test; GitHub Actions CI.

## [1.0.0] - 2026-03-13

### Added
- Initial stable release of ZSI Wildlife Identifier
- Complete SQLite database integration for offline support
- Expert verification workflow for scientific validation
- Community voting system for identification verification
- Geolocation tracking with address resolution
- Rich scientific metadata capture (habitat type, water conditions, behaviors)
- Multi-image reference system (Wikimedia, iNaturalist)
- IUCN RedList integration for conservation status
- CSV export functionality for sighting records
- Admin dashboard for record management and verification
- User authentication with email/phone/OTP support
- SMS notification system for important updates
- Material Design 3 theming with modern forest green color palette
- Full offline capability with automatic sync when online
- Support for Android, iOS, Web, Windows, Linux, macOS
- Comprehensive test suite (unit, widget, integration tests)
- Professional documentation and setup guides

### Fixed
- All Flutter deprecation warnings (withOpacity → withValues, TextFormField value → initialValue)
- Unused variable declarations
- Field mutability issues

### Infrastructure
- Implemented proper project structure with feature-based modules
- Created models module with all data classes
- Created services module with DatabaseService
- Created theme module with AppTheme configuration
- Enhanced .gitignore for cleaner repository
- Added comprehensive test suite (28+ tests)
- Improved code analysis (0 issues)

### Dependencies
- flutter_test: Testing framework
- sqflite: ^2.3.0 - SQLite database
- path_provider: ^2.1.1 - File system access
- cached_network_image: ^3.3.0 - Image caching
- geolocator: ^10.1.0 - GPS location
- geocoding: ^2.1.1 - Coordinate to address conversion
- permission_handler: ^11.0.1 - Runtime permissions
- google_fonts: ^6.1.0 - Modern typography
- intl: ^0.18.1 - Date formatting
- share_plus: ^7.2.1 - Share functionality
- And other supporting libraries

## [0.9.0] - 2025-02-23

### Added (Phase 1 - Beta)
- Core species identification functionality
- Image picker integration
- Basic database structure planning
- API integration skeleton
- Theme and UI foundation
- Wildlife species dataset
- Animal model with scientific information
- Identification result tracking

### Known Issues
- Database implementation not fully integrated
- TODO items for SQLite implementation
- Several deprecation warnings in Flutter APIs

## [0.1.0] - 2024-10-06

### Initial Commit
- Project scaffold created
- Basic Flutter project setup
- Initial git repository initialization

---

## Development Phases

### Phase 1 (Current - Completed)
- ✅ Core species identification with ML
- ✅ Offline database persistence
- ✅ Community verification system
- ✅ Expert review workflow
- ✅ Rich scientific metadata capture
- ✅ Geolocation and address tracking
- ✅ Complete test coverage
- ✅ All deprecation warnings fixed

### Phase 2 (Planned)
- [ ] Full monolith refactoring to feature modules
- [ ] Advanced ML model training
- [ ] Multi-language support (Hindi, Tamil, Bengali)
- [ ] Offline ML inference capabilities
- [ ] Advanced analytics dashboard
- [ ] Photo filtering and enhancement tools

### Phase 3 (Planned)
- [ ] AR visualization of species
- [ ] Real-time species tracking
- [ ] Biodiversity hotspot mapping
- [ ] Research collaboration tools
- [ ] Public API for data sharing

## Version History

- **1.0.0** - Stable release (Current)
- **0.9.0** - Beta with phase 1 features
- **0.1.0** - Initial scaffold

## Upgrading

### From 0.9.0 to 1.0.0
- No breaking changes
- Database schema remains compatible
- All old data will be automatically migrated
- Just run `flutter pub get` and rebuild

## Support

For issues or feature requests, please create an issue on GitHub or contact the ZSI development team.
