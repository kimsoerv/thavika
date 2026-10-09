import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Receipt photos live in the app's own folder on this phone. An entry
/// stores only the file name.
class ReceiptService {
  final _picker = ImagePicker();

  Future<Directory> _folder() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/receipts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Takes or picks a photo, shrinks it, and returns the saved file name.
  /// Returns null when the user cancels.
  Future<String?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return null;
    final name = '${const Uuid().v4()}.jpg';
    final dir = await _folder();
    await File(picked.path).copy('${dir.path}/$name');
    return name;
  }

  Future<File?> fileFor(String? name) async {
    if (name == null || name.isEmpty) return null;
    final file = File('${(await _folder()).path}/$name');
    return await file.exists() ? file : null;
  }

  Future<void> delete(String? name) async {
    final file = await fileFor(name);
    if (file != null) await file.delete();
  }
}
