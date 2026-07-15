import 'dart:developer' as developer;

class AppLogger {
  const AppLogger._();

  static void info(String message) {
    developer.log(message, name: 'LINERB');
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'LINERB',
      error: error,
      stackTrace: stackTrace,
      level: 900,
    );
  }
}
