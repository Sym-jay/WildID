import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../shared/models/index.dart';
import 'auth_service.dart';
import 'sms_service.dart';

class ArchiveService {
  ArchiveService._();

  static final List<UploadRecord> _uploadHistory = [];

  static const String apiBaseUrl = 'https://your-goi-server.gov.in/api';

  static Future<String> archiveUpload({
    required File imageFile,
    required String? identifiedSpecies,
    required double? confidence,
    LocationData? location,
    String? habitatType,
    double? waterTemperature,
    double? waterDepth,
    String? waterTurbidity,
    String? behaviors,
    DateTime? observationDateTime,
  }) async {
    try {
      final recordId = DateTime.now().millisecondsSinceEpoch.toString();

      final record = UploadRecord(
        id: recordId,
        imagePath: imageFile.path,
        timestamp: DateTime.now(),
        identifiedSpecies: identifiedSpecies,
        confidence: confidence,
        userEmail: AuthService.currentUser,
        userPhone: AuthService.currentUserPhone,
        needsVerification: (confidence != null && confidence < 0.6) || identifiedSpecies == null,
        location: location,
        status: 'pending',
        habitatType: habitatType,
        waterTemperature: waterTemperature,
        waterDepth: waterDepth,
        waterTurbidity: waterTurbidity,
        behaviors: behaviors,
        observationDateTime: observationDateTime ?? DateTime.now(),
      );

      _uploadHistory.insert(0, record);

      debugPrint('✓ Upload archived with metadata: ${record.toJson()}');
      return recordId;
    } catch (e) {
      debugPrint('Error archiving upload: $e');
      rethrow;
    }
  }

  static List<UploadRecord> getUploadHistory() => List.from(_uploadHistory);

  static List<UploadRecord> getNeedsVerification() =>
      _uploadHistory.where((r) => r.needsVerification && r.status == 'pending').toList();

  static List<UploadRecord> getVerifiedRecords() =>
      _uploadHistory.where((r) => r.status == 'verified').toList();

  static Future<bool> verifyUpload(String recordId, String verifiedSpecies, String adminNotes) async {
    try {
      final index = _uploadHistory.indexWhere((r) => r.id == recordId);
      if (index == -1) return false;

      final updatedRecord = _uploadHistory[index].copyWith(
        status: 'verified',
        verifiedSpecies: verifiedSpecies,
        adminNotes: adminNotes,
        verifiedAt: DateTime.now(),
      );

      _uploadHistory[index] = updatedRecord;

      if (updatedRecord.userPhone != null) {
        await SMSService.sendVerificationAlert(
          updatedRecord.userPhone!,
          verifiedSpecies,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error verifying upload: $e');
      return false;
    }
  }

  static Map<String, dynamic> getStatistics() {
    final total = _uploadHistory.length;
    final pending = _uploadHistory.where((r) => r.status == 'pending').length;
    final verified = _uploadHistory.where((r) => r.status == 'verified').length;
    final needsVerification = _uploadHistory.where((r) => r.needsVerification).length;

    Map<String, int> speciesCount = {};
    for (var record in _uploadHistory) {
      final species = record.verifiedSpecies ?? record.identifiedSpecies;
      if (species != null) {
        speciesCount[species] = (speciesCount[species] ?? 0) + 1;
      }
    }

    return {
      'total': total,
      'pending': pending,
      'verified': verified,
      'needsVerification': needsVerification,
      'speciesDistribution': speciesCount,
    };
  }

  static Future<String> exportToCSV() async {
    final buffer = StringBuffer();
    buffer.writeln('ID,Timestamp,Species,Confidence,Status,Latitude,Longitude,UserEmail,VerifiedAt');

    for (var record in _uploadHistory) {
      buffer.writeln([
        record.id,
        record.timestamp.toIso8601String(),
        record.verifiedSpecies ?? record.identifiedSpecies ?? 'Unknown',
        record.confidence?.toStringAsFixed(2) ?? 'N/A',
        record.status,
        record.location?.latitude ?? 'N/A',
        record.location?.longitude ?? 'N/A',
        record.userEmail ?? 'Guest',
        record.verifiedAt?.toIso8601String() ?? 'N/A',
      ].join(','));
    }

    return buffer.toString();
  }
}
