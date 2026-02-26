import 'sms_import_result.dart';
import 'sms_import_service_stub.dart' if (dart.library.io) 'sms_import_service_android.dart' as impl;

bool get isSmsImportSupported => impl.isSmsImportSupported;

/// SMS import: always request permission first, then read and analyse messages (Android only).
Future<bool> requestSmsPermission() => impl.requestSmsPermission();

Future<SmsImportResult> importFromSms() => impl.importFromSms();
