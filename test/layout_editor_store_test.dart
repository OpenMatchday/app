import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/layout_editor/layout_editor_store.dart';
import 'package:open_matchday/layout_editor/layout_models.dart';

void main() {
  test('outputs own layouts; explicit copy clears scene link', () {
    final store = LayoutEditorStore();
    expect(store.outputs.length, 3);
    expect(store.draft.aspect, '16:9');

    store.linkSharedScene('scene-shared');
    expect(store.draft.sceneId, 'scene-shared');

    store.explicitCopyFromScene(newLayoutId: 'layout-fork');
    expect(store.draft.sceneId, isNull);
    expect(store.draft.layoutId, 'layout-fork');
    expect(store.draft.state, LayoutState.draft);
  });

  test('drag resize aspect lock snap nudge undo apply presets source', () {
    final store = LayoutEditorStore();
    final itemId = store.selectedItemId!;
    expect(store.findItem(store.draft, itemId)!.aspectLock, isTrue);

    store.moveSelected(x: 0.2, y: 0.3);
    expect(store.findItem(store.draft, itemId)!.x, 0.2);
    expect(store.findItem(store.draft, itemId)!.y, 0.3);

    final beforeH = store.findItem(store.draft, itemId)!.h;
    final beforeW = store.findItem(store.draft, itemId)!.w;
    store.snapEnabled = false;
    store.resizeSelected(w: 0.4);
    final locked = store.findItem(store.draft, itemId)!;
    expect(locked.w, 0.4);
    expect(locked.h, round4(0.4 * (beforeH / beforeW)));

    store.setAspectLock(false);
    store.resizeSelected(w: 0.35, h: 0.2);
    expect(store.findItem(store.draft, itemId)!.h, 0.2);
    store.snapEnabled = true;

    store.setAnchor('bottom_right');
    store.setZOrder(7);
    store.snapEnabled = false;
    store.moveSelected(x: 0.1234, y: 0.5678);
    store.snapSelected();
    expect(store.findItem(store.draft, itemId)!.x, 0.12);
    expect(store.findItem(store.draft, itemId)!.y, 0.57);
    expect(store.findItem(store.draft, itemId)!.anchor, 'bottom_right');
    expect(store.findItem(store.draft, itemId)!.z, 7);

    final xBefore = store.findItem(store.draft, itemId)!.x;
    store.nudgeSelected(dx: 1);
    expect(store.findItem(store.draft, itemId)!.x, greaterThan(xBefore));
    store.undo();
    expect(store.findItem(store.draft, itemId)!.x, xBefore);
    store.redo();
    expect(store.findItem(store.draft, itemId)!.x, greaterThan(xBefore));

    store.savePreset('wide-bug');
    store.moveSelected(x: 0.5, y: 0.5);
    store.applyPreset('wide-bug');
    expect(store.draft.presetName, 'wide-bug');

    expect(store.applied, isNull);
    store.applyDraftToAir();
    expect(store.applied!.state, LayoutState.applied);
    expect(store.draft.state, LayoutState.draft);

    store.setScoreboardSource(mode: ScoreboardSourceMode.graphic);
    expect(
      store.findItem(store.draft, itemId)!.scoreboardSource!.mode,
      ScoreboardSourceMode.graphic,
    );
    store.setScoreboardSource(
      mode: ScoreboardSourceMode.liveCrop,
      cropRegionId: 'region-1',
    );
    expect(
      store.findItem(store.draft, itemId)!.scoreboardSource!.mode,
      ScoreboardSourceMode.liveCrop,
    );
  });

  test('preset aspect mismatch is rejected across outputs', () {
    final store = LayoutEditorStore();
    store.savePreset('wide-only');
    store.selectOutput('out-9x16');
    expect(
      () => store.applyPreset('wide-only'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
