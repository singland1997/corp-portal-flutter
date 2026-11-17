import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';

Future<bool> saveTextFile(String name, String content, String mimeType) async {
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  final file = XFile.fromData(Uint8List.fromList(utf8.encode(content)), mimeType: mimeType, name: name);
  await file.saveTo(location.path);
  return true;
}
