import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'capability_matrix.dart';
import 'pairing/ble_discovery.dart';
import 'pairing/control_medium.dart';
import 'pairing/media_medium.dart';
import 'pairing/pairing_session.dart';
import 'roles.dart';

/// Pairing UI: QR/manual always; BLE gated by matrix; director approve (AC-1.*).
class PairingPage extends StatefulWidget {
  const PairingPage({
    super.key,
    required this.session,
    required this.platform,
  });

  final PairingSession session;
  final MatrixPlatform platform;

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final TextEditingController _hostController =
      TextEditingController(text: '192.168.1.10');
  final TextEditingController _portController =
      TextEditingController(text: '7400');
  final TextEditingController _deviceLabelController =
      TextEditingController(text: 'Camera A');
  final TextEditingController _joinHostController =
      TextEditingController(text: '192.168.1.10');
  final TextEditingController _joinPortController =
      TextEditingController(text: '7400');

  ControlMedium _offerMedium = ControlMedium.qr;
  String _mediaMedium = 'wifi';
  String _status = 'Media uses Wi-Fi or Ethernet only. Cellular and BLE are refused.';
  PairingOffer? _lastOffer;
  BleDiscoveryOutcome? _bleOutcome;
  final Set<ProductionRole> _requestedRoles = <ProductionRole>{
    ProductionRole.camera,
  };

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _deviceLabelController.dispose();
    _joinHostController.dispose();
    _joinPortController.dispose();
    super.dispose();
  }

  void handleCreateOffer() {
    try {
      final port = int.parse(_portController.text.trim());
      final offer = widget.session.createOffer(
        controlMedium: _offerMedium,
        host: _hostController.text,
        port: port,
      );
      setState(() {
        _lastOffer = offer;
        _status = 'Offer created (${offer.controlMedium.wire}). '
            'Share the QR/manual payload with producers.';
      });
    } catch (error) {
      setState(() {
        _status = 'Offer failed: $error';
      });
    }
  }

  Future<void> handleCopyOffer() async {
    final offer = _lastOffer;
    if (offer == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: offer.toSharePayload()));
    setState(() {
      _status = 'Offer payload copied for QR encoding or paste join';
    });
  }

  void handleBleDiscovery() {
    final outcome = widget.session.startBleDiscovery(widget.platform);
    setState(() {
      _bleOutcome = outcome;
      _status = outcome.detail;
    });
  }

  void handleSubmitJoinRequest() {
    try {
      if (_requestedRoles.isEmpty) {
        setState(() {
          _status = 'Select at least one role';
        });
        return;
      }
      final request = PairingRequest(
        requestId: 'req-${DateTime.now().millisecondsSinceEpoch}',
        offerId: _lastOffer?.offerId,
        deviceId: 'dev-${DateTime.now().millisecondsSinceEpoch}',
        deviceLabel: _deviceLabelController.text.trim().isEmpty
            ? 'Producer'
            : _deviceLabelController.text.trim(),
        requestedRoles: _requestedRoles.toList(),
        controlMedium: ControlMedium.manualIp,
        mediaMedium: _mediaMedium,
      );
      final ack = widget.session.receiveRequest(
        request,
        platform: widget.platform,
      );
      setState(() {
        _status =
            'Request ${request.requestId} queued as ${ack.name}; waiting for director approval';
      });
    } on PairingRejectException catch (error) {
      setState(() {
        _status = error.message;
      });
    } on MediaMediumRefused catch (error) {
      setState(() {
        _status = error.message;
      });
    } catch (error) {
      setState(() {
        _status = 'Join request failed: $error';
      });
    }
  }

  void handleApprove(String requestId) {
    try {
      final member = widget.session.approve(
        requestId: requestId,
        platform: widget.platform,
      );
      setState(() {
        _status =
            'Approved ${member.deviceLabel} (${member.deviceId}); '
            'roles=${member.roles.map((role) => role.id).join('+')}; '
            'in session=${widget.session.isInSession(member.deviceId)}';
      });
    } on PairingRejectException catch (error) {
      setState(() {
        _status = error.message;
      });
    } catch (error) {
      setState(() {
        _status = 'Approve failed: $error';
      });
    }
  }

  void handleReject(String requestId) {
    try {
      widget.session.reject(requestId: requestId);
      setState(() {
        _status = 'Rejected request $requestId';
      });
    } catch (error) {
      setState(() {
        _status = 'Reject failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleAllowed =
        widget.session.allowsControlMedium(ControlMedium.ble, widget.platform);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairing'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Control pairing: QR and manual IP always available. '
            'BLE only when the capability matrix allows '
            '(${widget.platform.name}: ${bleAllowed ? "allowed" : "blocked"}).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Media: Wi-Fi or Ethernet only. Cellular and BLE are refused.',
            style: Theme.of(context).textTheme.bodyMedium,
            semanticsLabel:
                'Media streams use Wi-Fi or Ethernet only. Cellular and BLE are refused.',
          ),
          const SizedBox(height: 24),
          Text('Director offer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('QR'),
                selected: _offerMedium == ControlMedium.qr,
                onSelected: (_) {
                  setState(() {
                    _offerMedium = ControlMedium.qr;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Manual IP'),
                selected: _offerMedium == ControlMedium.manualIp,
                onSelected: (_) {
                  setState(() {
                    _offerMedium = ControlMedium.manualIp;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Control host',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Control port',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: handleCreateOffer,
                child: const Text('Create offer'),
              ),
              OutlinedButton(
                onPressed: _lastOffer == null ? null : handleCopyOffer,
                child: const Text('Copy QR / share payload'),
              ),
              OutlinedButton(
                onPressed: handleBleDiscovery,
                child: const Text('Start BLE discovery'),
              ),
            ],
          ),
          if (_lastOffer != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _lastOffer!.toSharePayload(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_bleOutcome != null) ...[
            const SizedBox(height: 8),
            Text(
              'BLE status: ${_bleOutcome!.status.name}. ${_bleOutcome!.detail}',
              key: const Key('ble-discovery-status'),
              semanticsLabel: 'BLE discovery ${_bleOutcome!.status.name}',
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Producer join request',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deviceLabelController,
            decoration: const InputDecoration(
              labelText: 'Device label',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Requested roles',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in allProductionRoles)
                FilterChip(
                  label: Text(role.label),
                  selected: _requestedRoles.contains(role),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _requestedRoles.add(role);
                      } else {
                        _requestedRoles.remove(role);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _joinHostController,
            decoration: const InputDecoration(
              labelText: 'Director host (manual IP)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _joinPortController,
            decoration: const InputDecoration(
              labelText: 'Director port',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _mediaMedium,
            decoration: const InputDecoration(
              labelText: 'Media medium',
              border: OutlineInputBorder(),
              helperText: 'Wi-Fi or Ethernet only',
            ),
            items: [
              for (final medium in allowedMediaMediums)
                DropdownMenuItem(value: medium, child: Text(medium)),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _mediaMedium = value;
              });
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: handleSubmitJoinRequest,
            child: const Text('Submit join request'),
          ),
          const SizedBox(height: 24),
          Text(
            'Pending approval (director gate)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (widget.session.pending.isEmpty)
            const Text('No pending devices')
          else
            for (final request in widget.session.pending) ...[
              Text(
                '${request.deviceLabel} (${request.deviceId})',
                key: Key('pending-${request.requestId}'),
              ),
              Text(
                '${request.controlMedium.wire} · media=${request.mediaMedium} · '
                'roles=${request.requestedRoles.map((role) => role.id).join('+')}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => handleApprove(request.requestId),
                    child: const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: () => handleReject(request.requestId),
                    child: const Text('Reject'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          const SizedBox(height: 16),
          Text(
            'Joined (${widget.session.joined.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final member in widget.session.joined.values)
            Text(
              '${member.deviceLabel} — approved_by_director=${member.approvedByDirector}',
            ),
          const SizedBox(height: 16),
          Text(_status),
        ],
      ),
    );
  }
}
