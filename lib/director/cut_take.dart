/// Explicit Cut/Take onto Program (AC-2.2). No silent auto-switch.
library;

class CutTakeAction {
  static const cut = 'cut';
  static const take = 'take';

  static bool isValid(String action) =>
      action == cut || action == take;
}

class CutTakeResult {
  const CutTakeResult({
    required this.action,
    required this.previewSourceId,
    required this.previousProgramSourceId,
    required this.programSourceId,
    required this.issuedAtMs,
    required this.appliedAtMs,
  });

  final String action;
  final String previewSourceId;
  final String previousProgramSourceId;
  final String programSourceId;
  final int issuedAtMs;
  final int appliedAtMs;

  /// Wall time from explicit Cut/Take issue to Program apply (G3).
  int get cutLatencyMs => appliedAtMs - issuedAtMs;
}

class CutTakeException implements Exception {
  CutTakeException(this.message);

  final String message;

  @override
  String toString() => message;
}
