class Issue {
  final String id;
  final List<String> photoUrls;
  final String gpsLocation; // "lat,lng"
  final String title;
  final String category;
  final String description;
  final String status; // "pending", "in_progress", "resolved", "rejected"
  final String createdBy;
  final String updatedBy;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Offline-specific fields
  final bool isDraft;
  final List<String> localPhotoPaths; // Local file paths for offline photos

  Issue({
    required this.id,
    required this.photoUrls,
    required this.gpsLocation,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.updatedBy,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.isDraft = false,
    this.localPhotoPaths = const [],
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    // Parse photoUrls
    List<String> photos = [];
    if (json['photo_urls'] != null) {
      photos = List<String>.from(json['photo_urls']);
    }

    // Parse localPhotoPaths
    List<String> localPhotos = [];
    if (json['local_photo_paths'] != null) {
      localPhotos = List<String>.from(json['local_photo_paths']);
    }

    return Issue(
      id: json['id'] as String,
      photoUrls: photos,
      gpsLocation: json['gps_location'] as String? ?? '0,0',
      title: (json['title'] ?? json['road']) as String? ?? '',
      category: json['category'] as String? ?? 'other',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdBy: json['created_by'] as String? ?? '',
      updatedBy: json['updated_by'] as String? ?? '',
      assignedTo: json['assigned_to'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      isDraft: json['is_draft'] as bool? ?? false,
      localPhotoPaths: localPhotos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photo_urls': photoUrls,
      'gps_location': gpsLocation,
      'title': title,
      'category': category,
      'description': description,
      'status': status,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'assigned_to': assignedTo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_draft': isDraft,
      'local_photo_paths': localPhotoPaths,
    };
  }

  Issue copyWith({
    String? id,
    List<String>? photoUrls,
    String? gpsLocation,
    String? title,
    String? category,
    String? description,
    String? status,
    String? createdBy,
    String? updatedBy,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDraft,
    List<String>? localPhotoPaths,
  }) {
    return Issue(
      id: id ?? this.id,
      photoUrls: photoUrls ?? this.photoUrls,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDraft: isDraft ?? this.isDraft,
      localPhotoPaths: localPhotoPaths ?? this.localPhotoPaths,
    );
  }
}
