import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/teams_registry/content_hash.dart';
import 'package:open_matchday/teams_registry/event_roster_pin.dart';
import 'package:open_matchday/teams_registry/offline_registry_cache.dart';

Directory _writePackage({
  required Directory dir,
  required String packageId,
  required String version,
  required Map<String, Object?> registry,
  String readme = 'fiction\n',
}) {
  dir.createSync(recursive: true);
  Directory('${dir.path}${Platform.pathSeparator}docs').createSync();
  File('${dir.path}${Platform.pathSeparator}manifest.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'schema_version': '0.1.0',
      'package_id': packageId,
      'version': version,
      'display_name': packageId,
      'description': 'test package',
      'fiction': true,
    }),
  );
  File('${dir.path}${Platform.pathSeparator}registry.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(registry),
  );
  File('${dir.path}${Platform.pathSeparator}docs${Platform.pathSeparator}README.md')
      .writeAsStringSync(readme);

  final computed = computePackageIntegrity(dir);
  File('${dir.path}${Platform.pathSeparator}integrity.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(computed.toWire()),
  );
  return dir;
}

Map<String, Object?> _sampleRegistry({
  String playerName = 'Ada Fiction',
}) =>
    <String, Object?>{
      'schema_version': '0.1.0',
      'sports': [
        <String, Object?>{'id': 'basketball', 'name': 'Basketball'},
      ],
      'countries': [
        <String, Object?>{
          'id': 'it',
          'name': 'Italy',
          'iso3166_1_alpha2': 'IT',
        },
      ],
      'competitions': [
        <String, Object?>{
          'id': 'harbor_open',
          'name': 'Harbor Open',
          'sport_id': 'basketball',
          'country_id': 'it',
        },
      ],
      'categories': [
        <String, Object?>{
          'id': 'senior',
          'name': 'Senior',
          'sport_id': 'basketball',
          'age_band': 'senior',
        },
      ],
      'clubs': [
        <String, Object?>{
          'id': 'north_harbor_club',
          'name': 'North Harbor',
          'country_id': 'it',
        },
      ],
      'teams': [
        <String, Object?>{
          'id': 'north_harbor_foxes',
          'name': 'Foxes',
          'club_id': 'north_harbor_club',
          'sport_id': 'basketball',
          'category_id': 'senior',
        },
      ],
      'seasons': [
        <String, Object?>{
          'id': 'harbor_2026',
          'name': '2026',
          'competition_id': 'harbor_open',
        },
      ],
      'squads': [
        <String, Object?>{
          'id': 'foxes_2026',
          'team_id': 'north_harbor_foxes',
          'season_id': 'harbor_2026',
        },
      ],
      'players': [
        <String, Object?>{
          'id': 'ada_fiction',
          'name': playerName,
          'is_minor': false,
        },
      ],
      'memberships': [
        <String, Object?>{
          'id': 'foxes_ada',
          'squad_id': 'foxes_2026',
          'player_id': 'ada_fiction',
          'number': 7,
          'position': 'G',
        },
      ],
    };

