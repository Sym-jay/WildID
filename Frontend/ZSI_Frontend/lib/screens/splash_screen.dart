import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/archive_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/species_lookup_service.dart';
import '../core/theme/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Loads species data and saved reports, then opens Home (signed in) or
/// Login. No artificial delay beyond a short brand moment.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.wait([
      SpeciesLookupService.loadSpecies().then<void>((_) {}, onError: (Object _) {}),
      ArchiveService.initialize(),
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) =>
            AuthService.isLoggedIn ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wild = WildColors.of(context);
    return Scaffold(
      backgroundColor: wild.shell,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset('assets/images/logo.jpg', width: 72, height: 72, semanticLabel: 'ZSI logo'),
              ),
              const SizedBox(height: 24),
              Text('WILDID', style: AppTheme.display(56, wild.onShell)),
              const SizedBox(height: 6),
              Text(
                'Protected marine species of India',
                style: GoogleFonts.anekLatin(fontSize: 18, color: wild.shellMuted),
              ),
              const Spacer(),
              Text(
                'ZOOLOGICAL SURVEY OF INDIA',
                style: GoogleFonts.anekLatin(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: wild.shellMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
