import 'social_models.dart';

class SocialActionResult {
  const SocialActionResult({
    required this.ok,
    required this.message,
    this.draft,
    this.bundle,
  });

  final bool ok;
  final String message;
  final SocialDraft? draft;
  final SocialExportBundle? bundle;
}

/// Offline social drafts and local export (AC-11.3, AC-11.4, AC-11.7).
class SocialStore {
  SocialStore({
    List<SocialTemplate>? templates,
    String Function()? clockIso,
  })  : _templates = List<SocialTemplate>.unmodifiable(
          templates ?? shippedSocialTemplates(),
        ),
        _clockIso = clockIso ?? (() => DateTime.now().toUtc().toIso8601String());

  final List<SocialTemplate> _templates;
  final String Function() _clockIso;
  final Map<String, SocialDraft> _drafts = <String, SocialDraft>{};
  int _seq = 0;
  SocialExportBundle? _lastExport;

  List<SocialTemplate> get templates => _templates;

  List<SocialDraft> get drafts => _drafts.values.toList(growable: false);

  SocialExportBundle? get lastExport => _lastExport;

  SocialTemplate templateByKind(String kind) {
    for (final template in _templates) {
      if (template.kind == kind) {
        return template;
      }
    }
    throw ArgumentError('unknown social template kind $kind');
  }

  void _assertNoFakeMetrics(Map<String, String> bindings) {
    for (final key in bindings.keys) {
      if (bannedEngagementFields.contains(key)) {
        throw ArgumentError('banned engagement field: $key');
      }
    }
  }

  void _validate(SocialTemplate template, Map<String, String> bindings) {
    _assertNoFakeMetrics(bindings);
    final allowed = template.slots.map((s) => s.slotId).toSet();
    for (final key in bindings.keys) {
      if (!allowed.contains(key)) {
        throw ArgumentError('unknown slot $key');
      }
    }
    for (final slot in template.slots) {
      final value = bindings[slot.slotId] ?? '';
      if (slot.required && value.isEmpty) {
        throw ArgumentError('slot ${slot.slotId} is required');
      }
      if (value.length > slot.maxLength) {
        throw ArgumentError(
          'slot ${slot.slotId} exceeds max_length ${slot.maxLength}',
        );
      }
    }
  }

  String _fillCaption(SocialTemplate template, Map<String, String> bindings) {
    var text = template.captionTemplate;
    for (final slot in template.slots) {
      text = text.replaceAll(
        '{{${slot.slotId}}}',
        bindings[slot.slotId] ?? '',
      );
    }
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Map<String, String> _cardBindings(
    SocialTemplate template,
    Map<String, String> bindings,
  ) {
    return <String, String>{
      for (final entry in template.cardMap.entries)
        entry.key: bindings[entry.value] ?? '',
    };
  }

  SocialActionResult createDraft({
    required String kind,
    required Map<String, String> bindings,
    String aspect = '1:1',
  }) {
    try {
      final template = templateByKind(kind);
      if (!template.aspects.contains(aspect)) {
        return SocialActionResult(
          ok: false,
          message: 'aspect $aspect not supported for $kind',
        );
      }
      _validate(template, bindings);
      _seq += 1;
      final now = _clockIso();
      final draft = SocialDraft(
        draftId: 'draft-$_seq',
        templateId: template.templateId,
        kind: template.kind,
        aspect: aspect,
        bindings: Map<String, String>.unmodifiable(bindings),
        caption: _fillCaption(template, bindings),
        cardBindings: _cardBindings(template, bindings),
        graphicsKind: template.graphicsKind,
        accountRequired: false,
        updatedAtIso: now,
      );
      _drafts[draft.draftId] = draft;
      return SocialActionResult(
        ok: true,
        message: 'draft ${draft.draftId} created offline (no account)',
        draft: draft,
      );
    } on ArgumentError catch (error) {
      return SocialActionResult(ok: false, message: error.message.toString());
    }
  }

  /// Local JSON-serializable export; account always null (AC-11.4).
  SocialActionResult exportLocal() {
    if (_drafts.isEmpty) {
      return const SocialActionResult(
        ok: false,
        message: 'no drafts to export',
      );
    }
    for (final draft in _drafts.values) {
      _assertNoFakeMetrics(draft.bindings);
      if (draft.accountRequired) {
        return SocialActionResult(
          ok: false,
          message: 'draft ${draft.draftId} incorrectly requires an account',
        );
      }
    }
    final bundle = SocialExportBundle(
      exportedAtIso: _clockIso(),
      drafts: drafts,
    );
    _lastExport = bundle;
    return SocialActionResult(
      ok: true,
      message:
          'exported ${bundle.drafts.length} draft(s) locally; account=null',
      bundle: bundle,
    );
  }

  /// UI must never surface engagement metrics (AC-11.7).
  bool displaysEngagementMetrics() => false;
}
