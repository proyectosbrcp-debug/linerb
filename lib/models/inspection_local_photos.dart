enum LocalPhotoSlot { photo1, photo2 }

LocalPhotoSlot localPhotoSlotFromNumber(int value) {
  return switch (value) {
    1 => LocalPhotoSlot.photo1,
    2 => LocalPhotoSlot.photo2,
    _ => throw RangeError.range(value, 1, 2, 'photoSlot'),
  };
}

class InspectionLocalPhotos {
  final String ownerId;
  final String? photo1LocalPath;
  final String? photo2LocalPath;
  final DateTime? photo1CapturedAt;
  final DateTime? photo2CapturedAt;

  const InspectionLocalPhotos({
    required this.ownerId,
    this.photo1LocalPath,
    this.photo2LocalPath,
    this.photo1CapturedAt,
    this.photo2CapturedAt,
  });

  String? pathFor(LocalPhotoSlot slot) {
    return switch (slot) {
      LocalPhotoSlot.photo1 => photo1LocalPath,
      LocalPhotoSlot.photo2 => photo2LocalPath,
    };
  }

  InspectionLocalPhotos replace(
    LocalPhotoSlot slot,
    String? path, {
    DateTime? capturedAt,
  }) {
    return switch (slot) {
      LocalPhotoSlot.photo1 => InspectionLocalPhotos(
        ownerId: ownerId,
        photo1LocalPath: path,
        photo2LocalPath: photo2LocalPath,
        photo1CapturedAt: capturedAt,
        photo2CapturedAt: photo2CapturedAt,
      ),
      LocalPhotoSlot.photo2 => InspectionLocalPhotos(
        ownerId: ownerId,
        photo1LocalPath: photo1LocalPath,
        photo2LocalPath: path,
        photo1CapturedAt: photo1CapturedAt,
        photo2CapturedAt: capturedAt,
      ),
    };
  }

  Map<String, Object?> toJson() {
    return {
      'ownerId': ownerId,
      'photo1LocalPath': photo1LocalPath,
      'photo2LocalPath': photo2LocalPath,
      'photo1CapturedAt': photo1CapturedAt?.toIso8601String(),
      'photo2CapturedAt': photo2CapturedAt?.toIso8601String(),
    };
  }

  static InspectionLocalPhotos fromJson(Map<String, Object?> json) {
    return InspectionLocalPhotos(
      ownerId: json['ownerId'] as String,
      photo1LocalPath: json['photo1LocalPath'] as String?,
      photo2LocalPath: json['photo2LocalPath'] as String?,
      photo1CapturedAt: _date(json['photo1CapturedAt']),
      photo2CapturedAt: _date(json['photo2CapturedAt']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
