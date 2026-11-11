import 'package:flutter/material.dart';

import 'connected_accounts_page.dart';
import 'social_models.dart';
import 'social_store.dart';

/// Social Operator: templates, drafts, local export (AC-11.3, AC-11.4, AC-11.7).
class SocialPage extends StatefulWidget {
  const SocialPage({super.key, this.store});

  final SocialStore? store;

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  late final SocialStore _store;
  late String _kind;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  String _status = 'Offline drafts; no account required';
  String _exportPreview = '';

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SocialStore();
    _kind = _store.templates.first.kind;
    _rebuildControllers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  SocialTemplate get _template => _store.templateByKind(_kind);

  void _rebuildControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (final slot in _template.slots) {
      _controllers[slot.slotId] = TextEditingController();
    }
  }

  void handleKindChanged(String? kind) {
    if (kind == null || kind == _kind) {
      return;
    }
    setState(() {
      _kind = kind;
      _rebuildControllers();
      _status = 'Template $kind selected';
    });
  }

  void handleCreateDraft() {
    final bindings = <String, String>{
      for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
    };
    final result = _store.createDraft(kind: _kind, bindings: bindings);
    setState(() {
      _status = result.message;
    });
  }

  void handleExport() {
    final result = _store.exportLocal();
    setState(() {
      _status = result.message;
      if (result.ok && result.bundle != null) {
        final bundle = result.bundle!;
        _exportPreview =
            'format=${bundle.format} v${bundle.formatVersion}; '
            'account=${bundle.account}; drafts=${bundle.drafts.length}';
      }
    });
  }

  void handleOpenConnectedAccounts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ConnectedAccountsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(!_store.displaysEngagementMetrics());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Operator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          OutlinedButton(
            key: const Key('social-open-connected-accounts'),
            onPressed: handleOpenConnectedAccounts,
            child: const Text('Connected accounts'),
          ),
          const SizedBox(height: 24),
          Text(
            'Templates',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Announcements, lineups, scores, results, and clips. '
            'Drafts and export work offline with no account. '
            'Engagement metrics are never shown.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            key: Key('social-no-metrics'),
            'Engagement metrics: not displayed',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('social-template-kind'),
            initialValue: _kind,
            decoration: const InputDecoration(
              labelText: 'Template',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final template in _store.templates)
                DropdownMenuItem<String>(
                  value: template.kind,
                  child: Text(template.title),
                ),
            ],
            onChanged: handleKindChanged,
          ),
          const SizedBox(height: 16),
          for (final slot in _template.slots) ...[
            TextField(
              key: Key('social-slot-${slot.slotId}'),
              controller: _controllers[slot.slotId],
              maxLength: slot.maxLength,
              decoration: InputDecoration(
                labelText: slot.required ? '${slot.label} *' : slot.label,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: const Key('social-create-draft'),
            onPressed: handleCreateDraft,
            child: const Text('Create draft'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('social-export-local'),
            onPressed: handleExport,
            child: const Text('Export locally'),
          ),
          const SizedBox(height: 16),
          Text(
            key: const Key('social-status'),
            _status,
            semanticsLabel: _status,
          ),
          if (_exportPreview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              key: const Key('social-export-preview'),
              _exportPreview,
              semanticsLabel: _exportPreview,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Drafts (${_store.drafts.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final draft in _store.drafts)
            ListTile(
              key: Key('social-draft-${draft.draftId}'),
              title: Text('${draft.kind}: ${draft.caption.split('\n').first}'),
              subtitle: Text(
                '${draft.draftId} · account_required=${draft.accountRequired}',
              ),
            ),
        ],
      ),
    );
  }
}
