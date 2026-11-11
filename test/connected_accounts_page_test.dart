import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/social/connected_accounts_page.dart';
import 'package:open_matchday/social/connected_accounts_store.dart';

void main() {
  testWidgets('connected accounts shows provider capabilities status revoke',
      (tester) async {
    final store = ConnectedAccountsStore();
    final seeded = store.connect(
      providerId: 'youtube',
      accountLabel: 'Harbor Fiction Club',
      opaqueTokenRef: 'yt-ref-1',
    );
    expect(seeded.ok, isTrue);
    final connectionId = seeded.account!.connectionId;

    await tester.pumpWidget(
      MaterialApp(
        home: ConnectedAccountsPage(store: store),
      ),
    );

    expect(find.byKey(const Key('connected-planes')), findsOneWidget);
    expect(find.textContaining('social_connections'), findsWidgets);
    expect(find.byKey(Key('connected-row-$connectionId')), findsOneWidget);
    expect(
      find.byKey(Key('connected-provider-$connectionId')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('connected-capabilities-$connectionId')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('connected-status-$connectionId')),
      findsOneWidget,
    );
    expect(find.textContaining('connected_runtime_disabled'), findsOneWidget);

    await tester.tap(find.byKey(Key('connected-revoke-$connectionId')));
    await tester.pumpAndSettle();

    expect(store.connections, isEmpty);
    expect(find.byKey(const Key('connected-empty')), findsOneWidget);
    expect(
      find.byKey(const Key('connected-status-message')),
      findsOneWidget,
    );
  });
}
