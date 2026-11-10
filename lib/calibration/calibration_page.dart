import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calibration_store.dart';
import 'geometry.dart';
import 'regions.dart';

/// Scoreboard Reader four-corner calibration UI (AC-4.1–4.6).
class CalibrationPage extends StatefulWidget {
  const CalibrationPage({
    super.key,
    this.store,
  });

  final CalibrationStore? store;

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  late final CalibrationStore _store;
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _zoomController;
  late final FocusNode _previewFocus;
  String _status = 'Freeze the live preview, then mark TL, TR, BR, BL.';

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? CalibrationStore();
    _previewFocus = FocusNode(debugLabel: 'calibration-preview');
    _xController = TextEditingController(text: '0');
    _yController = TextEditingController(text: '0');
    _zoomController = TextEditingController(text: '1.0');
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _zoomController.dispose();
    _previewFocus.dispose();
    super.dispose();
  }

  void _refresh(String status) {
    setState(() {
      _status = status;
      final id = _store.selectedCorner;
      final corners = _store.pixelCorners;
      if (id != null && corners != null) {
        final point = switch (id) {
          'tl' => corners.tl,
          'tr' => corners.tr,
          'br' => corners.br,
          'bl' => corners.bl,
          _ => const CalibPoint(0, 0),
        };
        _xController.text = point.x.toStringAsFixed(1);
        _yController.text = point.y.toStringAsFixed(1);
      }
      _zoomController.text = _store.zoom.toStringAsFixed(1);
    });
  }

  void handleFreeze() {
    final result = _store.freezeFrame();
    _refresh(result.message);
  }

  void handleSelectCorner(String id) {
    final result = _store.selectCorner(id);
    _refresh(result.message);
  }

  void handleApplyCorner() {
    final id = _store.selectedCorner;
    if (id == null) {
      _refresh('select a corner handle first');
      return;
    }
    final x = double.tryParse(_xController.text);
    final y = double.tryParse(_yController.text);
    if (x == null || y == null) {
      _refresh('corner coordinates must be numeric');
      return;
    }
    final result = _store.setCornerPixel(id, CalibPoint(x, y));
    _refresh(result.message);
  }

  void handleZoom() {
    final zoom = double.tryParse(_zoomController.text);
    if (zoom == null) {
      _refresh('zoom must be numeric');
      return;
    }
    final result = _store.setZoom(zoom);
    _refresh(result.message);
  }

  void handleCompute() {
    final result = _store.computeRectified();
    _refresh(result.message);
  }

  void handleConfirm() {
    final result = _store.confirmGeometry();
    if (result.ok) {
      _store.beginRegions();
    }
    _refresh(result.message);
  }

  void handleRedo() {
    final result = _store.redoCorners();
    _refresh(result.message);
  }

  void handleCompleteRegions() {
    final result = _store.completeRegions();
    _refresh(result.message);
  }

  void handleNudge(LogicalKeyboardKey key) {
    final id = _store.selectedCorner;
    final corners = _store.pixelCorners;
    if (id == null || corners == null) {
      return;
    }
    final current = switch (id) {
      'tl' => corners.tl,
      'tr' => corners.tr,
      'br' => corners.br,
      'bl' => corners.bl,
      _ => null,
    };
    if (current == null) {
      return;
    }
    final step = 1.0 / _store.zoom;
    var x = current.x;
    var y = current.y;
    if (key == LogicalKeyboardKey.arrowLeft) {
      x -= step;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      x += step;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      y -= step;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      y += step;
    } else {
      return;
    }
    final result = _store.setCornerPixel(id, CalibPoint(x, y));
    _refresh(result.message);
  }

  @override
  Widget build(BuildContext context) {
    final corners = _store.pixelCorners;
    final validation = _store.lastValidation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scoreboard calibration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            'Four-corner calibration',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Freeze the Scoreboard Reader preview, mark TL/TR/BR/BL with zoom '
            'and draggable handles, confirm the rectified board, then define '
            'OCR regions for ${_store.sportId}.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            key: const Key('calibration-phase'),
            'Phase: ${_store.phase.name}',
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('calibration-status'),
            _status,
            semanticsLabel: _status,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('calibration-freeze'),
                onPressed: handleFreeze,
                child: const Text('Freeze frame'),
              ),
              OutlinedButton(
                key: const Key('calibration-compute'),
                onPressed: handleCompute,
                child: const Text('Compute rectified'),
              ),
              OutlinedButton(
                key: const Key('calibration-confirm'),
                onPressed: handleConfirm,
                child: const Text('Confirm geometry'),
              ),
              OutlinedButton(
                key: const Key('calibration-redo'),
                onPressed: handleRedo,
                child: const Text('Redo'),
              ),
              OutlinedButton(
                key: const Key('calibration-complete-regions'),
                onPressed: handleCompleteRegions,
                child: const Text('Complete regions'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Corner handles',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final id in cornerOrder)
                FilterChip(
                  key: Key('corner-chip-$id'),
                  label: Text(id.toUpperCase()),
                  selected: _store.selectedCorner == id,
                  onSelected: (_) => handleSelectCorner(id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('corner-x'),
                  controller: _xController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'X'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('corner-y'),
                  controller: _yController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Y'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('corner-zoom'),
                  controller: _zoomController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Zoom'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const Key('corner-apply'),
                onPressed: handleApplyCorner,
                child: const Text('Apply handle'),
              ),
              OutlinedButton(
                key: const Key('zoom-apply'),
                onPressed: handleZoom,
                child: const Text('Apply zoom'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          KeyboardListener(
            focusNode: _previewFocus,
            autofocus: true,
            onKeyEvent: (event) {
              if (event is! KeyDownEvent) {
                return;
              }
              handleNudge(event.logicalKey);
            },
            child: Semantics(
              label: 'Calibration preview with corner handles',
              child: AspectRatio(
                aspectRatio: _store.frameWidth / _store.frameHeight,
                child: Container(
                  key: const Key('calibration-preview'),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13261F),
                    border: Border.all(color: const Color(0xFF3D8B6E)),
                  ),
                  child: CustomPaint(
                    painter: _CalibrationPreviewPainter(
                      corners: corners,
                      selected: _store.selectedCorner,
                      regions: _store.regions,
                      frameWidth: _store.frameWidth,
                      frameHeight: _store.frameHeight,
                      showRectified: _store.phase ==
                              CalibrationPhase.rectifiedPending ||
                          _store.geometryAccepted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (validation != null) ...[
            const SizedBox(height: 12),
            Text(
              key: const Key('calibration-validation'),
              validation.ok
                  ? 'Validation OK (area=${validation.area.toStringAsFixed(1)}, ${validation.winding})'
                  : 'Validation failed: ${validation.reasons.join(", ")}',
            ),
          ],
          if (_store.homography != null) ...[
            const SizedBox(height: 8),
            Text(
              key: const Key('calibration-homography'),
              'Homography ready (3x3, h33=1)',
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Regions (${_store.sportId})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('calibration-fields'),
            'Fields: ${_store.availableFields.join(", ")}',
          ),
          const SizedBox(height: 8),
          for (final region in _store.regions)
            Text(
              key: Key('region-${region.fieldId}'),
              '${region.fieldId}: '
              'x=${region.x.toStringAsFixed(2)} '
              'y=${region.y.toStringAsFixed(2)} '
              'w=${region.w.toStringAsFixed(2)} '
              'h=${region.h.toStringAsFixed(2)}',
            ),
        ],
        ),
      ),
    );
  }
}

class _CalibrationPreviewPainter extends CustomPainter {
  _CalibrationPreviewPainter({
    required this.corners,
    required this.selected,
    required this.regions,
    required this.frameWidth,
    required this.frameHeight,
    required this.showRectified,
  });

  final CornerSet? corners;
  final String? selected;
  final List<BoardRegion> regions;
  final double frameWidth;
  final double frameHeight;
  final bool showRectified;

  Offset _toCanvas(CalibPoint p, Size size) {
    return Offset(
      p.x / frameWidth * size.width,
      p.y / frameHeight * size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = const Color(0xFF3D8B6E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (corners != null) {
      final tl = _toCanvas(corners!.tl, size);
      final path = Path()..moveTo(tl.dx, tl.dy);
      for (final p in <CalibPoint>[corners!.tr, corners!.br, corners!.bl]) {
        final o = _toCanvas(p, size);
        path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, border);
      for (final entry in <MapEntry<String, CalibPoint>>[
        MapEntry('tl', corners!.tl),
        MapEntry('tr', corners!.tr),
        MapEntry('br', corners!.br),
        MapEntry('bl', corners!.bl),
      ]) {
        final fill = Paint()
          ..color = entry.key == selected
              ? const Color(0xFFE8C547)
              : const Color(0xFF9BB0A4);
        canvas.drawCircle(
          _toCanvas(entry.value, size),
          entry.key == selected ? 8 : 6,
          fill,
        );
      }
    }
    if (showRectified) {
      final rectPaint = Paint()
        ..color = const Color(0x553D8B6E)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.8,
            size.height * 0.8),
        rectPaint,
      );
    }
    final regionPaint = Paint()
      ..color = const Color(0x66E8C547)
      ..style = PaintingStyle.fill;
    for (final region in regions) {
      canvas.drawRect(
        Rect.fromLTWH(
          region.x * size.width,
          region.y * size.height,
          region.w * size.width,
          region.h * size.height,
        ),
        regionPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalibrationPreviewPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.selected != selected ||
        oldDelegate.regions != regions ||
        oldDelegate.showRectified != showRectified;
  }
}
