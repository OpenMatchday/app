import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'layout_editor_store.dart';
import 'layout_models.dart';

/// Graphics Operator layout editor (AC-3.2–3.10).
class LayoutEditorPage extends StatefulWidget {
  const LayoutEditorPage({
    super.key,
    this.store,
  });

  final LayoutEditorStore? store;

  @override
  State<LayoutEditorPage> createState() => _LayoutEditorPageState();
}

class _LayoutEditorPageState extends State<LayoutEditorPage> {
  late final LayoutEditorStore _store;
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _wController;
  late final TextEditingController _hController;
  late final TextEditingController _zController;
  late final TextEditingController _presetController;
  late final TextEditingController _cropController;
  late final FocusNode _previewFocus;
  String _status = 'Edit draft on the exact output preview. Apply to put on air.';

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LayoutEditorStore();
    _previewFocus = FocusNode(debugLabel: 'layout-preview');
    final item = _selectedItem();
    _xController = TextEditingController(text: _fmt(item?.x ?? 0));
    _yController = TextEditingController(text: _fmt(item?.y ?? 0));
    _wController = TextEditingController(text: _fmt(item?.w ?? 0));
    _hController = TextEditingController(text: _fmt(item?.h ?? 0));
    _zController = TextEditingController(text: '${item?.z ?? 0}');
    _presetController = TextEditingController(text: 'default');
    _cropController = TextEditingController(text: 'region-board-1');
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _wController.dispose();
    _hController.dispose();
    _zController.dispose();
    _presetController.dispose();
    _cropController.dispose();
    _previewFocus.dispose();
    super.dispose();
  }

  String _fmt(double n) => n.toStringAsFixed(4);

  LayoutItem? _selectedItem() {
    final id = _store.selectedItemId;
    if (id == null) {
      return null;
    }
    return _store.findItem(_store.draft, id);
  }

  void _syncFields() {
    final item = _selectedItem();
    _xController.text = _fmt(item?.x ?? 0);
    _yController.text = _fmt(item?.y ?? 0);
    _wController.text = _fmt(item?.w ?? 0);
    _hController.text = _fmt(item?.h ?? 0);
    _zController.text = '${item?.z ?? 0}';
  }

  void _refresh([String? status]) {
    setState(() {
      _syncFields();
      if (status != null) {
        _status = status;
      }
    });
  }

  double _aspectRatioFor(String aspect) {
    return switch (aspect) {
      '16:9' => 16 / 9,
      '9:16' => 9 / 16,
      '1:1' => 1,
      _ => 16 / 9,
    };
  }

  void handleSelectOutput(String outputId) {
    _store.selectOutput(outputId);
    _refresh('Editing output $outputId (${_store.draft.aspect})');
  }

  void handleSelectItem(String itemId) {
    _store.selectItem(itemId);
    _refresh('Selected $itemId');
  }

  void handleNumericApply() {
    final x = double.tryParse(_xController.text);
    final y = double.tryParse(_yController.text);
    final w = double.tryParse(_wController.text);
    final h = double.tryParse(_hController.text);
    final z = int.tryParse(_zController.text);
    if (x == null || y == null || w == null || h == null || z == null) {
      _refresh('Numeric fields must be valid numbers');
      return;
    }
    _store.moveSelected(x: x, y: y);
    _store.resizeSelected(w: w, h: h);
    _store.setZOrder(z);
    _refresh('Applied numeric geometry');
  }

  void handleToggleAspectLock(bool? locked) {
    if (locked == null) {
      return;
    }
    _store.setAspectLock(locked);
    _refresh(locked ? 'Aspect lock on' : 'Aspect lock unlocked');
  }

  void handleAnchor(String? anchor) {
    if (anchor == null) {
      return;
    }
    _store.setAnchor(anchor);
    _refresh('Anchor $anchor');
  }

  void handleSnap() {
    _store.snapSelected();
    _refresh('Snapped to $snapStep grid');
  }

  void handleUndo() {
    _store.undo();
    _refresh('Undo');
  }

  void handleRedo() {
    _store.redo();
    _refresh('Redo');
  }

  void handleSavePreset() {
    try {
      _store.savePreset(_presetController.text);
      _refresh('Saved preset ${_presetController.text.trim()}');
    } catch (error) {
      _refresh('$error');
    }
  }

  void handleApplyPreset() {
    try {
      _store.applyPreset(_presetController.text.trim());
      _refresh('Applied preset ${_presetController.text.trim()}');
    } catch (error) {
      _refresh('$error');
    }
  }

  void handleApplyToAir() {
    _store.applyDraftToAir();
    _refresh('Applied layout to air (${_store.draft.layoutId})');
  }

  void handleLinkScene() {
    _store.linkSharedScene('scene-shared');
    _refresh('Linked shared scene scene-shared');
  }

  void handleExplicitCopy() {
    try {
      _store.explicitCopyFromScene();
      _refresh('Explicit copy: scene link cleared');
    } catch (error) {
      _refresh('$error');
    }
  }

  void handleScoreboardGraphic() {
    try {
      _store.setScoreboardSource(mode: ScoreboardSourceMode.graphic);
      _refresh('Scoreboard source: graphic');
    } catch (error) {
      _refresh('$error');
    }
  }

  void handleScoreboardLiveCrop() {
    try {
      _store.setScoreboardSource(
        mode: ScoreboardSourceMode.liveCrop,
        cropRegionId: _cropController.text.trim(),
      );
      _refresh('Scoreboard source: live_crop');
    } catch (error) {
      _refresh('$error');
    }
  }

  KeyEventResult handlePreviewKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final coarse = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _store.nudgeSelected(dx: -1, coarse: coarse);
      _refresh('Nudge left');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _store.nudgeSelected(dx: 1, coarse: coarse);
      _refresh('Nudge right');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _store.nudgeSelected(dy: -1, coarse: coarse);
      _refresh('Nudge up');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _store.nudgeSelected(dy: 1, coarse: coarse);
      _refresh('Nudge down');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ &&
        HardwareKeyboard.instance.isControlPressed) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        handleRedo();
      } else {
        handleUndo();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void handlePreviewDrag(DragUpdateDetails details, Size size) {
    final item = _selectedItem();
    if (item == null || size.width <= 0 || size.height <= 0) {
      return;
    }
    final dx = details.delta.dx / size.width;
    final dy = details.delta.dy / size.height;
    _store.moveSelected(x: item.x + dx, y: item.y + dy);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _store.draft;
    final item = _selectedItem();
    final applied = _store.applied;
    final aspect = draft.aspect;
    final sourceMode = item?.scoreboardSource?.mode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Layout editor'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              key: const Key('layout-editor-status'),
              _status,
              semanticsLabel: _status,
            ),
            const SizedBox(height: 8),
            Text(
              key: const Key('layout-draft-state'),
              'Draft state: ${draft.state.name} · Applied: '
              '${applied == null ? 'none' : applied.state.name}',
            ),
            const SizedBox(height: 16),
            Text(
              'Output',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final output in _store.outputs)
                  ChoiceChip(
                    key: Key('output-${output.outputId}'),
                    label: Text('${output.outputId} (${output.aspect})'),
                    selected: output.outputId == _store.selectedOutputId,
                    onSelected: (_) => handleSelectOutput(output.outputId),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Exact output preview ($aspect)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Focus(
              focusNode: _previewFocus,
              onKeyEvent: handlePreviewKey,
              child: Semantics(
                label: 'Exact output layout preview $aspect',
                child: GestureDetector(
                  onTap: () => _previewFocus.requestFocus(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final previewWidth =
                          maxWidth > 640 ? 640.0 : maxWidth;
                      final previewHeight =
                          previewWidth / _aspectRatioFor(aspect);
                      return Center(
                        child: SizedBox(
                          key: const Key('exact-output-preview'),
                          width: previewWidth,
                          height: previewHeight,
                          child: GestureDetector(
                            onPanUpdate: (details) => handlePreviewDrag(
                              details,
                              Size(previewWidth, previewHeight),
                            ),
                            child: CustomPaint(
                              painter: _LayoutPreviewPainter(
                                layout: draft,
                                selectedItemId: _store.selectedItemId,
                                showSafeAreas: _store.showSafeAreas,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arrow keys nudge (Shift = coarse). Focus the preview first.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in draft.items)
                  ChoiceChip(
                    key: Key('item-${entry.itemId}'),
                    label: Text(entry.kind),
                    selected: entry.itemId == _store.selectedItemId,
                    onSelected: (_) => handleSelectItem(entry.itemId),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Geometry',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('layout-x'),
                    controller: _xController,
                    decoration: const InputDecoration(labelText: 'x'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('layout-y'),
                    controller: _yController,
                    decoration: const InputDecoration(labelText: 'y'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('layout-w'),
                    controller: _wController,
                    decoration: const InputDecoration(labelText: 'w'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('layout-h'),
                    controller: _hController,
                    decoration: const InputDecoration(labelText: 'h'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('layout-z'),
              controller: _zController,
              decoration: const InputDecoration(labelText: 'z-order'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('aspect-lock'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Aspect lock'),
              value: item?.aspectLock ?? defaultAspectLock,
              onChanged: handleToggleAspectLock,
            ),
            DropdownButtonFormField<String>(
              key: const Key('layout-anchor'),
              initialValue: item?.anchor ?? 'top_left',
              decoration: const InputDecoration(labelText: 'Anchor'),
              items: [
                for (final anchor in layoutAnchors)
                  DropdownMenuItem(value: anchor, child: Text(anchor)),
              ],
              onChanged: handleAnchor,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('apply-numeric'),
                  onPressed: handleNumericApply,
                  child: const Text('Apply numeric'),
                ),
                OutlinedButton(
                  key: const Key('snap-item'),
                  onPressed: handleSnap,
                  child: const Text('Snap'),
                ),
                OutlinedButton(
                  key: const Key('undo-layout'),
                  onPressed: _store.canUndo ? handleUndo : null,
                  child: const Text('Undo'),
                ),
                OutlinedButton(
                  key: const Key('redo-layout'),
                  onPressed: _store.canRedo ? handleRedo : null,
                  child: const Text('Redo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Presets / scene / air',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('preset-name'),
              controller: _presetController,
              decoration: const InputDecoration(labelText: 'Preset name'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('save-preset'),
                  onPressed: handleSavePreset,
                  child: const Text('Save preset'),
                ),
                OutlinedButton(
                  key: const Key('apply-preset'),
                  onPressed: handleApplyPreset,
                  child: const Text('Apply preset'),
                ),
                OutlinedButton(
                  key: const Key('link-scene'),
                  onPressed: handleLinkScene,
                  child: const Text('Link shared scene'),
                ),
                OutlinedButton(
                  key: const Key('explicit-copy'),
                  onPressed: handleExplicitCopy,
                  child: const Text('Explicit copy'),
                ),
                FilledButton(
                  key: const Key('apply-to-air'),
                  onPressed: handleApplyToAir,
                  child: const Text('Apply to air'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              key: const Key('scene-link-status'),
              draft.sceneId == null
                  ? 'Scene link: none (independent)'
                  : 'Scene link: ${draft.sceneId}',
            ),
            const SizedBox(height: 16),
            Text(
              'Scoreboard source',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('crop-region-id'),
              controller: _cropController,
              decoration: const InputDecoration(labelText: 'Crop region id'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('source-graphic'),
                  label: const Text('Graphic'),
                  selected: sourceMode == ScoreboardSourceMode.graphic,
                  onSelected: (_) => handleScoreboardGraphic(),
                ),
                ChoiceChip(
                  key: const Key('source-live-crop'),
                  label: const Text('Live crop'),
                  selected: sourceMode == ScoreboardSourceMode.liveCrop,
                  onSelected: (_) => handleScoreboardLiveCrop(),
                ),
              ],
            ),
            CheckboxListTile(
              key: const Key('show-safe-areas'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Safe-area guides (SMPTE ST 2046-1)'),
              value: _store.showSafeAreas,
              onChanged: (value) {
                setState(() {
                  _store.showSafeAreas = value ?? true;
                });
              },
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _LayoutPreviewPainter extends CustomPainter {
  _LayoutPreviewPainter({
    required this.layout,
    required this.selectedItemId,
    required this.showSafeAreas,
  });

  final LayoutDocument layout;
  final String? selectedItemId;
  final bool showSafeAreas;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF121816);
    canvas.drawRect(Offset.zero & size, bg);

    if (showSafeAreas) {
      final action = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF66AA88);
      final title = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFAACCEE);
      canvas.drawRect(
        Rect.fromLTWH(
          actionSafeInset * size.width,
          actionSafeInset * size.height,
          (1 - actionSafeInset * 2) * size.width,
          (1 - actionSafeInset * 2) * size.height,
        ),
        action,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          titleSafeInset * size.width,
          titleSafeInset * size.height,
          (1 - titleSafeInset * 2) * size.width,
          (1 - titleSafeInset * 2) * size.height,
        ),
        title,
      );
    }

    final items = [...layout.items]
      ..sort((a, b) {
        final z = a.z.compareTo(b.z);
        if (z != 0) {
          return z;
        }
        return a.itemId.compareTo(b.itemId);
      });

    for (final item in items) {
      final rect = Rect.fromLTWH(
        item.x * size.width,
        item.y * size.height,
        item.w * size.width,
        item.h * size.height,
      );
      final selected = item.itemId == selectedItemId;
      final fill = Paint()
        ..color = selected
            ? const Color(0xFF2A4A3C)
            : const Color(0xFF1A2420);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1
        ..color = selected
            ? const Color(0xFF3D8B6E)
            : const Color(0xFF2A3832);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);

      if (selected) {
        final handle = Paint()..color = const Color(0xFF3D8B6E);
        const handleSize = 8.0;
        canvas.drawRect(
          Rect.fromLTWH(
            rect.right - handleSize,
            rect.bottom - handleSize,
            handleSize,
            handleSize,
          ),
          handle,
        );
      }

      final tp = TextPainter(
        text: TextSpan(
          text: item.kind,
          style: const TextStyle(
            color: Color(0xFFF5F5F5),
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width);
      tp.paint(canvas, Offset(rect.left + 4, rect.top + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutPreviewPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.selectedItemId != selectedItemId ||
        oldDelegate.showSafeAreas != showSafeAreas;
  }
}
