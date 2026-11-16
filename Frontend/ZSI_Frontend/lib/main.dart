// lib/main.dart - Phase 1: Riverpod Integration
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/feedback_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/identification_service.dart';
import 'app.dart';

void main() async {
  await bootstrap();
  runApp(const ProviderScope(child: FishIDIndiaApp()));
}

/// Everything the app needs before the first frame. Shared with the native
/// end-to-end test in integration_test/.
/// [forceSemantics] keeps the accessibility tree on (demo builds, used by the
/// browser tests); widget tests manage semantics themselves and pass false.
Future<void> bootstrap({
  bool forceSemantics = IdentificationService.demoMode,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Anek Latin ships in assets/google_fonts, so text never waits on a
  // download (the app is used at sea with no signal).
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

  // Configure image cache limits to prevent memory bloat
  imageCache.maximumSize = 100;
  imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  // Initialize feedback service
  await FeedbackService.initialize();

  // Initialize auth service (load persisted credentials)
  await AuthService.initialize();

  // Demo builds are used for presentations and browser end-to-end tests;
  // keep the accessibility tree on so tests can find controls by label.
  if (forceSemantics) {
    SemanticsBinding.instance.ensureSemantics();
  }
}
