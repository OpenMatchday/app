/// Four-corner calibration geometry (OM-030 / AC-4.1–4.6).
///
/// Homography matches OpenCV getPerspectiveTransform (4-point, h33=1):
/// https://docs.opencv.org/4.11.0/da/d54/group__imgproc__transform.html
library;

import 'dart:math' as math;

const List<String> cornerOrder = <String>['tl', 'tr', 'br', 'bl'];
const double defaultMinAreaFraction = 0.01;
const double defaultMinEdgeFraction = 0.02;

class CalibPoint {
  const CalibPoint(this.x, this.y);

  final double x;
  final double y;

  Map<String, double> toJson() => <String, double>{'x': x, 'y': y};

  static CalibPoint fromJson(Map<String, Object?> json) {
    return CalibPoint(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }
}

class CornerSet {
  const CornerSet({
    required this.tl,
    required this.tr,
    required this.br,
    required this.bl,
  });

  final CalibPoint tl;
  final CalibPoint tr;
  final CalibPoint br;
  final CalibPoint bl;

  List<CalibPoint> ordered() => <CalibPoint>[tl, tr, br, bl];

  CornerSet copyWith({
    CalibPoint? tl,
    CalibPoint? tr,
    CalibPoint? br,
    CalibPoint? bl,
  }) {
    return CornerSet(
      tl: tl ?? this.tl,
      tr: tr ?? this.tr,
      br: br ?? this.br,
      bl: bl ?? this.bl,
    );
  }

  CornerSet withCorner(String id, CalibPoint point) {
    return switch (id) {
      'tl' => copyWith(tl: point),
      'tr' => copyWith(tr: point),
      'br' => copyWith(br: point),
      'bl' => copyWith(bl: point),
      _ => throw ArgumentError('unknown corner: $id'),
    };
  }

  Map<String, Object> toJson() => <String, Object>{
        'tl': tl.toJson(),
        'tr': tr.toJson(),
        'br': br.toJson(),
        'bl': bl.toJson(),
      };

  static CornerSet fromJson(Map<String, Object?> json) {
    Map<String, Object?> asMap(Object? raw) =>
        Map<String, Object?>.from(raw as Map);
    return CornerSet(
      tl: CalibPoint.fromJson(asMap(json['tl'])),
      tr: CalibPoint.fromJson(asMap(json['tr'])),
      br: CalibPoint.fromJson(asMap(json['br'])),
      bl: CalibPoint.fromJson(asMap(json['bl'])),
    );
  }
}

class CornerValidation {
  const CornerValidation({
    required this.ok,
    required this.reasons,
    required this.area,
    required this.winding,
  });

  final bool ok;
  final List<String> reasons;
  final double area;
  final String winding;
}

double _cross(CalibPoint a, CalibPoint b, CalibPoint c) {
  return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
}

double polygonArea(List<CalibPoint> points) {
  if (points.length < 3) {
    return 0;
  }
  var total = 0.0;
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    final q = points[(i + 1) % points.length];
    total += p.x * q.y - q.x * p.y;
  }
  return total.abs() * 0.5;
}

int windingSign(List<CalibPoint> points) {
  var total = 0.0;
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    final q = points[(i + 1) % points.length];
    total += p.x * q.y - q.x * p.y;
  }
  if (total.abs() < 1e-12) {
    return 0;
  }
  return total > 0 ? 1 : -1;
}

bool isConvex(List<CalibPoint> points) {
  if (points.length != 4) {
    return false;
  }
  final signs = <int>[];
  for (var i = 0; i < 4; i++) {
    final cr = _cross(points[i], points[(i + 1) % 4], points[(i + 2) % 4]);
    if (cr.abs() < 1e-12) {
      return false;
    }
    signs.add(cr > 0 ? 1 : -1);
  }
  return signs.every((s) => s == signs.first);
}

CornerValidation validateCorners(
  CornerSet corners, {
  required double frameWidth,
  required double frameHeight,
  double minAreaFraction = defaultMinAreaFraction,
  double minEdgeFraction = defaultMinEdgeFraction,
}) {
  final reasons = <String>[];
  final pts = corners.ordered();
  if (frameWidth <= 0 || frameHeight <= 0) {
    reasons.add('frame_size_invalid');
  }
  for (var i = 0; i < cornerOrder.length; i++) {
    final p = pts[i];
    if (p.x < 0 || p.y < 0 || p.x > frameWidth || p.y > frameHeight) {
      reasons.add('${cornerOrder[i]}_out_of_frame');
    }
  }
  final unique = <String>{
    for (final p in pts) '${p.x.toStringAsFixed(6)}:${p.y.toStringAsFixed(6)}',
  };
  if (unique.length < 4) {
    reasons.add('duplicate_corners');
  }
  if (!isConvex(pts)) {
    reasons.add('not_convex_or_crossed');
  }
  final wind = windingSign(pts);
  // Image y-down: TL→TR→BR→BL yields positive shoelace (math CCW).
  if (wind != 1) {
    reasons.add('corner_order_not_tl_tr_br_bl');
  }
  final area = polygonArea(pts);
  final frameArea = (frameWidth * frameHeight).clamp(1e-12, double.infinity);
  if (area < minAreaFraction * frameArea) {
    reasons.add('area_below_minimum');
  }
  final minEdge = minEdgeFraction *
      (frameWidth < frameHeight ? frameWidth : frameHeight);
  for (var i = 0; i < 4; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % 4];
    final edge = math.sqrt(
      (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y),
    );
    if (edge < minEdge) {
      reasons.add('edge_too_short');
      break;
    }
  }
  final windingLabel = switch (wind) {
    1 => 'ccw',
    -1 => 'cw',
    _ => 'degenerate',
  };
  return CornerValidation(
    ok: reasons.isEmpty,
    reasons: reasons,
    area: area,
    winding: windingLabel,
  );
}

