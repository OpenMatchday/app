import 'dart:convert';
import 'dart:io';

import 'content_hash.dart';

/// Immutable roster snapshot pinned to an event (AC-9.4).
///
/// Later registry cache updates must not mutate [registry] or [contentHash].
class EventRosterSnapshot {
  const EventRosterSnapshot({
    required this.eventId,
    required this.packageId,
    required this.packageVersion,
    required this.contentHash,
    required this.pinnedAt,
    required this.teamIds,
    required this.seasonIds,
    required this.registry,
  });

  final String eventId;
  final String packageId;
  final String packageVersion;
  final String contentHash;
  final DateTime pinnedAt;
  final List<String> teamIds;
  final List<String> seasonIds;

  /// Deep-copied registry subset used for live production.
  final Map<String, Object?> registry;

  Map<String, Object> toWire() => <String, Object>{
        'event_id': eventId,
        'package_id': packageId,
        'package_version': packageVersion,
        'content_hash': contentHash,
        'pinned_at': pinnedAt.toUtc().toIso8601String(),
        'team_ids': List<String>.from(teamIds),
        'season_ids': List<String>.from(seasonIds),
        'registry': jsonDecode(jsonEncode(registry)) as Object,
      };

  static EventRosterSnapshot fromWire(Map<String, Object?> wire) {
    final teamIdsRaw = wire['team_ids'];
    final seasonIdsRaw = wire['season_ids'];
    final registryRaw = wire['registry'];
    return EventRosterSnapshot(
      eventId: wire['event_id']?.toString() ?? '',
      packageId: wire['package_id']?.toString() ?? '',
      packageVersion: wire['package_version']?.toString() ?? '',
      contentHash: wire['content_hash']?.toString() ?? '',
      pinnedAt: DateTime.parse(
        wire['pinned_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      ),
      teamIds: teamIdsRaw is List
          ? teamIdsRaw.map((e) => e.toString()).toList()
          : <String>[],
      seasonIds: seasonIdsRaw is List
          ? seasonIdsRaw.map((e) => e.toString()).toList()
          : <String>[],
      registry: registryRaw is Map
          ? Map<String, Object?>.from(
              jsonDecode(jsonEncode(registryRaw)) as Map,
            )
          : <String, Object?>{},
    );
  }
}

/// Pins roster slices from a verified package directory into an event snapshot.
class EventRosterPinService {
  EventRosterPinService({DateTime Function()? now}) : now = now ?? DateTime.now;

  final DateTime Function() now;

  EventRosterSnapshot pinFromPackage({
    required String eventId,
    required Directory packageDir,
    required List<String> teamIds,
    required List<String> seasonIds,
  }) {
    final integrity = IntegrityManifest.load(packageDir);
    if (integrity == null) {
      throw StateError('package missing $kIntegrityFile');
    }
    final check = verifyPackageIntegrity(packageDir, integrity);
    if (!check.ok) {
      throw StateError('cannot pin unverified package: ${check.errors.join('; ')}');
    }

    final registryFile = File(
      '${packageDir.path}${Platform.pathSeparator}registry.json',
    );
    final decoded = jsonDecode(registryFile.readAsStringSync());
    if (decoded is! Map) {
      throw FormatException('registry.json is not an object');
    }
    final full = Map<String, Object?>.from(decoded);
    final subset = _sliceRegistry(
      full,
      teamIds: teamIds,
      seasonIds: seasonIds,
    );

    return EventRosterSnapshot(
      eventId: eventId,
      packageId: integrity.packageId,
      packageVersion: integrity.version,
      contentHash: integrity.contentHash,
      pinnedAt: now().toUtc(),
      teamIds: List<String>.from(teamIds),
      seasonIds: List<String>.from(seasonIds),
      registry: subset,
    );
  }
}

Map<String, Object?> _sliceRegistry(
  Map<String, Object?> full, {
  required List<String> teamIds,
  required List<String> seasonIds,
}) {
  final teamIdSet = teamIds.toSet();
  final seasonIdSet = seasonIds.toSet();

  List<Map<String, Object?>> asMaps(Object? raw) {
    if (raw is! List) {
      return <Map<String, Object?>>[];
    }
    return raw
        .whereType<Map>()
        .map((e) => Map<String, Object?>.from(e))
        .toList();
  }

  final teams = asMaps(full['teams'])
      .where((t) => teamIdSet.contains(t['id']?.toString()))
      .toList();
  final seasons = asMaps(full['seasons'])
      .where((s) => seasonIdSet.contains(s['id']?.toString()))
      .toList();
  final squads = asMaps(full['squads']).where((s) {
    final teamId = s['team_id']?.toString();
    final seasonId = s['season_id']?.toString();
    return teamIdSet.contains(teamId) && seasonIdSet.contains(seasonId);
  }).toList();
  final squadIds = squads.map((s) => s['id']?.toString()).whereType<String>().toSet();
  final memberships = asMaps(full['memberships'])
      .where((m) => squadIds.contains(m['squad_id']?.toString()))
      .toList();
  final playerIds = memberships
      .map((m) => m['player_id']?.toString())
      .whereType<String>()
      .toSet();
  final players = asMaps(full['players'])
      .where((p) => playerIds.contains(p['id']?.toString()))
      .toList();

  final clubIds = teams.map((t) => t['club_id']?.toString()).whereType<String>().toSet();
  final sportIds = teams.map((t) => t['sport_id']?.toString()).whereType<String>().toSet();
  final categoryIds =
      teams.map((t) => t['category_id']?.toString()).whereType<String>().toSet();
  final clubs = asMaps(full['clubs'])
      .where((c) => clubIds.contains(c['id']?.toString()))
      .toList();
  final sports = asMaps(full['sports'])
      .where((s) => sportIds.contains(s['id']?.toString()))
      .toList();
  final categories = asMaps(full['categories'])
      .where((c) => categoryIds.contains(c['id']?.toString()))
      .toList();
  final competitionIds =
      seasons.map((s) => s['competition_id']?.toString()).whereType<String>().toSet();
  final competitions = asMaps(full['competitions'])
      .where((c) => competitionIds.contains(c['id']?.toString()))
      .toList();
  final countryIds = <String>{
    ...clubs.map((c) => c['country_id']?.toString()).whereType<String>(),
    ...competitions.map((c) => c['country_id']?.toString()).whereType<String>(),
  };
  final countries = asMaps(full['countries'])
      .where((c) => countryIds.contains(c['id']?.toString()))
      .toList();

  // Deep copy via JSON so later mutations of [full] cannot affect the pin.
  final sliced = <String, Object?>{
    'schema_version': full['schema_version'],
    'sports': sports,
    'countries': countries,
    'competitions': competitions,
    'categories': categories,
    'clubs': clubs,
    'teams': teams,
    'seasons': seasons,
    'squads': squads,
    'players': players,
    'memberships': memberships,
  };
  return Map<String, Object?>.from(
    jsonDecode(jsonEncode(sliced)) as Map,
  );
}
