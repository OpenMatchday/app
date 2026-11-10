/// OCR region catalogs for calibrated boards (OM-030 / AC-4.5).
library;

class BoardRegion {
  const BoardRegion({
    required this.fieldId,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String fieldId;
  final double x;
  final double y;
  final double w;
  final double h;

  BoardRegion copyWith({
    String? fieldId,
    double? x,
    double? y,
    double? w,
    double? h,
  }) {
    return BoardRegion(
      fieldId: fieldId ?? this.fieldId,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'field_id': fieldId,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };

  static BoardRegion fromJson(Map<String, Object?> json) {
    return BoardRegion(
      fieldId: json['field_id']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      w: (json['w'] as num?)?.toDouble() ?? 0,
      h: (json['h'] as num?)?.toDouble() ?? 0,
    );
  }
}

const List<String> basketballFields = <String>[
  'clock',
  'shot_clock',
  'home_score',
  'away_score',
  'period',
  'home_fouls',
  'away_fouls',
];

const List<String> basketballYouthFields = <String>[
  'clock',
  'home_score',
  'away_score',
  'period',
  'home_fouls',
  'away_fouls',
];

const List<String> futsalFields = <String>[
  'clock',
  'home_score',
  'away_score',
  'period',
  'home_fouls',
  'away_fouls',
];

List<String> fieldsForSport(String sportId) {
  final key = sportId.trim().toLowerCase();
  switch (key) {
    case 'basketball':
    case 'basketball/fiba':
    case 'basketball/nba':
    case 'basketball/ncaa':
      return basketballFields;
    case 'basketball/youth':
      return basketballYouthFields;
    case 'futsal':
    case 'futsal/fifa':
    case 'futsal/youth':
      return futsalFields;
    default:
      if (key.startsWith('basketball/')) {
        return basketballFields;
      }
      if (key.startsWith('futsal/')) {
        return futsalFields;
      }
      throw ArgumentError('unknown_sport: $sportId');
  }
}

class RegionValidation {
  const RegionValidation({required this.ok, required this.reasons});

  final bool ok;
  final List<String> reasons;
}

RegionValidation validateRegions(
  Iterable<BoardRegion> regions, {
  required String sportId,
}) {
  final allowed = fieldsForSport(sportId).toSet();
  final reasons = <String>[];
  final seen = <String>{};
  for (final region in regions) {
    if (!allowed.contains(region.fieldId)) {
      reasons.add('field_not_in_sport:${region.fieldId}');
    }
    if (seen.contains(region.fieldId)) {
      reasons.add('duplicate_field:${region.fieldId}');
    }
    seen.add(region.fieldId);
    if (region.w <= 0 || region.h <= 0) {
      reasons.add('non_positive_size:${region.fieldId}');
    }
    if (region.x < 0 ||
        region.y < 0 ||
        region.x + region.w > 1.0 + 1e-9 ||
        region.y + region.h > 1.0 + 1e-9) {
      reasons.add('region_out_of_board:${region.fieldId}');
    }
  }
  return RegionValidation(ok: reasons.isEmpty, reasons: reasons);
}

List<BoardRegion> defaultRegionsForSport(String sportId) {
  const layouts = <String, List<double>>{
    'home_score': <double>[0.05, 0.15, 0.18, 0.25],
    'away_score': <double>[0.77, 0.15, 0.18, 0.25],
    'clock': <double>[0.35, 0.10, 0.30, 0.18],
    'shot_clock': <double>[0.40, 0.35, 0.20, 0.15],
    'period': <double>[0.45, 0.55, 0.10, 0.12],
    'home_fouls': <double>[0.05, 0.70, 0.18, 0.15],
    'away_fouls': <double>[0.77, 0.70, 0.18, 0.15],
  };
  return <BoardRegion>[
    for (final fieldId in fieldsForSport(sportId))
      if (layouts.containsKey(fieldId))
        BoardRegion(
          fieldId: fieldId,
          x: layouts[fieldId]![0],
          y: layouts[fieldId]![1],
          w: layouts[fieldId]![2],
          h: layouts[fieldId]![3],
        ),
  ];
}
