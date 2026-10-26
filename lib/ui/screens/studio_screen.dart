import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../editor/editor_controller.dart';
import '../../export/raster_exporter.dart';
import '../../models/design_element.dart';
import '../../models/project.dart';
import '../editor/ai_chat_panel.dart';
import '../editor/editor_canvas.dart';
import '../editor/insert_panel.dart';
import '../editor/properties_panel.dart';
import '../export_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/project_card.dart';

/// Atelier graphique.
class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(editorProvider);
    if (controller == null) return const _StudioLanding();
    return _Studio(key: ValueKey(controller), controller: controller);
  }
}

class _StudioLanding extends ConsumerWidget {
  const _StudioLanding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    return SectionPage(
      title: 'Atelier graphique',
      subtitle: 'Ouvrez un projet ou démarrez une nouvelle création.',
      icon: Icons.design_services,
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle création'),
          onPressed: () =>
              ref.read(navigationProvider.notifier).go(AppSection.newCreation),
        ),
      ],
      children: [
        if (projects.isEmpty)
          EmptyState(
            icon: Icons.brush_outlined,
            title: 'Aucun projet pour le moment',
            message: 'Créez une carte, un flyer ou une affiche à partir d’un modèle, d’une page blanche ou avec l’IA.',
            action: FilledButton(
              onPressed: () => ref
                  .read(navigationProvider.notifier)
                  .go(AppSection.templates),
              child: const Text('Parcourir les modèles'),
            ),
          )
        else ...[
          Text(
            'Projets récents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ProjectGrid(
            projects: projects.take(12).toList(),
            onOpen: (p) => openInStudio(ref, p),
          ),
        ],
      ],
    );
  }
}

class _Studio extends ConsumerStatefulWidget {
  const _Studio({super.key, required this.controller});

  final EditorController controller;

  @override
  ConsumerState<_Studio> createState() => _StudioState();
}

class _StudioState extends ConsumerState<_Studio> {
  final _focus = FocusNode(debugLabel: 'atelier');

