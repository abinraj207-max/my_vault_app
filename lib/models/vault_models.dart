
enum VaultType {
  password,
  apiKey,
  email,
  note,
  image,
  card,
  document,
}

class VaultItem {
  final String id;
  final VaultType type;
  final String title;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Passwords & Emails & Cards
  final String? username;
  final String? email;
  final String? password;
  final String? website;

  // API Keys
  final String? service;
  final String? apiKey;
  final String? secretKey;
  final String? environment;

  // Secure Notes
  final String? content;

  // Files / Images / Documents / Cards
  final String? fileVaultPath; // Encrypted path relative to vault root, e.g. "media/img_123.enc"
  final String? originalFileName;
  final String? mimeType;
  final int? fileSize;

  // Visiting Cards specific
  final String? cardHolderName;
  final String? company;
  final String? phone;

  // Common notes field
  final String? notes;

  VaultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.email,
    this.password,
    this.website,
    this.service,
    this.apiKey,
    this.secretKey,
    this.environment,
    this.content,
    this.fileVaultPath,
    this.originalFileName,
    this.mimeType,
    this.fileSize,
    this.cardHolderName,
    this.company,
    this.phone,
    this.notes,
  });

  // Convert a VaultItem to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'username': username,
      'email': email,
      'password': password,
      'website': website,
      'service': service,
      'apiKey': apiKey,
      'secretKey': secretKey,
      'environment': environment,
      'content': content,
      'fileVaultPath': fileVaultPath,
      'originalFileName': originalFileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'cardHolderName': cardHolderName,
      'company': company,
      'phone': phone,
      'notes': notes,
    };
  }

  // Create a VaultItem from JSON Map
  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      type: VaultType.values.byName(json['type'] as String),
      title: json['title'] as String,
      tags: List<String>.from(json['tags'] as List? ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      username: json['username'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      website: json['website'] as String?,
      service: json['service'] as String?,
      apiKey: json['apiKey'] as String?,
      secretKey: json['secretKey'] as String?,
      environment: json['environment'] as String?,
      content: json['content'] as String?,
      fileVaultPath: json['fileVaultPath'] as String?,
      originalFileName: json['originalFileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: json['fileSize'] as int?,
      cardHolderName: json['cardHolderName'] as String?,
      company: json['company'] as String?,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
    );
  }

  // Helper method to create a copy of the item with modified fields
  VaultItem copyWith({
    String? title,
    List<String>? tags,
    DateTime? updatedAt,
    String? username,
    String? email,
    String? password,
    String? website,
    String? service,
    String? apiKey,
    String? secretKey,
    String? environment,
    String? content,
    String? fileVaultPath,
    String? originalFileName,
    String? mimeType,
    int? fileSize,
    String? cardHolderName,
    String? company,
    String? phone,
    String? notes,
  }) {
    return VaultItem(
      id: this.id,
      type: this.type,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      website: website ?? this.website,
      service: service ?? this.service,
      apiKey: apiKey ?? this.apiKey,
      secretKey: secretKey ?? this.secretKey,
      environment: environment ?? this.environment,
      content: content ?? this.content,
      fileVaultPath: fileVaultPath ?? this.fileVaultPath,
      originalFileName: originalFileName ?? this.originalFileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
    );
  }
}
