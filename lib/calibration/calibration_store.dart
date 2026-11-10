import 'geometry.dart';
import 'regions.dart';

enum CalibrationPhase {
  live,
  frozen,
  corners,
  rectifiedPending,
  confirmed,
  regions,
  complete,
}

class CalibrationActionResult {
  const CalibrationActionResult({
    required this.ok,
    required this.message,
    this.phase,
  });

  final bool ok;
  final String message;
  final CalibrationPhase? phase;
}

/// Scoreboard Reader calibration store (AC-4.1–4.6).
class CalibrationStore {
  CalibrationStore({
    this.sportId = 'basketball/fiba',
    this.frameWidth = 1280,
    this.frameHeight = 720,
    int Function()? clockMs,
  }) : _clockMs = clockMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _clockMs;
  String sportId;
  double frameWidth;
  double frameHeight;
  int _rotationDegrees = 0;
  CalibrationPhase _phase = CalibrationPhase.live;
  String? _freezeId;
  CornerSet? _pixelCorners;
  CornerSet? _normalizedCorners;
  List<List<double>>? _homography;
  bool _geometryAccepted = false;
  List<BoardRegion> _regions = const <BoardRegion>[];
  String? _selectedCorner;
  double _zoom = 1;
  CornerValidation? _lastValidation;

  CalibrationPhase get phase => _phase;

  int get rotationDegrees => _rotationDegrees;

  String? get freezeId => _freezeId;

  CornerSet? get pixelCorners => _pixelCorners;

  CornerSet? get normalizedCorners => _normalizedCorners;

  List<List<double>>? get homography => _homography;

  bool get geometryAccepted => _geometryAccepted;

  List<BoardRegion> get regions => List<BoardRegion>.unmodifiable(_regions);

  String? get selectedCorner => _selectedCorner;

  double get zoom => _zoom;

  CornerValidation? get lastValidation => _lastValidation;

  List<String> get availableFields => fieldsForSport(sportId);

  /// AC-4.1 freeze live preview for calibration.
  CalibrationActionResult freezeFrame({
    double? width,
    double? height,
    String? freezeId,
  }) {
    frameWidth = width ?? frameWidth;
    frameHeight = height ?? frameHeight;
    _freezeId = freezeId ?? 'freeze-${_clockMs()}';
    _phase = CalibrationPhase.frozen;
    _geometryAccepted = false;
    _homography = null;
    _normalizedCorners = null;
    _pixelCorners = null;
    _regions = const <BoardRegion>[];
    _lastValidation = null;
    return CalibrationActionResult(
      ok: true,
      message: 'frame frozen for calibration ($_freezeId)',
      phase: _phase,
    );
  }

  CalibrationActionResult setZoom(double value) {
    if (value < 1 || value > 8) {
      return const CalibrationActionResult(
        ok: false,
        message: 'zoom must be between 1 and 8',
      );
    }
    _zoom = value;
    return CalibrationActionResult(
      ok: true,
      message: 'zoom $_zoom',
      phase: _phase,
    );
  }

  CalibrationActionResult selectCorner(String id) {
    if (!cornerOrder.contains(id)) {
      return CalibrationActionResult(
        ok: false,
        message: 'unknown corner $id',
      );
    }
    _selectedCorner = id;
    if (_phase == CalibrationPhase.frozen) {
      _phase = CalibrationPhase.corners;
    }
    return CalibrationActionResult(
      ok: true,
      message: 'selected corner $id',
      phase: _phase,
    );
  }

