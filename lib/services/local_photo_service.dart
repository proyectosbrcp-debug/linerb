import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/time/app_clock.dart';
import '../core/utils/stable_id.dart';
import '../models/hallazgo_inspeccion.dart';
import '../models/inspection_local_photos.dart';
import '../storage/local/file_local_photo_storage.dart';
import '../storage/local_photo_storage.dart';

class LocalPhotoService {
  final ImagePicker picker;
  final LocalPhotoStorage storage;
  final Future<Directory> Function() rootDirectoryProvider;
  final Clock clock;

  LocalPhotoService({
    ImagePicker? picker,
    LocalPhotoStorage? storage,
    Future<Directory> Function()? rootDirectoryProvider,
    this.clock = const SystemClock(),
  }) : picker = picker ?? ImagePicker(),
       rootDirectoryProvider =
           rootDirectoryProvider ?? _defaultRootDirectoryProvider,
       storage =
           storage ??
           FileLocalPhotoStorage(
             rootDirectoryProvider:
                 rootDirectoryProvider ?? _defaultRootDirectoryProvider,
           );

  Future<String?> capturePhoto({
    required String ownerId,
    required LocalPhotoSlot slot,
    String? previousPath,
  }) async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image == null) return null;

    return storeCapturedPhoto(
      ownerId: ownerId,
      slot: slot,
      temporaryPath: image.path,
      previousPath: previousPath,
    );
  }

  Future<String> storeCapturedPhoto({
    required String ownerId,
    required LocalPhotoSlot slot,
    required String temporaryPath,
    String? previousPath,
  }) async {
    final source = File(temporaryPath);
    if (!await source.exists()) {
      throw FileSystemException(
        'La fotografía temporal no existe',
        temporaryPath,
      );
    }

    final destination = await _destinationFile(ownerId, slot, temporaryPath);
    await destination.parent.create(recursive: true);
    await source.copy(destination.path);
    await storage.replaceReference(
      ownerId,
      slot,
      destination.path,
      capturedAt: clock.now(),
    );

    if (source.path != destination.path) {
      await deleteTemporaryFile(source.path);
    }

    if (previousPath != null && previousPath != destination.path) {
      await deleteTemporaryFile(previousPath);
    }

    return destination.path;
  }

  Future<InspectionLocalPhotos?> loadReferences(String ownerId) {
    return storage.loadReferences(ownerId);
  }

  Future<String?> existingPathOrNull(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return null;
    return await storage.fileExists(localPath) ? localPath : null;
  }

  Future<HallazgoInspeccion> sanitizeHallazgoPhotos(
    HallazgoInspeccion hallazgo,
  ) async {
    return HallazgoInspeccion(
      tipo: hallazgo.tipo,
      detalle: hallazgo.detalle,
      latitud: hallazgo.latitud,
      longitud: hallazgo.longitud,
      descripcion: hallazgo.descripcion,
      foto1Path: await existingPathOrNull(hallazgo.foto1Path),
      foto2Path: await existingPathOrNull(hallazgo.foto2Path),
    );
  }

  Future<List<String>> pdfPhotoPaths(HallazgoInspeccion hallazgo) async {
    final paths = <String>[];
    final first = await existingPathOrNull(hallazgo.foto1Path);
    final second = await existingPathOrNull(hallazgo.foto2Path);
    if (first != null) paths.add(first);
    if (second != null) paths.add(second);
    return paths.take(2).toList(growable: false);
  }

  Future<void> deleteTemporaryFile(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _destinationFile(
    String ownerId,
    LocalPhotoSlot slot,
    String sourcePath,
  ) async {
    final root = await rootDirectoryProvider();
    final safeOwner = _safeName(ownerId);
    final extension = path.extension(sourcePath).isEmpty
        ? '.jpg'
        : path.extension(sourcePath);
    final slotName = switch (slot) {
      LocalPhotoSlot.photo1 => 'photo1',
      LocalPhotoSlot.photo2 => 'photo2',
    };
    final fileName = StableId.fromParts('local_photo', [
      safeOwner,
      slotName,
      clock.now().toIso8601String(),
      sourcePath,
    ]);

    return File('${root.path}/$safeOwner/$slotName-$fileName$extension');
  }

  String _safeName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static Future<Directory> _defaultRootDirectoryProvider() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/linerb_local_photos');
  }
}
