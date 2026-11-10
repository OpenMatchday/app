/// Player placement on a lineup graphic (AC-7.*).
class LineupPlayer {
  const LineupPlayer({
    required this.playerId,
    required this.name,
    required this.number,
    required this.positionId,
    this.positionLabel = '',
    this.photoHref,
    this.focalX = 0.5,
    this.focalY = 0.5,
    this.isCaptain = false,
    this.markers = const <String>[],
    this.isSubstitute = false,
  });

  final String playerId;
  final String name;
  final int number;
  final String positionId;
  final String positionLabel;
  final String? photoHref;
  final double focalX;
  final double focalY;
  final bool isCaptain;
  final List<String> markers;
  final bool isSubstitute;

  Map<String, Object?> toWire() => <String, Object?>{
        'player_id': playerId,
        'name': name,
        'number': number,
        'position_id': positionId,
        'position_label': positionLabel,
        'photo_href': photoHref,
        'focal_x': focalX,
        'focal_y': focalY,
        'is_captain': isCaptain,
        'markers': List<String>.from(markers),
        'is_substitute': isSubstitute,
      };

  static LineupPlayer fromWire(Map<String, Object?> wire) {
    final markersRaw = wire['markers'];
    return LineupPlayer(
      playerId: wire['player_id']?.toString() ?? '',
      name: wire['name']?.toString() ?? '',
      number: wire['number'] is int
          ? wire['number'] as int
          : int.tryParse('${wire['number']}') ?? 0,
      positionId: wire['position_id']?.toString() ?? '',
      positionLabel: wire['position_label']?.toString() ?? '',
      photoHref: wire['photo_href']?.toString(),
      focalX: (wire['focal_x'] as num?)?.toDouble() ?? 0.5,
      focalY: (wire['focal_y'] as num?)?.toDouble() ?? 0.5,
      isCaptain: wire['is_captain'] == true,
      markers: markersRaw is List
          ? markersRaw.map((e) => e.toString()).toList()
          : const <String>[],
      isSubstitute: wire['is_substitute'] == true,
    );
  }
}

/// Draft lineup graphic awaiting preview before Program (AC-7.6).
class LineupDraft {
  const LineupDraft({
    required this.side,
    required this.teamName,
    required this.sportId,
    required this.formationId,
    required this.starters,
    required this.substitutes,
    required this.revision,
  });

  final String side;
  final String teamName;
  final String sportId;
  final String formationId;
  final List<LineupPlayer> starters;
  final List<LineupPlayer> substitutes;
  final String revision;

  LineupDraft copyWith({
    String? side,
    String? teamName,
    String? sportId,
    String? formationId,
    List<LineupPlayer>? starters,
    List<LineupPlayer>? substitutes,
    String? revision,
  }) {
    return LineupDraft(
      side: side ?? this.side,
      teamName: teamName ?? this.teamName,
      sportId: sportId ?? this.sportId,
      formationId: formationId ?? this.formationId,
      starters: starters ?? this.starters,
      substitutes: substitutes ?? this.substitutes,
      revision: revision ?? this.revision,
    );
  }

  Map<String, Object> toWire() => <String, Object>{
        'side': side,
        'team_name': teamName,
        'sport_id': sportId,
        'formation_id': formationId,
        'starters': starters.map((p) => p.toWire()).toList(),
        'substitutes': substitutes.map((p) => p.toWire()).toList(),
        'revision': revision,
      };

  static LineupDraft fromWire(Map<String, Object?> wire) {
    List<LineupPlayer> parsePlayers(Object? raw) {
      if (raw is! List) {
        return <LineupPlayer>[];
      }
      return raw
          .whereType<Map>()
          .map(
            (item) => LineupPlayer.fromWire(Map<String, Object?>.from(item)),
          )
          .toList();
    }

    return LineupDraft(
      side: wire['side']?.toString() ?? '',
      teamName: wire['team_name']?.toString() ?? '',
      sportId: wire['sport_id']?.toString() ?? '',
      formationId: wire['formation_id']?.toString() ?? '',
      starters: parsePlayers(wire['starters']),
      substitutes: parsePlayers(wire['substitutes']),
      revision: wire['revision']?.toString() ?? '',
    );
  }
}

enum LineupAirState {
  draft,
  previewed,
  onProgram,
}

extension LineupAirStateWire on LineupAirState {
  String get wire {
    switch (this) {
      case LineupAirState.draft:
        return 'draft';
      case LineupAirState.previewed:
        return 'previewed';
      case LineupAirState.onProgram:
        return 'on_program';
    }
  }

  static LineupAirState parse(String raw) {
    switch (raw) {
      case 'previewed':
        return LineupAirState.previewed;
      case 'on_program':
        return LineupAirState.onProgram;
      case 'draft':
      default:
        return LineupAirState.draft;
    }
  }
}
