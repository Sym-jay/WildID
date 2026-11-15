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
  if (IdentificationService.demoMode) {
    SemanticsBinding.instance.ensureSemantics();
  }

  runApp(
    const ProviderScope(
      child: FishIDIndiaApp(),
    ),
  );
}
