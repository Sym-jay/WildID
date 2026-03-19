import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/index.dart';

/// Current user profile provider
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return null;
});

/// User's life list provider - unique species observed by user
final userLifeListProvider = Provider<List<String>>((ref) {
  return [];
});

/// All user badges
final userBadgesProvider = Provider<List<Badge>>((ref) {
  return [
    Badge(
      id: 'first_observation',
      name: 'First Step',
      description: 'Submit your first observation',
      icon: '🌱',
      condition: 'totalSubmissions >= 1',
    ),
    Badge(
      id: 'verified_100',
      name: 'Verified Century',
      description: 'Get 100 observations verified',
      icon: '✅',
      condition: 'verifiedSubmissions >= 100',
    ),
    Badge(
      id: 'accuracy_90',
      name: 'Expert Eye',
      description: 'Achieve 90% accuracy rate',
      icon: '👁️',
      condition: 'accuracyScore >= 90',
    ),
    Badge(
      id: 'community_helper',
      name: 'Community Helper',
      description: 'Contribute 50+ community identifications',
      icon: '🤝',
      condition: 'communityVotes >= 50',
    ),
    Badge(
      id: 'data_scientist',
      name: 'Data Scientist',
      description: 'Submit 500 observations with metadata',
      icon: '📊',
      condition: 'submissionsWithMetadata >= 500',
    ),
  ];
});

/// Check if user has a specific badge
final hasBadgeProvider = Provider.family<bool, String>((ref, badgeId) {
  final profile = ref.watch(currentUserProfileProvider);
  return profile?.badges.contains(badgeId) ?? false;
});

/// Get user's accuracy percentage
final userAccuracyProvider = Provider<double>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  return profile?.accuracyScore ?? 0.0;
});

/// Get user's verification rate
final userVerificationRateProvider = Provider<double>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  return profile?.verificationRate ?? 0.0;
});
