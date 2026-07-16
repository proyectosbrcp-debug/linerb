import 'dart:convert';
import 'dart:io';

import '../../models/inspection_local_photos.dart';
import '../local_photo_storage.dart';

class FileLocalPhotoStorage implements LocalPhotoStorage {
  final Future<Directory> Function() rootDirectoryProvider;

  const FileLocalPhotoStorage({required this.rootDirectoryProvider});

  @override
  Future<void> saveReferences(InspectionLocalPhotos photos) async {
    final file = await _manifestFile(photos.ownerId);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(photos.toJson()));
  }

  @override
  Future<InspectionLocalPhotos?> loadReferences(String ownerId) async {
    final file = await _manifestFile(ownerId);
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString()) as Map;
    return InspectionLocalPhotos.fromJson(Map<String, Object?>.from(data));
  }

  @override
  Future<void> replaceReference(
    String ownerId,
    LocalPhotoSlot slot,
    String? localPath, {
    DateTime? capturedAt,
  }) async {
    final current =
        await loadReferences(ownerId) ??
        InspectionLocalPhotos(ownerId: ownerId);
    await saveReferences(
      current.replace(slot, localPath, capturedAt: capturedAt),
    );
  }

  @override
  Future<void> deleteReferences(String ownerId) async {
    final file = await _manifestFile(ownerId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> fileExists(String localPath) {
    return File(localPath).exists();
  }

  Future<File> _manifestFile(String ownerId) async {
    final root = await rootDirectoryProvider();
    final safeOwner = _safeName(ownerId);
    return File('${root.path}/$safeOwner/photos.json');
  }

  String _safeName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }
}
