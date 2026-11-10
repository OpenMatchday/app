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
}
