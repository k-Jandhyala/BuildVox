enum ProcessingStatus { pending, processing, completed, failed }

class VoiceMemoModel {
  final String id;
  final String createdBy;
  final String projectId;
  final String siteId;
  final String storagePath;
  final ProcessingStatus processingStatus;
  final String? overallSummary;
  final String? detectedLanguage;
  final DateTime? createdAt;
  final String? errorMessage;

  const VoiceMemoModel({
    required this.id,
    required this.createdBy,
    required this.projectId,
    required this.siteId,
    required this.storagePath,
    required this.processingStatus,
    this.overallSummary,
    this.detectedLanguage,
    this.createdAt,
    this.errorMessage,
  });

  factory VoiceMemoModel.fromJson(Map<String, dynamic> json) {
    return VoiceMemoModel(
      id: json['id'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      siteId: json['site_id'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      processingStatus:
          _parseStatus(json['processing_status'] as String?),
      overallSummary: json['overall_summary'] as String?,
      detectedLanguage: json['detected_language'] as String?,
      createdAt: _parse(json['created_at']),
      errorMessage: json['error_message'] as String?,
    );
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static ProcessingStatus _parseStatus(String? value) {
    switch (value) {
      case 'processing':
        return ProcessingStatus.processing;
      case 'completed':
        return ProcessingStatus.completed;
      case 'failed':
        return ProcessingStatus.failed;
      default:
        return ProcessingStatus.pending;
    }
  }
}
