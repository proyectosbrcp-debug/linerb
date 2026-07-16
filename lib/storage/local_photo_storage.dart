import '../models/inspection_local_photos.dart';

abstract class LocalPhotoStorage {
  Future<void> saveReferences(InspectionLocalPhotos photos);

  Future<InspectionLocalPhotos?> loadReferences(String ownerId);

  Future<void> replaceReference(
    String ownerId,
    LocalPhotoSlot slot,
    String? localPath, {
    DateTime? capturedAt,
  });

  Future<void> deleteReferences(String ownerId);

  Future<bool> fileExists(String localPath);
}
