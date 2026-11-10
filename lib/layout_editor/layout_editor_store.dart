import 'layout_models.dart';

/// Layout editor store: per-output draft/applied, history, presets (AC-3.*).
class LayoutEditorStore {
  LayoutEditorStore({
    List<OutputLayoutBinding>? outputs,
  }) {
    final seed = outputs ??
        <OutputLayoutBinding>[
          OutputLayoutBinding(
            outputId: 'out-16x9',
            aspect: '16:9',
            draft: createDraftLayout(
              layoutId: 'layout-16x9',
              outputId: 'out-16x9',
              aspect: '16:9',
            ),
          ),
          OutputLayoutBinding(
            outputId: 'out-9x16',
            aspect: '9:16',
            draft: createDraftLayout(
              layoutId: 'layout-9x16',
              outputId: 'out-9x16',
              aspect: '9:16',
            ),
          ),
          OutputLayoutBinding(
            outputId: 'out-1x1',
            aspect: '1:1',
            draft: createDraftLayout(
              layoutId: 'layout-1x1',
              outputId: 'out-1x1',
              aspect: '1:1',
            ),
          ),
        ];
    for (final binding in seed) {
      _outputs[binding.outputId] = binding;
    }
    selectedOutputId = seed.first.outputId;
    selectedItemId = seed.first.draft.items.first.itemId;
  }

  final Map<String, OutputLayoutBinding> _outputs =
      <String, OutputLayoutBinding>{};
  final Map<String, List<LayoutDocument>> _presetsByAspect =
      <String, List<LayoutDocument>>{};
  final List<LayoutDocument> _undo = <LayoutDocument>[];
  final List<LayoutDocument> _redo = <LayoutDocument>[];

  late String selectedOutputId;
  String? selectedItemId;
  bool snapEnabled = true;
  bool showSafeAreas = true;

  List<OutputLayoutBinding> get outputs =>
      _outputs.values.toList(growable: false);

  OutputLayoutBinding get selectedOutput => _outputs[selectedOutputId]!;

  LayoutDocument get draft => selectedOutput.draft;

  LayoutDocument? get applied => selectedOutput.applied;

  bool get canUndo => _undo.isNotEmpty;

  bool get canRedo => _redo.isNotEmpty;

  List<LayoutDocument> presetsForAspect(String aspect) =>
      List<LayoutDocument>.unmodifiable(
        _presetsByAspect[aspect] ?? const <LayoutDocument>[],
      );

  void selectOutput(String outputId) {
    final binding = _outputs[outputId];
    if (binding == null) {
      throw ArgumentError('unknown output $outputId');
    }
    _undo.clear();
    _redo.clear();
    selectedOutputId = outputId;
    selectedItemId =
        binding.draft.items.isEmpty ? null : binding.draft.items.first.itemId;
  }

  void selectItem(String itemId) {
    if (findItem(draft, itemId) == null) {
      throw ArgumentError('item not found: $itemId');
    }
    selectedItemId = itemId;
  }

  LayoutItem? findItem(LayoutDocument layout, String itemId) {
    for (final item in layout.items) {
      if (item.itemId == itemId) {
        return item;
      }
    }
    return null;
  }

  void _commit(LayoutDocument next) {
    _undo.add(draft);
    _redo.clear();
    selectedOutput.draft = next.copyWith(state: LayoutState.draft);
  }

  LayoutDocument _replaceItem(
    LayoutDocument layout,
    String itemId,
    LayoutItem Function(LayoutItem item) updater,
  ) {
    final items = <LayoutItem>[];
    var found = false;
    for (final item in layout.items) {
      if (item.itemId == itemId) {
        items.add(updater(item));
        found = true;
      } else {
        items.add(item);
      }
    }
    if (!found) {
      throw ArgumentError('item not found: $itemId');
    }
    return layout.copyWith(items: items, state: LayoutState.draft);
  }

  /// AC-3.2: link draft to a shared scene.
  void linkSharedScene(String sceneId) {
    _commit(draft.copyWith(sceneId: sceneId));
  }

  /// AC-3.2: explicit copy clears scene_id (never silent fork).
  void explicitCopyFromScene({String? newLayoutId}) {
    if (draft.sceneId == null) {
      throw StateError('layout is not linked to a shared scene');
    }
    final layoutId = newLayoutId ?? '${draft.layoutId}-copy';
    final items = <LayoutItem>[];
    for (var index = 0; index < draft.items.length; index += 1) {
      final item = draft.items[index];
      items.add(
        item.copyWith(itemId: '$layoutId-item-${index + 1}'),
      );
    }
    _commit(
      draft.copyWith(
        layoutId: layoutId,
        items: items,
        clearSceneId: true,
        state: LayoutState.draft,
      ),
    );
    selectedItemId = items.isEmpty ? null : items.first.itemId;
  }

  /// AC-3.4
  void moveSelected({required double x, required double y}) {
    final itemId = selectedItemId;
    if (itemId == null) {
      return;
    }
    _commit(
      _replaceItem(draft, itemId, (item) {
        var nextX = clamp01(snapValue(x, snapEnabled));
        var nextY = clamp01(snapValue(y, snapEnabled));
        nextX = clamp01(nextX.clamp(0.0, 1.0 - item.w));
        nextY = clamp01(nextY.clamp(0.0, 1.0 - item.h));
        return item.copyWith(x: nextX, y: nextY);
      }),
    );
  }

