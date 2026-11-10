import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media_bridge.dart';
import '../pairing/media_medium.dart';
import 'audio.dart';
import 'buses.dart';
import 'cut_take.dart';
import 'source_health.dart';

/// Director shell with Preview/Program buses, Cut/Take, tally, independent audio.
class DirectorPage extends StatefulWidget {
  const DirectorPage({
    super.key,
    required this.mediaBridge,
    this.initialMedium = 'wifi',
    this.initialPreviewSourceId = 'cam-1',
    this.onProgramChanged,
  });

  final MediaBridge mediaBridge;
  final String initialMedium;
  final String initialPreviewSourceId;
  final ValueChanged<String>? onProgramChanged;

  @override
  State<DirectorPage> createState() => _DirectorPageState();
}

class _DirectorPageState extends State<DirectorPage> {
  late final DirectorBuses _buses;
  late String _medium;
  late String _previewSourceId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _buses = DirectorBuses();
    _medium = widget.initialMedium;
    _previewSourceId = widget.initialPreviewSourceId;
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
        sourceId: _previewSourceId,
        message: 'Starting $_previewSourceId preview over $_medium...',
      );
    });
    try {
      final result = await widget.mediaBridge.startPreview(
        medium: _medium,
        sourceId: _previewSourceId,
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
          sourceId: _previewSourceId,
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
          sourceId: _previewSourceId,
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
          sourceId: _previewSourceId,
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
          sourceId: _previewSourceId,
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

  void handlePreviewCameraChanged(String? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _previewSourceId = value;
    });
  }

  Future<void> handleAudioSourceChanged(String? value) async {
    if (value == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _buses.audio.selectSource(value);
    });
    try {
      final result = await widget.mediaBridge.selectAudioSource(
        sourceId: value,
        videoProgramSourceId: _buses.programSourceId.isEmpty
            ? null
            : _buses.programSourceId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.audio.selectSource(result.sourceId);
      });
      await handleRefreshMeters();
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.audio.meters = AudioMeters(
          sourceId: value,
          peakDb: null,
          rmsDb: null,
        );
        _buses.preview = _buses.preview.copyWith(
          message: 'Audio select failed: ${error.message}',
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

  Future<void> handleRefreshMeters() async {
    final sourceId = _buses.audio.selectedSourceId;
    if (sourceId.isEmpty) {
      return;
    }
    try {
      final meters = await widget.mediaBridge.readAudioMeters(sourceId: sourceId);
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.audio.meters = meters;
      });
    } on PlatformException {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.audio.meters = AudioMeters(sourceId: sourceId);
      });
    }
  }

  Future<void> handleRefreshAvSync() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final result = await widget.mediaBridge.readAvSync();
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.avSync.recordSample(
          offsetMs: result.offsetMs,
          measuredAtMs: result.measuredAtMs > 0
              ? result.measuredAtMs
              : DateTime.now().millisecondsSinceEpoch,
        );
        _buses.avSync.correctionMs = result.correctionMs;
        _buses.avSync.message =
            'Offset ${result.offsetMs.toStringAsFixed(1)} ms '
            '(audio relative to video; positive = audio late)';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.avSync.message = 'Sync read failed: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> handleApplyDriftCorrection() async {
    if (_busy) {
      return;
    }
    final offset = _buses.avSync.offsetMs;
    if (offset == null) {
      setState(() {
        _buses.avSync.message = 'Measure sync before applying correction';
      });
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final result = await widget.mediaBridge.applyDriftCorrection(
        correctionMs: offset,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.avSync.applyCorrection(result.correctionMs);
        final residual = result.residualMs ?? result.offsetMs;
        _buses.avSync.recordSample(
          offsetMs: residual,
          measuredAtMs: result.measuredAtMs > 0
              ? result.measuredAtMs
              : DateTime.now().millisecondsSinceEpoch,
          corrected: true,
          residualMs: residual,
        );
        _buses.avSync.message =
            'Applied correction ${result.correctionMs.toStringAsFixed(1)} ms; '
            'residual ${residual.toStringAsFixed(1)} ms';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.avSync.message = 'Drift correction failed: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> handleRefreshSourceHealth() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final result = await widget.mediaBridge.readSourceHealth();
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.health.replaceSources(result.sources);
        _buses.health.fallbackMode = result.programFallback;
        _buses.health.sessionAlive = result.sessionAlive;
        _buses.health.message = result.sources.isEmpty
            ? 'No source health readings'
            : 'Health refreshed (${result.sources.length} sources)';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.health.message = 'Health read failed: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> handleSimulateSourceLoss(String lostSourceId) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final programSourceId = _buses.programSourceId.isEmpty
          ? lostSourceId
          : _buses.programSourceId;
      final local = _buses.health.applySourceLoss(
        lostSourceId: lostSourceId,
        programSourceId: programSourceId,
      );
      final bridge = await widget.mediaBridge.applySourceLossFallback(
        lostSourceId: lostSourceId,
        programSourceId: programSourceId,
        programFallback: _buses.health.fallbackMode.wire,
        alternateSourceId: _buses.health.alternateSourceId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.health.sessionAlive = bridge.sessionAlive;
        _buses.health.message = bridge.message.isEmpty
            ? local.message
            : bridge.message;
        _buses.health.lastFallback = SourceLossFallbackResult(
          lostSourceId: bridge.lostSourceId,
          fallbackMode: _buses.health.fallbackMode,
          programSafeState: bridge.programSafeState,
          sessionAlive: bridge.sessionAlive,
          observedAtMs: bridge.observedAtMs > 0
              ? bridge.observedAtMs
              : local.observedAtMs,
          programSourceId: bridge.programSourceId,
          alternateSourceId: _buses.health.alternateSourceId,
          message: bridge.message.isEmpty ? local.message : bridge.message,
        );
        if (bridge.programSafeState == 'alternate_source' &&
            bridge.programSourceId.isNotEmpty) {
          _buses.programSourceId = bridge.programSourceId;
          widget.onProgramChanged?.call(bridge.programSourceId);
        }
        _buses.health.upsert(
          SourceHealthEntry(
            sourceId: lostSourceId,
            state: SourceHealthState.lost,
            observedAtMs: bridge.observedAtMs > 0
                ? bridge.observedAtMs
                : local.observedAtMs,
            detail: 'source lost (simulated drop)',
          ),
        );
      });
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.health.message = error.message ?? error.toString();
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.health.message = 'Source-loss fallback failed: ${error.message}';
        // Session must remain alive even when the bridge call fails mid-drop.
        _buses.health.sessionAlive = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void handleFallbackModeChanged(ProgramFallbackMode? mode) {
    if (mode == null) {
      return;
    }
    setState(() {
      _buses.health.fallbackMode = mode;
    });
  }

  Future<void> handleCutTake(String action) async {
    if (_busy) {
      return;
    }
    final previewSourceId = _buses.preview.sourceId.isNotEmpty
        ? _buses.preview.sourceId
        : _previewSourceId;
    if (previewSourceId.isEmpty) {
      setState(() {
        _buses.preview = _buses.preview.copyWith(
          message: 'Cut/Take requires a Preview source (AC-2.2)',
        );
      });
      return;
    }
    setState(() {
      _busy = true;
    });
    final issuedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final local = _buses.cutTake(
        action: action,
        previewSourceId: previewSourceId,
        issuedAtMs: issuedAtMs,
      );
      final bridge = await widget.mediaBridge.cutTake(
        action: local.action,
        previewSourceId: local.previewSourceId,
        programSourceId: local.programSourceId,
        previousProgramSourceId: local.previousProgramSourceId,
      );
      final previous = local.previousProgramSourceId;
      if (previous.isNotEmpty && previous != local.programSourceId) {
        await widget.mediaBridge.setTally(sourceId: previous, onAir: false);
      }
      await widget.mediaBridge.setTally(
        sourceId: local.programSourceId,
        onAir: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.lastCutTake = CutTakeResult(
          action: bridge.action,
          previewSourceId: bridge.previewSourceId,
          previousProgramSourceId: bridge.previousProgramSourceId,
          programSourceId: bridge.programSourceId,
          issuedAtMs: bridge.issuedAtMs > 0 ? bridge.issuedAtMs : local.issuedAtMs,
          appliedAtMs:
              bridge.appliedAtMs > 0 ? bridge.appliedAtMs : local.appliedAtMs,
        );
      });
      widget.onProgramChanged?.call(local.programSourceId);
    } on CutTakeException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.preview = _buses.preview.copyWith(message: error.message);
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _buses.preview = _buses.preview.copyWith(
          message: 'Cut/Take failed: ${error.message}',
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

  @override
  Widget build(BuildContext context) {
    final preview = _buses.preview;
    final programLabel = _buses.programSourceId.isEmpty
        ? 'Program: none (awaiting explicit Cut/Take)'
        : 'Program: ${_buses.programSourceId}';
    final lastCut = _buses.lastCutTake;
    final audio = _buses.audio;
    final meters = audio.meters;
    final avSync = _buses.avSync;
    final health = _buses.health;
    final selectedAudio = audio.selectedSourceId.isEmpty
        ? null
        : audio.selectedSourceId;
    final previewReady = preview.sourceId.isNotEmpty || _previewSourceId.isNotEmpty;

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
            '(AC-2.1). Cut/Take is an explicit operator action (AC-2.2). '
            'Program camera receives tally (AC-2.3). Audio is independent '
            '(AC-2.4 / AC-2.5). A/V sync monitor and drift correction are '
            'available (AC-2.6). Connection health and source-loss fallback '
            'keep the director session alive (AC-2.7 / AC-2.8).',
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
                  key: const Key('preview-camera'),
                  initialValue: _previewSourceId,
                  decoration: const InputDecoration(
                    labelText: 'Camera source',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final id in _buses.cameraSourceIds)
                      DropdownMenuItem(value: id, child: Text(id)),
                  ],
                  onChanged: _busy ? null : handlePreviewCameraChanged,
                ),
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
                  key: const Key('program-feeds'),
                  _buses.programFeedsOutputs
                      ? 'Program feeds enabled outputs'
                      : 'No outputs fed until Program has a source',
                ),
                if (lastCut != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    key: const Key('cut-timing'),
                    'Last ${lastCut.action}: '
                    '${lastCut.previousProgramSourceId.isEmpty ? 'none' : lastCut.previousProgramSourceId}'
                    ' -> ${lastCut.programSourceId} '
                    '(${lastCut.cutLatencyMs} ms)',
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('cut-button'),
                      onPressed: _busy || !previewReady
                          ? null
                          : () => handleCutTake(CutTakeAction.cut),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B3D3D),
                        minimumSize: const Size(88, 48),
                      ),
                      child: const Text('Cut'),
                    ),
                    FilledButton(
                      key: const Key('take-button'),
                      onPressed: _busy || !previewReady
                          ? null
                          : () => handleCutTake(CutTakeAction.take),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5A3D),
                        minimumSize: const Size(88, 48),
                      ),
                      child: const Text('Take'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  key: const Key('cut-take-hint'),
                  previewReady
                      ? 'Cut/Take puts Preview source onto Program. '
                          'No silent auto-switch.'
                      : 'Start or select a Preview source before Cut/Take.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BusPanel(
            key: const Key('audio-panel'),
            title: 'Audio',
            semanticsLabel: 'Independent audio source and meters',
            accent: const Color(0xFF3D5A8B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const Key('audio-independence'),
                  'Audio does not follow Preview or Program video '
                  '(AC-2.4). Selected: ${selectedAudio ?? 'none'}.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('audio-source'),
                  initialValue: selectedAudio,
                  decoration: const InputDecoration(
                    labelText: 'Audio source',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final source in audio.sources)
                      DropdownMenuItem(
                        value: source.id,
                        child: Text(source.label),
                      ),
                  ],
                  onChanged: _busy ? null : handleAudioSourceChanged,
                ),
                const SizedBox(height: 12),
                Text(
                  key: const Key('audio-meters-label'),
                  'Meters (AC-2.5)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _MeterBar(
                  key: const Key('audio-meter-peak'),
                  label: 'Peak',
                  valueDb: meters.peakDb,
                  semanticsLabel: meters.peakDb == null
                      ? 'Peak meter empty'
                      : 'Peak ${meters.peakDb!.toStringAsFixed(1)} dB',
                ),
                const SizedBox(height: 8),
                _MeterBar(
                  key: const Key('audio-meter-rms'),
                  label: 'RMS',
                  valueDb: meters.rmsDb,
                  semanticsLabel: meters.rmsDb == null
                      ? 'RMS meter empty'
                      : 'RMS ${meters.rmsDb!.toStringAsFixed(1)} dB',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('refresh-audio-meters'),
                  onPressed: _busy || selectedAudio == null
                      ? null
                      : handleRefreshMeters,
                  child: const Text('Refresh meters'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BusPanel(
            key: const Key('av-sync-panel'),
            title: 'A/V sync',
            semanticsLabel: 'A/V sync monitor and drift correction',
            accent: const Color(0xFF6B4D8B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const Key('av-sync-status'),
                  avSync.hasReading
                      ? 'Offset: ${avSync.offsetMs!.toStringAsFixed(1)} ms'
                      : 'Offset: -- (not measured)',
                  semanticsLabel: avSync.hasReading
                      ? 'A/V offset ${avSync.offsetMs!.toStringAsFixed(1)} milliseconds'
                      : 'A/V offset not measured',
                ),
                const SizedBox(height: 4),
                Text(
                  key: const Key('av-sync-correction'),
                  'Correction applied: '
                  '${avSync.correctionMs.toStringAsFixed(1)} ms',
                ),
                if (avSync.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    key: const Key('av-sync-message'),
                    avSync.message,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('refresh-av-sync'),
                      onPressed: _busy ? null : handleRefreshAvSync,
                      child: const Text('Measure sync'),
                    ),
                    OutlinedButton(
                      key: const Key('apply-drift-correction'),
                      onPressed: _busy || !avSync.hasReading
                          ? null
                          : handleApplyDriftCorrection,
                      child: const Text('Apply drift correction'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BusPanel(
            key: const Key('source-health-panel'),
            title: 'Connection health',
            semanticsLabel: 'Source connection health and fallback',
            accent: const Color(0xFF8B6B3D),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const Key('session-alive'),
                  health.sessionAlive
                      ? 'Director session: alive'
                      : 'Director session: dead',
                  semanticsLabel: health.sessionAlive
                      ? 'Director session alive'
                      : 'Director session dead',
                ),
                const SizedBox(height: 4),
                Text(
                  key: const Key('health-fallback-label'),
                  'Program fallback: ${health.fallbackMode.wire}',
                ),
                if (health.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    key: const Key('health-message'),
                    health.message,
                  ),
                ],
                if (health.lastFallback != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    key: const Key('last-fallback'),
                    'Last fallback: ${health.lastFallback!.programSafeState} '
                    'for ${health.lastFallback!.lostSourceId} at '
                    '${health.lastFallback!.observedAtMs}',
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<ProgramFallbackMode>(
                  key: const Key('fallback-mode'),
                  initialValue: health.fallbackMode,
                  decoration: const InputDecoration(
                    labelText: 'Source-loss fallback',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ProgramFallbackMode.lastFrameFreeze,
                      child: Text('Last frame freeze'),
                    ),
                    DropdownMenuItem(
                      value: ProgramFallbackMode.slate,
                      child: Text('Slate'),
                    ),
                    DropdownMenuItem(
                      value: ProgramFallbackMode.alternateSource,
                      child: Text('Alternate source'),
                    ),
                  ],
                  onChanged: _busy ? null : handleFallbackModeChanged,
                ),
                const SizedBox(height: 12),
                if (health.sources.isEmpty)
                  const Text(
                    key: Key('health-empty'),
                    'No source health yet. Refresh or simulate a drop.',
                  )
                else
                  for (final entry in health.sources) ...[
                    Text(
                      key: Key('health-${entry.sourceId}'),
                      '${entry.sourceId}: ${entry.state.name} '
                      '@ ${entry.observedAtMs}'
                      '${entry.detail.isEmpty ? '' : ' (${entry.detail})'}',
                      semanticsLabel:
                          '${entry.sourceId} health ${entry.state.name}',
                    ),
                    const SizedBox(height: 4),
                  ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('refresh-source-health'),
                      onPressed: _busy ? null : handleRefreshSourceHealth,
                      child: const Text('Refresh health'),
                    ),
                    OutlinedButton(
                      key: const Key('simulate-source-loss-cam-1'),
                      onPressed: _busy
                          ? null
                          : () => handleSimulateSourceLoss('cam-1'),
                      child: const Text('Simulate cam-1 drop'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterBar extends StatelessWidget {
  const _MeterBar({
    super.key,
    required this.label,
    required this.valueDb,
    required this.semanticsLabel,
  });

  final String label;
  final double? valueDb;
  final String semanticsLabel;

  /// Map dBFS roughly into 0..1 for a simple bar (silence near -90).
  double get _fraction {
    final value = valueDb;
    if (value == null) {
      return 0;
    }
    const minDb = -60.0;
    const maxDb = 0.0;
    final clamped = value.clamp(minDb, maxDb);
    return (clamped - minDb) / (maxDb - minDb);
  }

  @override
  Widget build(BuildContext context) {
    final text = valueDb == null ? '$label: --' : '$label: ${valueDb!.toStringAsFixed(1)} dB';
    return Semantics(
      label: semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          const SizedBox(height: 4),
          SizedBox(
            height: 12,
            child: LinearProgressIndicator(
              value: _fraction,
              backgroundColor: const Color(0xFF1A2A22),
              color: const Color(0xFF3D8B6E),
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
