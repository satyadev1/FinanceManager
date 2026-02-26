import 'sms_import_result.dart';

/// Stub for non-Android: SMS import not supported.
bool get isSmsImportSupported => false;
Future<bool> requestSmsPermission() async => false;

Future<SmsImportResult> importFromSms() async {
  return const SmsImportResult(notSupported: true);
}
