class ProjectModel {
  final String id;
  final String name;
  final List<String> gcUserIds;
  final List<String> companyIds;
  final List<String> jobSiteIds;
  final List<String> tradeSequence;
  final DateTime? createdAt;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.gcUserIds,
    required this.companyIds,
    required this.jobSiteIds,
    required this.tradeSequence,
    this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      gcUserIds: List<String>.from(json['gc_user_ids'] as List? ?? []),
      companyIds: List<String>.from(json['company_ids'] as List? ?? []),
      jobSiteIds: List<String>.from(json['job_site_ids'] as List? ?? []),
      tradeSequence:
          List<String>.from(json['trade_sequence'] as List? ?? []),
      createdAt: _parse(json['created_at']),
    );
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
