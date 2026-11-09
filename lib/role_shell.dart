import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'capability_matrix.dart';
import 'media_bridge.dart';
import 'pairing/pairing_session.dart';
import 'pairing_page.dart';
import 'roles.dart';

/// Minimal role shell: assign one of seven roles, ping media, open pairing.
class RoleShellPage extends StatefulWidget {
  const RoleShellPage({super.key, this.mediaBridge});

  final MediaBridge? mediaBridge;

  @override
  State<RoleShellPage> createState() => _RoleShellPageState();
}

class _RoleShellPageState extends State<RoleShellPage> {
  late final MediaBridge _media;
  ProductionRole? _selected;
  String _mediaStatus = 'Media callback not invoked yet';
  bool _pinging = false;

  @override
  void initState() {
    super.initState();
    _media = widget.mediaBridge ?? MediaBridge();
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

  void handleRoleSelected(ProductionRole? role) {
    setState(() {
      _selected = role;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Matchday — role shell'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select a production role',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in allProductionRoles)
                  ChoiceChip(
                    label: Text(role.label),
                    selected: _selected == role,
                    onSelected: (selected) {
                      if (selected) {
                        handleRoleSelected(role);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _selected == null
                  ? 'No role assigned'
                  : 'Assigned: ${_selected!.label} (${_selected!.id})',
              semanticsLabel: _selected == null
                  ? 'No role assigned'
                  : 'Assigned role ${_selected!.label}',
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
            Text(_mediaStatus),
          ],
        ),
      ),
    );
  }
}