  EditorController get c => widget.controller;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _editText(DesignElement e) async {
    final value = await promptText(
      context,
      title: 'Modifier le texte',
      initial: e.text,
      maxLines: 6,
    );
    if (value != null) c.updateElement(e.id, (x) => x.copyWith(text: value));
    _focus.requestFocus();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): c.undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        c.redo,
    const SingleActivator(LogicalKeyboardKey.keyY, control: true): c.redo,
    const SingleActivator(LogicalKeyboardKey.keyD, control: true):
        c.duplicateSelected,
    const SingleActivator(LogicalKeyboardKey.keyC, control: true):
        c.copySelection,
    const SingleActivator(LogicalKeyboardKey.keyX, control: true):
        c.cutSelection,
    const SingleActivator(LogicalKeyboardKey.keyV, control: true): c.paste,
    const SingleActivator(LogicalKeyboardKey.keyA, control: true): c.selectAll,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
        c.saveNow(),
    const SingleActivator(LogicalKeyboardKey.delete): c.deleteSelected,
    const SingleActivator(LogicalKeyboardKey.backspace): c.deleteSelected,
    const SingleActivator(LogicalKeyboardKey.escape): c.clearSelection,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () => c.nudge(-0.5, 0),
    const SingleActivator(LogicalKeyboardKey.arrowRight): () => c.nudge(0.5, 0),
    const SingleActivator(LogicalKeyboardKey.arrowUp): () => c.nudge(0, -0.5),
    const SingleActivator(LogicalKeyboardKey.arrowDown): () => c.nudge(0, 0.5),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
        c.nudge(-5, 0),
    const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
        c.nudge(5, 0),
    const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
        c.nudge(0, -5),
    const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () =>
        c.nudge(0, 5),
    const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
        c.setZoom(c.zoom * 1.2),
    const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
        c.setZoom(c.zoom / 1.2),
    const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
        c.setZoom(1),
    const SingleActivator(LogicalKeyboardKey.keyG, control: true): c.toggleGrid,
  };

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(servicesProvider).images;
    final canvas = Focus(
      focusNode: _focus,
      autofocus: true,
      child: GestureDetector(
        onTapDown: (_) => _focus.requestFocus(),
        behavior: HitTestBehavior.translucent,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: EditorCanvas(
            controller: c,
            images: images,
            onEditText: _editText,
          ),
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: _shortcuts,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final toolbar = _Toolbar(controller: c, compact: width < 760);
          if (width >= 1100) {
            return Column(
              children: [
                toolbar,
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 290,
                        child: _Tabs(
                          tabs: {
                            'Insérer': InsertPanel(controller: c),
                            'Calques': LayersPanel(controller: c),
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: canvas),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 350,
                        child: _Tabs(
                          tabs: {
                            'Propriétés': PropertiesPanel(controller: c),
                            'Agent IA': AiChatPanel(controller: c),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          if (width >= 760) {
            return Column(
              children: [
                toolbar,
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: canvas),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 340,
                        child: _Tabs(
                          tabs: {
                            'Propriétés': PropertiesPanel(controller: c),
                            'Insérer': InsertPanel(controller: c),
                            'Calques': LayersPanel(controller: c),
                            'IA': AiChatPanel(controller: c),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              toolbar,
              const Divider(height: 1),
              Expanded(child: canvas),
              _MobileBar(controller: c),
            ],
          );
        },
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabs});

  final Map<String, Widget> tabs;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: tabs.length,
    child: Column(
      children: [
        TabBar(
          tabs: [for (final t in tabs.keys) Tab(text: t)],
          isScrollable: tabs.length > 3,
          tabAlignment: tabs.length > 3 ? TabAlignment.start : null,
        ),
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: tabs.values.toList(),
          ),
        ),
      ],
    ),
  );
}

class _MobileBar extends StatelessWidget {
  const _MobileBar({required this.controller});

  final EditorController controller;

  void _sheet(
    BuildContext context,
    String title,
    Widget Function(VoidCallback close) child,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        builder: (context, scroll) => Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Expanded(child: child(() => Navigator.pop(context))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 6,
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _BarButton(
                icon: Icons.add_circle_outline,
                label: 'Insérer',
                onTap: () => _sheet(
                  context,
                  'Insérer',
                  (close) =>
                      InsertPanel(controller: controller, onInserted: close),
                ),
              ),
              _BarButton(
                icon: Icons.tune,
                label: 'Propriétés',
                onTap: () => _sheet(
                  context,
                  'Propriétés',
                  (_) => PropertiesPanel(controller: controller),
                ),
              ),
              _BarButton(
                icon: Icons.layers_outlined,
                label: 'Calques',
                onTap: () => _sheet(
                  context,
                  'Calques',
                  (_) => LayersPanel(controller: controller),
                ),
              ),
              _BarButton(
                icon: Icons.auto_awesome,
                label: 'Agent IA',
                onTap: () => _sheet(
                  context,
                  'Agent IA',
                  (_) => AiChatPanel(controller: controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.controller, required this.compact});

  final EditorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final doc = c.document;
        final row = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Fermer le projet',
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(editorProvider.notifier).close(),
              ),
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final name = await promptText(
                      context,
                      title: 'Renommer le projet',
                      initial: c.project.name,
                      label: 'Nom',
                    );
                    if (name != null) c.rename(name);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        _SaveIndicator(controller: c),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ToolButton(
                icon: Icons.undo,
                tooltip: 'Annuler (Ctrl+Z)',
                onPressed: c.canUndo ? c.undo : null,
              ),
              ToolButton(
                icon: Icons.redo,
                tooltip: 'Rétablir (Ctrl+Y)',
                onPressed: c.canRedo ? c.redo : null,
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                ToolButton(
                  icon: Icons.zoom_out,
                  tooltip: 'Dézoomer (Ctrl+-)',
                  onPressed: () => c.setZoom(c.zoom / 1.2),
                ),
                TextButton(
                  onPressed: () => c.setZoom(1),
                  child: Text('${(c.zoom * 100).round()} %'),
                ),
                ToolButton(
                  icon: Icons.zoom_in,
                  tooltip: 'Zoomer (Ctrl++)',
                  onPressed: () => c.setZoom(c.zoom * 1.2),
                ),
                ToolButton(
                  icon: Icons.grid_4x4,
                  tooltip: 'Grille (Ctrl+G)',
                  active: c.showGrid,
                  onPressed: c.toggleGrid,
                ),
                ToolButton(
                  icon: Icons.straighten,
                  tooltip: 'Guides d’alignement',
                  active: c.smartGuides,
                  onPressed: c.toggleSmartGuides,
                ),
              ],
              if (doc.isDuplex && !compact) ...[
                const SizedBox(width: 8),
                _FaceSwitch(controller: c),
              ],
              const Spacer(),
              if (compact)
                PopupMenuButton<String>(
                  tooltip: 'Affichage',
                  icon: const Icon(Icons.visibility_outlined),
                  onSelected: (v) => switch (v) {
                    'in' => c.setZoom(c.zoom * 1.25),
                    'out' => c.setZoom(c.zoom / 1.25),
                    'fit' => c.setZoom(1),
                    'grid' => c.toggleGrid(),
                    _ => c.toggleSmartGuides(),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'in', child: Text('Zoomer')),
                    const PopupMenuItem(value: 'out', child: Text('Dézoomer')),
                    const PopupMenuItem(
                      value: 'fit',
                      child: Text('Ajuster à l’écran'),
                    ),
                    CheckedPopupMenuItem(
                      value: 'grid',
                      checked: c.showGrid,
                      child: const Text('Grille'),
                    ),
                    CheckedPopupMenuItem(
                      value: 'guides',
                      checked: c.smartGuides,
                      child: const Text('Guides'),
                    ),
                  ],
                ),
              _ExportMenu(controller: c, compact: compact),
            ],
          ),
        );
        if (!(compact && doc.isDuplex)) return row;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _FaceSwitch(controller: c),
            ),
          ],
        );
      },
    );
  }
}

