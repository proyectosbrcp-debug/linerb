import '../logging/app_logger.dart';

enum PerformanceResult { success, failure }

class PerformanceMeasurement {
  final String operationName;
  final String category;
  final DateTime startedAt;
  final Duration duration;
  final int? recordCount;
  final PerformanceResult result;
  final String? failureCategory;

  const PerformanceMeasurement({
    required this.operationName,
    required this.category,
    required this.startedAt,
    required this.duration,
    required this.result,
    this.recordCount,
    this.failureCategory,
  });
}

class PerformanceMonitor {
  const PerformanceMonitor._();

  static Future<T> measure<T>(
    String operationName, {
    String category = 'local',
    int? recordCount,
    String Function(Object error)? failureClassifier,
    required Future<T> Function() action,
  }) async {
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();

    try {
      final value = await action();
      stopwatch.stop();
      _log(
        PerformanceMeasurement(
          operationName: operationName,
          category: category,
          startedAt: startedAt,
          duration: stopwatch.elapsed,
          recordCount: recordCount,
          result: PerformanceResult.success,
        ),
      );
      return value;
    } catch (error, stackTrace) {
      stopwatch.stop();
      final failureCategory = failureClassifier?.call(error) ?? 'unclassified';
      _log(
        PerformanceMeasurement(
          operationName: operationName,
          category: category,
          startedAt: startedAt,
          duration: stopwatch.elapsed,
          recordCount: recordCount,
          result: PerformanceResult.failure,
          failureCategory: failureCategory,
        ),
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  static void _log(
    PerformanceMeasurement measurement, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final recordCount = measurement.recordCount == null
        ? ''
        : ' records=${measurement.recordCount}';
    final failure = measurement.failureCategory == null
        ? ''
        : ' failure=${measurement.failureCategory}';
    final message =
        'performance op=${measurement.operationName} '
        'category=${measurement.category} '
        'result=${measurement.result.name} '
        'duration_ms=${measurement.duration.inMilliseconds}'
        '$recordCount$failure';

    if (measurement.result == PerformanceResult.success) {
      AppLogger.debug(message);
    } else {
      AppLogger.warning(message, error, stackTrace);
    }
  }
}
