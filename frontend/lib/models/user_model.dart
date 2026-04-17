enum UserRole { worker, gc, manager, admin }

enum TradeType {
  electrical,
  plumbing,
  framing,
  drywall,
  paint,
  general,
  inspection,
  other;

  String get displayName {
    switch (this) {
      case TradeType.electrical:
        return 'Electrical';
      case TradeType.plumbing:
        return 'Plumbing';
      case TradeType.framing:
        return 'Framing';
      case TradeType.drywall:
        return 'Drywall';
      case TradeType.paint:
        return 'Paint';
      case TradeType.general:
        return 'General';
      case TradeType.inspection:
        return 'Inspection';
      case TradeType.other:
        return 'Other';
    }
  }
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final TradeType? trade;
  final String? companyId;
  final List<String> assignedProjectIds;
  final List<String> assignedSiteIds;
  final List<String> fcmTokens;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.trade,
    this.companyId,
    required this.assignedProjectIds,
    required this.assignedSiteIds,
    required this.fcmTokens,
    this.createdAt,
  });

  static UserRole _parseRole(dynamic raw) {
    final s = (raw?.toString() ?? 'worker').trim().toLowerCase();
    for (final r in UserRole.values) {
      if (r.name == s) return r;
    }

    switch (s) {
      case 'general_contractor':
      case 'general contractor':
      case 'contractor':
        return UserRole.gc;
      case 'trade_manager':
      case 'trade manager':
        return UserRole.manager;
      case 'administrator':
        return UserRole.admin;
      case 'electrician':
      case 'plumber':
        return UserRole.worker;
      default:
        return UserRole.worker;
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: _parseRole(json['role']),
      trade: json['trade'] != null
          ? TradeType.values.firstWhere(
              (t) => t.name == json['trade'],
              orElse: () => TradeType.other,
            )
          : null,
      companyId: json['company_id'] as String?,
      assignedProjectIds:
          List<String>.from(json['assigned_project_ids'] as List? ?? []),
      assignedSiteIds:
          List<String>.from(json['assigned_site_ids'] as List? ?? []),
      fcmTokens: List<String>.from(json['fcm_tokens'] as List? ?? []),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  String get roleLabel {
    switch (role) {
      case UserRole.worker:
        return 'Worker';
      case UserRole.gc:
        return 'General Contractor';
      case UserRole.manager:
        return 'Trade Manager';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
