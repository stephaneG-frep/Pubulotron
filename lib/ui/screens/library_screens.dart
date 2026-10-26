import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/creation_state.dart';
import '../../app/providers.dart';
import '../../data/backup_service.dart';
import '../../export/file_service.dart';
import '../../layout/template_catalog.dart';
import '../../models/design_document.dart';
import '../../models/project.dart';
import '../export_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/project_card.dart';
import 'print_screen.dart';

/// Aperçus des modèles, calculés une fois par session.
final templatePreviewsProvider = Provider<Map<String, DesignDocument>>(
  (ref) => {
    for (final t in TemplateCatalog.all) t.id: TemplateCatalog.instantiate(t),
  },
);

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  String? _category;
  static const _mine = 'Mes modèles';

  Future<void> _use(TemplateDef template) async {
    final profile = ref.read(activeProfileProvider);
    var useProfile = false;
    if (profile != null) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Utiliser « ${template.title} »'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, true),
              child: ListTile(
                leading: const Icon(Icons.business_center_outlined),
                title: Text('Avec ma fiche « ${profile.name} »'),
                subtitle: const Text(
                  'Nom, slogan, coordonnées, couleurs et logo',
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, false),
              child: const ListTile(
                leading: Icon(Icons.text_snippet_outlined),
                title: Text('Avec le contenu d’exemple'),
              ),
            ),
          ],
        ),
      );
      if (choice == null) return;
      useProfile = choice;
    }
    final doc = useProfile
        ? TemplateCatalog.instantiate(template, profile: profile)
        : ref.read(templatePreviewsProvider)[template.id]!;
    await createAndOpen(ref, name: template.title, document: doc);
  }

  @override
  Widget build(BuildContext context) {
    final previews = ref.watch(templatePreviewsProvider);
    final custom =
        ref.watch(customTemplatesProvider).value ?? const <CustomTemplate>[];
    final templates = TemplateCatalog.all
        .where((t) => _category == null || t.category == _category)
        .toList();
    final showCustom = _category == null || _category == _mine;

    Widget card({
      required DesignDocument doc,
      required String title,
      required String subtitle,
      required String description,
      required List<Widget> actions,
    }) => Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocumentThumbnail(document: doc, height: 170),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: PubColors.rose),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: actions),
              ],
            ),
          ),
        ],
      ),
    );

    return SectionPage(
      title: 'Bibliothèque de modèles',
      subtitle:
          '${TemplateCatalog.all.length} modèles dans ${TemplateCatalog.categories.length} métiers, personnalisables avec votre fiche. Disponible hors ligne.',
      icon: Icons.grid_view_rounded,
      accent: PubColors.turquoise,
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(navigationProvider.notifier).go(AppSection.newCreation),
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Page blanche'),
        ),
      ],
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Tous'),
              selected: _category == null,
              onSelected: (_) => setState(() => _category = null),
            ),
            for (final c in TemplateCatalog.categories)
              ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
            ChoiceChip(
              label: Text('$_mine (${custom.length})'),
              selected: _category == _mine,
              onSelected: (_) => setState(() => _category = _mine),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 250).floor().clamp(1, 6);
            final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                if (showCustom)
                  for (final t in custom)
                    SizedBox(
                      width: width,
                      child: card(
                        doc: t.document,
                        title: t.name,
                        subtitle: t.category,
                        description:
                            'Modèle personnel enregistré le ${formatDate(t.createdAt)}.',
                        actions: [
                          FilledButton.tonal(
                            onPressed: () => createAndOpen(
                              ref,
                              name: t.name,
                              document: t.document,
                            ),
                            child: const Text('Utiliser'),
                          ),
                          IconButton(
                            tooltip: 'Supprimer le modèle',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (await confirm(
                                context,
                                title: 'Supprimer ce modèle ?',
                                message:
                                    '« ${t.name} » sera retiré de la bibliothèque.',
                                destructive: true,
                                confirmLabel: 'Supprimer',
                              )) {
                                await ref
                                    .read(customTemplatesProvider.notifier)
                                    .delete(t.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                if (_category != _mine)
                  for (final t in templates)
                    SizedBox(
                      width: width,
                      child: card(
                        doc: previews[t.id]!,
                        title: t.title,
                        subtitle: '${t.category} · ${t.format.label}',
                        description: t.description,
                        actions: [
                          FilledButton.tonal(
                            onPressed: () => _use(t),
                            child: const Text('Utiliser ce modèle'),
                          ),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
        if (_category == _mine && custom.isEmpty)
          const EmptyState(
            icon: Icons.bookmark_add_outlined,
            title: 'Aucun modèle personnel',
            message:
                'Dans l’atelier, menu Exporter › « Enregistrer comme modèle ».',
          ),
      ],
    );
  }
}

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _query = '';
  bool _byName = false;

  Future<void> _action(Project project, ProjectAction action) async {
    final notifier = ref.read(projectsProvider.notifier);
    switch (action) {
      case ProjectAction.open:
        openInStudio(ref, project);
      case ProjectAction.rename:
        final name = await promptText(
          context,
          title: 'Renommer',
          initial: project.name,
          label: 'Nom du projet',
        );
        if (name == null || name.trim().isEmpty) return;
        await notifier.rename(project.id, name);
        final editor = ref.read(editorProvider);
        if (editor?.project.id == project.id) editor!.rename(name);
      case ProjectAction.duplicate:
        final copy = await notifier.duplicate(project.id);
        if (mounted) showMessage(context, '« ${copy.name} » créé.');
      case ProjectAction.print:
        ref.read(printTargetProvider.notifier).set(project.id);
        ref.read(navigationProvider.notifier).go(AppSection.print);
      case ProjectAction.export:
        await ExportActions.exportProjectArchive(context, ref, project);
      case ProjectAction.delete:
        if (!await confirm(
          context,
          title: 'Supprimer « ${project.name} » ?',
          message: 'Le projet sera définitivement supprimé de cet appareil.',
          destructive: true,
          confirmLabel: 'Supprimer',
        )) {
          return;
        }
        if (ref.read(editorProvider)?.project.id == project.id) {
          await ref.read(editorProvider.notifier).close();
        }
        await notifier.delete(project.id);
    }
  }

  Future<void> _backup() async {
    try {
      final bytes = await ref.read(servicesProvider).backup.exportAll();
      if (!mounted) return;
      final now = DateTime.now();
      await ExportActions.deliver(
        context,
        ref,
        bytes,
        'pubulotron_sauvegarde_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.zip',
        'application/zip',
      );
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Échec de la sauvegarde : $e', error: true);
      }
    }
  }

  Future<void> _restore() async {
    final services = ref.read(servicesProvider);
    final PickedFile? picked;
    try {
      picked = await services.files.pick(extensions: const ['zip']);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
      return;
    }
    if (picked == null || !mounted) return;
    if (!await confirm(
      context,
      title: 'Restaurer « ${picked.name} » ?',
      message: 'Les projets, fiches et modèles de l’archive seront ajoutés. Ceux qui existent déjà (même identifiant) seront remplacés par la version de l’archive.',
      confirmLabel: 'Restaurer',
    )) {
      return;
    }
    try {
      final BackupReport report = await services.backup.import(picked.bytes);
      await ref.read(projectsProvider.notifier).refresh();
      await ref.read(profilesProvider.notifier).reload();
      await ref.read(customTemplatesProvider.notifier).reload();
      if (mounted) {
        showMessage(
          context,
          'Restauration terminée : ${report.summary}.${report.skipped.isEmpty ? '' : ' ${report.skipped.length} fichier(s) ignoré(s).'}',
        );
      }
    } on BackupException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Échec de la restauration : $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectsProvider);
    final all = async.value ?? const <Project>[];
    final q = _query.trim().toLowerCase();
    final projects = all
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.brief.toLowerCase().contains(q),
        )
        .toList();
    if (_byName) {
      projects.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    return SectionPage(
      title: 'Mes projets',
      subtitle:
          '${all.length} projet${all.length > 1 ? 's' : ''} enregistré${all.length > 1 ? 's' : ''} sur cet appareil (sauvegarde automatique).',
      icon: Icons.folder_copy_outlined,
      accent: PubColors.night,
      actions: [
        OutlinedButton.icon(
          onPressed: _backup,
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Sauvegarde ZIP'),
        ),
        OutlinedButton.icon(
          onPressed: _restore,
          icon: const Icon(Icons.restore),
          label: const Text('Restaurer / importer'),
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher un projet',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(width: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Récents')),
                ButtonSegment(value: true, label: Text('Nom')),
              ],
              selected: {_byName},
              onSelectionChanged: (s) => setState(() => _byName = s.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (async.isLoading && all.isEmpty)
          const Center(child: CircularProgressIndicator()),
        if (async.hasError)
          ErrorBanner(
            message: 'Impossible de lire les projets',
            details: '${async.error}',
          ),
        if (!async.isLoading && all.isEmpty)
          EmptyState(
            icon: Icons.folder_open,
            title: 'Aucun projet',
            message: 'Vos créations sont enregistrées automatiquement ici.',
            action: FilledButton(
              onPressed: () => ref
                  .read(navigationProvider.notifier)
                  .go(AppSection.newCreation),
              child: const Text('Créer mon premier projet'),
            ),
          )
        else
          ProjectGrid(
            projects: projects,
            onOpen: (p) => openInStudio(ref, p),
            onAction: _action,
          ),
      ],
    );
  }
}
