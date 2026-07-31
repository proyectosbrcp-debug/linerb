import '../core/time/app_clock.dart';

typedef SyncJitterProvider = Duration Function(int attempt);

class SyncRetryPolicy {
  final Clock clock;
  final SyncJitterProvider jitter;
  final Duration maxDelay;

  const SyncRetryPolicy({
    this.clock = const SystemClock(),
    this.jitter = _defaultJitter,
    this.maxDelay = const Duration(minutes: 10),
  });

  DateTime nextRetryAt(int attempt) {
    return clock.now().add(delayForAttempt(attempt));
  }

  Duration delayForAttempt(int attempt) {
    final safeAttempt = attempt < 1 ? 1 : attempt;
    final base = switch (safeAttempt) {
      1 => const Duration(seconds: 30),
      2 => const Duration(minutes: 1),
      3 => const Duration(minutes: 2),
      _ => const Duration(minutes: 5),
    };
    final delayed = base + jitter(safeAttempt);
    return delayed > maxDelay ? maxDelay : delayed;
  }

  static Duration _defaultJitter(int attempt) {
    final seconds = (attempt * 7) % 11;
    return Duration(seconds: seconds);
  }
}
