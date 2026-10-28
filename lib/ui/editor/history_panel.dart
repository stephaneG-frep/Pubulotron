import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../editor/editor_controller.dart';
import '../../history/change_summary.dart';
import '../../history/history_service.dart';
import '../../models/project.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/compare_view.dart';
import '../widgets/project_card.dart';

/// Ouvre l'historique de la création en cours.
Future<void> showHistory(
  BuildContext context,
  WidgetRef ref,
  EditorController controller,
) async {
  // L'état courant est d'abord enregistré pour figurer dans l'historique.
  await controller.saveNow();
  ref.invalidate(versionsProvider(controller.project.id));
  if (!context.mounted) return;
  final wide = MediaQuery.sizeOf(context).width >= 760;
  final panel = HistoryPanel(controller: controller);
  if (wide) {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          Dialog(child: SizedBox(width: 760, height: 640, child: panel)),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(child: panel),
    );
  }
}

class HistoryPanel extends ConsumerStatefulWidget {
  const HistoryPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  ConsumerState<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<HistoryPanel> {
  final Set<String> _selected = {};

  EditorController get c => widget.controller;

  void _refresh() => ref.invalidate(versionsProvider(c.project.id));

  Future<void> _restore(VersionEntry v) async {
    if (!await confirm(
      context,
      title: 'Restaurer la version ${v.number} ?',
      message: 'L’état actuel reste disponible dans l’historique : vous pourrez y revenir à tout moment.',
      confirmLabel: 'Restaurer',
    )) {
      return;
    }
    await c.saveNow();
    c.replaceDocument(v.document);
    c.noteHistory(
      'Restauration de la version ${v.number}',
      kind: VersionKind.restore,
    );
    await c.saveNow();
    _refresh();
    if (mounted) showMessage(context, 'Version ${v.number} restaurée.');
  }

  Future<void> _duplicate(VersionEntry v) async {
    final copy = Project(
      name: '${c.project.name} (version ${v.number})',
      document: v.document,
      profileId: c.project.profileId,
    );
    await ref
        .read(projectsProvider.notifier)
        .save(
          copy,
          historyLabel:
              'Copie de la version ${v.number} de « ${c.project.name} »',
          kind: VersionKind.initial,
        );
    if (mounted) showMessage(context, '« ${copy.name} » ajouté à Mes projets.');
  }

  Future<void> _delete(VersionEntry v) async {
    if (!await confirm(
      context,
      title: 'Supprimer la version ${v.number} ?',
      message: 'Cette version sera définitivement effacée.',
      destructive: true,
      confirmLabel: 'Supprimer',
    )) {
      return;
    }
    await ref.read(servicesProvider).history.deleteVersion(v.id);
    _selected.remove(v.id);
    _refresh();
  }

  Future<void> _prune(int count) async {
    final keep = ref.read(settingsProvider).historyMaxVersions;
    final target = (keep ~/ 2).clamp(3, 50);
    if (!await confirm(
      context,
      title: 'Nettoyer l’historique ?',
      message:
          'Seules la version initiale et les ${target - 1} plus récentes seront conservées ($count actuellement).',
      destructive: true,
      confirmLabel: 'Nettoyer',
    )) {
      return;
    }
    final removed = await ref
        .read(servicesProvider)
        .history
        .prune(c.project.id, keep: target);
    _selected.clear();
    _refresh();
    if (mounted) {
      showMessage(
        context,
        '$removed version${removed > 1 ? 's' : ''} supprimée${removed > 1 ? 's' : ''}.',
      );
    }
  }

  void _compare(List<VersionEntry> versions) {
    final chosen = versions.where((v) => _selected.contains(v.id)).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final changes = describeChanges(chosen[0].document, chosen[1].document);
    showCompareDialog<void>(
      context,
      title: 'Version ${chosen[0].number} ↔ version ${chosen[1].number}',
      header: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          changes.isEmpty
              ? 'Aucune différence.'
              : 'Différences : ${changes.toSet().join(' · ')}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      items: [
        for (final v in chosen)
          CompareItem(
            title: 'Version ${v.number}',
            subtitle: '${formatDate(v.createdAt)} — ${v.label}',
            document: v.document,
          ),
      ],
      actions: (dialogContext) => [
        for (final v in chosen)
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _restore(v);
            },
            child: Text('Restaurer la version ${v.number}'),
          ),
      ],
    );
  }

  Color _kindColor(VersionKind k) => switch (k) {
    VersionKind.initial => PubColors.turquoise,
    VersionKind.ai => PubColors.violet,
    VersionKind.sync => PubColors.orange,
    VersionKind.restore || VersionKind.restorePoint => PubColors.rose,
    VersionKind.edit => PubColors.night,
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(versionsProvider(c.project.id));
    final versions = async.value ?? const <VersionEntry>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Historique — ${c.project.name}',
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Comparer les 2 versions cochées',
            onPressed: _selected.length == 2 ? () => _compare(versions) : null,
            icon: const Icon(Icons.compare),
          ),
          IconButton(
            tooltip: 'Nettoyer les anciennes versions',
            onPressed: versions.length > 3
                ? () => _prune(versions.length)
                : null,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: async.isLoading && versions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : versions.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'Pas encore d’historique',
              message: 'Les versions apparaissent au fil de vos modifications.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Text(
                    '${versions.length} version${versions.length > 1 ? 's' : ''} conservée${versions.length > 1 ? 's' : ''} '
                    '(limite : ${ref.watch(settingsProvider).historyMaxVersions}, réglable dans Paramètres). Cochez deux versions pour les comparer.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: versions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final v = versions[i];
                      final current = i == 0;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selected.contains(v.id),
                                onChanged: (on) => setState(() {
                                  if (on == true) {
                                    if (_selected.length >= 2) {
                                      _selected.remove(_selected.first);
                                    }
                                    _selected.add(v.id);
                                  } else {
                                    _selected.remove(v.id);
                                  }
                                }),
                              ),
                              SizedBox(
                                width: 92,
                                child: DocumentThumbnail(
                                  document: v.document,
                                  height: 70,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'Version ${v.number}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _kindColor(v.kind)
                                                .withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            v.kind.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _kindColor(v.kind),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (current)
                                          const Text(
                                            '· actuelle',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      v.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      formatDate(v.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Actions',
                                onSelected: (a) => switch (a) {
                                  'restore' => _restore(v),
                                  'duplicate' => _duplicate(v),
                                  _ => _delete(v),
                                },
                                itemBuilder: (_) => [
                                  if (!current)
                                    const PopupMenuItem(
                                      value: 'restore',
                                      child: ListTile(
                                        leading: Icon(Icons.restore),
                                        title: Text('Restaurer'),
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: ListTile(
                                      leading: Icon(Icons.copy),
                                      title: Text(
                                        'Dupliquer en nouvelle création',
                                      ),
                                    ),
                                  ),
                                  if (!current)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete_outline),
                                        title: Text('Supprimer'),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
