import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Statutory Indian DPDP Act 2023 Purpose Taxonomy for Ledgify.
/// Adheres strictly to docs/11_dpdp_compliance_and_audit_spec.md.
enum DpdpPurpose {
  financialOcrExtraction,
  voiceVoucherProcessing,
  connectedBankingSync,
  governmentPortalSync,
  telemetryAnalytics,
}

extension DpdpPurposeExtension on DpdpPurpose {
  String get code {
    switch (this) {
      case DpdpPurpose.financialOcrExtraction:
        return 'FINANCIAL_OCR_EXTRACTION';
      case DpdpPurpose.voiceVoucherProcessing:
        return 'VOICE_VOUCHER_PROCESSING';
      case DpdpPurpose.connectedBankingSync:
        return 'CONNECTED_BANKING_SYNC';
      case DpdpPurpose.governmentPortalSync:
        return 'GOVERNMENT_PORTAL_SYNC';
      case DpdpPurpose.telemetryAnalytics:
        return 'TELEMETRY_ANALYTICS';
    }
  }

  String get titleEnglish {
    switch (this) {
      case DpdpPurpose.financialOcrExtraction:
        return 'Financial Bill AI Scanning';
      case DpdpPurpose.voiceVoucherProcessing:
        return 'Voice Voucher Audio Processing';
      case DpdpPurpose.connectedBankingSync:
        return 'Connected Banking & BRS Statement Sync';
      case DpdpPurpose.governmentPortalSync:
        return 'GST Portal & E-Invoice Sync';
      case DpdpPurpose.telemetryAnalytics:
        return 'App Performance & Error Telemetry';
    }
  }

  String get titleHindi {
    switch (this) {
      case DpdpPurpose.financialOcrExtraction:
        return 'बिल की एआई स्कैनिंग';
      case DpdpPurpose.voiceVoucherProcessing:
        return 'आवाज़ द्वारा वाउचर रिकॉर्डिंग';
      case DpdpPurpose.connectedBankingSync:
        return 'बैंक खाता एवं बीआरएस स्टेटमेंट';
      case DpdpPurpose.governmentPortalSync:
        return 'जीएसटी एवं ई-इनवॉइस पोर्टल सिंक';
      case DpdpPurpose.telemetryAnalytics:
        return 'ऐप उपयोग व त्रुटि रिपोर्टिंग';
    }
  }

  String get descriptionEnglish {
    switch (this) {
      case DpdpPurpose.financialOcrExtraction:
        return 'Your uploaded bill image is temporarily processed by Gemini 2.5 Flash exclusively to extract vendor name, GSTIN, and tax line items. Your image is never used to train foundation models.';
      case DpdpPurpose.voiceVoucherProcessing:
        return 'Audio recordings in vernacular languages (Hindi, Hinglish, English) are processed strictly to infer transaction debit/credit lines and discarded immediately after transcription.';
      case DpdpPurpose.connectedBankingSync:
        return 'Bank e-statements are ingested to compute automated Trigram reconciliation. Account credentials are never stored on device.';
      case DpdpPurpose.governmentPortalSync:
        return 'GSTIN and invoice summaries are communicated securely via NIC/IRP GSP APIs for statutory E-Invoice and E-Way Bill generation.';
      case DpdpPurpose.telemetryAnalytics:
        return 'Anonymized crash reports and app performance metrics to ensure continuous accounting uptime.';
    }
  }

  String get descriptionHindi {
    switch (this) {
      case DpdpPurpose.financialOcrExtraction:
        return 'आपके बिल की फोटो केवल व्यापारी नाम, जीएसटी और कर विवरण निकालने के लिए जेमिनी एआई द्वारा प्रोसेस की जाती है। आपकी फोटो का उपयोग किसी अन्य उद्देश्य के लिए नहीं होता।';
      case DpdpPurpose.voiceVoucherProcessing:
        return 'आपकी आवाज की रिकॉर्डिंग केवल वाउचर प्रविष्टि दर्ज करने के लिए प्रोसेस की जाती है और ट्रांसक्रिप्शन के तुरंत बाद हटा दी जाती है।';
      case DpdpPurpose.connectedBankingSync:
        return 'बैंक स्टेटमेंट केवल स्वचालित समाधान (BRS) के लिए पढ़े जाते हैं। बैंक पासवर्ड कभी सेव नहीं होते।';
      case DpdpPurpose.governmentPortalSync:
        return 'जीएसटी और ई-इनवॉइस पोर्टल के साथ सरकारी नियमों के तहत डेटा का सुरक्षित आदान-प्रदान किया जाता है।';
      case DpdpPurpose.telemetryAnalytics:
        return 'ऐप की गति और त्रुटियों की तकनीकी रिपोर्ट ताकि हिसाब-किताब में कोई रुकावट न आए।';
    }
  }

  /// Computes deterministic SHA-256 hash of the statutory notice text
  String get statutoryNoticeHash {
    final rawNotice = '$code|$titleEnglish|$descriptionEnglish|v1.0';
    return sha256.convert(utf8.encode(rawNotice)).toString();
  }

  static DpdpPurpose fromCode(String code) {
    switch (code) {
      case 'FINANCIAL_OCR_EXTRACTION':
        return DpdpPurpose.financialOcrExtraction;
      case 'VOICE_VOUCHER_PROCESSING':
        return DpdpPurpose.voiceVoucherProcessing;
      case 'CONNECTED_BANKING_SYNC':
        return DpdpPurpose.connectedBankingSync;
      case 'GOVERNMENT_PORTAL_SYNC':
        return DpdpPurpose.governmentPortalSync;
      case 'TELEMETRY_ANALYTICS':
      default:
        return DpdpPurpose.telemetryAnalytics;
    }
  }
}