void main() {
  test('sha256 helper matches package:crypto', () {
    expect(
      sha256HexBytes(utf8.encode('open-matchday')),
      sha256.convert(utf8.encode('open-matchday')).toString(),
    );
  });

  test('integrity check rejects tampered package', () {
    final dir = Directory.systemTemp.createTempSync('om-integrity-');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    _writePackage(
      dir: dir,
      packageId: 'tamper_pkg',
      version: '0.1.0',
      registry: _sampleRegistry(),
    );
    final manifest = IntegrityManifest.load(dir)!;
    expect(verifyPackageIntegrity(dir, manifest).ok, isTrue);

    File('${dir.path}${Platform.pathSeparator}docs${Platform.pathSeparator}README.md')
        .writeAsStringSync('tampered\n');
    final bad = verifyPackageIntegrity(dir, manifest);
    expect(bad.ok, isFalse);
    expect(bad.errors, isNotEmpty);
  });

  test('offline cache installs verified package and keeps last-good on failure',
      () {
    final root = Directory.systemTemp.createTempSync('om-cache-');
    final goodA = Directory.systemTemp.createTempSync('om-pkg-a-');
    final goodB = Directory.systemTemp.createTempSync('om-pkg-b-');
    final bad = Directory.systemTemp.createTempSync('om-pkg-bad-');
    addTearDown(() {
      for (final d in <Directory>[root, goodA, goodB, bad]) {
        if (d.existsSync()) {
          d.deleteSync(recursive: true);
        }
      }
    });

    _writePackage(
      dir: goodA,
      packageId: 'harbor_fiction',
      version: '0.1.0',
      registry: _sampleRegistry(playerName: 'Ada Fiction'),
    );
    _writePackage(
      dir: goodB,
      packageId: 'harbor_fiction',
      version: '0.1.1',
      registry: _sampleRegistry(playerName: 'Bea Fiction'),
    );
    _writePackage(
      dir: bad,
      packageId: 'harbor_fiction',
      version: '0.1.2',
      registry: _sampleRegistry(playerName: 'Bad Fiction'),
    );
    // Break integrity after writing manifest.
    File('${bad.path}${Platform.pathSeparator}docs${Platform.pathSeparator}README.md')
        .writeAsStringSync('broken after hash\n');

    final cache = OfflineRegistryCache(root: root);
    final first = cache.installCandidate(goodA);
    expect(first.installed, isTrue);
    expect(cache.hasCurrent, isTrue);

    final second = cache.installCandidate(goodB);
    expect(second.installed, isTrue);
    expect(cache.hasLastGood, isTrue);

    final playersBefore = jsonDecode(
      File('${cache.currentDir.path}${Platform.pathSeparator}registry.json')
          .readAsStringSync(),
    ) as Map;
    final nameBefore =
        ((playersBefore['players'] as List).first as Map)['name'];

    final failed = cache.installCandidate(bad);
    expect(failed.installed, isFalse);
    expect(failed.keptLastGood, isTrue);
    expect(failed.errors, isNotEmpty);

    final playersAfter = jsonDecode(
      File('${cache.currentDir.path}${Platform.pathSeparator}registry.json')
          .readAsStringSync(),
    ) as Map;
    final nameAfter =
        ((playersAfter['players'] as List).first as Map)['name'];
    expect(nameAfter, nameBefore);
    expect(nameAfter, 'Bea Fiction');
  });

  test('event pin freezes roster against later registry edits', () {
    final pkg = Directory.systemTemp.createTempSync('om-pin-pkg-');
    final root = Directory.systemTemp.createTempSync('om-pin-cache-');
    addTearDown(() {
      for (final d in <Directory>[pkg, root]) {
        if (d.existsSync()) {
          d.deleteSync(recursive: true);
        }
      }
    });

    _writePackage(
      dir: pkg,
      packageId: 'harbor_fiction',
      version: '0.1.0',
      registry: _sampleRegistry(playerName: 'Ada Fiction'),
    );

    final cache = OfflineRegistryCache(root: root);
    expect(cache.installCandidate(pkg).installed, isTrue);

    final pin = EventRosterPinService(
      now: () => DateTime.utc(2026, 11, 10, 18),
    ).pinFromPackage(
      eventId: 'event-1',
      packageDir: cache.activePackageDir!,
      teamIds: const <String>['north_harbor_foxes'],
      seasonIds: const <String>['harbor_2026'],
    );

    expect(pin.packageId, 'harbor_fiction');
    expect(pin.contentHash, isNotEmpty);
    final pinnedName =
        ((pin.registry['players'] as List).first as Map)['name'];
    expect(pinnedName, 'Ada Fiction');

    // Mutate active cache registry after pin (simulates later registry edit).
    final registryPath = File(
      '${cache.currentDir.path}${Platform.pathSeparator}registry.json',
    );
    final mutated = _sampleRegistry(playerName: 'Changed After Pin');
    registryPath.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(mutated),
    );
    // Re-hash so cache could theoretically reinstall; pin must stay frozen.
    final recomputed = computePackageIntegrity(cache.currentDir);
    File('${cache.currentDir.path}${Platform.pathSeparator}integrity.json')
        .writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(recomputed.toWire()),
    );

    final stillPinned =
        ((pin.registry['players'] as List).first as Map)['name'];
    expect(stillPinned, 'Ada Fiction');

    final wire = EventRosterSnapshot.fromWire(
      Map<String, Object?>.from(pin.toWire()),
    );
    expect(wire.contentHash, pin.contentHash);
    expect(
      ((wire.registry['players'] as List).first as Map)['name'],
      'Ada Fiction',
    );
  });
}
