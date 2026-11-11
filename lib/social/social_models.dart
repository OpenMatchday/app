/// Social template kinds from AC-11.3 (mirrored from social/templates).
const List<String> socialTemplateKinds = <String>[
  'announcement',
  'lineup',
  'score',
  'result',
  'clip',
];

/// Engagement / vanity metric keys never shown or stored (AC-11.7).
const Set<String> bannedEngagementFields = <String>{
  'likes',
  'views',
  'shares',
  'comments',
  'followers',
  'impressions',
  'reach',
  'engagement',
  'engagement_rate',
  'fake_metrics',
};

class SocialSlot {
  const SocialSlot({
    required this.slotId,
    required this.label,
    required this.maxLength,
    required this.required,
  });

  final String slotId;
  final String label;
  final int maxLength;
  final bool required;
}

class SocialTemplate {
  const SocialTemplate({
    required this.templateId,
    required this.kind,
    required this.title,
    required this.slots,
    required this.cardMap,
    required this.captionTemplate,
    this.graphicsKind = 'social_cards',
    this.aspects = const <String>['16:9', '9:16', '1:1'],
  });

  final String templateId;
  final String kind;
  final String title;
  final List<SocialSlot> slots;
  final Map<String, String> cardMap;
  final String captionTemplate;
  final String graphicsKind;
  final List<String> aspects;
}

class SocialDraft {
  const SocialDraft({
    required this.draftId,
    required this.templateId,
    required this.kind,
    required this.aspect,
    required this.bindings,
    required this.caption,
    required this.cardBindings,
    required this.updatedAtIso,
    this.graphicsKind = 'social_cards',
    this.accountRequired = false,
  });

  final String draftId;
  final String templateId;
  final String kind;
  final String aspect;
  final Map<String, String> bindings;
  final String caption;
  final Map<String, String> cardBindings;
  final String graphicsKind;
  final bool accountRequired;
  final String updatedAtIso;

  Map<String, Object?> toJson() => <String, Object?>{
        'draft_id': draftId,
        'template_id': templateId,
        'kind': kind,
        'aspect': aspect,
        'bindings': bindings,
        'caption': caption,
        'card_bindings': cardBindings,
        'graphics_kind': graphicsKind,
        'account_required': accountRequired,
        'updated_at': updatedAtIso,
      };
}

class SocialExportBundle {
  const SocialExportBundle({
    required this.exportedAtIso,
    required this.drafts,
    this.format = 'open-matchday.social-export',
    this.formatVersion = '0.1.0',
  });

  final String format;
  final String formatVersion;
  final String exportedAtIso;
  final List<SocialDraft> drafts;

  /// Local export never attaches an account (AC-11.4).
  Null get account => null;

  Map<String, Object?> toJson() => <String, Object?>{
        'format': format,
        'format_version': formatVersion,
        'exported_at': exportedAtIso,
        'account': account,
        'graphics_contract': 'open-matchday.social-export@0.1.0',
        'drafts': drafts.map((d) => d.toJson()).toList(growable: false),
      };
}

/// Shipped catalog matching social/templates/*.json.
List<SocialTemplate> shippedSocialTemplates() => const <SocialTemplate>[
      SocialTemplate(
        templateId: 'tmpl-announcement',
        kind: 'announcement',
        title: 'Announcement',
        slots: <SocialSlot>[
          SocialSlot(
            slotId: 'headline',
            label: 'Headline',
            maxLength: 80,
            required: true,
          ),
          SocialSlot(
            slotId: 'body',
            label: 'Body',
            maxLength: 280,
            required: false,
          ),
        ],
        cardMap: <String, String>{'title': 'headline', 'subtitle': 'body'},
        captionTemplate: '{{headline}}\n\n{{body}}',
      ),
      SocialTemplate(
        templateId: 'tmpl-lineup',
        kind: 'lineup',
        title: 'Lineup',
        slots: <SocialSlot>[
          SocialSlot(
            slotId: 'team_name',
            label: 'Team',
            maxLength: 60,
            required: true,
          ),
          SocialSlot(
            slotId: 'starters',
            label: 'Starters',
            maxLength: 400,
            required: true,
          ),
        ],
        cardMap: <String, String>{
          'title': 'team_name',
          'subtitle': 'starters',
        },
        captionTemplate: 'Lineup — {{team_name}}\n{{starters}}',
      ),
      SocialTemplate(
        templateId: 'tmpl-score',
        kind: 'score',
        title: 'Score',
        slots: <SocialSlot>[
          SocialSlot(
            slotId: 'matchup',
            label: 'Matchup',
            maxLength: 80,
            required: true,
          ),
          SocialSlot(
            slotId: 'scoreline',
            label: 'Scoreline',
            maxLength: 40,
            required: true,
          ),
        ],
        cardMap: <String, String>{
          'title': 'matchup',
          'subtitle': 'scoreline',
        },
        captionTemplate: '{{matchup}}\n{{scoreline}}',
      ),
      SocialTemplate(
        templateId: 'tmpl-result',
        kind: 'result',
        title: 'Result',
        slots: <SocialSlot>[
          SocialSlot(
            slotId: 'matchup',
            label: 'Matchup',
            maxLength: 80,
            required: true,
          ),
          SocialSlot(
            slotId: 'final_score',
            label: 'Final score',
            maxLength: 40,
            required: true,
          ),
          SocialSlot(
            slotId: 'note',
            label: 'Note',
            maxLength: 160,
            required: false,
          ),
        ],
        cardMap: <String, String>{
          'title': 'matchup',
          'subtitle': 'final_score',
        },
        captionTemplate: 'Final — {{matchup}}\n{{final_score}}\n{{note}}',
      ),
      SocialTemplate(
        templateId: 'tmpl-clip',
        kind: 'clip',
        title: 'Clip',
        slots: <SocialSlot>[
          SocialSlot(
            slotId: 'clip_title',
            label: 'Clip title',
            maxLength: 80,
            required: true,
          ),
          SocialSlot(
            slotId: 'timecode',
            label: 'Timecode',
            maxLength: 32,
            required: false,
          ),
          SocialSlot(
            slotId: 'local_media_path',
            label: 'Local media path',
            maxLength: 512,
            required: false,
          ),
        ],
        cardMap: <String, String>{
          'title': 'clip_title',
          'subtitle': 'timecode',
        },
        captionTemplate: '{{clip_title}}\n{{timecode}}',
      ),
    ];
