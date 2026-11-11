/// AC-11.1 credential planes. Social connections never share these stores.
const List<String> credentialPlanes = <String>[
  'app_sign_in',
  'social_connections',
  'stream_destinations',
  'contribution_service',
];

const String socialConnectionsPlane = 'social_connections';

/// Mirrored from social/providers/registry.json policy_verified rows.
class SocialProviderInfo {
  const SocialProviderInfo({
    required this.id,
    required this.displayName,
    required this.useCases,
    required this.scopes,
    required this.runtimeEnabled,
    required this.verification,
  });

  final String id;
  final String displayName;
  final List<String> useCases;
  final List<String> scopes;
  final bool runtimeEnabled;
  final String verification;

  List<String> get capabilities => <String>[...useCases, ...scopes];
}

class ConnectedAccount {
  const ConnectedAccount({
    required this.connectionId,
    required this.providerId,
    required this.providerDisplayName,
    required this.accountLabel,
    required this.capabilities,
    required this.status,
    required this.revokeAvailable,
    this.plane = socialConnectionsPlane,
  });

  final String connectionId;
  final String providerId;
  final String providerDisplayName;
  final String accountLabel;
  final List<String> capabilities;
  final String status;
  final bool revokeAvailable;
  final String plane;
}

/// Shipped catalog matching social D8 policy_verified providers.
List<SocialProviderInfo> shippedSocialProviders() => const <SocialProviderInfo>[
      SocialProviderInfo(
        id: 'youtube',
        displayName: 'YouTube',
        useCases: <String>['video_upload'],
        scopes: <String>[
          'https://www.googleapis.com/auth/youtube.upload',
        ],
        runtimeEnabled: false,
        verification: 'policy_verified',
      ),
      SocialProviderInfo(
        id: 'meta_instagram',
        displayName: 'Instagram (professional)',
        useCases: <String>['image_post', 'video_post', 'reels', 'carousel'],
        scopes: <String>[
          'instagram_business_content_publish',
          'instagram_business_basic',
        ],
        runtimeEnabled: false,
        verification: 'policy_verified',
      ),
      SocialProviderInfo(
        id: 'meta_facebook_pages',
        displayName: 'Facebook Pages',
        useCases: <String>['page_photo', 'page_video'],
        scopes: <String>[
          'pages_show_list',
          'pages_read_engagement',
          'pages_manage_posts',
        ],
        runtimeEnabled: false,
        verification: 'policy_verified',
      ),
      SocialProviderInfo(
        id: 'tiktok',
        displayName: 'TikTok',
        useCases: <String>[
          'video_direct_post',
          'photo_direct_post',
          'draft_upload',
        ],
        scopes: <String>['video.publish', 'video.upload'],
        runtimeEnabled: false,
        verification: 'policy_verified',
      ),
      SocialProviderInfo(
        id: 'x',
        displayName: 'X',
        useCases: <String>['text_post', 'image_post', 'video_post'],
        scopes: <String>[
          'tweet.write',
          'tweet.read',
          'users.read',
          'media.write',
        ],
        runtimeEnabled: false,
        verification: 'policy_verified',
      ),
      SocialProviderInfo(
        id: 'bluesky',
        displayName: 'Bluesky',
        useCases: <String>['text_post', 'image_post'],
        scopes: <String>['atproto', 'transition:generic'],
        runtimeEnabled: false,
        verification: 'policy_verified',
      ),
    ];
