import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../shared/models/index.dart';
import 'dart:convert';
import '../config/error_handler.dart';

class DatabaseService {
  DatabaseService._();
  
  static Database? _database;
  static const String _dbName = 'zsi_wildlife.db';
  static const int _dbVersion = 1;

  // Table names
  static const String uploadRecordsTable = 'upload_records';
  static const String expertVerificationsTable = 'expert_verifications';
  static const String communityVotesTable = 'community_votes';

  static Future<Database> _getDatabase() async {
    try {
      _database ??= await _initDatabase();
      return _database!;
    } catch (e, stackTrace) {
      AppLogger.logError('Database initialization failed', e, stackTrace);
      throw AppDatabaseException(
        'Failed to initialize database',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);

      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stackTrace) {
      AppLogger.logError('Database file open failed', e, stackTrace);
      throw AppDatabaseException(
        'Failed to open database file',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $uploadRecordsTable (
        id TEXT PRIMARY KEY,
        imagePath TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        identifiedSpecies TEXT,
        confidence REAL,
        userEmail TEXT,
        userPhone TEXT,
        needsVerification INTEGER DEFAULT 0,
        location TEXT,
        status TEXT DEFAULT 'pending',
        adminNotes TEXT,
        verifiedSpecies TEXT,
        verifiedAt TEXT,
        habitatType TEXT,
        waterTemperature REAL,
        waterDepth REAL,
        waterTurbidity TEXT,
        behaviors TEXT,
        observationDateTime TEXT,
        communityVotes TEXT,
        expertConfidenceScore INTEGER,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE $expertVerificationsTable (
        verificationId TEXT PRIMARY KEY,
        recordId TEXT NOT NULL,
        expertId TEXT NOT NULL,
        verifiedSpecies TEXT NOT NULL,
        confidenceScore INTEGER NOT NULL,
        notes TEXT NOT NULL,
        alternativeSpecies TEXT NOT NULL,
        verifiedAt TEXT NOT NULL,
        status TEXT DEFAULT 'accepted',
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (recordId) REFERENCES $uploadRecordsTable(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $communityVotesTable (
        id TEXT PRIMARY KEY,
        recordId TEXT NOT NULL,
        userId TEXT NOT NULL,
        suggestedSpecies TEXT NOT NULL,
        voteCount INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        voters TEXT NOT NULL,
        FOREIGN KEY (recordId) REFERENCES $uploadRecordsTable(id)
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_status ON $uploadRecordsTable(status)');
    await db.execute('CREATE INDEX idx_needsVerification ON $uploadRecordsTable(needsVerification)');
    await db.execute('CREATE INDEX idx_recordId ON $expertVerificationsTable(recordId)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
  }

  // Initialize database (called on app startup)
  static Future<void> initialize() async {
    await _getDatabase();
  }

  // Store a sighting record locally
  static Future<void> saveSighting(UploadRecord record) async {
    final db = await _getDatabase();
    await db.insert(
      uploadRecordsTable,
      _uploadRecordToMap(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieve all sightings for export
  static Future<List<UploadRecord>> getAllSightings() async {
    final db = await _getDatabase();
    final maps = await db.query(uploadRecordsTable, orderBy: 'timestamp DESC');
    return maps.map((map) => _mapToUploadRecord(map)).toList();
  }

  // Get unverified sightings (admin queue)
  static Future<List<UploadRecord>> getUnverifiedSightings() async {
    final db = await _getDatabase();
    final maps = await db.query(
      uploadRecordsTable,
      where: "status = ? AND needsVerification = 1",
      whereArgs: ['pending'],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => _mapToUploadRecord(map)).toList();
  }

  // Get pending sightings
  static Future<List<UploadRecord>> getPendingSightings() async {
    final db = await _getDatabase();
    final maps = await db.query(
      uploadRecordsTable,
      where: "status = ?",
      whereArgs: ['pending'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => _mapToUploadRecord(map)).toList();
  }

  // Get verified sightings
  static Future<List<UploadRecord>> getVerifiedSightings() async {
    final db = await _getDatabase();
    final maps = await db.query(
      uploadRecordsTable,
      where: "status = ?",
      whereArgs: ['verified'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => _mapToUploadRecord(map)).toList();
  }

  // Update a sighting record
  static Future<void> updateSighting(UploadRecord record) async {
    final db = await _getDatabase();
    await db.update(
      uploadRecordsTable,
      _uploadRecordToMap(record),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // Delete a sighting
  static Future<void> deleteSighting(String recordId) async {
    final db = await _getDatabase();
    await db.delete(
      uploadRecordsTable,
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  // Save expert verification
  static Future<void> saveVerification(ExpertVerification verification) async {
    final db = await _getDatabase();
    await db.insert(
      expertVerificationsTable,
      _verificationToMap(verification),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get verifications for a record
  static Future<List<ExpertVerification>> getVerificationsForRecord(String recordId) async {
    final db = await _getDatabase();
    final maps = await db.query(
      expertVerificationsTable,
      where: 'recordId = ?',
      whereArgs: [recordId],
      orderBy: 'verifiedAt DESC',
    );
    return maps.map((map) => _mapToVerification(map)).toList();
  }

  // Get all verifications
  static Future<List<ExpertVerification>> getAllVerifications() async {
    final db = await _getDatabase();
    final maps = await db.query(
      expertVerificationsTable,
      orderBy: 'verifiedAt DESC',
    );
    return maps.map((map) => _mapToVerification(map)).toList();
  }

  // Save community votes
  static Future<void> saveCommunityVote(CommunityVote vote, String recordId) async {
    final db = await _getDatabase();
    await db.insert(
      communityVotesTable,
      {
        'id': '${recordId}_${vote.userId}',
        'recordId': recordId,
        'userId': vote.userId,
        'suggestedSpecies': vote.suggestedSpecies,
        'voteCount': vote.voteCount,
        'createdAt': vote.createdAt.toIso8601String(),
        'voters': jsonEncode(vote.voters),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get community votes for a record
  static Future<List<CommunityVote>> getCommunityVotesForRecord(String recordId) async {
    final db = await _getDatabase();
    final maps = await db.query(
      communityVotesTable,
      where: 'recordId = ?',
      whereArgs: [recordId],
      orderBy: 'voteCount DESC',
    );
    return maps.map((map) => _mapToCommunityVote(map)).toList();
  }

  // Clear old records (for cleanup)
  static Future<void> deleteOldRecords(Duration olderThan) async {
    final db = await _getDatabase();
    final cutoffDate = DateTime.now().subtract(olderThan);
    await db.delete(
      uploadRecordsTable,
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // Get database statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final db = await _getDatabase();
    // Single query combining all counts using SUM() and CASE WHEN
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'verified' THEN 1 ELSE 0 END) as verified,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending
      FROM $uploadRecordsTable
    ''');

    final row = result.first;
    return {
      'total': row['total'] as int? ?? 0,
      'verified': row['verified'] as int? ?? 0,
      'pending': row['pending'] as int? ?? 0,
    };
  }

  // Helper methods for conversions
  static Map<String, dynamic> _uploadRecordToMap(UploadRecord record) {
    return {
      'id': record.id,
      'imagePath': record.imagePath,
      'timestamp': record.timestamp.toIso8601String(),
      'identifiedSpecies': record.identifiedSpecies,
      'confidence': record.confidence,
      'userEmail': record.userEmail,
      'userPhone': record.userPhone,
      'needsVerification': record.needsVerification ? 1 : 0,
      'location': record.location != null ? jsonEncode(record.location!.toJson()) : null,
      'status': record.status,
      'adminNotes': record.adminNotes,
      'verifiedSpecies': record.verifiedSpecies,
      'verifiedAt': record.verifiedAt?.toIso8601String(),
      'habitatType': record.habitatType,
      'waterTemperature': record.waterTemperature,
      'waterDepth': record.waterDepth,
      'waterTurbidity': record.waterTurbidity,
      'behaviors': record.behaviors,
      'observationDateTime': record.observationDateTime?.toIso8601String(),
      'communityVotes': record.communityVotes != null
          ? jsonEncode(record.communityVotes!.map((v) => v.toJson()).toList())
          : null,
      'expertConfidenceScore': record.expertConfidenceScore,
    };
  }

  static UploadRecord _mapToUploadRecord(Map<String, dynamic> map) {
    return UploadRecord(
      id: map['id'] as String,
      imagePath: map['imagePath'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      identifiedSpecies: map['identifiedSpecies'] as String?,
      confidence: map['confidence'] as double?,
      userEmail: map['userEmail'] as String?,
      userPhone: map['userPhone'] as String?,
      needsVerification: (map['needsVerification'] as int?) == 1,
      location: map['location'] != null
          ? LocationData.fromJson(jsonDecode(map['location'] as String))
          : null,
      status: map['status'] as String? ?? 'pending',
      adminNotes: map['adminNotes'] as String?,
      verifiedSpecies: map['verifiedSpecies'] as String?,
      verifiedAt: map['verifiedAt'] != null
          ? DateTime.parse(map['verifiedAt'] as String)
          : null,
      habitatType: map['habitatType'] as String?,
      waterTemperature: map['waterTemperature'] as double?,
      waterDepth: map['waterDepth'] as double?,
      waterTurbidity: map['waterTurbidity'] as String?,
      behaviors: map['behaviors'] as String?,
      observationDateTime: map['observationDateTime'] != null
          ? DateTime.parse(map['observationDateTime'] as String)
          : null,
      communityVotes: map['communityVotes'] != null
          ? (jsonDecode(map['communityVotes'] as String) as List)
              .map((v) => CommunityVote.fromJson(v as Map<String, dynamic>))
              .toList()
          : null,
      expertConfidenceScore: map['expertConfidenceScore'] as int?,
    );
  }

  static Map<String, dynamic> _verificationToMap(ExpertVerification verification) {
    return {
      'verificationId': verification.verificationId,
      'recordId': verification.recordId,
      'expertId': verification.expertId,
      'verifiedSpecies': verification.verifiedSpecies,
      'confidenceScore': verification.confidenceScore,
      'notes': verification.notes,
      'alternativeSpecies': jsonEncode(verification.alternativeSpecies),
      'verifiedAt': verification.verifiedAt.toIso8601String(),
      'status': verification.status,
    };
  }

  static ExpertVerification _mapToVerification(Map<String, dynamic> map) {
    return ExpertVerification(
      verificationId: map['verificationId'] as String,
      recordId: map['recordId'] as String,
      expertId: map['expertId'] as String,
      verifiedSpecies: map['verifiedSpecies'] as String,
      confidenceScore: map['confidenceScore'] as int,
      notes: map['notes'] as String,
      alternativeSpecies: List<String>.from(jsonDecode(map['alternativeSpecies'] as String)),
      verifiedAt: DateTime.parse(map['verifiedAt'] as String),
      status: map['status'] as String? ?? 'accepted',
    );
  }

  static CommunityVote _mapToCommunityVote(Map<String, dynamic> map) {
    return CommunityVote(
      userId: map['userId'] as String,
      suggestedSpecies: map['suggestedSpecies'] as String,
      voteCount: map['voteCount'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      voters: List<String>.from(jsonDecode(map['voters'] as String)),
    );
  }
}
