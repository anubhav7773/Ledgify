import '../../../masters/domain/models/account_model.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../models/gst_registration_model.dart';
import 'ewb_validity_calculator.dart';

/// Service generating FORM GST EWB-01 JSON payloads and managing logistics compliance.
/// Adheres strictly to docs/05_gst_einvoice_and_ewaybill_spec.md.
class EWayBillService {
  /// Generates the complete FORM GST EWB-01 Part A and Part B payload
  static Map<String, dynamic> generateEwb01Payload({
    required VoucherModel voucher,
    required GstRegistrationModel sellerReg,
    required AccountModel buyerAccount,
    required double distanceKm,
    String? transporterId,
    String? transporterName,
    String? vehicleNumber,
    bool isOdc = false,
    String subSupplyType = 'Supply',
    String transportMode = '1', // 1: Road, 2: Rail, 3: Air, 4: Ship
    int buyerPincode = 400001,
  }) {
    final date = voucher.voucherDate;
    final formattedDocDate =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    final bool isUnder10KmIntraState = distanceKm < 10 &&
        sellerReg.stateCode == (int.tryParse(buyerAccount.partyGstin?.substring(0, 2) ?? '') ?? sellerReg.stateCode);

    final double totalConsignmentVal = voucher.totalCreditAmount > 0
        ? voucher.totalCreditAmount
        : voucher.totalDebitAmount;

    final int validityDays = EwbValidityCalculator.calculateValidityDays(distanceKm, isOdc: isOdc);

    // Part A Data Structure
    final Map<String, dynamic> partAData = {
      'supplyType': 'O', // Outward
      'subSupplyType': subSupplyType,
      'docType': 'INV',
      'docNo': voucher.voucherNumber,
      'docDate': formattedDocDate,
      'fromGstin': sellerReg.gstin,
      'fromTrdName': sellerReg.tradeName ?? sellerReg.legalName,
      'fromAddr1': sellerReg.principalAddress,
      'fromPlace': 'Origin Hub',
      'fromPincode': sellerReg.pincode,
      'fromStateCode': sellerReg.stateCode,
      'toGstin': buyerAccount.partyGstin ?? 'URP',
      'toTrdName': buyerAccount.name,
      'toAddr1': 'Delivery Destination',
      'toPlace': 'Destination City',
      'toPincode': buyerPincode,
      'toStateCode': int.tryParse(buyerAccount.partyGstin?.substring(0, 2) ?? '') ?? sellerReg.stateCode,
      'totalValue': totalConsignmentVal,
      'cgstValue': 0.00,
      'sgstValue': 0.00,
      'igstValue': 0.00,
      'cessValue': 0.00,
      'totInvValue': totalConsignmentVal,
      'transDistance': distanceKm.round(),
      'transporterId': transporterId ?? '',
      'transporterName': transporterName ?? '',
    };

    // Part B Data Structure (Road Vehicle)
    final Map<String, dynamic> partBData = {
      'transMode': transportMode,
      'vehicleNo': vehicleNumber ?? (isUnder10KmIntraState ? 'DEF_INTRA_10KM' : ''),
      'vehicleType': isOdc ? 'O' : 'R',
      'transDocNo': '',
      'transDocDate': formattedDocDate,
    };

    return {
      'partA': partAData,
      'partB': partBData,
      'is_odc': isOdc,
      'distance_km': distanceKm,
      'validity_days': validityDays,
      'is_intra_10km_exemption': isUnder10KmIntraState,
    };
  }

  /// Generates a mock 12-digit E-Way Bill Number for development simulation
  static String generateMockEwbNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return '2410${timestamp.substring(timestamp.length - 8)}';
  }
}
