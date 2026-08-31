import 'dpdp_purpose.dart';

/// Domain model representing an immutable DPDP Act 2023 consent audit log.
class DpdpConsentLogModel {
  final String id;
  final String? businessId;
  final String userId;
  final DpdpPurpose purpose;
  final String consentStatus; // 'GRANTED', 'REVOKED', 'EXPIRED'
  final String consentVersion;
  final String consentPayloadHash;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final String? ipAddress;
  final String? userAgent;

  const DpdpConsentLogModel({
    required this.id,
    this.businessId,
    required this.userId,
    required this.purpose,
    required this.consentStatus,
    this.consentVersion = 'v1.0',
    required this.consentPayloadHash,
    required this.grantedAt,
    this.revokedAt,
    this.ipAddress,
    this.userAgent,
  });

  factory DpdpConsentLogModel.fromJson(Map<String, dynamic> json) {
    return DpdpConsentLogModel(
      id: json['id'] as String? ?? '',
      businessId: json['business_id'] as String?,
      userId: json['user_id'] as String? ?? '',
      purpose: DpdpPurposeExtension.fromCode(json['purpose'] as String? ?? 'TELEMETRY_ANALYTICS'),
      consentStatus: json['consent_status'] as String? ?? 'GRANTED',
      consentVersion: json['consent_version'] as String? ?? 'v1.0',
      consentPayloadHash: json['consent_payload_hash'] as String? ?? '',
      grantedAt: DateTime.parse(json['granted_at'] as String),
      revokedAt: json['revoked_at'] != null ? DateTime.parse(json['revoked_at'] as String) : null,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
    );
  }

  bool get isActive => consentStatus == 'GRANTED' && revokedAt == null;
}
