class TeamMember {
  final String id;
  final String ownerID;
  final String? memberID; // null until member signs up and is linked
  final String memberEmail;
  final String roleID;
  final String? roleName; // populated from join query
  final String status; // 'pending' or 'active'
  final DateTime createdAt;

  TeamMember({
    required this.id,
    required this.ownerID,
    this.memberID,
    required this.memberEmail,
    required this.roleID,
    this.roleName,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerID,
      'member_id': memberID,
      'member_email': memberEmail,
      'role_id': roleID,
      'status': status,
    };
  }

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    // Handle joined role data
    String? roleName;
    if (json['roles'] != null && json['roles'] is Map) {
      roleName = (json['roles'] as Map)['name'] as String?;
    }

    return TeamMember(
      id: json['id'] as String,
      ownerID: json['owner_id'] as String,
      memberID: json['member_id'] as String?,
      memberEmail: json['member_email'] as String,
      roleID: json['role_id'] as String,
      roleName: roleName,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  TeamMember copyWith({
    String? memberID,
    String? roleID,
    String? roleName,
    String? status,
  }) {
    return TeamMember(
      id: id,
      ownerID: ownerID,
      memberID: memberID ?? this.memberID,
      memberEmail: memberEmail,
      roleID: roleID ?? this.roleID,
      roleName: roleName ?? this.roleName,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
