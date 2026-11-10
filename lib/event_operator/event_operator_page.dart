import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'authority_store.dart';
import 'fields.dart';
import 'ocr_reading.dart';

/// Event Operator shell: clocks, scores, authority, event log (AC-5.*).
class EventOperatorPage extends StatefulWidget {
  const EventOperatorPage({
    super.key,
    this.store,
  });

  final AuthorityStore? store;

  @override
  State<EventOperatorPage> createState() => _EventOperatorPageState();
}

class _EventOperatorPageState extends State<EventOperatorPage> {
  late final AuthorityStore _store;
  late final TextEditingController _homeScoreController;
  late final TextEditingController _awayScoreController;
  late final TextEditingController _clockController;
  int _commandSeq = 0;
  String _status = 'Ready';
  String? _lastEventId;

  @override
  void initState() {
    super.initState();
    _store = widget.store ??
        AuthorityStore(
          sessionId: 'sess-local',
          deviceId: 'evt-op-local',
        );
    _store.syncClockFromTimer();
    _homeScoreController = TextEditingController(
      text: '${_store.fieldState(ScoreField.homeScore).value}',
    );
    _awayScoreController = TextEditingController(
      text: '${_store.fieldState(ScoreField.awayScore).value}',
    );
    _clockController = TextEditingController(
      text: '${_store.fieldState(ScoreField.clock).value}',
    );
  }

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _clockController.dispose();
    super.dispose();
  }

  String _nextCommandId(String prefix) {
    _commandSeq += 1;
    return '$prefix-$_commandSeq';
  }

  void handleStartTimer() {
    _store.timer.start();
    _store.syncClockFromTimer();
    setState(() {
      _clockController.text = '${_store.fieldState(ScoreField.clock).value}';
      _status = 'Manual timer running';
    });
  }

  void handlePauseTimer() {
    _store.timer.pause();
    _store.syncClockFromTimer();
    setState(() {
      _clockController.text = '${_store.fieldState(ScoreField.clock).value}';
      _status = 'Manual timer paused';
    });
  }

  void handleSetClock() {
    final result = _store.setField(
      commandId: _nextCommandId('cmd-clock'),
      field: ScoreField.clock,
      value: _clockController.text.trim(),
      authority: FieldAuthority.manual,
    );
    setState(() {
      _status = result.message;
      _lastEventId = result.event?.eventId;
      _clockController.text = '${_store.fieldState(ScoreField.clock).value}';
    });
  }

  void handleSetHomeScore() {
    final parsed = int.tryParse(_homeScoreController.text.trim());
    if (parsed == null) {
      setState(() {
        _status = 'Home score must be an integer';
      });
      return;
    }
    final authority = _store.fieldState(ScoreField.homeScore).authority;
    final result = _store.setField(
      commandId: _nextCommandId('cmd-home'),
      field: ScoreField.homeScore,
      value: parsed,
      authority: authority,
    );
    setState(() {
      _status = result.message;
      _lastEventId = result.event?.eventId;
    });
  }

  void handleSetAwayScore() {
    final parsed = int.tryParse(_awayScoreController.text.trim());
    if (parsed == null) {
      setState(() {
        _status = 'Away score must be an integer';
      });
      return;
    }
    final authority = _store.fieldState(ScoreField.awayScore).authority;
    final result = _store.setField(
      commandId: _nextCommandId('cmd-away'),
      field: ScoreField.awayScore,
      value: parsed,
      authority: authority,
    );
    setState(() {
      _status = result.message;
      _lastEventId = result.event?.eventId;
    });
  }

  void handleToggleAuthority(ScoreField field) {
    final current = _store.fieldState(field);
    final next = current.authority == FieldAuthority.manual
        ? FieldAuthority.ocrAssisted
        : FieldAuthority.manual;
    final result = _store.setField(
      commandId: _nextCommandId('cmd-auth'),
      field: field,
      value: current.value,
      authority: next,
    );
    setState(() {
      _status = result.message;
      _lastEventId = result.event?.eventId;
    });
  }

  void handleConfirm(ScoreField field) {
    final result = _store.confirmField(
      commandId: _nextCommandId('cmd-confirm'),
      field: field,
      action: ConfirmAction.confirm,
    );
    setState(() {
      _status = result.message;
      _lastEventId = result.event?.eventId;
    });
  }

  void handleLock(ScoreField field) {
    final result = _store.confirmField(
      commandId: _nextCommandId('cmd-lock'),
      field: field,
      action: ConfirmAction.lock,
    );
    setState(() {
      _status = result.message;
      _lastEventId = result.event?.eventId;
    });
  }

  void handleSimulateOcr({
    required ScoreField field,
    required Object value,
    required double confidence,
  }) {
    final result = _store.applyOcrReading(
      commandId: _nextCommandId('cmd-ocr'),
      reading: OcrReading(
        field: field,
        value: value,
        confidence: confidence,
        capturedAt: DateTime.now().toUtc(),
        stale: false,
      ),
    );
    setState(() {
      _status = result.message;
      _lastEventId = result.event?.eventId;
      if (field == ScoreField.homeScore) {
        _homeScoreController.text =
            '${_store.fieldState(ScoreField.homeScore).value}';
      }
    });
  }

  void handleUndoLast() {
    final target = _lastEventId;
    if (target == null) {
      setState(() {
        _status = 'No event to undo';
      });
      return;
    }
    final result = _store.undo(
      commandId: _nextCommandId('cmd-undo'),
      targetEventId: target,
    );
    setState(() {
      _status = result.message;
      _lastEventId = result.event?.eventId;
      _homeScoreController.text =
          '${_store.fieldState(ScoreField.homeScore).value}';
      _awayScoreController.text =
          '${_store.fieldState(ScoreField.awayScore).value}';
      _clockController.text = '${_store.fieldState(ScoreField.clock).value}';
    });
  }

  void handleEmitSnapshot() {
    final snapshot = _store.emitSnapshot();
    setState(() {
      _status =
          'Snapshot ${snapshot.snapshotId} at seq ${snapshot.eventLogSeq}';
      _lastEventId = _store.log.records.isEmpty
          ? null
          : _store.log.records.last.eventId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = _store.fieldState(ScoreField.homeScore);
    final away = _store.fieldState(ScoreField.awayScore);
    final clock = _store.fieldState(ScoreField.clock);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Operator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            key: const Key('broadcast-aid-copy'),
            AuthorityStore.broadcastAidCopy,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Manual clock (default authority)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('clock-authority'),
            'Authority: ${clock.authority.wire}'
            '${clock.confirmed ? ', confirmed' : ''}'
            '${clock.locked ? ', locked' : ''}',
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('clock-input'),
            controller: _clockController,
            decoration: const InputDecoration(
              labelText: 'Clock (mm:ss)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('timer-start'),
                onPressed: handleStartTimer,
                child: const Text('Start'),
              ),
              OutlinedButton(
                key: const Key('timer-pause'),
                onPressed: handlePauseTimer,
                child: const Text('Pause'),
              ),
              OutlinedButton(
                key: const Key('clock-set'),
                onPressed: handleSetClock,
                child: const Text('Set clock'),
              ),
              OutlinedButton(
                key: const Key('clock-confirm'),
                onPressed: () => handleConfirm(ScoreField.clock),
                child: const Text('Confirm clock'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Scores',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('home-score-input'),
            controller: _homeScoreController,
            decoration: InputDecoration(
              labelText:
                  'Home score (${home.authority.wire}'
                  '${home.confirmed ? ', confirmed' : ''}'
                  '${home.locked ? ', locked' : ''})',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('home-score-set'),
                onPressed: handleSetHomeScore,
                child: const Text('Set home'),
              ),
              OutlinedButton(
                key: const Key('home-authority-toggle'),
                onPressed: () => handleToggleAuthority(ScoreField.homeScore),
                child: const Text('Toggle home authority'),
              ),
              OutlinedButton(
                key: const Key('home-confirm'),
                onPressed: () => handleConfirm(ScoreField.homeScore),
                child: const Text('Confirm home'),
              ),
              OutlinedButton(
                key: const Key('home-lock'),
                onPressed: () => handleLock(ScoreField.homeScore),
                child: const Text('Lock home'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('away-score-input'),
            controller: _awayScoreController,
            decoration: InputDecoration(
              labelText:
                  'Away score (${away.authority.wire}'
                  '${away.confirmed ? ', confirmed' : ''}'
                  '${away.locked ? ', locked' : ''})',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('away-score-set'),
                onPressed: handleSetAwayScore,
                child: const Text('Set away'),
              ),
              OutlinedButton(
                key: const Key('away-confirm'),
                onPressed: () => handleConfirm(ScoreField.awayScore),
                child: const Text('Confirm away'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'OCR assist (sim)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('ocr-high'),
                onPressed: () => handleSimulateOcr(
                  field: ScoreField.homeScore,
                  value: 99,
                  confidence: 0.95,
                ),
                child: const Text('OCR high conf'),
              ),
              OutlinedButton(
                key: const Key('ocr-low'),
                onPressed: () => handleSimulateOcr(
                  field: ScoreField.homeScore,
                  value: 77,
                  confidence: 0.2,
                ),
                child: const Text('OCR low conf'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Event log',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('event-log-seq'),
            'Seq: ${_store.log.seq} · records: ${_store.log.records.length}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('undo-last'),
                onPressed: handleUndoLast,
                child: const Text('Compensating undo'),
              ),
              FilledButton(
                key: const Key('emit-snapshot'),
                onPressed: handleEmitSnapshot,
                child: const Text('Emit late-joiner snapshot'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            key: const Key('event-operator-status'),
            _status,
            semanticsLabel: _status,
          ),
          const SizedBox(height: 12),
          for (final record in _store.log.records.reversed.take(8))
            Text(
              key: Key('event-${record.eventId}'),
              '#${record.seq} ${record.type} ${record.eventId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        ),
      ),
    );
  }
}
