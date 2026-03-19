import 'package:flutter_test/flutter_test.dart';
import 'package:fish_id_india/shared/models/index.dart';

void main() {
  group('UploadRecord with Metadata Tests', () {
    test('UploadRecord with scientific metadata', () {
      final record = UploadRecord(
        id: 'test-scientific-001',
        imagePath: '/test/scientific_image.jpg',
        timestamp: DateTime(2024, 3, 14),
        identifiedSpecies: 'Bengal Tiger',
        confidence: 0.92,
        habitatType: 'Tropical Forest',
        waterTemperature: 28.5,
        waterDepth: 2.5,
        waterTurbidity: 'Clear',
        behaviors: 'Drinking water',
        observationDateTime: DateTime(2024, 3, 14, 10, 30),
      );

      expect(record.habitatType, equals('Tropical Forest'));
      expect(record.waterTemperature, equals(28.5));
      expect(record.behaviors, equals('Drinking water'));
      expect(record.identifiedSpecies, equals('Bengal Tiger'));
    });

    test('UploadRecord with comments', () {
      final comment = Comment(
        id: 'comment-1',
        recordId: 'record-1',
        userId: 'user-1',
        userName: 'John Doe',
        content: 'Great observation!',
        createdAt: DateTime(2024, 3, 14),
        likes: ['user2', 'user3'],
      );

      expect(comment.content, equals('Great observation!'));
      expect(comment.likeCount, equals(2));
      expect(comment.recordId, equals('record-1'));
    });

    test('ObservationFilters matching', () {
      final filter = ObservationFilters(
        statusFilters: ['verified'],
        minConfidence: 0.8,
      );

      final record1 = UploadRecord(
        id: 'test-1',
        imagePath: '/test/image1.jpg',
        timestamp: DateTime(2024, 3, 14),
        identifiedSpecies: 'Tiger',
        confidence: 0.95,
        status: 'verified',
      );

      final record2 = UploadRecord(
        id: 'test-2',
        imagePath: '/test/image2.jpg',
        timestamp: DateTime(2024, 3, 14),
        identifiedSpecies: 'Leopard',
        confidence: 0.7,
        status: 'pending',
      );

      expect(filter.matches(record1), isTrue);
      expect(filter.matches(record2), isFalse);
    });

    test('ObservationFilters with date range', () {
      final filter = ObservationFilters(
        startDate: DateTime(2024, 3, 1),
        endDate: DateTime(2024, 3, 15),
      );

      final recordInRange = UploadRecord(
        id: 'test-1',
        imagePath: '/test/image1.jpg',
        timestamp: DateTime(2024, 3, 10),
        identifiedSpecies: 'Tiger',
        confidence: 0.95,
      );

      final recordOutOfRange = UploadRecord(
        id: 'test-2',
        imagePath: '/test/image2.jpg',
        timestamp: DateTime(2024, 4, 10),
        identifiedSpecies: 'Leopard',
        confidence: 0.85,
      );

      expect(filter.matches(recordInRange), isTrue);
      expect(filter.matches(recordOutOfRange), isFalse);
    });

    test('UserProfile with badges', () {
      final profile = UserProfile(
        userId: 'user-123',
        email: 'user@example.com',
        displayName: 'Wildlife Observer',
        joinDate: DateTime(2024, 1, 1),
        totalSubmissions: 25,
        verifiedSubmissions: 20,
        accuracyScore: 92.5,
        badges: ['first_observation', 'verified_10'],
      );

      expect(profile.userId, equals('user-123'));
      expect(profile.totalSubmissions, equals(25));
      expect(profile.badges.length, equals(2));
      expect(profile.accuracyScore, equals(92.5));
    });

    test('Badge achievement tracking', () {
      final badge = Badge(
        id: 'first_observation',
        name: 'First Step',
        description: 'Submit your first observation',
        icon: '🌱',
        condition: 'totalSubmissions >= 1',
      );

      expect(badge.name, equals('First Step'));
      expect(badge.icon, equals('🌱'));
      expect(badge.condition, contains('totalSubmissions'));
    });

    test('CommunityVote tracking', () {
      final vote = CommunityVote(
        userId: 'user-001',
        suggestedSpecies: 'Tiger',
        voteCount: 5,
        createdAt: DateTime(2024, 3, 14),
        voters: ['user1', 'user2', 'user3', 'user4', 'user5'],
      );

      expect(vote.suggestedSpecies, equals('Tiger'));
      expect(vote.voteCount, equals(5));
      expect(vote.voters.length, equals(5));
    });

    test('UploadRecord copyWith method', () {
      final original = UploadRecord(
        id: 'test-001',
        imagePath: '/test/image.jpg',
        timestamp: DateTime(2024, 3, 14),
        identifiedSpecies: 'Tiger',
        confidence: 0.85,
        status: 'pending',
      );

      final updated = original.copyWith(
        status: 'verified',
        verifiedSpecies: 'Bengal Tiger',
      );

      expect(updated.id, equals('test-001'));
      expect(updated.status, equals('verified'));
      expect(updated.verifiedSpecies, equals('Bengal Tiger'));
      expect(updated.identifiedSpecies, equals('Tiger'));
    });
  });
}
