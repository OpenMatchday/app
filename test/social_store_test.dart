import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/social/social_models.dart';
import 'package:open_matchday/social/social_store.dart';

void main() {
  test('AC-11.3 ships five social template kinds', () {
    final store = SocialStore();
    expect(
      store.templates.map((t) => t.kind).toList()..sort(),
      equals(List<String>.from(socialTemplateKinds)..sort()),
    );
  });

  test('AC-11.4 drafts and export work without account', () {
    final store = SocialStore(clockIso: () => '2026-11-11T09:00:00.000Z');
    final created = store.createDraft(
      kind: 'announcement',
      bindings: <String, String>{
        'headline': 'Tip-off at 19:00',
        'body': 'Local draft only',
      },
    );
    expect(created.ok, isTrue);
    expect(created.draft!.accountRequired, isFalse);

    final exported = store.exportLocal();
    expect(exported.ok, isTrue);
    expect(exported.bundle!.account, isNull);
    expect(exported.bundle!.drafts, hasLength(1));
    expect(exported.bundle!.toJson()['account'], isNull);
  });

  test('AC-11.7 rejects banned engagement fields', () {
    final store = SocialStore(clockIso: () => '2026-11-11T09:00:00.000Z');
    final refused = store.createDraft(
      kind: 'score',
      bindings: <String, String>{
        'matchup': 'Foxes vs Cats',
        'scoreline': '10-8',
        'likes': '9999',
      },
    );
    expect(refused.ok, isFalse);
    expect(refused.message, contains('banned engagement'));
    expect(store.displaysEngagementMetrics(), isFalse);
  });

  test('export refuses when no drafts', () {
    final store = SocialStore();
    final result = store.exportLocal();
    expect(result.ok, isFalse);
    expect(result.message, contains('no drafts'));
  });
}