  /// AC-4.2 place/drag a labeled handle in freeze-frame pixel space.
  CalibrationActionResult setCornerPixel(String id, CalibPoint point) {
    if (_phase == CalibrationPhase.live) {
      return const CalibrationActionResult(
        ok: false,
        message: 'freeze a frame before marking corners',
      );
    }
    if (!cornerOrder.contains(id)) {
      return CalibrationActionResult(ok: false, message: 'unknown corner $id');
    }
    final current = _pixelCorners ??
        CornerSet(
          tl: CalibPoint(frameWidth * 0.2, frameHeight * 0.2),
          tr: CalibPoint(frameWidth * 0.8, frameHeight * 0.2),
          br: CalibPoint(frameWidth * 0.8, frameHeight * 0.8),
          bl: CalibPoint(frameWidth * 0.2, frameHeight * 0.8),
        );
    _pixelCorners = current.withCorner(id, point);
    _selectedCorner = id;
    _phase = CalibrationPhase.corners;
    _geometryAccepted = false;
    _homography = null;
    _lastValidation = validateCorners(
      _pixelCorners!,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
    return CalibrationActionResult(
      ok: true,
      message: 'corner $id at (${point.x.toStringAsFixed(1)}, ${point.y.toStringAsFixed(1)})',
      phase: _phase,
    );
  }

  CalibrationActionResult setAllCorners(CornerSet corners) {
    if (_phase == CalibrationPhase.live) {
      return const CalibrationActionResult(
        ok: false,
        message: 'freeze a frame before marking corners',
      );
    }
    _pixelCorners = corners;
    _phase = CalibrationPhase.corners;
    _geometryAccepted = false;
    _homography = null;
    _lastValidation = validateCorners(
      corners,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
    return CalibrationActionResult(
      ok: _lastValidation!.ok,
      message: _lastValidation!.ok
          ? 'corners set'
          : 'invalid corners: ${_lastValidation!.reasons.join(", ")}',
      phase: _phase,
    );
  }

  /// AC-4.3 + AC-4.4: validate, compute homography, show rectified pending confirm.
  CalibrationActionResult computeRectified() {
    final corners = _pixelCorners;
    if (corners == null) {
      return const CalibrationActionResult(
        ok: false,
        message: 'mark TL, TR, BR, BL before computing homography',
      );
    }
    final validation = validateCorners(
      corners,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
    );
    _lastValidation = validation;
    if (!validation.ok) {
      return CalibrationActionResult(
        ok: false,
        message: 'validation failed: ${validation.reasons.join(", ")}',
        phase: _phase,
      );
    }
    try {
      _homography = boardHomography(corners);
    } catch (error) {
      return CalibrationActionResult(
        ok: false,
        message: 'homography failed: $error',
        phase: _phase,
      );
    }
    _normalizedCorners = normalizeCorners(
      corners,
      width: frameWidth,
      height: frameHeight,
    );
    _phase = CalibrationPhase.rectifiedPending;
    _geometryAccepted = false;
    return CalibrationActionResult(
      ok: true,
      message: 'rectified preview ready; confirm or redo',
      phase: _phase,
    );
  }

  /// AC-4.4 confirm geometry.
  CalibrationActionResult confirmGeometry() {
    if (_phase != CalibrationPhase.rectifiedPending || _homography == null) {
      return const CalibrationActionResult(
        ok: false,
        message: 'compute and review rectified board before confirm',
      );
    }
    _geometryAccepted = true;
    _phase = CalibrationPhase.confirmed;
    return CalibrationActionResult(
      ok: true,
      message: 'geometry confirmed',
      phase: _phase,
    );
  }

  CalibrationActionResult redoCorners() {
    _geometryAccepted = false;
    _homography = null;
    _regions = const <BoardRegion>[];
    _phase = _pixelCorners == null ? CalibrationPhase.frozen : CalibrationPhase.corners;
    return CalibrationActionResult(
      ok: true,
      message: 'redo corners',
      phase: _phase,
    );
  }

  /// AC-4.5 define OCR regions after confirm; omit absent sport fields.
  CalibrationActionResult beginRegions({List<BoardRegion>? seed}) {
    if (!_geometryAccepted) {
      return const CalibrationActionResult(
        ok: false,
        message: 'confirm geometry before defining regions',
      );
    }
    _regions = seed ?? defaultRegionsForSport(sportId);
    final validation = validateRegions(_regions, sportId: sportId);
    if (!validation.ok) {
      return CalibrationActionResult(
        ok: false,
        message: 'region seed invalid: ${validation.reasons.join(", ")}',
      );
    }
    _phase = CalibrationPhase.regions;
    return CalibrationActionResult(
      ok: true,
      message: 'define regions for ${availableFields.join(", ")}',
      phase: _phase,
    );
  }

  CalibrationActionResult upsertRegion(BoardRegion region) {
    if (_phase != CalibrationPhase.regions &&
        _phase != CalibrationPhase.complete) {
      return const CalibrationActionResult(
        ok: false,
        message: 'enter region editor after geometry confirm',
      );
    }
    if (!availableFields.contains(region.fieldId)) {
      return CalibrationActionResult(
        ok: false,
        message: 'field ${region.fieldId} absent for $sportId (not faked)',
      );
    }
    final next = <BoardRegion>[
      for (final existing in _regions)
        if (existing.fieldId != region.fieldId) existing,
      region,
    ];
    final validation = validateRegions(next, sportId: sportId);
    if (!validation.ok) {
      return CalibrationActionResult(
        ok: false,
        message: validation.reasons.join(', '),
      );
    }
    _regions = next;
    _phase = CalibrationPhase.regions;
    return CalibrationActionResult(
      ok: true,
      message: 'region ${region.fieldId} updated',
      phase: _phase,
    );
  }

  CalibrationActionResult completeRegions() {
    if (!_geometryAccepted) {
      return const CalibrationActionResult(
        ok: false,
        message: 'geometry not confirmed',
      );
    }
    final validation = validateRegions(_regions, sportId: sportId);
    if (!validation.ok) {
      return CalibrationActionResult(
        ok: false,
        message: validation.reasons.join(', '),
      );
    }
    _phase = CalibrationPhase.complete;
    return CalibrationActionResult(
      ok: true,
      message: 'calibration complete with ${_regions.length} regions',
      phase: _phase,
    );
  }

  /// AC-4.6 re-bind calibration to a new preview size/rotation.
  CalibrationActionResult applyDisplayTransform({
    required double displayWidth,
    required double displayHeight,
    int rotationDegrees = 0,
  }) {
    final normalized = _normalizedCorners;
    if (normalized == null) {
      return const CalibrationActionResult(
        ok: false,
        message: 'no normalized calibration to reproject',
      );
    }
    final mapped = mapNormalizedCornersToDisplay(
      normalized,
      displayWidth: displayWidth,
      displayHeight: displayHeight,
      rotationDegrees: rotationDegrees,
    );
    frameWidth = displayWidth;
    frameHeight = displayHeight;
    _rotationDegrees = rotationDegrees;
    _pixelCorners = mapped;
    try {
      _homography = boardHomography(mapped);
    } catch (error) {
      return CalibrationActionResult(
        ok: false,
        message: 'reproject failed: $error',
      );
    }
    return CalibrationActionResult(
      ok: true,
      message:
          'calibration rebound to ${displayWidth.toInt()}x${displayHeight.toInt()} rot=$rotationDegrees',
      phase: _phase,
    );
  }

  /// Sample board point in unit board space via current homography.
  CalibPoint? mapFrameToBoard(CalibPoint framePoint) {
    final h = _homography;
    if (h == null) {
      return null;
    }
    return applyHomography(h, framePoint);
  }

  /// AC-4.7: camera move invalidates geometry; operator must recalibrate.
  CalibrationActionResult invalidateForCameraMove() {
    _geometryAccepted = false;
    _homography = null;
    _regions = const <BoardRegion>[];
    _phase = _pixelCorners == null
        ? (_freezeId == null ? CalibrationPhase.live : CalibrationPhase.frozen)
        : CalibrationPhase.corners;
    return CalibrationActionResult(
      ok: true,
      message: 'camera move invalidated calibration; recalibrate',
      phase: _phase,
    );
  }
}