class _FaceSwitch extends StatelessWidget {
  const _FaceSwitch({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: const [
      ButtonSegment(value: 0, label: Text('Recto')),
      ButtonSegment(value: 1, label: Text('Verso')),
    ],
    selected: {controller.pageIndex},
    onSelectionChanged: (s) => controller.setPage(s.first),
  );
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (controller.saveState) {
      SaveState.saved => (
        Icons.cloud_done_outlined,
        'Enregistré',
        PubColors.turquoise,
      ),
      SaveState.pending => (
        Icons.edit_note,
        'Modifications…',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      SaveState.saving => (
        Icons.sync,
        'Enregistrement…',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      SaveState.error => (
        Icons.error_outline,
        'Erreur d’enregistrement',
        Theme.of(context).colorScheme.error,
      ),
    };
    return Tooltip(
      message: controller.saveError ?? 'Sauvegarde automatique locale',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportMenu extends ConsumerWidget {
  const _ExportMenu({required this.controller, this.compact = false});

  final EditorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Exporter',
      onSelected: (value) async {
        await controller.saveNow();
        final project = controller.project;
        if (!context.mounted) return;
        switch (value) {
          case 'pdf':
            await ExportActions.exportPdf(context, ref, project);
          case 'pdf-bleed':
            await ExportActions.exportPdf(context, ref, project, bleedMm: 3);
          case 'png':
            await ExportActions.exportRaster(
              context,
              ref,
              project,
              RasterFormat.png,
            );
          case 'jpeg':
            await ExportActions.exportRaster(
              context,
              ref,
              project,
              RasterFormat.jpeg,
            );
          case 'print':
            await ExportActions.printProject(context, ref, project);
          case 'multi':
            ref.read(navigationProvider.notifier).go(AppSection.print);
          case 'zip':
            await ExportActions.exportProjectArchive(context, ref, project);
          case 'template':
            await ExportActions.saveAsTemplate(context, ref, project);
          case 'save':
            await controller.saveNow();
            if (context.mounted) {
              showMessage(
                context,
                controller.saveState == SaveState.error
                    ? 'Échec : ${controller.saveError}'
                    : 'Projet enregistré.',
                error: controller.saveState == SaveState.error,
              );
            }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'save',
          child: ListTile(
            leading: Icon(Icons.save_outlined),
            title: Text('Enregistrer maintenant'),
            subtitle: Text('Ctrl+S'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'pdf',
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('PDF vectoriel'),
          ),
        ),
        PopupMenuItem(
          value: 'pdf-bleed',
          child: ListTile(
            leading: Icon(Icons.crop_free),
            title: Text('PDF avec fond perdu 3 mm'),
          ),
        ),
        PopupMenuItem(
          value: 'png',
          child: ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Image PNG'),
          ),
        ),
        PopupMenuItem(
          value: 'jpeg',
          child: ListTile(
            leading: Icon(Icons.photo_outlined),
            title: Text('Image JPEG'),
          ),
        ),
        PopupMenuItem(
          value: 'print',
          child: ListTile(
            leading: Icon(Icons.print_outlined),
            title: Text('Imprimer'),
          ),
        ),
        PopupMenuItem(
          value: 'multi',
          child: ListTile(
            leading: Icon(Icons.grid_view),
            title: Text('Plusieurs exemplaires par feuille…'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'zip',
          child: ListTile(
            leading: Icon(Icons.folder_zip_outlined),
            title: Text('Archive du projet (ZIP)'),
          ),
        ),
        PopupMenuItem(
          value: 'template',
          child: ListTile(
            leading: Icon(Icons.bookmark_add_outlined),
            title: Text('Enregistrer comme modèle'),
          ),
        ),
      ],
      icon: compact ? const Icon(Icons.ios_share) : null,
      child: compact
          ? null
          : const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                avatar: Icon(Icons.ios_share, size: 18),
                label: Text('Exporter'),
              ),
            ),
    );
  }
}
