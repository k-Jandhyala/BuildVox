import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory VoiceMemoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VoiceMemoModel(
      id: doc.id,
      createdBy: data['createdBy'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      siteId: data['siteId'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      processingStatus: _parseStatus(data['processingStatus'] as String?),
      overallSummary: data['overallSummary'] as String?,
      detectedLanguage: data['detectedLanguage'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      errorMessage: data['errorMessage'] as String?,
    );
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
