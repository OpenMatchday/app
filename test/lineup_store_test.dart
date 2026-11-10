import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/lineups/lineup_models.dart';
import 'package:open_matchday/lineups/lineup_store.dart';

void main() {
  LineupDraft sample({String team = 'Foxes', String revision = 'rev-a'}) {
    return LineupDraft(
      side: 'home',
      teamName: team,
      sportId: 'basketball',
      formationId: 'starting_five',
      revision: revision,
      starters: const <LineupPlayer>[
        LineupPlayer(
          playerId: 'alex_rivera',
          name: 'Alex Rivera',
          number: 7,
          positionId: 'point_guard',
          isCaptain: true,
        ),
      ],
      substitutes: const <LineupPlayer>[
        LineupPlayer(
          playerId: 'harper_quinn',
          name: 'Harper Quinn',
          number: 8,
          positionId: 'point_guard',
          isSubstitute: true,
        ),
      ],
    );
  }

  test('AC-7.6 refuses Program without preview', () {
    final store = LineupStore(initialDraft: sample(), clockMs: () => 1);
    final refused = store.takeToProgram();
    expect(refused.ok, isFalse);
    expect(refused.message, contains('preview required'));
    expect(store.airState, LineupAirState.draft);
  });

  test('AC-7.6 allows Program after matching preview', () {
    final store = LineupStore(initialDraft: sample(), clockMs: () => 1);
    expect(store.markPreviewed().ok, isTrue);
    final taken = store.takeToProgram();
    expect(taken.ok, isTrue);
    expect(store.airState, LineupAirState.onProgram);
    expect(store.programRevision, store.draft.revision);
  });

  test('editing draft invalidates preview', () {
    var tick = 10;
    final store = LineupStore(
      initialDraft: sample(),
      clockMs: () => tick++,
    );
    store.markPreviewed();
    expect(store.canTakeToProgram, isTrue);
    store.updateDraft(sample(team: 'Foxes Edited'));
    expect(store.canTakeToProgram, isFalse);
    expect(store.airState, LineupAirState.draft);
    final refused = store.takeToProgram();
    expect(refused.ok, isFalse);
  });

  test('starters and substitutes remain distinguishable in draft', () {
    final draft = sample();
    expect(draft.starters.first.isSubstitute, isFalse);
    expect(draft.substitutes.first.isSubstitute, isTrue);
    expect(draft.starters.first.isCaptain, isTrue);
  });

  test('reduced motion flag defaults on', () {
    final store = LineupStore(initialDraft: sample());
    expect(store.reducedMotion, isTrue);
    store.setReducedMotion(false);
    expect(store.reducedMotion, isFalse);
  });
}
