import 'package:flutter/material.dart';

import 'lineup_models.dart';
import 'lineup_store.dart';

/// Event-operator lineup shell: geometry summary, photos, preview-before-Program.
class LineupPage extends StatefulWidget {
  const LineupPage({
    super.key,
    this.store,
  });

  final LineupStore? store;

  @override
  State<LineupPage> createState() => _LineupPageState();
}

class _LineupPageState extends State<LineupPage> {
  late final LineupStore _store;
  String _status = 'Edit lineup, then preview before Program (AC-7.6).';

  @override
  void initState() {
    super.initState();
    _store = widget.store ??
        LineupStore(
          initialDraft: LineupDraft(
            side: 'home',
            teamName: 'North Harbor Foxes',
            sportId: 'basketball',
            formationId: 'starting_five',
            revision: 'rev-demo',
            starters: const <LineupPlayer>[
              LineupPlayer(
                playerId: 'alex_rivera',
                name: 'Alex Rivera',
                number: 7,
                positionId: 'point_guard',
                positionLabel: 'Point Guard',
                photoHref: 'photos/alex_rivera.png',
                focalX: 0.5,
                focalY: 0.5,
                isCaptain: true,
              ),
              LineupPlayer(
                playerId: 'blake_nguyen',
                name: 'Blake Nguyen',
                number: 12,
                positionId: 'shooting_guard',
                positionLabel: 'Shooting Guard',
                photoHref: 'photos/blake_nguyen.png',
                focalX: 0.35,
                focalY: 0.4,
              ),
              LineupPlayer(
                playerId: 'eden_park',
                name: 'Eden Park',
                number: 21,
                positionId: 'small_forward',
                positionLabel: 'Small Forward',
              ),
              LineupPlayer(
                playerId: 'finley_ortiz',
                name: 'Finley Ortiz',
                number: 33,
                positionId: 'power_forward',
                positionLabel: 'Power Forward',
              ),
              LineupPlayer(
                playerId: 'gray_morrison',
                name: 'Gray Morrison',
                number: 15,
                positionId: 'center',
                positionLabel: 'Center',
              ),
            ],
            substitutes: const <LineupPlayer>[
              LineupPlayer(
                playerId: 'harper_quinn',
                name: 'Harper Quinn',
                number: 8,
                positionId: 'point_guard',
                positionLabel: 'Point Guard',
                isSubstitute: true,
              ),
              LineupPlayer(
                playerId: 'indie_vale',
                name: 'Indie Vale',
                number: 5,
                positionId: 'center',
                positionLabel: 'Center',
                isSubstitute: true,
              ),
            ],
          ),
        );
  }

  void handleToggleReducedMotion(bool? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _store.setReducedMotion(value);
      _status = value
          ? 'Reduced motion on (WCAG 2.2 / sports package cut|fade)'
          : 'Full entry/exit motion allowed';
    });
  }

  void handleBumpDraft() {
    final next = _store.draft.copyWith(
      teamName: '${_store.draft.teamName}*',
    );
    final result = _store.updateDraft(next);
    setState(() {
      _status = result.message;
    });
  }

  void handlePreview() {
    final result = _store.markPreviewed();
    setState(() {
      _status = result.message;
    });
  }

  void handleTakeToProgram() {
    final result = _store.takeToProgram();
    setState(() {
      _status = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = _store.draft;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F1412),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13261F),
        title: const Text('Lineups'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            draft.teamName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFF5F5F5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sport ${draft.sportId} / formation ${draft.formationId}. '
            'Geometry comes from the sports package field; photos use focal crop '
            'with neutral number fallbacks when missing (AC-7.1–7.2).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFC4C4C4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            key: const Key('lineup-air-state'),
            'Air state: ${_store.airState.wire}; revision ${draft.revision}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFF5F5F5),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('reduced-motion-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Reduced motion',
              style: TextStyle(color: Color(0xFFF5F5F5)),
            ),
            subtitle: const Text(
              'Uses sports package reduced_motion cut/fade (AC-7.5)',
              style: TextStyle(color: Color(0xFFC4C4C4)),
            ),
            value: _store.reducedMotion,
            onChanged: handleToggleReducedMotion,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('lineup-edit-draft'),
            onPressed: handleBumpDraft,
            child: const Text('Edit draft'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('lineup-preview'),
            onPressed: handlePreview,
            child: const Text('Preview lineup'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('lineup-take-program'),
            onPressed: handleTakeToProgram,
            child: const Text('Take to Program'),
          ),
          const SizedBox(height: 12),
          Text(
            key: const Key('lineup-status'),
            _status,
            semanticsLabel: _status,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFC4C4C4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Starters',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFFF5F5F5),
            ),
          ),
          const SizedBox(height: 8),
          for (final player in draft.starters)
            _PlayerRow(player: player, roleLabel: 'Starter'),
          const SizedBox(height: 16),
          Text(
            'Substitutes',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFFF5F5F5),
            ),
          ),
          const SizedBox(height: 8),
          for (final player in draft.substitutes)
            _PlayerRow(player: player, roleLabel: 'Substitute'),
        ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.roleLabel,
  });

  final LineupPlayer player;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final markers = <String>[
      if (player.isCaptain) 'captain',
      ...player.markers.where((m) => m != 'none'),
    ];
    final photoLabel = player.photoHref == null
        ? 'fallback #${player.number}'
        : 'photo focal ${player.focalX},${player.focalY}';
    return Semantics(
      label:
          '$roleLabel ${player.number} ${player.name} ${player.positionLabel}',
      child: Container(
        key: Key('lineup-player-${player.playerId}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: roleLabel == 'Substitute'
              ? const Color(0xFF1A2220)
              : const Color(0xFF18241F),
          border: Border(
            left: BorderSide(
              color: roleLabel == 'Substitute'
                  ? const Color(0xFF6B6B6B)
                  : const Color(0xFFC4C4C4),
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${player.number} ${player.name}',
              style: const TextStyle(
                color: Color(0xFFF5F5F5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${player.positionLabel.isEmpty ? player.positionId : player.positionLabel}'
              ' · $roleLabel · $photoLabel'
              '${markers.isEmpty ? '' : ' · ${markers.join(', ')}'}',
              style: const TextStyle(color: Color(0xFFC4C4C4), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