List<double> _solveLinear(List<List<double>> a, List<double> b) {
  final n = b.length;
  final m = <List<double>>[
    for (var i = 0; i < n; i++) <double>[...a[i], b[i]],
  ];
  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var r = col + 1; r < n; r++) {
      if (m[r][col].abs() > m[pivot][col].abs()) {
        pivot = r;
      }
    }
    if (m[pivot][col].abs() < 1e-12) {
      throw StateError('singular_homography');
    }
    if (pivot != col) {
      final tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;
    }
    final div = m[col][col];
    for (var j = col; j <= n; j++) {
      m[col][j] /= div;
    }
    for (var row = 0; row < n; row++) {
      if (row == col) {
        continue;
      }
      final factor = m[row][col];
      for (var j = col; j <= n; j++) {
        m[row][j] -= factor * m[col][j];
      }
    }
  }
  return <double>[for (var i = 0; i < n; i++) m[i][n]];
}

/// 3x3 row-major perspective matrix mapping [src] -> [dst] (h33 = 1).
List<List<double>> computeHomography(
  List<CalibPoint> src,
  List<CalibPoint> dst,
) {
  if (src.length != 4 || dst.length != 4) {
    throw ArgumentError('exactly_four_point_pairs_required');
  }
  final a = <List<double>>[];
  final b = <double>[];
  for (var i = 0; i < 4; i++) {
    final x = src[i].x;
    final y = src[i].y;
    final u = dst[i].x;
    final v = dst[i].y;
    a.add(<double>[x, y, 1, 0, 0, 0, -x * u, -y * u]);
    b.add(u);
    a.add(<double>[0, 0, 0, x, y, 1, -x * v, -y * v]);
    b.add(v);
  }
  final c = _solveLinear(a, b);
  return <List<double>>[
    <double>[c[0], c[1], c[2]],
    <double>[c[3], c[4], c[5]],
    <double>[c[6], c[7], 1],
  ];
}

List<CalibPoint> unitBoardDst({double width = 1, double height = 1}) {
  return <CalibPoint>[
    CalibPoint(0, 0),
    CalibPoint(width, 0),
    CalibPoint(width, height),
    CalibPoint(0, height),
  ];
}

List<List<double>> boardHomography(
  CornerSet corners, {
  double boardW = 1,
  double boardH = 1,
}) {
  return computeHomography(corners.ordered(), unitBoardDst(width: boardW, height: boardH));
}

CalibPoint applyHomography(List<List<double>> h, CalibPoint p) {
  final x = h[0][0] * p.x + h[0][1] * p.y + h[0][2];
  final y = h[1][0] * p.x + h[1][1] * p.y + h[1][2];
  final w = h[2][0] * p.x + h[2][1] * p.y + h[2][2];
  if (w.abs() < 1e-12) {
    throw StateError('homography_w_zero');
  }
  return CalibPoint(x / w, y / w);
}

CornerSet normalizeCorners(
  CornerSet corners, {
  required double width,
  required double height,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('frame_size_invalid');
  }
  CalibPoint n(CalibPoint p) => CalibPoint(p.x / width, p.y / height);
  return CornerSet(tl: n(corners.tl), tr: n(corners.tr), br: n(corners.br), bl: n(corners.bl));
}

CornerSet denormalizeCorners(
  CornerSet corners, {
  required double width,
  required double height,
}) {
  CalibPoint d(CalibPoint p) => CalibPoint(p.x * width, p.y * height);
  return CornerSet(tl: d(corners.tl), tr: d(corners.tr), br: d(corners.br), bl: d(corners.bl));
}

CalibPoint rotateNormalized(CalibPoint p, int degrees) {
  final d = degrees % 360;
  return switch (d) {
    0 => p,
    90 => CalibPoint(1 - p.y, p.x),
    180 => CalibPoint(1 - p.x, 1 - p.y),
    270 => CalibPoint(p.y, 1 - p.x),
    _ => throw ArgumentError('rotation_must_be_multiple_of_90'),
  };
}

/// AC-4.6: map freeze-normalized corners into current display pixels.
CornerSet mapNormalizedCornersToDisplay(
  CornerSet normalized, {
  required double displayWidth,
  required double displayHeight,
  int rotationDegrees = 0,
}) {
  final rotated = CornerSet(
    tl: rotateNormalized(normalized.tl, rotationDegrees),
    tr: rotateNormalized(normalized.tr, rotationDegrees),
    br: rotateNormalized(normalized.br, rotationDegrees),
    bl: rotateNormalized(normalized.bl, rotationDegrees),
  );
  return denormalizeCorners(
    rotated,
    width: displayWidth,
    height: displayHeight,
  );
}
