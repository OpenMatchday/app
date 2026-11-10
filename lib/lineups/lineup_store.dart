import 'lineup_models.dart';

class LineupActionResult {
  const LineupActionResult({
    required this.ok,
    required this.message,
    this.state,
  });

  final bool ok;
  final String message;
  final LineupAirState? state;
}

/// Lineup operator store: preview required before Program (AC-7.6).
class LineupStore {
  LineupStore({
    LineupDraft? initialDraft,
    int Function()? clockMs,
  }) : _clockMs = clockMs ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _draft = initialDraft ??
        LineupDraft(
          side: 'home',
          teamName: 'Home',
          sportId: 'basketball',
          formationId: 'starting_five',
          starters: const <LineupPlayer>[],
          substitutes: const <LineupPlayer>[],
          revision: 'rev-0',
        );
  }

  final int Function() _clockMs;
  late LineupDraft _draft;
  String? _previewedRevision;
  String? _programRevision;
  LineupAirState _airState = LineupAirState.draft;
  bool _reducedMotion = true;

  LineupDraft get draft => _draft;

  LineupAirState get airState => _airState;

  bool get reducedMotion => _reducedMotion;

  String? get previewedRevision => _previewedRevision;

  String? get programRevision => _programRevision;

  bool get canTakeToProgram =>
      _previewedRevision != null && _previewedRevision == _draft.revision;

  void setReducedMotion(bool value) {
    _reducedMotion = value;
  }

  LineupActionResult updateDraft(LineupDraft next) {
    final revision = 'rev-${_clockMs()}';
    _draft = next.copyWith(revision: revision);
    _previewedRevision = null;
    if (_airState == LineupAirState.previewed ||
        _airState == LineupAirState.onProgram) {
      _airState = LineupAirState.draft;
    }
    _programRevision = null;
    return LineupActionResult(
      ok: true,
      message: 'lineup draft updated; preview required before Program',
      state: _airState,
    );
  }

  LineupActionResult markPreviewed() {
    _previewedRevision = _draft.revision;
    _airState = LineupAirState.previewed;
    return LineupActionResult(
      ok: true,
      message: 'lineup preview confirmed for ${_draft.revision}',
      state: _airState,
    );
  }

  /// AC-7.6: refuse Program unless current draft was previewed.
  LineupActionResult takeToProgram() {
    if (!canTakeToProgram) {
      return const LineupActionResult(
        ok: false,
        message: 'preview required before lineup can go to Program',
        state: LineupAirState.draft,
      );
    }
    _programRevision = _draft.revision;
    _airState = LineupAirState.onProgram;
    return LineupActionResult(
      ok: true,
      message: 'lineup ${_draft.revision} on Program',
      state: _airState,
    );
  }
}
