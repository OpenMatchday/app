import 'connected_accounts_models.dart';

class ConnectedAccountsActionResult {
  const ConnectedAccountsActionResult({
    required this.ok,
    required this.message,
    this.account,
  });

  final bool ok;
  final String message;
  final ConnectedAccount? account;
}

/// In-app social connections only (AC-11.1 / AC-11.2).
/// Opaque token refs stay on the social_connections plane; never mixed with
/// app sign-in, stream destinations, or contribution credentials.
class ConnectedAccountsStore {
  ConnectedAccountsStore({
    List<SocialProviderInfo>? providers,
    Map<String, Map<String, String>>? otherPlaneTokens,
  })  : _providers = List<SocialProviderInfo>.unmodifiable(
          providers ?? shippedSocialProviders(),
        ),
        _otherPlaneTokens = <String, Map<String, String>>{
          for (final plane in credentialPlanes)
            if (plane != socialConnectionsPlane)
              plane: Map<String, String>.from(
                otherPlaneTokens?[plane] ?? const <String, String>{},
              ),
        };

  final List<SocialProviderInfo> _providers;
  final Map<String, Map<String, String>> _otherPlaneTokens;
  final Map<String, ConnectedAccount> _connections =
      <String, ConnectedAccount>{};
  final Map<String, String> _socialTokenRefs = <String, String>{};
  int _seq = 0;

  List<SocialProviderInfo> get providers => _providers;

  List<ConnectedAccount> get connections =>
      _connections.values.toList(growable: false);

  List<String> get planes => List<String>.from(credentialPlanes);

  SocialProviderInfo providerById(String id) {
    for (final provider in _providers) {
      if (provider.id == id) {
        return provider;
      }
    }
    throw ArgumentError('unknown provider $id');
  }

  String _statusFor(SocialProviderInfo provider) {
    if (provider.runtimeEnabled) {
      return 'connected';
    }
    return 'connected_runtime_disabled';
  }

  /// Simulated connect after OAuth; stores opaque ref on social plane only.
  ConnectedAccountsActionResult connect({
    required String providerId,
    required String accountLabel,
    required String opaqueTokenRef,
  }) {
    if (accountLabel.trim().isEmpty) {
      return const ConnectedAccountsActionResult(
        ok: false,
        message: 'account label required',
      );
    }
    if (opaqueTokenRef.isEmpty) {
      return const ConnectedAccountsActionResult(
        ok: false,
        message: 'token ref required',
      );
    }
    try {
      final provider = providerById(providerId);
      if (provider.verification != 'policy_verified') {
        return ConnectedAccountsActionResult(
          ok: false,
          message: '$providerId: cannot connect unverified provider',
        );
      }
      _seq += 1;
      final connectionId = 'social-conn-$providerId-$_seq';
      _socialTokenRefs[connectionId] = opaqueTokenRef;
      final account = ConnectedAccount(
        connectionId: connectionId,
        providerId: provider.id,
        providerDisplayName: provider.displayName,
        accountLabel: accountLabel.trim(),
        capabilities: provider.capabilities,
        status: _statusFor(provider),
        revokeAvailable: true,
      );
      _connections[connectionId] = account;
      return ConnectedAccountsActionResult(
        ok: true,
        message: 'connected ${provider.displayName} on $socialConnectionsPlane',
        account: account,
      );
    } on ArgumentError catch (error) {
      return ConnectedAccountsActionResult(
        ok: false,
        message: error.message.toString(),
      );
    }
  }

  ConnectedAccountsActionResult revoke(String connectionId) {
    if (!_connections.containsKey(connectionId)) {
      return ConnectedAccountsActionResult(
        ok: false,
        message: 'unknown connection: $connectionId',
      );
    }
    _connections.remove(connectionId);
    _socialTokenRefs.remove(connectionId);
    return ConnectedAccountsActionResult(
      ok: true,
      message: 'revoked $connectionId',
    );
  }

  /// AC-11.1: social token refs must not appear on other planes.
  bool otherPlanesLackSocialTokens() {
    for (final entry in _otherPlaneTokens.entries) {
      for (final connectionId in _socialTokenRefs.keys) {
        if (entry.value.containsKey(connectionId)) {
          return false;
        }
      }
      for (final value in _socialTokenRefs.values) {
        if (entry.value.containsValue(value)) {
          return false;
        }
      }
    }
    return true;
  }

  bool hasSocialToken(String connectionId) =>
      _socialTokenRefs.containsKey(connectionId);

  /// UI never surfaces raw token material.
  bool displaysTokenMaterial() => false;
}
