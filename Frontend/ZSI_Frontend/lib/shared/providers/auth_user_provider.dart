// lib/shared/providers/auth_user_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';

/// Provides current logged-in user email
final currentUserProvider = Provider((ref) {
  return AuthService.currentUser;
});

/// Provides current user's phone number
final currentUserPhoneProvider = Provider((ref) {
  return AuthService.currentUserPhone;
});

/// Provides whether user is logged in
final isLoggedInProvider = Provider((ref) {
  return AuthService.isLoggedIn;
});
