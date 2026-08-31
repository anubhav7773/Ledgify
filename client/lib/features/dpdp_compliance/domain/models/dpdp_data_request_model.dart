/// Domain model representing a formal Data Principal / Subject Rights request.
class DpdpDataRequestModel {
  final String id;
  final String businessId;
  final String userId;
  final String requestType; // 'ACCESS_SUMMARY', 'DATA_PORTABILITY_EXPORT', 'RECTIFICATION', 'ERASURE_FORGOTTEN', 'GRIEVANCE_REDRESSAL'
  final String status; // 'PENDING', 'PROCESSING', 'COMPLETED', 'REJECTED'
  final Map<String, dynamic> requestDetails;
  final String? rejectionReason;
  final String? downloadUrl;
  final DateTime? downloadExpiresAt;
  final DateTime requestedAt;
  final DateTime? completedAt;

  const DpdpDataRequestModel({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.requestType,
    required this.status,
    this.requestDetails = const {},
    this.rejectionReason,
    this.downloadUrl,
    this.downloadExpiresAt,
    required this.requestedAt,
    this.completedAt,
  });

  factory DpdpDataRequestModel.fromJson(Map<String, dynamic> json) {
    return DpdpDataRequestModel(
      id: json['id'] as String? ?? '',
      businessId: json['business_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      requestType: json['request_type'] as String? ?? 'ACCESS_SUMMARY',
      status: json['status'] as String? ?? 'PENDING',
      requestDetails: json['request_details'] as Map<String, dynamic>? ?? {},
      rejectionReason: json['rejection_reason'] as String?,
      downloadUrl: json['download_url'] as String?,
      downloadExpiresAt: json['download_expires_at'] != null
          ? DateTime.parse(json['download_expires_at'] as String)
          : null,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isPending => status == 'PENDING' || status == 'PROCESSING';

  String get typeLabelBilingual {
    switch (requestType) {
      case 'DATA_PORTABILITY_EXPORT':
        return 'Data Export (Portability) / डेटा बैकअप';
      case 'RECTIFICATION':
        return 'Information Correction / डेटा सुधार';
      case 'ERASURE_FORGOTTEN':
        return 'Account Erasure / डेटा मिटाना';
      case 'ACCESS_SUMMARY':
        return 'Data Summary / डेटा सारांश';
      case 'GRIEVANCE_REDRESSAL':
      default:
        return 'Privacy Grievance / शिकायत निवारण';
    }
  }
}
