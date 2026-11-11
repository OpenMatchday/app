import 'package:flutter/material.dart';

import 'connected_accounts_models.dart';
import 'connected_accounts_store.dart';

/// Connected accounts: provider, capabilities, status, revoke (AC-11.1/11.2).
class ConnectedAccountsPage extends StatefulWidget {
  const ConnectedAccountsPage({super.key, this.store});

  final ConnectedAccountsStore? store;

  @override
  State<ConnectedAccountsPage> createState() => _ConnectedAccountsPageState();
}

class _ConnectedAccountsPageState extends State<ConnectedAccountsPage> {
  late final ConnectedAccountsStore _store;
  late String _providerId;
  final TextEditingController _labelController = TextEditingController();
  String _status = 'Social connections only; other credential planes stay separate';

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ConnectedAccountsStore();
    _providerId = _store.providers.first.id;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void handleProviderChanged(String? id) {
    if (id == null || id == _providerId) {
      return;
    }
    setState(() {
      _providerId = id;
    });
  }

  void handleConnect() {
    final result = _store.connect(
      providerId: _providerId,
      accountLabel: _labelController.text,
      opaqueTokenRef: 'local-ref-$_providerId-${_store.connections.length + 1}',
    );
    setState(() {
      _status = result.message;
      if (result.ok) {
        _labelController.clear();
      }
    });
  }

  void handleRevoke(String connectionId) {
    final result = _store.revoke(connectionId);
    setState(() {
      _status = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(!_store.displaysTokenMaterial());
    assert(_store.otherPlanesLackSocialTokens());
    final provider = _store.providerById(_providerId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected accounts'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Credential planes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('connected-planes'),
            'Separate stores: ${_store.planes.join(', ')}. '
            'This screen uses only $socialConnectionsPlane.',
            semanticsLabel: 'Credential planes are separate',
          ),
          const SizedBox(height: 24),
          Text(
            'Connections (${_store.connections.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_store.connections.isEmpty)
            const Text(
              key: Key('connected-empty'),
              'No social connections yet.',
            ),
          for (final account in _store.connections)
            Padding(
              key: Key('connected-row-${account.connectionId}'),
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key: Key('connected-provider-${account.connectionId}'),
                    account.providerDisplayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    key: Key('connected-label-${account.connectionId}'),
                    'Account: ${account.accountLabel}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    key: Key(
                      'connected-capabilities-${account.connectionId}',
                    ),
                    'Capabilities: ${account.capabilities.join(', ')}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    key: Key('connected-status-${account.connectionId}'),
                    'Status: ${account.status}',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: Key('connected-revoke-${account.connectionId}'),
                    onPressed: account.revokeAvailable
                        ? () => handleRevoke(account.connectionId)
                        : null,
                    child: const Text('Revoke'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            key: const Key('connected-status-message'),
            _status,
            semanticsLabel: _status,
          ),
          const SizedBox(height: 24),
          Text(
            'Add connection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'OAuth authorize stays owner-gated while runtime_enabled is false. '
            'Connect stores an opaque local ref for UI and revoke testing.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('connected-provider'),
            initialValue: _providerId,
            decoration: const InputDecoration(
              labelText: 'Provider',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final row in _store.providers)
                DropdownMenuItem<String>(
                  value: row.id,
                  child: Text(row.displayName),
                ),
            ],
            onChanged: handleProviderChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('connected-account-label'),
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Account label',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            key: const Key('connected-provider-capabilities'),
            'Capabilities: ${provider.capabilities.join(', ')}',
            semanticsLabel: 'Provider capabilities',
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('connected-connect'),
            onPressed: handleConnect,
            child: const Text('Connect (local ref)'),
          ),
        ],
      ),
    );
  }
}
