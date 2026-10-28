import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_client.dart';
import '../../app/providers.dart';
import '../../app/variant_state.dart';
import '../../history/history_service.dart';
import '../../models/formats.dart';
import '../../models/project.dart';
import '../../variants/variant_service.dart';
import '../export_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/compare_view.dart';
import '../widgets/project_card.dart';

/// Studio de variantes : plusieurs designs différents pour un même format.
class VariantsScreen extends ConsumerStatefulWidget {
  const VariantsScreen({super.key});

  @override
  ConsumerState<VariantsScreen> createState() => _VariantsScreenState();
}

class _VariantsScreenState extends ConsumerState<VariantsScreen> {
  late final TextEditingController _brief = TextEditingController(
    text: ref.read(variantStudioProvider).brief,
  );
  final Set<String> _compare = {};

  @override
  void dispose() {
    _brief.dispose();
    super.dispose();
  }

  Future<void> _generate({
    required bool useAi,
    String? groupId,
    List<ArtDirection>? directions,
  }) async {
    if (useAi && ref.read(aiConfigProvider) == null) {
      showMessage(
        context,
        'Aucune clé API configurée : utilisez le générateur hors ligne ou ouvrez Paramètres IA.',
        error: true,
      );
      return;
    }
    try {
      final result = await ref
          .read(variantStudioProvider.notifier)
          .generate(useAi: useAi, groupId: groupId, directions: directions);
      if (!mounted) return;
      final n = result.created.length;
      showMessage(
        context,
        result.failures.isEmpty
            ? '$n variante${n > 1 ? 's' : ''} créée${n > 1 ? 's' : ''} et enregistrée${n > 1 ? 's' : ''}.'
            : '$n variante${n > 1 ? 's' : ''} créée${n > 1 ? 's' : ''}, ${result.failures.length} échec${result.failures.length > 1 ? 's' : ''} (les variantes produites sont conservées).',
        error: n == 0,
      );
    } catch (e) {
      if (mounted) showMessage(context, 'Échec : $e', error: true);
    }
  }

  ArtDirection _directionOf(Project p) => ArtDirection.defaults.firstWhere(
    (d) => d.name == p.variantStyle,
    orElse: () =>
        ArtDirection(p.variantStyle ?? 'Variante', 'Composition originale.'),
  );

