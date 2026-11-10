/// Manual monotonic timer — default clock authority (AC-5.1).
/// Elapsed only increases while running; never jumps backward on tick.
class ManualMonotonicTimer {
  ManualMonotonicTimer({
    Duration initialElapsed = Duration.zero,
    this.now = DateTime.now,
  }) : _elapsed = initialElapsed.isNegative ? Duration.zero : initialElapsed;

  final DateTime Function() now;

  Duration _elapsed;
  DateTime? _startedAt;
  bool _running = false;

  bool get isRunning => _running;

  Duration get elapsed {
    if (!_running || _startedAt == null) {
      return _elapsed;
    }
    final delta = now().difference(_startedAt!);
    if (delta.isNegative) {
      return _elapsed;
    }
    return _elapsed + delta;
  }

  void start() {
    if (_running) {
      return;
    }
    _startedAt = now();
    _running = true;
  }

  void pause() {
    if (!_running) {
      return;
    }
    _elapsed = elapsed;
    _startedAt = null;
    _running = false;
  }

  /// Set absolute elapsed. Rejects negative values (monotonic product rule).
  void setElapsed(Duration value) {
    if (value.isNegative) {
      throw ArgumentError('elapsed must be non-negative');
    }
    _elapsed = value;
    if (_running) {
      _startedAt = now();
    }
  }

  String formatMmSs() {
    final total = elapsed.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
