import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera/camera_page.dart';
import 'camera/tally.dart';
import 'capability_matrix.dart';
import 'director/director_page.dart';
import 'event_operator/event_operator_page.dart';
import 'layout_editor/layout_editor_page.dart';
import 'lineups/lineup_page.dart';
import 'media_bridge.dart';
import 'pairing/pairing_session.dart';
import 'pairing_page.dart';
import 'role_assignment.dart';
import 'roles.dart';

/// Role shell: assign any of seven roles; combinations gated (AC-1.5, AC-1.6).
class RoleShellPage extends StatefulWidget {
  const RoleShellPage({
    super.key,
    this.mediaBridge,
    this.matrix = const CapabilityMatrix(),
    this.releaseBuild,
  });

  final MediaBridge? mediaBridge;
  final CapabilityMatrix matrix;
  final bool? releaseBuild;

  @override
  State<RoleShellPage> createState() => _RoleShellPageState();
}

class _RoleShellPageState extends State<RoleShellPage> {
  late final MediaBridge _media;
  late final RoleAssignment _assignment;
  final Set<ProductionRole> _selected = <ProductionRole>{};
  List<ProductionRole> _applied = const [];
  String _assignStatus = 'No role assigned';
  String _mediaStatus = 'Media callback not invoked yet';
  bool _pinging = false;
  String _programSourceId = '';
  final String _cameraSourceId = 'cam-1';

  @override
  void initState() {
    super.initState();
    _media = widget.mediaBridge ?? MediaBridge();
    _assignment = RoleAssignment(
      matrix: widget.matrix,
      releaseBuild: widget.releaseBuild,
    );
  }

  MatrixPlatform _hostPlatform() {
    if (kIsWeb) {
      return MatrixPlatform.android;
    }
    if (Platform.isAndroid) {
      return MatrixPlatform.android;
    }
    if (Platform.isIOS) {
      return MatrixPlatform.ios;
    }
    if (Platform.isWindows) {
      return MatrixPlatform.windows;
    }
    if (Platform.isLinux) {
      return MatrixPlatform.linux;
    }
    if (Platform.isMacOS) {
      return MatrixPlatform.macos;
    }
    return MatrixPlatform.windows;
  }

