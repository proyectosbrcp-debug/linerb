abstract class StorageException implements Exception {
  final String message;
  final Object? cause;

  const StorageException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause == null) {
      return '$runtimeType: $message';
    }
    return '$runtimeType: $message ($cause)';
  }
}

class StorageNotFoundException extends StorageException {
  const StorageNotFoundException(super.message, [super.cause]);
}

class StorageCorruptDataException extends StorageException {
  const StorageCorruptDataException(super.message, [super.cause]);
}

class StorageReadException extends StorageException {
  const StorageReadException(super.message, [super.cause]);
}

class StorageWriteException extends StorageException {
  const StorageWriteException(super.message, [super.cause]);
}
