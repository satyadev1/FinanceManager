/// Categories used by the app for SMS (e.g. import only uses BANK_TRANSACTION).
/// For full intent analysis use [analyzeSms] from [sms_intelligence_engine.dart].
import 'sms_intelligence_engine.dart';

export 'sms_intelligence_engine.dart' show analyzeSms, SmsAnalysisResult, SmsIntentCategory;

/// Legacy categories for import, counts, and Messages tab filters.
enum SmsCategory {
  otp,
  bankTransaction,
  promotional,
  spam,
  broker,
  regulatory,
  other,
}

extension SmsCategoryLabel on SmsCategory {
  String get label {
    switch (this) {
      case SmsCategory.otp:
        return 'OTP';
      case SmsCategory.bankTransaction:
        return 'BANK_TRANSACTION';
      case SmsCategory.promotional:
        return 'PROMOTIONAL';
      case SmsCategory.spam:
        return 'SPAM';
      case SmsCategory.broker:
        return 'BROKER';
      case SmsCategory.regulatory:
        return 'REGULATORY';
      case SmsCategory.other:
        return 'OTHER';
    }
  }

  /// User-friendly display label for UI.
  String get displayLabel {
    switch (this) {
      case SmsCategory.otp:
        return 'Verification Code';
      case SmsCategory.bankTransaction:
        return 'Bank Alert';
      case SmsCategory.promotional:
        return 'Promotional';
      case SmsCategory.spam:
        return 'Spam';
      case SmsCategory.broker:
        return 'Trading/Broker';
      case SmsCategory.regulatory:
        return 'Regulatory';
      case SmsCategory.other:
        return 'Other';
    }
  }
}

/// Maps enterprise intent to legacy category for import/counts.
SmsCategory intentToLegacyCategory(SmsIntentCategory intent) {
  switch (intent) {
    case SmsIntentCategory.otp:
      return SmsCategory.otp;
    case SmsIntentCategory.bankTransaction:
      return SmsCategory.bankTransaction;
    case SmsIntentCategory.promotional:
      return SmsCategory.promotional;
    case SmsIntentCategory.spam:
    case SmsIntentCategory.phishing:
      return SmsCategory.spam;
    case SmsIntentCategory.brokerTransaction:
    case SmsIntentCategory.brokerNonTransactional:
      return SmsCategory.broker;
    case SmsIntentCategory.regulatory:
      return SmsCategory.regulatory;
    case SmsIntentCategory.bankNonTransactional:
    case SmsIntentCategory.serviceNotification:
    case SmsIntentCategory.personal:
    case SmsIntentCategory.unknown:
      return SmsCategory.other;
  }
}

/// Rule-based classification into legacy categories. Uses full engine under the hood.
SmsCategory classifySms(String message) {
  final result = analyzeSms(message);
  return intentToLegacyCategory(result.category);
}
