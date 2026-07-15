import '../logging/app_logger.dart';

enum RuntimeInitializationStatus { initializing, ready, degraded }

class RuntimeInitializationResult {
  final RuntimeInitializationStatus status;
  final Object? error;

  const RuntimeInitializationResult({required this.status, this.error});
}

class AppRuntimeInitializer {
  final Future<void> Function() openDatabase;
  final Future<void> Function() migrate;
  final Duration timeout;

  RuntimeInitializationStatus status = RuntimeInitializationStatus.initializing;
  RuntimeInitializationResult? _result;

  RuntimeInitializationResult? get result => _result;

  Object? get lastError => _result?.error;

  AppRuntimeInitializer({
    required this.openDatabase,
    required this.migrate,
    this.timeout = const Duration(seconds: 4),
  });

  Future<RuntimeInitializationResult> initialize() async {
    final existing = _result;
    if (existing != null) return existing;

    status = RuntimeInitializationStatus.initializing;

    try {
      await _initialize().timeout(timeout);
      status = RuntimeInitializationStatus.ready;
      _result = const RuntimeInitializationResult(
        status: RuntimeInitializationStatus.ready,
      );
      AppLogger.info('Inicialización local completada.');
    } catch (e, stackTrace) {
      status = RuntimeInitializationStatus.degraded;
      _result = RuntimeInitializationResult(
        status: RuntimeInitializationStatus.degraded,
        error: e,
      );
      AppLogger.warning(
        'Inicialización local degradada; se usará fallback V1.',
        e,
        stackTrace,
      );
    }

    return _result!;
  }

  Future<void> _initialize() async {
    await openDatabase();
    await migrate();
  }
}
