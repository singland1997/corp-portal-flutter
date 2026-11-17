import 'save_text_file_native.dart' if (dart.library.js_interop) 'save_text_file_web.dart' as platform;

/// Saves generated text (CSV). Returns false when the user cancels the save dialog.
Future<bool> saveTextFile(String name, String content, {String mimeType = 'text/csv'}) =>
    platform.saveTextFile(name, content, mimeType);
