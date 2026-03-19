class Animal {
  final String name;
  final String scientificName;
  final String description;
  final String conservationStatus;
  final String iucnUrl;
  final String imageUrl;
  final List<String> additionalImageUrls;

  Animal({
    required this.name,
    required this.scientificName,
    required this.description,
    required this.conservationStatus,
    required this.iucnUrl,
    required this.imageUrl,
    this.additionalImageUrls = const [],
  });

  bool get isEndangered =>
      conservationStatus == 'Endangered' ||
      conservationStatus == 'Critically Endangered';
  
  List<String> getAllImageUrls() => [imageUrl, ...additionalImageUrls];
}

class IdentificationResult {
  final String label;
  final double confidence;

  IdentificationResult({required this.label, required this.confidence});
}

class CommunityVote {
  final String userId;
  final String suggestedSpecies;
  final int voteCount;
  final DateTime createdAt;
  final List<String> voters;

  CommunityVote({
    required this.userId,
    required this.suggestedSpecies,
    required this.voteCount,
    required this.createdAt,
    required this.voters,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'suggestedSpecies': suggestedSpecies,
    'voteCount': voteCount,
    'createdAt': createdAt.toIso8601String(),
    'voters': voters,
  };

  factory CommunityVote.fromJson(Map<String, dynamic> json) => CommunityVote(
    userId: json['userId'] as String,
    suggestedSpecies: json['suggestedSpecies'] as String,
    voteCount: json['voteCount'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    voters: List<String>.from(json['voters'] as List),
  );
}

class ExpertVerification {
  final String verificationId;
  final String recordId;
  final String expertId;
  final String verifiedSpecies;
  final int confidenceScore;
  final String notes;
  final List<String> alternativeSpecies;
  final DateTime verifiedAt;
  final String status;

  ExpertVerification({
    required this.verificationId,
    required this.recordId,
    required this.expertId,
    required this.verifiedSpecies,
    required this.confidenceScore,
    required this.notes,
    required this.alternativeSpecies,
    required this.verifiedAt,
    this.status = 'accepted',
  });

  Map<String, dynamic> toJson() => {
    'verificationId': verificationId,
    'recordId': recordId,
    'expertId': expertId,
    'verifiedSpecies': verifiedSpecies,
    'confidenceScore': confidenceScore,
    'notes': notes,
    'alternativeSpecies': alternativeSpecies,
    'verifiedAt': verifiedAt.toIso8601String(),
    'status': status,
  };

  factory ExpertVerification.fromJson(Map<String, dynamic> json) => ExpertVerification(
    verificationId: json['verificationId'] as String,
    recordId: json['recordId'] as String,
    expertId: json['expertId'] as String,
    verifiedSpecies: json['verifiedSpecies'] as String,
    confidenceScore: json['confidenceScore'] as int,
    notes: json['notes'] as String,
    alternativeSpecies: List<String>.from(json['alternativeSpecies'] as List),
    verifiedAt: DateTime.parse(json['verifiedAt'] as String),
    status: json['status'] as String? ?? 'accepted',
  );
}

class LocationData {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? address;

  LocationData({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.address,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'address': address,
  };

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
    latitude: json['latitude'],
    longitude: json['longitude'],
    accuracy: json['accuracy'],
    address: json['address'],
  );
}

class UserProfile {
  final String userId;
  final String email;
  final String? displayName;
  final DateTime joinDate;
  final int totalSubmissions;
  final int verifiedSubmissions;
  final double accuracyScore;
  final List<String> badges;

  UserProfile({
    required this.userId,
    required this.email,
    this.displayName,
    required this.joinDate,
    this.totalSubmissions = 0,
    this.verifiedSubmissions = 0,
    this.accuracyScore = 0.0,
    this.badges = const [],
  });

  double get verificationRate => totalSubmissions > 0 
    ? (verifiedSubmissions / totalSubmissions) * 100 
    : 0.0;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'joinDate': joinDate.toIso8601String(),
    'totalSubmissions': totalSubmissions,
    'verifiedSubmissions': verifiedSubmissions,
    'accuracyScore': accuracyScore,
    'badges': badges,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: json['userId'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String?,
    joinDate: DateTime.parse(json['joinDate'] as String),
    totalSubmissions: json['totalSubmissions'] as int? ?? 0,
    verifiedSubmissions: json['verifiedSubmissions'] as int? ?? 0,
    accuracyScore: (json['accuracyScore'] as num?)?.toDouble() ?? 0.0,
    badges: List<String>.from(json['badges'] as List? ?? []),
  );

  UserProfile copyWith({
    String? displayName,
    int? totalSubmissions,
    int? verifiedSubmissions,
    double? accuracyScore,
    List<String>? badges,
  }) => UserProfile(
    userId: userId,
    email: email,
    displayName: displayName ?? this.displayName,
    joinDate: joinDate,
    totalSubmissions: totalSubmissions ?? this.totalSubmissions,
    verifiedSubmissions: verifiedSubmissions ?? this.verifiedSubmissions,
    accuracyScore: accuracyScore ?? this.accuracyScore,
    badges: badges ?? this.badges,
  );
}

class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String condition;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.condition,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'condition': condition,
  };

  factory Badge.fromJson(Map<String, dynamic> json) => Badge(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    icon: json['icon'] as String,
    condition: json['condition'] as String,
  );
}

class Comment {
  final String id;
  final String recordId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final List<String> likes;

  Comment({
    required this.id,
    required this.recordId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.likes = const [],
  });

