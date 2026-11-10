import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/lineups/lineup_models.dart';
import 'package:open_matchday/lineups/lineup_page.dart';
import 'package:open_matchday/lineups/lineup_store.dart';

void main() {
  testWidgets('preview gate blocks then allows Program', (tester) async {
    final store = LineupStore(
      clockMs: () => 42,
      initialDraft: const LineupDraft(
        side: 'home',
        teamName: 'North Harbor Foxes',
        sportId: 'basketball',
        formationId: 'starting_five',
        revision: 'rev-demo',
        starters: <LineupPlayer>[
          LineupPlayer(
            playerId: 'alex_rivera',
            name: 'Alex Rivera',
            number: 7,
            positionId: 'point_guard',
            positionLabel: 'Point Guard',
            isCaptain: true,
          ),
        ],
        substitutes: <LineupPlayer>[
          LineupPlayer(
            playerId: 'harper_quinn',
            name: 'Harper Quinn',
            number: 8,
            positionId: 'point_guard',
            isSubstitute: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LineupPage(store: store),
      ),
    );

    expect(find.textContaining('Alex Rivera'), findsOneWidget);
    expect(find.textContaining('Substitute'), findsWidgets);
    expect(find.textContaining('captain'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lineup-take-program')));
    await tester.pump();
    expect(find.textContaining('preview required'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lineup-preview')));
    await tester.pump();
    expect(find.textContaining('preview confirmed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lineup-take-program')));
    await tester.pump();
    expect(find.textContaining('on Program'), findsOneWidget);
    expect(find.textContaining('on_program'), findsOneWidget);
  });
}
