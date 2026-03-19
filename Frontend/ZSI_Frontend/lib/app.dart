// lib/app.dart - ZSI Wildlife App Root Widget
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/index.dart';

class ZSIWildlifeApp extends StatelessWidget {
  const ZSIWildlifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZSI Wildlife Identifier',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
