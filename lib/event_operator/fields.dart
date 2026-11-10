// Scoreboard / clock fields aligned with protocol command/event enums.

enum ScoreField {
  clock,
  shotClock,
  homeScore,
  awayScore,
  period,
  homeFouls,
  awayFouls,
}

extension ScoreFieldWire on ScoreField {
  String get wire => switch (this) {
        ScoreField.clock => 'clock',
        ScoreField.shotClock => 'shot_clock',
        ScoreField.homeScore => 'home_score',
        ScoreField.awayScore => 'away_score',
        ScoreField.period => 'period',
        ScoreField.homeFouls => 'home_fouls',
        ScoreField.awayFouls => 'away_fouls',
      };

  String get label => switch (this) {
        ScoreField.clock => 'Clock',
        ScoreField.shotClock => 'Shot clock',
        ScoreField.homeScore => 'Home score',
        ScoreField.awayScore => 'Away score',
        ScoreField.period => 'Period',
        ScoreField.homeFouls => 'Home fouls',
        ScoreField.awayFouls => 'Away fouls',
      };

  static ScoreField parse(String value) {
    switch (value) {
      case 'clock':
        return ScoreField.clock;
      case 'shot_clock':
        return ScoreField.shotClock;
      case 'home_score':
        return ScoreField.homeScore;
      case 'away_score':
        return ScoreField.awayScore;
      case 'period':
        return ScoreField.period;
      case 'home_fouls':
        return ScoreField.homeFouls;
      case 'away_fouls':
        return ScoreField.awayFouls;
      default:
        throw ArgumentError('unknown score field: $value');
    }
  }
}

enum FieldAuthority {
  manual,
  ocrAssisted,
}

extension FieldAuthorityWire on FieldAuthority {
  String get wire => switch (this) {
        FieldAuthority.manual => 'manual',
        FieldAuthority.ocrAssisted => 'ocr_assisted',
      };

  static FieldAuthority parse(String value) {
    switch (value) {
      case 'manual':
        return FieldAuthority.manual;
      case 'ocr_assisted':
        return FieldAuthority.ocrAssisted;
      default:
        throw ArgumentError('unknown authority: $value');
    }
  }
}

enum ConfirmAction {
  confirm,
  correct,
  lock,
}

extension ConfirmActionWire on ConfirmAction {
  String get wire => switch (this) {
        ConfirmAction.confirm => 'confirm',
        ConfirmAction.correct => 'correct',
        ConfirmAction.lock => 'lock',
      };
}

class FieldState {
  const FieldState({
    required this.field,
    required this.value,
    required this.authority,
    this.confirmed = false,
    this.locked = false,
  });

  final ScoreField field;
  final Object value;
  final FieldAuthority authority;
  final bool confirmed;
  final bool locked;

  FieldState copyWith({
    ScoreField? field,
    Object? value,
    FieldAuthority? authority,
    bool? confirmed,
    bool? locked,
  }) {
    return FieldState(
      field: field ?? this.field,
      value: value ?? this.value,
      authority: authority ?? this.authority,
      confirmed: confirmed ?? this.confirmed,
      locked: locked ?? this.locked,
    );
  }

  Map<String, Object> toWire() => <String, Object>{
        'field': field.wire,
        'value': value,
        'authority': authority.wire,
        'confirmed': confirmed,
        'locked': locked,
      };

  static FieldState fromWire(Map<String, Object?> wire) {
    final fieldName = wire['field']?.toString() ?? '';
    final authorityName = wire['authority']?.toString() ?? 'manual';
    final rawValue = wire['value'];
    final Object value;
    if (rawValue is num) {
      value = fieldName == 'clock' ? rawValue.toString() : rawValue.toInt();
    } else if (rawValue is String) {
      value = rawValue;
    } else if (fieldName == 'clock') {
      value = '00:00';
    } else {
      value = 0;
    }
    return FieldState(
      field: ScoreFieldWire.parse(fieldName),
      value: value,
      authority: FieldAuthorityWire.parse(authorityName),
      confirmed: wire['confirmed'] == true,
      locked: wire['locked'] == true,
    );
  }
}

/// Lineup authority plane slot (AC-5.6). Full lineups arrive in OM-029.
class LineupSideAuthority {
  const LineupSideAuthority({
    required this.side,
    required this.authority,
    this.confirmed = false,
    this.locked = false,
    this.revision = '',
  });

  final String side;
  final FieldAuthority authority;
  final bool confirmed;
  final bool locked;
  final String revision;

  LineupSideAuthority copyWith({
    String? side,
    FieldAuthority? authority,
    bool? confirmed,
    bool? locked,
    String? revision,
  }) {
    return LineupSideAuthority(
      side: side ?? this.side,
      authority: authority ?? this.authority,
      confirmed: confirmed ?? this.confirmed,
      locked: locked ?? this.locked,
      revision: revision ?? this.revision,
    );
  }

  Map<String, Object> toWire() => <String, Object>{
        'side': side,
        'authority': authority.wire,
        'confirmed': confirmed,
        'locked': locked,
        'revision': revision,
      };

  static LineupSideAuthority fromWire(Map<String, Object?> wire) {
    return LineupSideAuthority(
      side: wire['side']?.toString() ?? '',
      authority: FieldAuthorityWire.parse(
        wire['authority']?.toString() ?? 'manual',
      ),
      confirmed: wire['confirmed'] == true,
      locked: wire['locked'] == true,
      revision: wire['revision']?.toString() ?? '',
    );
  }
}
