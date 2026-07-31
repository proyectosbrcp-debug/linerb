import 'dart:developer' as developer;

class AppLogger {
  const AppLogger._();

  static void debug(String message) {
    developer.log(message, name: 'LINERB', level: 500);
  }

  static void info(String message) {
    developer.log(message, name: 'LINERB', level: 800);
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

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'LINERB',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
