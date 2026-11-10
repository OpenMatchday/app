import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media_bridge.dart';
import '../pairing/media_medium.dart';
import 'buses.dart';

/// Director shell with distinct Preview and Program buses (AC-2.1 preview path).
class DirectorPage extends StatefulWidget {
  const DirectorPage({
    super.key,
    required this.mediaBridge,
    this.initialMedium = 'wifi',
  });

  final MediaBridge mediaBridge;
  final String initialMedium;

  @override
  State<DirectorPage> createState() => _DirectorPageState();
}

class _DirectorPageState extends State<DirectorPage> {
  late final DirectorBuses _buses;
  late String _medium;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _buses = DirectorBuses();
    _medium = widget.initialMedium;
  }

  Future<void> handleStartPreview() async {
    if (_busy) {
      return;
    }
    final refusal = mediaMediumRefusalReason(_medium);
    if (refusal != null) {
      setState(() {
        _buses.preview = PreviewSourceStatus(
          state: PreviewSourceState.refused,
          medium: _medium,
          message: refusal,
        );
      });
      return;
    }
    setState(() {
      _busy = true;
      _buses.preview = PreviewSourceStatus(
        state: PreviewSourceState.starting,
        medium: _medium,
        message: 'Starting camera preview over $_medium...',
      );
    });
    try {
      final result = await widget.mediaBridge.startPreview(
        medium: _medium,
        sourceId: 'cam-1',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.preview = PreviewSourceStatus(
          state: PreviewSourceState.receiving,
          medium: result.medium,
          platform: result.platform,
          sourceId: result.sourceId,
          message: result.message,
          snapshotPath: result.snapshotPath,
        );
      });
    } on MediaMediumRefused catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.preview = PreviewSourceStatus(
          state: PreviewSourceState.refused,
          medium: _medium,
          message: error.message,
        );
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.preview = PreviewSourceStatus(
          state: PreviewSourceState.error,
          medium: _medium,
          message: '${error.code}: ${error.message}',
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.preview = PreviewSourceStatus(
          state: PreviewSourceState.error,
          medium: _medium,
          message: '$error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> handleStopPreview() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await widget.mediaBridge.stopPreview();
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.preview = PreviewSourceStatus(
          state: PreviewSourceState.stopped,
          medium: _medium,
          message: 'Preview stopped',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void handleMediumChanged(String? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _medium = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buses.preview;
    final programLabel = _buses.programSourceId.isEmpty
        ? 'Program: none (Cut/Take not enabled yet)'
        : 'Program: ${_buses.programSourceId}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Director'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Buses',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Preview and Program are distinct. Only Program feeds outputs '
            '(AC-2.1). This task wires the one-camera Preview path.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _BusPanel(
            key: const Key('preview-bus'),
            title: 'Preview',
            semanticsLabel: 'Preview bus',
            accent: const Color(0xFF3D8B6E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const Key('preview-status'),
                  'State: ${preview.state.name}',
                  semanticsLabel: 'Preview state ${preview.state.name}',
                ),
                const SizedBox(height: 4),
                Text(
                  preview.message.isEmpty
                      ? 'No preview source'
                      : preview.message,
                ),
                if (preview.sourceId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Source: ${preview.sourceId}'),
                ],
                if (preview.snapshotPath.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Snapshot: ${preview.snapshotPath}'),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('preview-medium'),
                  initialValue: _medium,
                  decoration: const InputDecoration(
                    labelText: 'Media medium',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'wifi', child: Text('Wi-Fi')),
                    DropdownMenuItem(
                      value: 'ethernet',
                      child: Text('Ethernet'),
                    ),
                    DropdownMenuItem(
                      value: 'cellular',
                      child: Text('Cellular (refused)'),
                    ),
                  ],
                  onChanged: _busy ? null : handleMediumChanged,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('start-preview'),
                      onPressed: _busy ? null : handleStartPreview,
                      child: const Text('Start camera preview'),
                    ),
                    OutlinedButton(
                      key: const Key('stop-preview'),
                      onPressed: _busy ? null : handleStopPreview,
                      child: const Text('Stop preview'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BusPanel(
            key: const Key('program-bus'),
            title: 'Program',
            semanticsLabel: 'Program bus',
            accent: const Color(0xFF8B3D3D),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const Key('program-status'),
                  programLabel,
                  semanticsLabel: programLabel,
                ),
                const SizedBox(height: 4),
                Text(
                  _buses.programFeedsOutputs
                      ? 'Program feeds enabled outputs'
                      : 'No outputs fed until Program has a source',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusPanel extends StatelessWidget {
  const _BusPanel({
    super.key,
    required this.title,
    required this.semanticsLabel,
    required this.accent,
    required this.child,
  });

  final String title;
  final String semanticsLabel;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13261F),
          border: Border.all(color: accent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
