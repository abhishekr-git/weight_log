sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message';
}

class StorageException extends AppException {
  const StorageException(super.message, [super.cause]);
}

class SyncException extends AppException {
  const SyncException(super.message, [super.cause]);
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.cause]);
}
