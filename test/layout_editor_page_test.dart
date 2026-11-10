import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/layout_editor/layout_editor_page.dart';
import 'package:open_matchday/layout_editor/layout_editor_store.dart';
import 'package:open_matchday/layout_editor/layout_models.dart';

void main() {
  testWidgets('exact-output preview, draft apply, source, copy',
      (tester) async {
    final store = LayoutEditorStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutEditorPage(store: store),
      ),
    );

    expect(find.byKey(const Key('exact-output-preview')), findsOneWidget);
    expect(find.byKey(const Key('layout-draft-state')), findsOneWidget);
    expect(find.textContaining('Applied: none'), findsOneWidget);

    store.snapEnabled = false;
    store.moveSelected(x: 0.1, y: 0.2);
    store.resizeSelected(w: 0.3, h: 0.15);
    await tester.pump();

    final item = store.findItem(store.draft, store.selectedItemId!)!;
    expect(item.x, 0.1);
    expect(item.y, 0.2);

    await tester.ensureVisible(find.byKey(const Key('link-scene')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('link-scene')));
    await tester.pump();
    expect(store.draft.sceneId, 'scene-shared');

    await tester.tap(find.byKey(const Key('explicit-copy')));
    await tester.pump();
    expect(store.draft.sceneId, isNull);

    await tester.ensureVisible(find.byKey(const Key('source-live-crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('source-live-crop')));
    await tester.pump();
    expect(
      store.findItem(store.draft, store.selectedItemId!)!.scoreboardSource!.mode,
      ScoreboardSourceMode.liveCrop,
    );

    await tester.ensureVisible(find.byKey(const Key('apply-to-air')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-to-air')));
    await tester.pump();
    expect(store.applied!.state, LayoutState.applied);
    expect(find.textContaining('Applied: applied'), findsOneWidget);
  });

  testWidgets('keyboard nudge moves selected item', (tester) async {
    final store = LayoutEditorStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutEditorPage(store: store),
      ),
    );

    final before = store.findItem(store.draft, store.selectedItemId!)!.x;
    await tester.tap(find.byKey(const Key('exact-output-preview')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      store.findItem(store.draft, store.selectedItemId!)!.x,
      greaterThan(before),
    );
  });

  testWidgets('numeric fields update geometry', (tester) async {
    final store = LayoutEditorStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutEditorPage(store: store),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('layout-x')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('layout-x')), '0.1100');
    await tester.enterText(find.byKey(const Key('layout-y')), '0.2200');
    await tester.enterText(find.byKey(const Key('layout-w')), '0.3000');
    await tester.enterText(find.byKey(const Key('layout-h')), '0.1500');
    await tester.ensureVisible(find.byKey(const Key('apply-numeric')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('apply-numeric')));
    await tester.pump();

    final item = store.findItem(store.draft, store.selectedItemId!)!;
    expect(item.x, 0.11);
    expect(item.y, 0.22);
  });
}