  Future<void> _regenerate(Project variant, List<Project> group) async {
    final config = ref.read(aiConfigProvider);
    if (!await confirm(
      context,
      title: 'Régénérer « ${variant.variantStyle ?? variant.name} » ?',
      message: 'Une nouvelle composition remplace celle-ci. L’actuelle reste disponible dans son historique.',
      confirmLabel: 'Régénérer',
    )) {
      return;
    }
    if (!mounted) return;
    final services = ref.read(servicesProvider);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Nouvelle composition en cours…')),
          ],
        ),
      ),
    );
    try {
      final format =
          DesignFormats.byId(variant.document.formatId) ??
          DesignFormat(
            id: variant.document.formatId,
            label: 'Format',
            group: '',
            widthMm: variant.document.widthMm,
            heightMm: variant.document.heightMm,
          );
      final doc = await services.variants.generateOne(
        config: config,
        brief: variant.brief,
        profile: ref.read(activeProfileProvider),
        format: format,
        direction: _directionOf(variant),
        avoid: group,
      );
      final editor = ref.read(editorProvider);
      if (editor != null && editor.project.id == variant.id) {
        editor.replaceDocument(doc);
        editor.noteHistory(
          'Régénération ${config == null ? 'hors ligne' : 'par IA'}',
          kind: VersionKind.ai,
        );
        await editor.saveNow();
      } else {
        await services.history.record(
          variant,
          label: 'Avant régénération',
          kind: VersionKind.restorePoint,
          force: true,
        );
        await ref
            .read(projectsProvider.notifier)
            .save(
              variant.copyWith(document: doc, updatedAt: DateTime.now()),
              historyLabel:
                  'Régénération ${config == null ? 'hors ligne' : 'par IA'}',
              kind: VersionKind.ai,
            );
      }
      if (mounted) {
        showMessage(
          context,
          'Variante régénérée. L’ancienne version est dans l’historique.',
        );
      }
    } on AiException catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.details == null ? e.message : '${e.message} (${e.details})',
          error: true,
        );
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _duplicate(Project variant, List<Project> group) async {
    final next =
        group.map((p) => p.variantIndex ?? 0).fold(0, (a, b) => a > b ? a : b) +
        1;
    final copy = Project(
      name: '${variant.name} (copie)',
      document: variant.document,
      brief: variant.brief,
      profileId: variant.profileId,
      variantGroupId: variant.variantGroupId,
      variantIndex: next,
      variantStyle: '${variant.variantStyle ?? 'Variante'} (copie)',
    );
    await ref
        .read(projectsProvider.notifier)
        .save(
          copy,
          historyLabel: 'Copie de la variante ${variant.variantIndex ?? ''}'
              .trim(),
          kind: VersionKind.initial,
        );
    if (mounted) showMessage(context, 'Variante $next créée (copie).');
  }

  void _preview(Project variant) {
    showCompareDialog<void>(
      context,
      title:
          'Variante ${variant.variantIndex ?? ''} — ${variant.variantStyle ?? variant.name}',
      items: [
        CompareItem(
          title: variant.document.isDuplex
              ? 'Recto'
              : (variant.variantStyle ?? ''),
          document: variant.document,
        ),
        if (variant.document.isDuplex)
          CompareItem(title: 'Verso', document: variant.document, pageIndex: 1),
      ],
      actions: (dialogContext) => [
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(dialogContext);
            openInStudio(ref, variant);
          },
          icon: const Icon(Icons.edit),
          label: const Text('Modifier dans l’atelier'),
        ),
      ],
    );
  }

  void _compareSelected(List<Project> group) {
    final selected = group.where((p) => _compare.contains(p.id)).toList();
    showCompareDialog<void>(
      context,
      title: 'Comparer ${selected.length} variantes',
      items: [
        for (final p in selected)
          CompareItem(
            title: 'Variante ${p.variantIndex ?? ''}',
            subtitle: p.variantStyle ?? '',
            document: p.document,
          ),
      ],
      footer: (i) => Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => openInStudio(ref, selected[i]),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(variantStudioProvider);
    final notifier = ref.read(variantStudioProvider.notifier);
    final groups = ref.watch(variantGroupsProvider);
    final config = ref.watch(aiConfigProvider);
    final orderedGroups = groups.entries.toList()
      ..sort(
        (a, b) => b.value.first.createdAt.compareTo(a.value.first.createdAt),
      );
    final currentId = state.groupId != null && groups.containsKey(state.groupId)
        ? state.groupId
        : (orderedGroups.isEmpty ? null : orderedGroups.first.key);
    final group = currentId == null ? const <Project>[] : groups[currentId]!;
    final progress = state.progress;
    final usedStyles = group.map((p) => p.variantStyle).toSet();
    final nextDirection = ArtDirection.defaults
        .where((d) => !usedStyles.contains(d.name))
        .firstOrNull;

    return SectionPage(
      title: 'Studio de variantes',
      subtitle: 'Plusieurs designs vraiment différents pour un même format. (Le pack publicitaire, lui, décline un même design en plusieurs formats.)',
      icon: Icons.auto_awesome_mosaic_outlined,
      accent: PubColors.rose,
      children: [
        PanelCard(
          title: 'Nouvelle série de variantes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _brief,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Ex. : Crée cinq cartes de visite différentes pour mon activité de dépannage informatique.',
                ),
                onChanged: notifier.setBrief,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      initialValue: state.format.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Format'),
                      items: [
                        for (final f in DesignFormats.all)
                          DropdownMenuItem(
                            value: f.id,
                            child: Text(
                              '${f.label} · ${f.sizeLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) =>
                          notifier.setFormat(DesignFormats.byId(id!)!),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre de variantes',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          for (var n = 2; n <= 5; n++)
                            ButtonSegment(value: n, label: Text('$n')),
                        ],
                        selected: {state.count},
                        onSelectionChanged: (s) => notifier.setCount(s.first),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in ArtDirection.defaults.take(state.count))
                    Tooltip(
                      message: d.description,
                      child: Chip(label: Text(d.name)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: state.running
                        ? null
                        : () => _generate(useAi: true),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text('Générer ${state.count} variantes avec l’IA'),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.running
                        ? null
                        : () => _generate(useAi: false),
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: const Text('Hors ligne (sans IA)'),
                  ),
                ],
              ),
              if (config == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'IA non configurée : seule la génération hors ligne est disponible.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (state.running && progress != null) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: progress.total == 0
                      ? null
                      : (progress.done + 0.35) / progress.total,
                ),
                const SizedBox(height: 6),
                Text(
                  'Variante ${(progress.done + 1).clamp(1, progress.total)} sur ${progress.total} : ${progress.current}…',
                ),
              ],
              if (!state.running && state.failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                ErrorBanner(
                  message: 'Certaines variantes n’ont pas pu être produites (les autres sont conservées)',
                  details: state.failures.join('\n'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (orderedGroups.isEmpty)
          const EmptyState(
            icon: Icons.auto_awesome_mosaic_outlined,
            title: 'Aucune série de variantes',
            message: 'Générez votre première série ci-dessus.',
          )
        else ...[
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final entry in orderedGroups)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: entry.key == currentId,
                      label: Text(
                        '${formatLabel(entry.value.first.document)} · ${formatDate(entry.value.first.createdAt)} · ${entry.value.length}',
                      ),
                      onSelected: (_) {
                        _compare.clear();
                        notifier.showGroup(entry.key);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _compare.length >= 2 && _compare.length <= 5
                    ? () => _compareSelected(group)
                    : null,
                icon: const Icon(Icons.compare),
                label: Text('Comparer (${_compare.length})'),
              ),
              if (nextDirection != null && currentId != null)
                OutlinedButton.icon(
                  onPressed: state.running
                      ? null
                      : () => _generate(
                          useAi: config != null,
                          groupId: currentId,
                          directions: [nextDirection],
                        ),
                  icon: const Icon(Icons.add),
                  label: Text('Ajouter « ${nextDirection.name} »'),
                ),
              OutlinedButton.icon(
                onPressed: group.isEmpty
                    ? null
                    : () => ExportActions.exportZip(
                        context,
                        ref,
                        group,
                        'Variantes_${group.first.document.formatId}',
                      ),
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('Exporter la série (ZIP)'),
              ),
              Text(
                'Cochez 2 à 5 variantes pour les comparer.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 260).floor().clamp(1, 5);
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final v in group)
                    SizedBox(
                      width: width,
                      child: _VariantCard(
                        variant: v,
                        selected: _compare.contains(v.id),
                        onSelect: (on) => setState(
                          () => on ? _compare.add(v.id) : _compare.remove(v.id),
                        ),
                        onOpen: () => _preview(v),
                        onEdit: () => openInStudio(ref, v),
                        onRegenerate: () => _regenerate(
                          v,
                          group.where((p) => p.id != v.id).toList(),
                        ),
                        onDuplicate: () => _duplicate(v, group),
                        onTemplate: () =>
                            ExportActions.saveAsTemplate(context, ref, v),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.variant,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onEdit,
    required this.onRegenerate,
    required this.onDuplicate,
    required this.onTemplate,
  });

  final Project variant;
  final bool selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;
  final VoidCallback onDuplicate;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: PubColors.violet, width: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: DocumentThumbnail(document: variant.document, height: 170),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (v) => onSelect(v ?? false),
                      semanticLabel: 'Comparer',
                    ),
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: PubColors.violet,
                      foregroundColor: Colors.white,
                      child: Text(
                        '${variant.variantIndex ?? '?'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        variant.variantStyle ?? variant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 0,
                  runSpacing: 0,
                  children: [
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Ouvrir'),
                    ),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifier'),
                    ),
                    TextButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Régénérer'),
                    ),
                    TextButton.icon(
                      onPressed: onDuplicate,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Dupliquer'),
                    ),
                    TextButton.icon(
                      onPressed: onTemplate,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('Enregistrer comme modèle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
