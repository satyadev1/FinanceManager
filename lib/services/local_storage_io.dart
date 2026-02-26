/// Local file storage for mobile/desktop (not web).
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> saveToLocal(String filename, String csv) async {
  final dir = await _dir();
  await File('$dir/$filename').writeAsString(csv);
}

Future<String?> loadFromLocal(String filename) async {
  final dir = await _dir();
  final file = File('$dir/$filename');
  if (await file.exists()) return await file.readAsString();
  return null;
}

Future<String> _dir() async {
  final appDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${appDir.path}/fin_manager');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir.path;
}
