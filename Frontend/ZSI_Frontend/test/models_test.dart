import 'package:flutter_test/flutter_test.dart';
import 'package:fish_id_india/shared/models/index.dart';

void main() {
  group('Animal Model Tests', () {
    test('Animal creation with valid data', () {
      final animal = Animal(
        name: 'Tiger',
        scientificName: 'Panthera tigris',
        description: 'Large striped cat',
        conservationStatus: 'Endangered',
        iucnUrl: 'https://iucn.org/tiger',
        imageUrl: 'https://example.com/tiger.jpg',
      );

      expect(animal.name, equals('Tiger'));
      expect(animal.scientificName, equals('Panthera tigris'));
      expect(animal.isEndangered, isTrue);
    });

    test('Animal with multiple images', () {
      final animal = Animal(
        name: 'Deer',
        scientificName: 'Cervus elaphus',
        description: 'Forest deer',
        conservationStatus: 'Vulnerable',
        iucnUrl: 'https://iucn.org/deer',
        imageUrl: 'https://example.com/deer1.jpg',
        additionalImageUrls: [
          'https://example.com/deer2.jpg',
          'https://example.com/deer3.jpg',
        ],
      );

      expect(animal.getAllImageUrls().length, equals(3));
      expect(animal.isEndangered, isFalse);
    });
  });

  group('IdentificationResult Tests', () {
    test('IdentificationResult creation', () {
      final result = IdentificationResult(label: 'Tiger', confidence: 0.95);

      expect(result.label, equals('Tiger'));
      expect(result.confidence, equals(0.95));
    });

    test('IdentificationResult with low confidence', () {
      final result = IdentificationResult(label: 'Unknown', confidence: 0.2);

      expect(result.confidence, lessThan(0.5));
    });
  });

  group('LocationData Tests', () {
    test('LocationData with coordinates', () {
      final location = LocationData(
        latitude: 28.7041,
        longitude: 77.1025,
        accuracy: 10.5,
        address: 'Delhi, India',
      );

      expect(location.latitude, equals(28.7041));
      expect(location.longitude, equals(77.1025));
      expect(location.address, equals('Delhi, India'));
    });

    test('LocationData JSON serialization', () {
      final location = LocationData(
        latitude: 28.7041,
        longitude: 77.1025,
        accuracy: 10.5,
        address: 'Delhi, India',
      );

      final json = location.toJson();
      expect(json['latitude'], equals(28.7041));
      expect(json['longitude'], equals(77.1025));
    });

    test('LocationData JSON deserialization', () {
      final json = {
        'latitude': 28.7041,
        'longitude': 77.1025,
        'accuracy': 10.5,
        'address': 'Delhi, India',
      };

      final location = LocationData.fromJson(json);
      expect(location.latitude, equals(28.7041));
      expect(location.address, equals('Delhi, India'));
    });
  });

  group('UploadRecord Tests', () {
    test('UploadRecord creation with required fields', () {
      final record = UploadRecord(
        id: 'test-123',
        imagePath: '/path/to/image.jpg',
        timestamp: DateTime(2024, 1, 1),
      );

      expect(record.id, equals('test-123'));
      expect(record.status, equals('pending'));
      expect(record.needsVerification, isFalse);
    });

    test('UploadRecord with scientific metadata', () {
      final record = UploadRecord(
        id: 'test-456',
        imagePath: '/path/to/image.jpg',
        timestamp: DateTime(2024, 1, 1),
        habitatType: 'river',
        waterTemperature: 22.5,
        waterDepth: 3.2,
        waterTurbidity: 'clear',
        behaviors: 'swimming',
      );

      expect(record.habitatType, equals('river'));
      expect(record.waterTemperature, equals(22.5));
      expect(record.waterDepth, equals(3.2));
    });

    test('UploadRecord JSON serialization', () {
      final record = UploadRecord(
        id: 'test-789',
        imagePath: '/path/to/image.jpg',
        timestamp: DateTime(2024, 1, 1),
        identifiedSpecies: 'Tiger',
        confidence: 0.92,
      );

      final json = record.toJson();
      expect(json['id'], equals('test-789'));
      expect(json['identifiedSpecies'], equals('Tiger'));
      expect(json['confidence'], equals(0.92));
    });

    test('UploadRecord copyWith method', () {
      final original = UploadRecord(
        id: 'test-100',
        imagePath: '/path/to/image.jpg',
        timestamp: DateTime(2024, 1, 1),
        status: 'pending',
      );

      final updated = original.copyWith(status: 'verified');

      expect(original.status, equals('pending'));
      expect(updated.status, equals('verified'));
      expect(updated.id, equals(original.id));
    });
  });

  group('CommunityVote Tests', () {
    test('CommunityVote creation', () {
      final vote = CommunityVote(
        userId: 'user-123',
        suggestedSpecies: 'Tiger',
        voteCount: 5,
        createdAt: DateTime(2024, 1, 1),
        voters: ['user-1', 'user-2', 'user-3'],
      );

      expect(vote.userId, equals('user-123'));
      expect(vote.suggestedSpecies, equals('Tiger'));
      expect(vote.voters.length, equals(3));
    });

    test('CommunityVote JSON serialization', () {
      final vote = CommunityVote(
        userId: 'user-123',
        suggestedSpecies: 'Tiger',
        voteCount: 5,
        createdAt: DateTime(2024, 1, 1),
        voters: ['user-1', 'user-2'],
      );

      final json = vote.toJson();
      expect(json['suggestedSpecies'], equals('Tiger'));
      expect(json['voteCount'], equals(5));
    });

    test('CommunityVote JSON deserialization', () {
      final json = {
        'userId': 'user-456',
        'suggestedSpecies': 'Deer',
        'voteCount': 3,
        'createdAt': '2024-01-01T12:00:00.000Z',
        'voters': ['user-a', 'user-b'],
      };

      final vote = CommunityVote.fromJson(json);
      expect(vote.userId, equals('user-456'));
      expect(vote.suggestedSpecies, equals('Deer'));
    });
  });

  group('ExpertVerification Tests', () {
    test('ExpertVerification creation', () {
      final verification = ExpertVerification(
        verificationId: 'ver-123',
        recordId: 'rec-123',
        expertId: 'exp-123',
        verifiedSpecies: 'Tiger',
        confidenceScore: 95,
        notes: 'Clear striped patterns',
        alternativeSpecies: ['Leopard'],
        verifiedAt: DateTime(2024, 1, 1),
      );

      expect(verification.verifiedSpecies, equals('Tiger'));
      expect(verification.confidenceScore, equals(95));
      expect(verification.status, equals('accepted'));
    });

    test('ExpertVerification JSON serialization', () {
      final verification = ExpertVerification(
        verificationId: 'ver-456',
        recordId: 'rec-456',
        expertId: 'exp-456',
        verifiedSpecies: 'Lion',
        confidenceScore: 98,
        notes: 'Distinctive mane pattern',
        alternativeSpecies: ['Tiger'],
        verifiedAt: DateTime(2024, 1, 1),
        status: 'rejected',
      );

      final json = verification.toJson();
      expect(json['verifiedSpecies'], equals('Lion'));
      expect(json['status'], equals('rejected'));
    });

    test('ExpertVerification JSON deserialization', () {
      final json = {
        'verificationId': 'ver-789',
        'recordId': 'rec-789',
        'expertId': 'exp-789',
        'verifiedSpecies': 'Elephant',
        'confidenceScore': 99,
        'notes': 'Large tusks visible',
        'alternativeSpecies': ['Tiger', 'Rhino'],
        'verifiedAt': '2024-01-01T12:00:00.000Z',
      };

      final verification = ExpertVerification.fromJson(json);
      expect(verification.verifiedSpecies, equals('Elephant'));
    });
  });
}
