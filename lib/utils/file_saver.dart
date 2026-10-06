// lib/utils/file_saver.dart
//
// Saves a generated file (Excel, CSV …) for the user:
//   web      → a normal browser download with [fileName]
//   phones   → the app's documents folder (exports/), then opened with the
//              phone's viewer; [shareSavedFile] offers it to other apps
//   desktop  → the Downloads folder, then opened

import 'dart:io' show Directory, File, Platform;

import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class SavedFile {
  final String fileName;

  /// Where it was written (null on the web — the browser downloaded it).
  final String? path;
  const SavedFile(this.fileName, this.path);
}

/// A safe file name (keeps letters, digits, spaces and - _ . ( ) ,).
String safeFileName(String name) =>
    name.replaceAll(RegExp(r'[^\w\s\-.(),]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

Future<SavedFile> saveFileForUser(Uint8List bytes, String fileName, {required String mimeType}) async {
  final name = safeFileName(fileName);
  if (kIsWeb) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = name
      ..style.display = 'none'
      ..click();
    html.Url.revokeObjectUrl(url);
    return SavedFile(name, null);
  }
  Directory dir;
  if (Platform.isAndroid || Platform.isIOS) {
    dir = Directory('${(await getApplicationDocumentsDirectory()).path}/exports');
  } else {
    dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  }
  if (!await dir.exists()) await dir.create(recursive: true);
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  // Open it straight away; failing to open (no viewer) is not an error.
  try {
    await OpenFile.open(file.path, type: mimeType);
  } catch (_) {}
  return SavedFile(name, file.path);
}

/// Offers a saved file to other apps (email, WhatsApp, Drive …).
Future<void> shareSavedFile(SavedFile f, {required String mimeType, String? text}) async {
  if (f.path == null) return;
  await SharePlus.instance.share(ShareParams(
    files: [XFile(f.path!, mimeType: mimeType, name: f.fileName)],
    text: text,
  ));
}
