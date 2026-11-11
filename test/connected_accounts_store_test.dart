import 'package:flutter_test/flutter_test.dart';
import 'package:open_matchday/social/connected_accounts_models.dart';
import 'package:open_matchday/social/connected_accounts_store.dart';

void main() {
  test('AC-11.1 keeps social tokens off other credential planes', () {
    final store = ConnectedAccountsStore(
      otherPlaneTokens: <String, Map<String, String>>{
        'app_sign_in': <String, String>{'app-session': 'app-secret'},
        'stream_destinations': <String, String>{'srt-key': 'stream-secret'},
        'contribution_service': <String, String>{'gh-app': 'contrib-secret'},
      },
    );
    expect(store.planes, equals(credentialPlanes));
    final connected = store.connect(
      providerId: 'youtube',
      accountLabel: 'Harbor Fiction',
      opaqueTokenRef: 'social-ref-1',
    );
    expect(connected.ok, isTrue);
    expect(connected.account!.plane, socialConnectionsPlane);
    expect(store.otherPlanesLackSocialTokens(), isTrue);
    expect(store.hasSocialToken(connected.account!.connectionId), isTrue);
    expect(store.displaysTokenMaterial(), isFalse);
  });

  test('AC-11.2 connection exposes provider capabilities status revoke', () {
    final store = ConnectedAccountsStore();
    final connected = store.connect(
      providerId: 'bluesky',
      accountLabel: 'foxes.bsky.social',
      opaqueTokenRef: 'bsky-ref',
    );
    expect(connected.ok, isTrue);
    final row = connected.account!;
    expect(row.providerId, 'bluesky');
    expect(row.providerDisplayName, 'Bluesky');
    expect(row.capabilities, contains('text_post'));
    expect(row.capabilities, contains('atproto'));
    expect(row.status, 'connected_runtime_disabled');
    expect(row.revokeAvailable, isTrue);

    final revoked = store.revoke(row.connectionId);
    expect(revoked.ok, isTrue);
    expect(store.connections, isEmpty);
    expect(store.hasSocialToken(row.connectionId), isFalse);
  });

  test('refuses empty label and unknown provider', () {
    final store = ConnectedAccountsStore();
    expect(
      store
          .connect(
            providerId: 'youtube',
            accountLabel: '  ',
            opaqueTokenRef: 'x',
          )
          .ok,
      isFalse,
    );
    expect(
      store
          .connect(
            providerId: 'twitch',
            accountLabel: 'nope',
            opaqueTokenRef: 'x',
          )
          .ok,
      isFalse,
    );
  });
}
