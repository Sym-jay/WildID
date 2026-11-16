import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/index.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'sms_service.dart';

/// Single source of truth for the user's sightings.
///
/// Records live in memory for fast, synchronous reads by the UI and are
/// persisted to the on-device SQLite database (not on web), so history
/// survives restarts. Every change goes through this class so the list, the
/// database and listeners stay in step.
class ArchiveService {
  ArchiveService._();

  static final List<UploadRecord> _records = [];
  static bool _loaded = false;

  /// Bumps on every change; screens listen to rebuild.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static bool get _persist => !kIsWeb;

  /// Load saved sightings. Safe to call more than once.
  static Future<void> initialize() async {
    if (_loaded) return;
    _loaded = true;
    if (!_persist) return;
    try {
      final saved = await DatabaseService.getAllSightings();
      _records
        ..clear()
        ..addAll(saved)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      changes.value++;
    } catch (e) {
      debugPrint('Could not load saved sightings: $e');
    }
  }

  /// Copy the picked photo into app storage so it outlives the picker cache.
  static Future<String> _keepImage(XFile image, String recordId) async {
    if (kIsWeb) return image.path;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, 'sightings'));
      if (!await folder.exists()) await folder.create(recursive: true);
      final ext = p.extension(image.path).isEmpty ? '.jpg' : p.extension(image.path);
      final target = p.join(folder.path, '$recordId$ext');
      await image.saveTo(target);
      return target;
    } catch (e) {
      debugPrint('Could not copy photo, keeping original path: $e');
      return image.path;
    }
  }

  static void _notify() => changes.value++;

  static Future<void> _save(UploadRecord record) async {
    if (!_persist) return;
    try {
      await DatabaseService.saveSighting(record);
    } catch (e) {
      debugPrint('Could not save sighting ${record.id}: $e');
    }
  }

  /// Create a sighting for a photo that was just identified.
  static Future<UploadRecord> archiveUpload({
    required XFile image,
    required String? identifiedSpecies,
    required double? confidence,
    LocationData? location,
    DateTime? observationDateTime,
  }) async {
    final recordId = DateTime.now().microsecondsSinceEpoch.toString();
    final imagePath = await _keepImage(image, recordId);
    final record = UploadRecord(
      id: recordId,
      imagePath: imagePath,
      timestamp: DateTime.now(),
      identifiedSpecies: identifiedSpecies,
      confidence: confidence,
      userEmail: AuthService.currentUser,
      userPhone: AuthService.currentUserPhone,
      needsVerification:
          identifiedSpecies == null || (confidence != null && confidence < 0.6),
      location: location,
      status: 'pending',
      observationDateTime: observationDateTime ?? DateTime.now(),
    );
    _records.insert(0, record);
    _notify();
    await _save(record);
    return record;
  }

  static UploadRecord? getById(String id) {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Replace a record (e.g. after adding details or verifying it).
  static Future<void> updateRecord(UploadRecord record) async {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index == -1) return;
    _records[index] = record;
    _notify();
    await _save(record);
  }

  static Future<void> deleteRecord(String id) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final removed = _records.removeAt(index);
    _notify();
    if (_persist) {
      try {
        await DatabaseService.deleteSighting(id);
        final file = File(removed.imagePath);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('Could not delete sighting $id: $e');
      }
    }
  }

  static List<UploadRecord> getUploadHistory() => List.unmodifiable(_records);

  static List<UploadRecord> getNeedsVerification() => _records
      .where((r) => r.needsVerification && r.status == 'pending')
      .toList();

  static List<UploadRecord> getVerifiedRecords() =>
      _records.where((r) => r.status == 'verified').toList();

  static Future<bool> verifyUpload(
    String recordId,
    String verifiedSpecies,
    String adminNotes, {
    int? expertConfidence,
  }) async {
    final record = getById(recordId);
    if (record == null) return false;
    final updated = record.copyWith(
      status: 'verified',
      verifiedSpecies: verifiedSpecies,
      adminNotes: adminNotes,
      verifiedAt: DateTime.now(),
      expertConfidenceScore: expertConfidence,
      needsVerification: false,
    );
    await updateRecord(updated);
    if (updated.userPhone != null) {
      await SMSService.sendVerificationAlert(updated.userPhone!, verifiedSpecies);
    }
    return true;
  }

  static Future<void> rejectUpload(String recordId, String notes) async {
    final record = getById(recordId);
    if (record == null) return;
    await updateRecord(record.copyWith(status: 'rejected', adminNotes: notes));
  }

  static Map<String, dynamic> getStatistics() {
    final total = _records.length;
    final verified = _records.where((r) => r.status == 'verified').length;
    final speciesCount = <String, int>{};
    for (final record in _records) {
      final species = record.verifiedSpecies ?? record.identifiedSpecies;
      if (species != null) {
        speciesCount[species] = (speciesCount[species] ?? 0) + 1;
      }
    }
    return {
      'total': total,
      'pending': _records.where((r) => r.status == 'pending').length,
      'verified': verified,
      'needsVerification': _records.where((r) => r.needsVerification).length,
      'verifiedPercentage': total == 0 ? 0.0 : verified * 100 / total,
      'speciesDistribution': speciesCount,
    };
  }

  /// RFC 4180 field quoting.
  @visibleForTesting
  static String csvField(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(RegExp(r'[",\r\n]'))) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static Future<String> exportToCSV() async {
    final buffer = StringBuffer()
      ..writeln(
        'ID,Timestamp,Species,Confidence,Status,Latitude,Longitude,Habitat,Notes,UserEmail,VerifiedAt',
      );
    for (final r in _records) {
      buffer.writeln([
        r.id,
        r.timestamp.toIso8601String(),
        r.verifiedSpecies ?? r.identifiedSpecies ?? 'Unknown',
        r.confidence?.toStringAsFixed(2) ?? '',
        r.status,
        r.location?.latitude ?? '',
        r.location?.longitude ?? '',
        r.habitatType ?? '',
        r.behaviors ?? '',
        r.userEmail ?? 'Guest',
        r.verifiedAt?.toIso8601String() ?? '',
      ].map(csvField).join(','));
    }
    return buffer.toString();
  }

  /// Test hook: forget the in-memory list and read everything back from the
  /// database, as a cold app start would.
  @visibleForTesting
  static Future<void> reloadFromStorageForTest() async {
    _records.clear();
    _loaded = false;
    await initialize();
  }

  /// Test hook: clear all in-memory state.
  @visibleForTesting
  static void resetForTest() {
    _records.clear();
    _loaded = true;
  }
}
