class CompanyModel {
  final String id;
  final String name;
  final String tradeType;
  final List<String> managerUserIds;
  final List<String> activeProjectIds;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.tradeType,
    required this.managerUserIds,
    required this.activeProjectIds,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tradeType: json['trade_type'] as String? ?? 'other',
      managerUserIds:
          List<String>.from(json['manager_user_ids'] as List? ?? []),
      activeProjectIds:
          List<String>.from(json['active_project_ids'] as List? ?? []),
    );
  }
}
