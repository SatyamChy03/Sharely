// Smooths the readout so it doesn't jitter between progress reports.
const _smoothing = 0.3;

/// Bytes per second, worked out from successive progress reports.
class SpeedMeter {
  final _sinceLastReport = Stopwatch();
  int _lastBytes = 0;
  double _bytesPerSecond = 0;

  void reset() {
    _sinceLastReport
      ..stop()
      ..reset();
    _lastBytes = 0;
    _bytesPerSecond = 0;
  }

  /// The current speed, given the total [bytesSoFar].
  double measure(int bytesSoFar) {
    final seconds = _sinceLastReport.elapsedMicroseconds / 1e6;
    if (_sinceLastReport.isRunning && seconds > 0) {
      final instant = (bytesSoFar - _lastBytes) / seconds;
      _bytesPerSecond = _bytesPerSecond == 0
          ? instant
          : _bytesPerSecond + _smoothing * (instant - _bytesPerSecond);
    }
    _lastBytes = bytesSoFar;
    _sinceLastReport
      ..reset()
      ..start();
    return _bytesPerSecond;
  }
}
