class RemoteMappingException implements Exception {
  final String message;

  const RemoteMappingException(this.message);

  @override
  String toString() => 'RemoteMappingException: $message';
}
