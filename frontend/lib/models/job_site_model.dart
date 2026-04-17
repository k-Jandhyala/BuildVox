class JobSiteModel {
  final String id;
  final String projectId;
  final String name;
  final String address;
  final List<String> activeTrades;
  final DateTime? createdAt;

  const JobSiteModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.address,
    required this.activeTrades,
    this.createdAt,
  });

  factory JobSiteModel.fromJson(Map<String, dynamic> json) {
    return JobSiteModel(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      activeTrades: List<String>.from(json['active_trades'] as List? ?? []),
      createdAt: _parse(json['created_at']),
    );
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