  void handleRoleToggled(ProductionRole role, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(role);
      } else {
        _selected.remove(role);
      }
    });
  }

  void handleApplyRoles() {
    try {
      final result = _assignment.assign(
        roles: _selected,
        platform: _hostPlatform(),
      );
      setState(() {
        _applied = result.roles;
        if (_applied.isEmpty) {
          _assignStatus = 'No role assigned';
        } else if (_applied.length == 1) {
          _assignStatus =
              'Assigned: ${_applied.first.label} (${_applied.first.id})';
        } else {
          final labels = _applied.map((role) => role.label).join(', ');
          _assignStatus =
              'Assigned combination: $labels '
              '(matrix=${result.combinationState.name}'
              '${_assignment.releaseBuild ? ', release' : ', non-release'})';
        }
      });
    } on RoleAssignmentException catch (error) {
      setState(() {
        _assignStatus = error.message;
      });
    }
  }

  Future<void> handlePingMedia() async {
    if (_pinging) {
      return;
    }
    setState(() {
      _pinging = true;
      _mediaStatus = 'Calling native media callback...';
    });
    try {
      final result = await _media.pingMedia();
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaStatus =
            'Media callback OK: platform=${result.platform} stamp=${result.stamp}';
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaStatus =
            'Media callback missing on this host (plugin not registered)';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaStatus = 'Media callback failed: ${error.code} ${error.message}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaStatus = 'Media callback failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _pinging = false;
        });
      }
    }
  }

  void handleOpenPairing() {
    final session = PairingSession(
      sessionId: 'sess-local',
      directorDeviceId: 'dir-local',
      matrix: widget.matrix,
      releaseBuild: widget.releaseBuild,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PairingPage(
          session: session,
          platform: _hostPlatform(),
        ),
      ),
    );
  }

  void handleOpenDirector() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DirectorPage(
          mediaBridge: _media,
          onProgramChanged: (sourceId) {
            setState(() {
              _programSourceId = sourceId;
            });
          },
        ),
      ),
    );
  }

  void handleOpenCamera() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CameraPage(
          tally: CameraTally(
            cameraSourceId: _cameraSourceId,
            programSourceId: _programSourceId,
          ),
        ),
      ),
    );
  }

  void handleOpenEventOperator() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const EventOperatorPage(),
      ),
    );
  }

  void handleOpenLayoutEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const LayoutEditorPage(),
      ),
    );
  }

  void handleOpenLineups() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const LineupPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = _hostPlatform();
    final combinationNote = widget.matrix.roleCombination(_selected, platform);
    final combinationBlockedInRelease = _selected.length >= 2 &&
        combinationNote.state != CapabilityState.verified &&
        combinationNote.state != CapabilityState.partial;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Matchday — role shell'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Select production roles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Each of the seven roles is assignable (AC-1.5). '
            'Combinations require a verified or partial capability matrix '
            'cell in release builds (AC-1.6).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in allProductionRoles)
                FilterChip(
                  label: Text(role.label),
                  selected: _selected.contains(role),
                  onSelected: (selected) => handleRoleToggled(role, selected),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selected.length >= 2)
            Text(
              key: const Key('combination-gate-status'),
              'Combination ${CapabilityMatrix.combinationKey(_selected)} on '
              '${platform.name}: ${combinationNote.state.name}'
              '${combinationBlockedInRelease ? ' (blocked in release)' : ''}',
              semanticsLabel:
                  'Role combination matrix state ${combinationNote.state.name}',
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('apply-roles'),
            onPressed: handleApplyRoles,
            child: const Text('Apply role assignment'),
          ),
          const SizedBox(height: 12),
          Text(
            _assignStatus,
            key: const Key('assign-status'),
            semanticsLabel: _assignStatus,
          ),
          const SizedBox(height: 24),
          Text(
            'Role shells',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final role in allProductionRoles)
            _RoleShellCard(
              role: role,
              active: _applied.contains(role),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _pinging ? null : handlePingMedia,
            child: const Text('Ping media callback'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: handleOpenPairing,
            child: const Text('Open pairing'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('open-director'),
            onPressed: handleOpenDirector,
            child: const Text('Open director'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('open-camera'),
            onPressed: handleOpenCamera,
            child: const Text('Open camera tally'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('open-event-operator'),
            onPressed: handleOpenEventOperator,
            child: const Text('Open event operator'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('open-layout-editor'),
            onPressed: handleOpenLayoutEditor,
            child: const Text('Open layout editor'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('open-lineups'),
            onPressed: handleOpenLineups,
            child: const Text('Open lineups'),
          ),
          const SizedBox(height: 12),
          Text(
            key: const Key('program-source-status'),
            _programSourceId.isEmpty
                ? 'Program source: none'
                : 'Program source: $_programSourceId',
          ),
          const SizedBox(height: 12),
          Text(_mediaStatus),
        ],
      ),
    );
  }
}

class _RoleShellCard extends StatelessWidget {
  const _RoleShellCard({
    required this.role,
    required this.active,
  });

  final ProductionRole role;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isDirector = role == ProductionRole.director;
    final isCamera = role == ProductionRole.camera;
    return Semantics(
      label: '${role.label} shell${active ? ', active' : ''}',
      child: Container(
        key: Key('role-shell-${role.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active
              ? (isDirector
                  ? const Color(0xFF13261F)
                  : isCamera
                      ? const Color(0xFF243028)
                      : const Color(0xFF1A2420))
              : const Color(0xFF121816),
          border: Border.all(
            color: active
                ? const Color(0xFF3D8B6E)
                : const Color(0xFF2A3832),
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              role.responsibility,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
