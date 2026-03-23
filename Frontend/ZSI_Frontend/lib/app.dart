// lib/app.dart - ZSI Wildlife App Root Widget
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/index.dart';

class FishIDIndiaApp extends StatelessWidget {
  const FishIDIndiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FISH ID India',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
