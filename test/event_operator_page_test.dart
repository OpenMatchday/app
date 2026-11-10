import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/event_operator/authority_store.dart';
import 'package:open_matchday/event_operator/event_operator_page.dart';
import 'package:open_matchday/event_operator/fields.dart';

void main() {
  testWidgets('shows broadcast-aid copy and manual clock authority',
      (tester) async {
    final store = AuthorityStore();
    await tester.pumpWidget(
      MaterialApp(
        home: EventOperatorPage(store: store),
      ),
    );

    expect(find.byKey(const Key('broadcast-aid-copy')), findsOneWidget);
    expect(find.text(AuthorityStore.broadcastAidCopy), findsOneWidget);
    expect(find.byKey(const Key('clock-authority')), findsOneWidget);
    expect(find.textContaining('Authority: manual'), findsWidgets);

    await tester.enterText(find.byKey(const Key('home-score-input')), '7');
    await tester.tap(find.byKey(const Key('home-score-set')));
    await tester.pump();
    expect(store.fieldState(ScoreField.homeScore).value, 7);

    await tester.ensureVisible(find.byKey(const Key('emit-snapshot')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('emit-snapshot')));
    await tester.pump();
    expect(find.textContaining('Snapshot'), findsOneWidget);
  });
}
