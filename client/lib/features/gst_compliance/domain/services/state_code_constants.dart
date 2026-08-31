/// 2-digit Indian GST State Codes dictionary with bilingual state names.
/// Adheres strictly to Indian GST statutory master tables (1 to 38).
class GstStateCodes {
  static const Map<int, Map<String, String>> stateMap = {
    1: {'en': 'Jammu & Kashmir', 'hi': 'जम्मू और कश्मीर'},
    2: {'en': 'Himachal Pradesh', 'hi': 'हिमाचल प्रदेश'},
    3: {'en': 'Punjab', 'hi': 'पंजाब'},
    4: {'en': 'Chandigarh', 'hi': 'चंडीगढ़'},
    5: {'en': 'Uttarakhand', 'hi': 'उत्तराखंड'},
    6: {'en': 'Haryana', 'hi': 'हरियाणा'},
    7: {'en': 'Delhi', 'hi': 'दिल्ली'},
    8: {'en': 'Rajasthan', 'hi': 'राजस्थान'},
    9: {'en': 'Uttar Pradesh', 'hi': 'उत्तर प्रदेश'},
    10: {'en': 'Bihar', 'hi': 'बिहार'},
    11: {'en': 'Sikkim', 'hi': 'सिक्किम'},
    12: {'en': 'Arunachal Pradesh', 'hi': 'अरुणाचल प्रदेश'},
    13: {'en': 'Nagaland', 'hi': 'नागालैंड'},
    14: {'en': 'Manipur', 'hi': 'मणिपुर'},
    15: {'en': 'Mizoram', 'hi': 'मिजोरम'},
    16: {'en': 'Tripura', 'hi': 'त्रिपुरा'},
    17: {'en': 'Meghalaya', 'hi': 'मेघालय'},
    18: {'en': 'Assam', 'hi': 'असम'},
    19: {'en': 'West Bengal', 'hi': 'पश्चिम बंगाल'},
    20: {'en': 'Jharkhand', 'hi': 'झारखंड'},
    21: {'en': 'Odisha', 'hi': 'ओडिशा'},
    22: {'en': 'Chhattisgarh', 'hi': 'छत्तीसगढ़'},
    23: {'en': 'Madhya Pradesh', 'hi': 'मध्य प्रदेश'},
    24: {'en': 'Gujarat', 'hi': 'गुजरात'},
    26: {'en': 'Dadra & Nagar Haveli and Daman & Diu', 'hi': 'दादरा और नगर हवेली एवं दमन और दीव'},
    27: {'en': 'Maharashtra', 'hi': 'महाराष्ट्र'},
    28: {'en': 'Andhra Pradesh (Old)', 'hi': 'आंध्र प्रदेश'},
    29: {'en': 'Karnataka', 'hi': 'कर्नाटक'},
    30: {'en': 'Goa', 'hi': 'गोवा'},
    31: {'en': 'Lakshadweep', 'hi': 'लक्षद्वीप'},
    32: {'en': 'Kerala', 'hi': 'केरल'},
    33: {'en': 'Tamil Nadu', 'hi': 'तमिलनाडु'},
    34: {'en': 'Puducherry', 'hi': 'पुडुचेरी'},
    35: {'en': 'Andaman & Nicobar Islands', 'hi': 'अंडमान और निकोबार द्वीप समूह'},
    36: {'en': 'Telangana', 'hi': 'तेलंगाना'},
    37: {'en': 'Andhra Pradesh (New)', 'hi': 'आंध्र प्रदेश'},
    38: {'en': 'Ladakh', 'hi': 'लद्दाख'},
    97: {'en': 'Other Territory', 'hi': 'अन्य क्षेत्र'},
  };

  /// Returns bilingual state name string formatted like "Maharashtra / महाराष्ट्र (27)"
  static String getStateDisplayName(int code) {
    final entry = stateMap[code];
    if (entry == null) return 'State $code';
    return '${entry['en']} / ${entry['hi']} (${code.toString().padLeft(2, '0')})';
  }

  /// Returns English state name for a given 2-digit code
  static String getStateNameEn(int code) {
    return stateMap[code]?['en'] ?? 'Unknown State';
  }

  /// Extracts the 2-digit integer state code from a 15-character GSTIN
  static int? extractStateCodeFromGstin(String? gstin) {
    if (gstin == null || gstin.trim().length < 2) return null;
    final prefix = gstin.trim().substring(0, 2);
    return int.tryParse(prefix);
  }

  /// Validates if an integer is a recognized statutory GST State Code
  static bool isValidStateCode(int code) {
    return stateMap.containsKey(code);
  }
}
