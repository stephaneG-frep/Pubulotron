import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../editor/editor_controller.dart';
import '../../editor/element_factory.dart';
import '../../engine/icon_catalog.dart';
import '../../models/design_element.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'image_actions.dart';
import 'properties_panel.dart' show shapeIcon, shapeLabel;
import 'qr_dialog.dart';

/// Ajout d'éléments : textes, formes, pictogrammes, images, QR, fiche.
class InsertPanel extends ConsumerStatefulWidget {
  const InsertPanel({super.key, required this.controller, this.onInserted});

  final EditorController controller;

  /// Appelé après insertion (ferme la feuille sur mobile).
  final VoidCallback? onInserted;

  @override
  ConsumerState<InsertPanel> createState() => _InsertPanelState();
}

class _InsertPanelState extends ConsumerState<InsertPanel> {
  String _iconQuery = '';

  EditorController get c => widget.controller;

  ElementFactory get _factory => ElementFactory(c.pageSize);

  Color get _accent {
    final colors = ref.read(activeProfileProvider)?.brandColors ?? const [];
    return colors.isNotEmpty ? colors.first : PubColors.violet;
  }

  void _done() => widget.onInserted?.call();

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    final icons = IconCatalog.search(_iconQuery);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _title('Texte'),
        _InsertTile(
          icon: Icons.title,
          label: 'Titre',
          onTap: () {
            c.addElement(_factory.text(TextPreset.title, color: _accent));
            _done();
          },
        ),
        _InsertTile(
          icon: Icons.short_text,
          label: 'Sous-titre',
          onTap: () {
            c.addElement(_factory.text(TextPreset.subtitle));
            _done();
          },
        ),
        _InsertTile(
          icon: Icons.notes,
          label: 'Paragraphe',
          onTap: () {
            c.addElement(_factory.text(TextPreset.body));
            _done();
          },
        ),
        _title('Formes'),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final kind in ShapeKind.values)
              ToolButton(
                icon: shapeIcon(kind),
                tooltip: shapeLabel(kind),
                onPressed: () {
                  c.addElement(_factory.shape(kind, color: _accent));
                  _done();
                },
              ),
          ],
        ),
        _title('Images'),
        _InsertTile(
          icon: Icons.add_photo_alternate_outlined,
          label: 'Importer une photo',
          onTap: () async {
            await addImage(context, ref, c);
            _done();
          },
        ),
        _InsertTile(
          icon: Icons.verified_outlined,
          label: 'Importer un logo',
          onTap: () async {
            await addImage(context, ref, c, logo: true);
            _done();
          },
        ),
        if (profile?.logoAssetId != null)
          _InsertTile(
            icon: Icons.badge_outlined,
            label: 'Logo de ma fiche',
            onTap: () async {
              await addProfileLogo(context, ref, c);
              _done();
            },
          ),
        _InsertTile(
          icon: Icons.crop_original,
          label: 'Emplacement photo (à remplir)',
          onTap: () {
            final side = c.pageSize.shortestSide * 0.4;
            c.addCentered(
              DesignElement(
                type: ElementType.image,
                name: 'Photo',
                role: 'photo',
                x: 0,
                y: 0,
                width: side * 1.4,
                height: side,
              ),
            );
            _done();
          },
        ),
        _title('QR code'),
        _InsertTile(
          icon: Icons.qr_code_2,
          label: 'Générer un QR code',
          onTap: () async {
            final choice = await showQrDialog(context, profile);
            if (choice == null) return;
            c.addElement(
              _factory.qr(choice.data, name: 'QR ${choice.kind.name}'),
            );
            _done();
          },
        ),
        if (profile != null) ...[
          _title('Mon activité — ${profile.name}'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in profile.insertableFields.entries)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(entry.key),
                  onPressed: () {
                    c.addElement(_factory.field(entry.key, entry.value));
                    _done();
                  },
                ),
            ],
          ),
        ],
        _title('Pictogrammes'),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Rechercher un pictogramme',
          ),
          onChanged: (v) => setState(() => _iconQuery = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            for (final p in icons.take(_iconQuery.isEmpty ? 40 : 80))
              ToolButton(
                icon: p.icon,
                tooltip: p.label,
                onPressed: () {
                  c.addElement(_factory.icon(p.key, color: _accent));
                  _done();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _InsertTile extends StatelessWidget {
  const _InsertTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    leading: Icon(icon),
    title: Text(label),
    onTap: onTap,
  );
}

/// Liste des calques, du premier plan (en haut) à l'arrière-plan.
class LayersPanel extends StatelessWidget {
  const LayersPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final elements = controller.page.elements;
        if (elements.isEmpty) {
          return const EmptyState(
            icon: Icons.layers_outlined,
            title: 'Aucun calque',
            message: 'Ajoutez du texte, une forme ou une image.',
          );
        }
        final reversed = elements.reversed.toList();
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(8),
          buildDefaultDragHandles: false,
          itemCount: reversed.length,
          onReorderItem: (oldIndex, newIndex) {
            final from = elements.length - 1 - oldIndex;
            final to = elements.length - 1 - newIndex;
            controller.reorderLayer(from, to);
          },
          itemBuilder: (context, index) {
            final e = reversed[index];
            final selected = controller.selection.contains(e.id);
            return Material(
              key: ValueKey(e.id),
              color: selected
                  ? Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                onTap: () => controller.select(e.id, additive: false),
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator),
                ),
                title: Text(
                  e.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: e.visible ? null : Theme.of(context).disabledColor,
                  ),
                ),
                subtitle: Text(_typeLabel(e.type)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ToolButton(
                      icon: e.visible ? Icons.visibility : Icons.visibility_off,
                      tooltip: e.visible ? 'Masquer' : 'Afficher',
                      onPressed: () => controller.toggleVisible(e.id),
                    ),
                    ToolButton(
                      icon: e.locked ? Icons.lock : Icons.lock_open,
                      tooltip: e.locked ? 'Déverrouiller' : 'Verrouiller',
                      active: e.locked,
                      onPressed: () => controller.toggleLock(e.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _typeLabel(ElementType t) => switch (t) {
    ElementType.text => 'Texte',
    ElementType.shape => 'Forme',
    ElementType.image => 'Image',
    ElementType.qr => 'QR code',
    ElementType.icon => 'Pictogramme',
  };
}