  int get likeCount => likes.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recordId': recordId,
    'userId': userId,
    'userName': userName,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'likes': likes,
  };

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    recordId: json['recordId'] as String,
    userId: json['userId'] as String,
    userName: json['userName'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    likes: List<String>.from(json['likes'] as List? ?? []),
  );

  Comment copyWith({
    List<String>? likes,
  }) => Comment(
    id: id,
    recordId: recordId,
    userId: userId,
    userName: userName,
    content: content,
    createdAt: createdAt,
    likes: likes ?? this.likes,
  );
}

class UploadRecord {
  final String id;
  final String imagePath;
  final DateTime timestamp;
  final String? identifiedSpecies;
  final double? confidence;
  final String? userEmail;
  final String? userPhone;
  final String? userId;
  final bool needsVerification;
  final LocationData? location;
  final String status;
  final String? adminNotes;
  final String? verifiedSpecies;
  final DateTime? verifiedAt;
  
  final String? habitatType;
  final double? waterTemperature;
  final double? waterDepth;
  final String? waterTurbidity;
  final String? behaviors;
  final DateTime? observationDateTime;
  
  final List<CommunityVote>? communityVotes;
  final int? expertConfidenceScore;
  final List<Comment>? comments;

  UploadRecord({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    this.identifiedSpecies,
    this.confidence,
    this.userEmail,
    this.userPhone,
    this.userId,
    this.needsVerification = false,
    this.location,
    this.status = 'pending',
    this.adminNotes,
    this.verifiedSpecies,
    this.verifiedAt,
    this.habitatType,
    this.waterTemperature,
    this.waterDepth,
    this.waterTurbidity,
    this.behaviors,
    this.observationDateTime,
    this.communityVotes,
    this.expertConfidenceScore,
    this.comments,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'timestamp': timestamp.toIso8601String(),
    'identifiedSpecies': identifiedSpecies,
    'confidence': confidence,
    'userEmail': userEmail,
    'userPhone': userPhone,
    'userId': userId,
    'needsVerification': needsVerification,
    'location': location?.toJson(),
    'status': status,
    'adminNotes': adminNotes,
    'verifiedSpecies': verifiedSpecies,
    'verifiedAt': verifiedAt?.toIso8601String(),
    'habitatType': habitatType,
    'waterTemperature': waterTemperature,
    'waterDepth': waterDepth,
    'waterTurbidity': waterTurbidity,
    'behaviors': behaviors,
    'observationDateTime': observationDateTime?.toIso8601String(),
    'communityVotes': communityVotes?.map((v) => v.toJson()).toList(),
    'expertConfidenceScore': expertConfidenceScore,
    'comments': comments?.map((c) => c.toJson()).toList(),
  };

  UploadRecord copyWith({
    String? status,
    String? adminNotes,
    String? verifiedSpecies,
    DateTime? verifiedAt,
    String? habitatType,
    double? waterTemperature,
    double? waterDepth,
    String? waterTurbidity,
    String? behaviors,
    DateTime? observationDateTime,
    List<CommunityVote>? communityVotes,
    int? expertConfidenceScore,
    List<Comment>? comments,
  }) {
    return UploadRecord(
      id: id,
      imagePath: imagePath,
      timestamp: timestamp,
      identifiedSpecies: identifiedSpecies,
      confidence: confidence,
      userEmail: userEmail,
      userPhone: userPhone,
      userId: userId,
      needsVerification: needsVerification,
      location: location,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      verifiedSpecies: verifiedSpecies ?? this.verifiedSpecies,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      habitatType: habitatType ?? this.habitatType,
      waterTemperature: waterTemperature ?? this.waterTemperature,
      waterDepth: waterDepth ?? this.waterDepth,
      waterTurbidity: waterTurbidity ?? this.waterTurbidity,
      behaviors: behaviors ?? this.behaviors,
      observationDateTime: observationDateTime ?? this.observationDateTime,
      communityVotes: communityVotes ?? this.communityVotes,
      expertConfidenceScore: expertConfidenceScore ?? this.expertConfidenceScore,
      comments: comments ?? this.comments,
    );
  }
}

/// Advanced observation filtering
class ObservationFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> statusFilters;
  final double? minConfidence;
  final List<String>? habitatFilters;
  final bool? onlyVerified;

  ObservationFilters({
    this.startDate,
    this.endDate,
    this.statusFilters = const [],
    this.minConfidence,
    this.habitatFilters,
    this.onlyVerified = false,
  });

  ObservationFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? statusFilters,
    double? minConfidence,
    List<String>? habitatFilters,
    bool? onlyVerified,
  }) {
    return ObservationFilters(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      statusFilters: statusFilters ?? this.statusFilters,
      minConfidence: minConfidence ?? this.minConfidence,
      habitatFilters: habitatFilters ?? this.habitatFilters,
      onlyVerified: onlyVerified ?? this.onlyVerified,
    );
  }

  bool matches(UploadRecord record) {
    // Date range filter
    if (startDate != null && record.timestamp.isBefore(startDate!)) return false;
    if (endDate != null && record.timestamp.isAfter(endDate!)) return false;

    // Status filter
    if (statusFilters.isNotEmpty && !statusFilters.contains(record.status)) {
      return false;
    }

    // Confidence filter
    if (minConfidence != null && (record.confidence ?? 0) < minConfidence!) {
      return false;
    }

    // Habitat filter
    if (habitatFilters != null && 
        habitatFilters!.isNotEmpty && 
        (record.habitatType == null || !habitatFilters!.contains(record.habitatType))) {
      return false;
    }

    // Verified filter
    if (onlyVerified == true && record.status != 'verified') {
      return false;
    }

    return true;
  }
}
