import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

// App-level providers

final appThemeProvider = Provider((ref) {
  return AppTheme.theme;
});