  /// AC-3.5
  void resizeSelected({double? w, double? h}) {
    final itemId = selectedItemId;
    if (itemId == null) {
      return;
    }
    _commit(
      _replaceItem(draft, itemId, (item) {
        var nextW = w ?? item.w;
        var nextH = h ?? item.h;
        if (item.aspectLock && item.w > 0) {
          final ratio = item.h / item.w;
          if (w != null && h == null) {
            nextW = w;
            nextH = w * ratio;
          } else if (h != null && w == null) {
            nextH = h;
            nextW = h / ratio;
          } else if (w != null && h != null) {
            nextW = w;
            nextH = w * ratio;
          }
        }
        nextW = clamp01(snapValue(nextW, snapEnabled));
        nextH = clamp01(snapValue(nextH, snapEnabled));
        var nextX = item.x;
        var nextY = item.y;
        if (nextX + nextW > 1) {
          nextX = clamp01(1 - nextW);
        }
        if (nextY + nextH > 1) {
          nextY = clamp01(1 - nextH);
        }
        return item.copyWith(x: nextX, y: nextY, w: nextW, h: nextH);
      }),
    );
  }

  void setAspectLock(bool locked) {
    final itemId = selectedItemId;
    if (itemId == null) {
      return;
    }
    _commit(
      _replaceItem(
        draft,
        itemId,
        (item) => item.copyWith(aspectLock: locked),
      ),
    );
  }

  void setAnchor(String anchor) {
    if (!layoutAnchors.contains(anchor)) {
      throw ArgumentError('invalid anchor $anchor');
    }
    final itemId = selectedItemId;
    if (itemId == null) {
      return;
    }
    _commit(
      _replaceItem(draft, itemId, (item) => item.copyWith(anchor: anchor)),
    );
  }

  void setZOrder(int z) {
    final itemId = selectedItemId;
    if (itemId == null) {
      return;
    }
    _commit(
      _replaceItem(
        draft,
        itemId,
        (item) => item.copyWith(z: z < 0 ? 0 : z),
      ),
    );
  }

  void snapSelected() {
    final itemId = selectedItemId;
    if (itemId == null) {
      return;
    }
    _commit(
      _replaceItem(
        draft,
        itemId,
        (item) => item.copyWith(
          x: clamp01(snapValue(item.x, true)),
          y: clamp01(snapValue(item.y, true)),
          w: clamp01(snapValue(item.w, true)),
          h: clamp01(snapValue(item.h, true)),
        ),
      ),
    );
  }

  /// AC-3.7
  void nudgeSelected({int dx = 0, int dy = 0, bool coarse = false}) {
    final itemId = selectedItemId;
    if (itemId == null) {
      return;
    }
    final item = findItem(draft, itemId);
    if (item == null) {
      return;
    }
    final step = coarse ? nudgeCoarse : nudgeFine;
    final previousSnap = snapEnabled;
    snapEnabled = false;
    moveSelected(x: item.x + dx * step, y: item.y + dy * step);
    snapEnabled = previousSnap;
  }

  void undo() {
    if (_undo.isEmpty) {
      return;
    }
    _redo.add(draft);
    selectedOutput.draft = _undo.removeLast();
    selectedItemId = selectedOutput.draft.items.isEmpty
        ? null
        : selectedOutput.draft.items.first.itemId;
  }

  void redo() {
    if (_redo.isEmpty) {
      return;
    }
    _undo.add(draft);
    selectedOutput.draft = _redo.removeLast();
    selectedItemId = selectedOutput.draft.items.isEmpty
        ? null
        : selectedOutput.draft.items.first.itemId;
  }

  /// AC-3.8
  void savePreset(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('preset name required');
    }
    final preset = draft.copyWith(
      state: LayoutState.draft,
      presetName: trimmed,
      clearSceneId: true,
    );
    final list =
        _presetsByAspect.putIfAbsent(draft.aspect, () => <LayoutDocument>[]);
    list.removeWhere((entry) => entry.presetName == trimmed);
    list.add(preset);
  }

  void applyPreset(String name) {
    final list = _presetsByAspect[draft.aspect] ?? const <LayoutDocument>[];
    LayoutDocument? preset;
    for (final entry in list) {
      if (entry.presetName == name) {
        preset = entry;
        break;
      }
    }
    if (preset == null) {
      throw ArgumentError('preset not found: $name');
    }
    if (preset.aspect != draft.aspect) {
      throw StateError('preset aspect mismatch');
    }
    final items = preset.items.map((item) => item.copyWith()).toList();
    _commit(
      draft.copyWith(
        items: items,
        presetName: preset.presetName,
        state: LayoutState.draft,
      ),
    );
    selectedItemId = items.isEmpty ? null : items.first.itemId;
  }

  /// AC-3.9
  void applyDraftToAir() {
    selectedOutput.applied = draft.copyWith(state: LayoutState.applied);
  }

  void discardDraftTowardApplied() {
    final current = applied;
    if (current == null) {
      throw StateError('no applied layout to restore');
    }
    _commit(current.copyWith(state: LayoutState.draft));
  }

  /// AC-3.10
  void setScoreboardSource({
    required ScoreboardSourceMode mode,
    String? cropRegionId,
  }) {
    final itemId = selectedItemId;
    if (itemId == null) {
      return;
    }
    final item = findItem(draft, itemId);
    if (item == null || item.kind != 'scoreboard') {
      throw StateError('scoreboard_source only applies to scoreboard items');
    }
    if (mode == ScoreboardSourceMode.liveCrop &&
        (cropRegionId == null || cropRegionId.isEmpty)) {
      throw ArgumentError('live_crop requires crop_region_id');
    }
    _commit(
      _replaceItem(
        draft,
        itemId,
        (current) => current.copyWith(
          scoreboardSource: ScoreboardSource(
            mode: mode,
            cropRegionId:
                mode == ScoreboardSourceMode.liveCrop ? cropRegionId : null,
          ),
        ),
      ),
    );
  }
}
