class Role {
  final String id;
  final String ownerID;
  final String name;
  final String? description;

  // Category view permissions
  final bool canViewPasswords;
  final bool canViewApiKeys;
  final bool canViewEmails;
  final bool canViewNotes;
  final bool canViewImages;
  final bool canViewCards;
  final bool canViewDocuments;

  // Action permissions
  final bool canAddItems;
  final bool canEditItems;
  final bool canDeleteItems;
  final bool canManageTeam;

  final DateTime createdAt;

  Role({
    required this.id,
    required this.ownerID,
    required this.name,
    this.description,
    this.canViewPasswords = false,
    this.canViewApiKeys = false,
    this.canViewEmails = false,
    this.canViewNotes = false,
    this.canViewImages = false,
    this.canViewCards = false,
    this.canViewDocuments = false,
    this.canAddItems = false,
    this.canEditItems = false,
    this.canDeleteItems = false,
    this.canManageTeam = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerID,
      'name': name,
      'description': description,
      'can_view_passwords': canViewPasswords,
      'can_view_api_keys': canViewApiKeys,
      'can_view_emails': canViewEmails,
      'can_view_notes': canViewNotes,
      'can_view_images': canViewImages,
      'can_view_cards': canViewCards,
      'can_view_documents': canViewDocuments,
      'can_add_items': canAddItems,
      'can_edit_items': canEditItems,
      'can_delete_items': canDeleteItems,
      'can_manage_team': canManageTeam,
    };
  }

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      ownerID: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      canViewPasswords: json['can_view_passwords'] as bool? ?? false,
      canViewApiKeys: json['can_view_api_keys'] as bool? ?? false,
      canViewEmails: json['can_view_emails'] as bool? ?? false,
      canViewNotes: json['can_view_notes'] as bool? ?? false,
      canViewImages: json['can_view_images'] as bool? ?? false,
      canViewCards: json['can_view_cards'] as bool? ?? false,
      canViewDocuments: json['can_view_documents'] as bool? ?? false,
      canAddItems: json['can_add_items'] as bool? ?? false,
      canEditItems: json['can_edit_items'] as bool? ?? false,
      canDeleteItems: json['can_delete_items'] as bool? ?? false,
      canManageTeam: json['can_manage_team'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Role copyWith({
    String? name,
    String? description,
    bool? canViewPasswords,
    bool? canViewApiKeys,
    bool? canViewEmails,
    bool? canViewNotes,
    bool? canViewImages,
    bool? canViewCards,
    bool? canViewDocuments,
    bool? canAddItems,
    bool? canEditItems,
    bool? canDeleteItems,
    bool? canManageTeam,
  }) {
    return Role(
      id: id,
      ownerID: ownerID,
      name: name ?? this.name,
      description: description ?? this.description,
      canViewPasswords: canViewPasswords ?? this.canViewPasswords,
      canViewApiKeys: canViewApiKeys ?? this.canViewApiKeys,
      canViewEmails: canViewEmails ?? this.canViewEmails,
      canViewNotes: canViewNotes ?? this.canViewNotes,
      canViewImages: canViewImages ?? this.canViewImages,
      canViewCards: canViewCards ?? this.canViewCards,
      canViewDocuments: canViewDocuments ?? this.canViewDocuments,
      canAddItems: canAddItems ?? this.canAddItems,
      canEditItems: canEditItems ?? this.canEditItems,
      canDeleteItems: canDeleteItems ?? this.canDeleteItems,
      canManageTeam: canManageTeam ?? this.canManageTeam,
      createdAt: createdAt,
    );
  }
}
