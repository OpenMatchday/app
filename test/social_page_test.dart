import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/social/social_page.dart';
import 'package:open_matchday/social/social_store.dart';

void main() {
  testWidgets('social page creates draft and exports offline', (tester) async {
    final store = SocialStore(clockIso: () => '2026-11-11T10:00:00.000Z');
    await tester.pumpWidget(
      MaterialApp(
        home: SocialPage(store: store),
      ),
    );

    expect(find.byKey(const Key('social-no-metrics')), findsOneWidget);
    expect(find.text('Engagement metrics: not displayed'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('social-slot-headline')),
      'Doors open',
    );
    await tester.enterText(
      find.byKey(const Key('social-slot-body')),
      'Come early',
    );
    await tester.ensureVisible(find.byKey(const Key('social-create-draft')));
    await tester.tap(find.byKey(const Key('social-create-draft')));
    await tester.pump();

    expect(store.drafts, hasLength(1));
    expect(find.textContaining('created offline'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('social-export-local')));
    await tester.tap(find.byKey(const Key('social-export-local')));
    await tester.pump();

    expect(store.lastExport, isNotNull);
    expect(store.lastExport!.account, isNull);
    await tester.ensureVisible(find.byKey(const Key('social-export-preview')));
    expect(find.byKey(const Key('social-export-preview')), findsOneWidget);
    expect(find.textContaining('account=null'), findsWidgets);
  });
}
