import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../editor/editor_controller.dart';
import '../../history/history_service.dart';
import '../../models/design_document.dart';
import '../../models/project.dart';
import '../../sync/sync_engine.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/project_card.dart';

/// Propose de répercuter une modification sur les déclinaisons et variantes.
class SyncBanner extends ConsumerStatefulWidget {
  const SyncBanner({super.key, required this.controller});

  final EditorController controller;

  @override
  ConsumerState<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends ConsumerState<SyncBanner> {
  late DesignDocument _baseline;
  List<SyncChange> _changes = const [];
  List<SyncPreview> _affected = const [];
  Timer? _debounce;

  EditorController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    // Référence figée dès l'ouverture (et non au premier accès).
    _baseline = c.document;
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    c.removeListener(_onChange);
    super.dispose();
  }

  List<Project> get _siblings => SyncEngine.siblings(
    c.project,
    ref.read(projectsProvider).value ?? const [],
  );

  void _onChange() {
    if (c.inTransaction) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _evaluate);
  }

  void _evaluate() {
    if (!mounted) return;
    final siblings = _siblings;
    if (siblings.isEmpty) {
      if (_affected.isNotEmpty) setState(() => _affected = const []);
      return;
    }
    final changes = SyncEngine.detect(_baseline, c.document);
    final affected = changes.isEmpty
        ? const <SyncPreview>[]
        : SyncEngine.previewAll(
            siblings,
            changes,
          ).where((p) => p.affected).toList();
    setState(() {
      _changes = changes;
      _affected = affected;
    });
  }

  void _dismiss() => setState(() {
    _baseline = c.document;
    _changes = const [];
    _affected = const [];
  });

  Future<void> _open({required bool all}) async {
    final applied = await showDialog<int>(
      context: context,
      builder: (_) => SyncDialog(
        controller: c,
        changes: _changes,
        targets: _siblings,
        preselectAll: all,
      ),
    );
    if (applied != null && applied > 0) {
      _dismiss();
      if (mounted) {
        showMessage(
          context,
          'Modification appliquée à $applied création${applied > 1 ? 's' : ''}. Un point de restauration a été créé pour chacune.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_affected.isEmpty) return const SizedBox.shrink();
    final labels = _changes.map((ch) => ch.label).take(2).join(' ; ');
    final related = _affected.length;
    return Material(
      color: PubColors.orange.withValues(alpha: 0.16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.sync, color: PubColors.orange),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Souhaites-tu appliquer cette modification aux autres formats ? ($related création${related > 1 ? 's' : ''} liée${related > 1 ? 's' : ''})\n$labels',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _dismiss,
              child: const Text('Uniquement cette création'),
            ),
            FilledButton.tonal(
              onPressed: () => _open(all: true),
              child: const Text('Toutes les déclinaisons'),
            ),
            OutlinedButton(
              onPressed: () => _open(all: false),
              child: const Text('Choisir…'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation détaillée d'une synchronisation groupée.
class SyncDialog extends ConsumerStatefulWidget {
  const SyncDialog({
    super.key,
    required this.controller,
    required this.changes,
    required this.targets,
    required this.preselectAll,
  });

  final EditorController controller;
  final List<SyncChange> changes;
  final List<Project> targets;
  final bool preselectAll;

  @override
  ConsumerState<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends ConsumerState<SyncDialog> {
  late final Set<String> _changeKeys = widget.changes.map((c) => c.key).toSet();
  late final Set<String> _targetIds = widget.preselectAll
      ? widget.targets.map((t) => t.id).toSet()
      : <String>{};
  bool _busy = false;

  List<SyncChange> get _selectedChanges =>
      widget.changes.where((c) => _changeKeys.contains(c.key)).toList();

  String _role(Project p) {
    if (p.packId != null && p.packId == widget.controller.project.packId) {
      return 'Déclinaison';
    }
    return 'Variante ${p.variantIndex ?? ''}'.trim();
  }

  Future<void> _apply(List<SyncPreview> previews) async {
    setState(() => _busy = true);
    final services = ref.read(servicesProvider);
    final notifier = ref.read(projectsProvider.notifier);
    final what = _selectedChanges.map((c) => c.label).join(' ; ');
    var count = 0;
    try {
      await widget.controller.saveNow();
      for (final preview in previews.where(
        (p) => _targetIds.contains(p.project.id) && p.affected,
      )) {
        await services.history.record(
          preview.project,
          label: 'Point de restauration avant synchronisation',
          kind: VersionKind.restorePoint,
          force: true,
        );
        await notifier.save(
          preview.project.copyWith(
            document: preview.document,
            updatedAt: DateTime.now(),
          ),
          historyLabel:
              'Synchronisation depuis « ${widget.controller.project.name} » : $what',
          kind: VersionKind.sync,
        );
        count++;
      }
      if (mounted) Navigator.pop(context, count);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, 'Échec de la synchronisation : $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previews = SyncEngine.previewAll(widget.targets, _selectedChanges);
    final affected = previews.where((p) => p.affected).toList();
    final chosen = affected
        .where((p) => _targetIds.contains(p.project.id))
        .length;
    return AlertDialog(
      title: const Text('Synchroniser les créations liées'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Modifications à répercuter',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final ch in widget.changes)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _changeKeys.contains(ch.key),
                  onChanged: (v) => setState(
                    () => v == true
                        ? _changeKeys.add(ch.key)
                        : _changeKeys.remove(ch.key),
                  ),
                  title: Text(ch.label),
                ),
              const Divider(),
              Text(
                'Créations concernées (aperçu après modification)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              if (affected.isEmpty)
                const Text(
                  'Aucune création liée n’est concernée par ces modifications.',
                ),
              for (final p in affected)
                Card(
                  child: CheckboxListTile(
                    value: _targetIds.contains(p.project.id),
                    onChanged: (v) => setState(
                      () => v == true
                          ? _targetIds.add(p.project.id)
                          : _targetIds.remove(p.project.id),
                    ),
                    title: Text(
                      p.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_role(p.project)} · ${formatLabel(p.project.document)} · ${p.total} élément${p.total > 1 ? 's' : ''} modifié${p.total > 1 ? 's' : ''}',
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: DocumentThumbnail(
                                document: p.project.document,
                                height: 90,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward),
                            ),
                            Expanded(
                              child: DocumentThumbnail(
                                document: p.document,
                                height: 90,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Les compositions de chaque format sont conservées : seuls les contenus indiqués changent. Un point de restauration est créé dans l’historique de chaque création.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, 0),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _busy || chosen == 0 || _selectedChanges.isEmpty
              ? null
              : () => _apply(previews),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text('Appliquer à $chosen création${chosen > 1 ? 's' : ''}'),
        ),
      ],
    );
  }
}
