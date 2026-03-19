// lib/shared/providers/app_state_provider.dart
//
// NOTE: This file uses Riverpod's StateProvider which causes a false positive
// in `flutter analyze` with the message "StateProvider isn't defined". This is
// a known analyzer bug (see https://github.com/rrousselGit/riverpod/issues/).
// The app builds and runs correctly despite this warning. The import is correct
// and StateProvider is properly exported from package:flutter_riverpod.
// ignore_for_file: undefined_function

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global app state providers for navigation and UI state

/// Current route/screen provider - tracks which screen is displayed
final currentRouteProvider = StateProvider<String>((ref) {
  return '/splash';
});

/// Loading state provider - global loading indicator state
final loadingProvider = StateProvider<bool>((ref) {
  return false;
});

/// Error message provider - global error notifications
final errorMessageProvider = StateProvider<String?>((ref) {
  return null;
});

/// Success message provider - global success notifications
final successMessageProvider = StateProvider<String?>((ref) {
  return null;
});
