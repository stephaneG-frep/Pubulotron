import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/units.dart';
import '../../editor/editor_controller.dart';
import '../../engine/font_catalog.dart';
import '../../engine/geometry.dart';
import '../../engine/icon_catalog.dart';
import '../../engine/qr_payload.dart';
import '../../engine/text_layout.dart';
import '../../models/business_profile.dart';
import '../../models/design_element.dart';
import '../../models/fill.dart';
import '../../models/formats.dart';
import '../theme.dart';
import '../widgets/color_picker.dart';
import '../widgets/common.dart';
import 'image_actions.dart';

/// Panneau des propriétés de la sélection (ou de la page).
class PropertiesPanel extends ConsumerWidget {
  const PropertiesPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    final brand = profile?.brandColors ?? const <Color>[];
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final selected = c.selectedElements;
        final children = selected.isEmpty
            ? _pageProperties(context, c, brand)
            : selected.length > 1
            ? _multiProperties(context, c)
            : _elementProperties(
                context,
                ref,
                c,
                selected.single,
                brand,
                profile,
              );
        return ListView(padding: const EdgeInsets.all(14), children: children);
      },
    );
  }

  static Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );

  // ------------------------------------------------------------ page

  List<Widget> _pageProperties(
    BuildContext context,
    EditorController c,
    List<Color> brand,
  ) {
    final doc = c.document;
    final format = DesignFormats.byId(doc.formatId);
    return [
      Text(
        'Page — ${c.page.name}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        '${format?.label ?? 'Format personnalisé'} · ${'${formatMm(doc.widthMm)} × ${formatMm(doc.heightMm)} mm'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      _label(context, 'Fond'),
      FillEditor(
        fill: c.page.background,
        brandColors: brand,
        onChanged: c.setBackground,
      ),
      _label(context, 'Format'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          NumberField(
            label: 'Largeur',
            suffix: 'mm',
            value: doc.widthMm,
            min: 10,
            max: 2000,
            onChanged: (v) => c.resizeDocument(v, doc.heightMm),
          ),
          NumberField(
            label: 'Hauteur',
            suffix: 'mm',
            value: doc.heightMm,
            min: 10,
            max: 2000,
            onChanged: (v) => c.resizeDocument(doc.widthMm, v),
          ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.aspect_ratio),
        label: const Text('Changer de format…'),
        onPressed: () => pickFormatAndResize(context, c),
      ),
      _label(context, 'Recto verso'),
      if (!doc.isDuplex)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.flip_to_back),
              label: const Text('Ajouter un verso vierge'),
              onPressed: () => c.addBackPage(),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Verso copié du recto'),
              onPressed: () => c.addBackPage(copyFront: true),
            ),
          ],
        )
      else
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Supprimer le verso'),
          onPressed: () async {
            if (await confirm(
              context,
              title: 'Supprimer le verso ?',
              message: 'Les éléments du verso seront supprimés (annulable).',
              destructive: true,
            )) {
              c.removeBackPage();
            }
          },
        ),
      _label(context, 'Grille et repères'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Afficher la grille'),
        value: c.showGrid,
        onChanged: (_) => c.toggleGrid(),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Aimanter à la grille'),
        value: c.snapToGrid,
        onChanged: (_) => c.toggleSnapToGrid(),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Guides d’alignement intelligents'),
        value: c.smartGuides,
        onChanged: (_) => c.toggleSmartGuides(),
      ),
      NumberField(
        label: 'Pas de grille',
        suffix: 'mm',
        value: c.gridMm,
        min: 1,
        max: 50,
        onChanged: c.setGridSize,
      ),
      const SizedBox(height: 16),
      Text(
        'Astuce : sélectionnez un élément sur la page pour le modifier. Maj + clic pour une sélection multiple.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  // ------------------------------------------------------------ multiple

  List<Widget> _multiProperties(BuildContext context, EditorController c) {
    final selected = c.selectedElements;
    return [
      Text(
        '${selected.length} éléments sélectionnés',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      _label(context, 'Aligner la sélection'),
      _alignRow(c),
      _label(context, 'Répartir'),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.horizontal_distribute),
            label: const Text('Horizontalement'),
            onPressed: selected.length >= 3
                ? () => c.distribute(horizontal: true)
                : null,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.vertical_distribute),
            label: const Text('Verticalement'),
            onPressed: selected.length >= 3
                ? () => c.distribute(horizontal: false)
                : null,
          ),
        ],
      ),
      _label(context, 'Opacité'),
      Slider(
        value: selected.first.opacity,
        divisions: 20,
        label: '${(selected.first.opacity * 100).round()} %',
        onChangeStart: (_) => c.beginTransaction(),
        onChanged: (v) => c.updateSelected((e) => e.copyWith(opacity: v)),
        onChangeEnd: (_) => c.endTransaction(),
      ),
      _label(context, 'Actions'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_all),
            label: const Text('Dupliquer'),
            onPressed: c.duplicateSelected,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text('Verrouiller'),
            onPressed: () => c.lockSelected(true),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.lock_open),
            label: const Text('Déverrouiller'),
            onPressed: () => c.lockSelected(false),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.flip_to_front),
            label: const Text('Premier plan'),
            onPressed: c.bringToFront,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.flip_to_back),
            label: const Text('Arrière-plan'),
            onPressed: c.sendToBack,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer'),
            onPressed: c.deleteSelected,
          ),
        ],
      ),
    ];
  }

  static Widget _alignRow(EditorController c, {bool toPage = false}) => Wrap(
    spacing: 4,
    children: [
      ToolButton(
        icon: Icons.align_horizontal_left,
        tooltip: 'Aligner à gauche',
        onPressed: () => c.align(AlignMode.left, toPage: toPage),
      ),
      ToolButton(
        icon: Icons.align_horizontal_center,
        tooltip: 'Centrer horizontalement',
        onPressed: () => c.align(AlignMode.centerH, toPage: toPage),
      ),
      ToolButton(
        icon: Icons.align_horizontal_right,
        tooltip: 'Aligner à droite',
        onPressed: () => c.align(AlignMode.right, toPage: toPage),
      ),
      ToolButton(
        icon: Icons.align_vertical_top,
        tooltip: 'Aligner en haut',
        onPressed: () => c.align(AlignMode.top, toPage: toPage),
      ),
      ToolButton(
        icon: Icons.align_vertical_center,
        tooltip: 'Centrer verticalement',
        onPressed: () => c.align(AlignMode.centerV, toPage: toPage),
      ),
      ToolButton(
        icon: Icons.align_vertical_bottom,
        tooltip: 'Aligner en bas',
        onPressed: () => c.align(AlignMode.bottom, toPage: toPage),
      ),
    ],
  );

  // ------------------------------------------------------------ élément

  List<Widget> _elementProperties(
    BuildContext context,
    WidgetRef ref,
    EditorController c,
    DesignElement e,
    List<Color> brand,
    BusinessProfile? profile,
  ) {
    void update(DesignElement Function(DesignElement) f) =>
        c.updateElement(e.id, f);
    final locked = e.locked;
    return [
      Row(
        children: [
          Icon(_typeIcon(e.type), color: PubColors.violet),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.displayName,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ToolButton(
            icon: e.locked ? Icons.lock : Icons.lock_open,
            tooltip: e.locked ? 'Déverrouiller' : 'Verrouiller',
            active: e.locked,
            onPressed: () => c.toggleLock(e.id),
          ),
          ToolButton(
            icon: e.visible ? Icons.visibility : Icons.visibility_off,
            tooltip: e.visible ? 'Masquer' : 'Afficher',
            onPressed: () => c.toggleVisible(e.id),
          ),
        ],
      ),
      if (locked)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Élément verrouillé : déverrouillez-le pour le modifier.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? 0.45 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(context, 'Nom du calque'),
              _NameField(
                key: ValueKey('name-${e.id}'),
                value: e.name,
                hint: e.displayName,
                onChanged: (v) => update((x) => x.copyWith(name: v)),
              ),
              _label(context, 'Position et taille'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NumberField(
                    label: 'X',
                    suffix: 'mm',
                    value: e.x,
                    onChanged: (v) => update((x) => x.copyWith(x: v)),
                  ),
                  NumberField(
                    label: 'Y',
                    suffix: 'mm',
                    value: e.y,
                    onChanged: (v) => update((x) => x.copyWith(y: v)),
                  ),
                  NumberField(
                    label: 'Largeur',
                    suffix: 'mm',
                    value: e.width,
                    min: 0.5,
                    onChanged: (v) => update(
                      (x) => x.copyWith(
                        width: v,
                        height:
                            x.type == ElementType.qr ||
                                x.type == ElementType.icon
                            ? v
                            : null,
                      ),
                    ),
                  ),
                  NumberField(
                    label: 'Hauteur',
                    suffix: 'mm',
                    value: e.height,
                    min: 0.5,
                    onChanged: (v) => update(
                      (x) => x.copyWith(
                        height: v,
                        width:
                            x.type == ElementType.qr ||
                                x.type == ElementType.icon
                            ? v
                            : null,
                      ),
                    ),
                  ),
                  NumberField(
                    label: 'Rotation',
                    suffix: '°',
                    value: e.rotation,
                    min: -360,
                    max: 360,
                    onChanged: (v) => update((x) => x.copyWith(rotation: v)),
                  ),
                ],
              ),
              _label(context, 'Opacité'),
              Slider(
                value: e.opacity,
                divisions: 20,
                label: '${(e.opacity * 100).round()} %',
                onChangeStart: (_) => c.beginTransaction(),
                onChanged: (v) => update((x) => x.copyWith(opacity: v)),
                onChangeEnd: (_) => c.endTransaction(),
              ),
              _label(context, 'Aligner sur la page'),
              _alignRow(c, toPage: true),
              _label(context, 'Ordre des calques'),
              Wrap(
                spacing: 4,
                children: [
                  ToolButton(
                    icon: Icons.vertical_align_top,
                    tooltip: 'Premier plan',
                    onPressed: c.bringToFront,
                  ),
                  ToolButton(
                    icon: Icons.arrow_upward,
                    tooltip: 'Avancer',
                    onPressed: c.bringForward,
                  ),
                  ToolButton(
                    icon: Icons.arrow_downward,
                    tooltip: 'Reculer',
                    onPressed: c.sendBackward,
                  ),
                  ToolButton(
                    icon: Icons.vertical_align_bottom,
                    tooltip: 'Arrière-plan',
                    onPressed: c.sendToBack,
                  ),
                  ToolButton(
                    icon: Icons.copy_all,
                    tooltip: 'Dupliquer (Ctrl+D)',
                    onPressed: c.duplicateSelected,
                  ),
                  ToolButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Supprimer (Suppr)',
                    onPressed: c.deleteSelected,
                  ),
                ],
              ),
              ...switch (e.type) {
                ElementType.text => _textProperties(context, c, e, brand),
                ElementType.shape => _shapeProperties(
                  context,
                  e,
                  brand,
                  update,
                ),
                ElementType.image => _imageProperties(
                  context,
                  ref,
                  c,
                  e,
                  brand,
                  update,
                ),
                ElementType.qr => _qrProperties(
                  context,
                  e,
                  brand,
                  profile,
                  update,
                ),
                ElementType.icon => _iconProperties(context, e, brand, update),
              },
            ],
          ),
        ),
      ),
    ];
  }

  static IconData _typeIcon(ElementType type) => switch (type) {
    ElementType.text => Icons.text_fields,
    ElementType.shape => Icons.category,
    ElementType.image => Icons.image,
    ElementType.qr => Icons.qr_code_2,
    ElementType.icon => Icons.emoji_symbols,
  };

  List<Widget> _strokeEditor(
    BuildContext context,
    DesignElement e,
    List<Color> brand,
    void Function(DesignElement Function(DesignElement)) update,
  ) => [
    _label(context, 'Contour'),
    Row(
      children: [
        ColorSwatchButton(
          color: e.strokeColor ?? PubColors.night,
          brandColors: brand,
          onChanged: (color) => update(
            (x) => x.copyWith(
              strokeColor: color,
              strokeWidth: x.strokeWidth == 0 ? 0.5 : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        NumberField(
          label: 'Épaisseur',
          suffix: 'mm',
          value: e.strokeWidth,
          min: 0,
          max: 20,
          decimals: 2,
          onChanged: (v) => update(
            (x) => x.copyWith(
              strokeWidth: v,
              strokeColor: x.strokeColor ?? PubColors.night,
            ),
          ),
        ),
        if (e.strokeWidth > 0)
          IconButton(
            tooltip: 'Supprimer le contour',
            icon: const Icon(Icons.close),
            onPressed: () =>
                update((x) => x.copyWith(strokeWidth: 0, strokeColor: null)),
          ),
      ],
    ),
  ];

  List<Widget> _textProperties(
    BuildContext context,
    EditorController c,
    DesignElement e,
    List<Color> brand,
  ) {
    void update(DesignElement Function(DesignElement) f) =>
        c.updateElement(e.id, f);
    final def = FontCatalog.byFamily(e.fontFamily);
    final layout = TextLayoutEngine.layout(e);
    return [
      _label(context, 'Texte'),
      _TextContentField(
        key: ValueKey('text-${e.id}'),
        editor: c,
        value: e.text,
        onChanged: (v) => update((x) => x.copyWith(text: v)),
      ),
      if (layout.overflows(e.height))
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber,
                size: 18,
                color: PubColors.orange,
              ),
              const SizedBox(width: 6),
              const Expanded(child: Text('Le texte dépasse de son cadre.')),
              TextButton(
                onPressed: () => update(
                  (x) => x.copyWith(
                    height: TextLayoutEngine.layout(x).height + 0.5,
                  ),
                ),
                child: const Text('Agrandir le cadre'),
              ),
            ],
          ),
        ),
      _label(context, 'Police'),
      DropdownButtonFormField<String>(
        initialValue: def.family,
        isExpanded: true,
        items: [
          for (final f in FontCatalog.families)
            DropdownMenuItem(
              value: f.family,
              child: Text(f.label, style: TextStyle(fontFamily: f.family)),
            ),
        ],
        onChanged: (v) => update((x) => x.copyWith(fontFamily: v)),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          NumberField(
            label: 'Taille',
            suffix: 'pt',
            value: e.fontSize,
            min: 2,
            max: 1000,
            onChanged: (v) => update((x) => x.copyWith(fontSize: v)),
          ),
          ToolButton(
            icon: Icons.format_bold,
            tooltip: def.hasBold ? 'Gras' : 'Pas de gras pour cette police',
            active: e.bold,
            onPressed: def.hasBold
                ? () => update((x) => x.copyWith(bold: !x.bold))
                : null,
          ),
          ToolButton(
            icon: Icons.format_italic,
            tooltip: def.hasItalic
                ? 'Italique'
                : 'Pas d’italique pour cette police',
            active: e.italic,
            onPressed: def.hasItalic
                ? () => update((x) => x.copyWith(italic: !x.italic))
                : null,
          ),
          ColorSwatchButton(
            color: e.color,
            brandColors: brand,
            onChanged: (color) => update((x) => x.copyWith(color: color)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SegmentedButton<TextAlignH>(
        segments: const [
          ButtonSegment(
            value: TextAlignH.left,
            icon: Icon(Icons.format_align_left),
            tooltip: 'Gauche',
          ),
          ButtonSegment(
            value: TextAlignH.center,
            icon: Icon(Icons.format_align_center),
            tooltip: 'Centré',
          ),
          ButtonSegment(
            value: TextAlignH.right,
            icon: Icon(Icons.format_align_right),
            tooltip: 'Droite',
          ),
        ],
        selected: {e.textAlign},
        onSelectionChanged: (s) =>
            update((x) => x.copyWith(textAlign: s.first)),
      ),
      const SizedBox(height: 8),
      SegmentedButton<TextAlignV>(
        segments: const [
          ButtonSegment(
            value: TextAlignV.top,
            icon: Icon(Icons.vertical_align_top),
            tooltip: 'Haut',
          ),
          ButtonSegment(
            value: TextAlignV.middle,
            icon: Icon(Icons.vertical_align_center),
            tooltip: 'Milieu',
          ),
          ButtonSegment(
            value: TextAlignV.bottom,
            icon: Icon(Icons.vertical_align_bottom),
            tooltip: 'Bas',
          ),
        ],
        selected: {e.verticalAlign},
        onSelectionChanged: (s) =>
            update((x) => x.copyWith(verticalAlign: s.first)),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          NumberField(
            label: 'Interligne',
            value: e.lineHeight,
            min: 0.6,
            max: 4,
            decimals: 2,
            onChanged: (v) => update((x) => x.copyWith(lineHeight: v)),
          ),
          NumberField(
            label: 'Approche',
            suffix: 'pt',
            value: e.letterSpacing,
            min: -5,
            max: 50,
            decimals: 2,
            onChanged: (v) => update((x) => x.copyWith(letterSpacing: v)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.height),
        label: const Text('Ajuster le cadre au texte'),
        onPressed: () => update(
          (x) => x.copyWith(height: TextLayoutEngine.layout(x).height + 0.3),
        ),
      ),
      _label(context, 'Fond du texte'),
      _OptionalFill(
        fill: e.fill,
        brand: brand,
        onChanged: (f) => update((x) => x.copyWith(fill: f)),
      ),
      if (e.fill != null)
        NumberField(
          label: 'Arrondi',
          suffix: 'mm',
          value: e.cornerRadius,
          min: 0,
          onChanged: (v) => update((x) => x.copyWith(cornerRadius: v)),
        ),
      ..._strokeEditor(context, e, brand, update),
    ];
  }

  List<Widget> _shapeProperties(
    BuildContext context,
    DesignElement e,
    List<Color> brand,
    void Function(DesignElement Function(DesignElement)) update,
  ) => [
    _label(context, 'Forme'),
    Wrap(
      spacing: 4,
      children: [
        for (final kind in ShapeKind.values)
          ToolButton(
            icon: shapeIcon(kind),
            tooltip: shapeLabel(kind),
            active: e.shape == kind,
            onPressed: () => update((x) => x.copyWith(shape: kind)),
          ),
      ],
    ),
    _label(context, 'Remplissage'),
    _OptionalFill(
      fill: e.fill,
      brand: brand,
      onChanged: (f) => update((x) => x.copyWith(fill: f)),
    ),
    if (e.shape == ShapeKind.rectangle) ...[
      const SizedBox(height: 8),
      NumberField(
        label: 'Arrondi des coins',
        suffix: 'mm',
        value: e.cornerRadius,
        min: 0,
        width: 150,
        onChanged: (v) => update((x) => x.copyWith(cornerRadius: v)),
      ),
    ],
    ..._strokeEditor(context, e, brand, update),
  ];

  List<Widget> _imageProperties(
    BuildContext context,
    WidgetRef ref,
    EditorController c,
    DesignElement e,
    List<Color> brand,
    void Function(DesignElement Function(DesignElement)) update,
  ) => [
    _label(context, 'Image'),
    if (e.assetId == null)
      Text(
        'Emplacement photo vide : il ne sera pas imprimé.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    const SizedBox(height: 6),
    FilledButton.tonalIcon(
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: Text(
        e.assetId == null ? 'Choisir une image' : 'Remplacer l’image',
      ),
      onPressed: () => replaceImage(context, ref, c, e),
    ),
    _label(context, 'Cadrage'),
    SegmentedButton<ImageFit>(
      segments: const [
        ButtonSegment(value: ImageFit.cover, label: Text('Remplir')),
        ButtonSegment(value: ImageFit.contain, label: Text('Entière')),
        ButtonSegment(value: ImageFit.fill, label: Text('Étirer')),
      ],
      selected: {e.imageFit},
      onSelectionChanged: (s) => update((x) => x.copyWith(imageFit: s.first)),
    ),
    const SizedBox(height: 8),
    NumberField(
      label: 'Arrondi des coins',
      suffix: 'mm',
      value: e.cornerRadius,
      min: 0,
      width: 150,
      onChanged: (v) => update((x) => x.copyWith(cornerRadius: v)),
    ),
    ..._strokeEditor(context, e, brand, update),
  ];

  List<Widget> _qrProperties(
    BuildContext context,
    DesignElement e,
    List<Color> brand,
    BusinessProfile? profile,
    void Function(DesignElement Function(DesignElement)) update,
  ) => [
    _label(context, 'Contenu du QR code'),
    _TextContentField(
      key: ValueKey('qr-${e.id}'),
      editor: controller,
      value: e.qrData,
      onChanged: (v) {
        if (QrPayload.isEncodable(v)) update((x) => x.copyWith(qrData: v));
      },
    ),
    if (profile != null) ...[
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final kind in QrKind.values.where((k) => k != QrKind.text))
            if (QrPayload.isEncodable(QrPayload.forKind(kind, profile)))
              ActionChip(
                label: Text(kind.label),
                onPressed: () => update(
                  (x) => x.copyWith(qrData: QrPayload.forKind(kind, profile)),
                ),
              ),
        ],
      ),
    ],
    if (e.width < 18 && e.qrData.length > 120)
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Conseil : ce QR code contient beaucoup de données. Agrandissez-le (≥ 20 mm) pour une lecture fiable.',
        ),
      ),
    _label(context, 'Couleurs'),
    Row(
      children: [
        ColorSwatchButton(
          label: 'Modules',
          color: e.color,
          brandColors: brand,
          onChanged: (color) => update((x) => x.copyWith(color: color)),
        ),
        const SizedBox(width: 12),
        ColorSwatchButton(
          label: 'Fond',
          color: e.fill?.primary ?? const Color(0x00FFFFFF),
          brandColors: brand,
          allowTransparent: true,
          onChanged: (color) => update(
            (x) => x.copyWith(fill: color.a < 0.05 ? null : Fill.solid(color)),
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    Text(
      'Gardez un fort contraste (modules foncés sur fond clair) pour garantir la lecture.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  ];

  List<Widget> _iconProperties(
    BuildContext context,
    DesignElement e,
    List<Color> brand,
    void Function(DesignElement Function(DesignElement)) update,
  ) => [
    _label(context, 'Pictogramme'),
    Row(
      children: [
        ColorSwatchButton(
          color: e.color,
          brandColors: brand,
          onChanged: (color) => update((x) => x.copyWith(color: color)),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          icon: Icon(IconCatalog.byKey(e.iconKey).icon),
          label: const Text('Changer…'),
          onPressed: () async {
            final key = await pickPictogram(context);
            if (key != null) update((x) => x.copyWith(iconKey: key));
          },
        ),
      ],
    ),
  ];
}

IconData shapeIcon(ShapeKind kind) => switch (kind) {
  ShapeKind.rectangle => Icons.crop_square,
  ShapeKind.ellipse => Icons.circle_outlined,
  ShapeKind.triangle => Icons.change_history,
  ShapeKind.diamond => Icons.diamond_outlined,
  ShapeKind.star => Icons.star_border,
  ShapeKind.hexagon => Icons.hexagon_outlined,
};

String shapeLabel(ShapeKind kind) => switch (kind) {
  ShapeKind.rectangle => 'Rectangle',
  ShapeKind.ellipse => 'Ellipse',
  ShapeKind.triangle => 'Triangle',
  ShapeKind.diamond => 'Losange',
  ShapeKind.star => 'Étoile',
  ShapeKind.hexagon => 'Hexagone',
};

/// Éditeur de remplissage : uni, dégradé linéaire ou radial.
class FillEditor extends StatelessWidget {
  const FillEditor({
    super.key,
    required this.fill,
    required this.onChanged,
    this.brandColors = const [],
  });

  final Fill fill;
  final ValueChanged<Fill> onChanged;
  final List<Color> brandColors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<FillKind>(
          segments: const [
            ButtonSegment(value: FillKind.solid, label: Text('Uni')),
            ButtonSegment(value: FillKind.linear, label: Text('Dégradé')),
            ButtonSegment(value: FillKind.radial, label: Text('Radial')),
          ],
          selected: {fill.kind},
          onSelectionChanged: (s) => onChanged(fill.withKind(s.first)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ColorSwatchButton(
              label: fill.isGradient ? 'Début' : 'Couleur',
              color: fill.primary,
              brandColors: brandColors,
              allowTransparent: true,
              onChanged: (c) => onChanged(fill.withPrimary(c)),
            ),
            if (fill.isGradient) ...[
              const SizedBox(width: 12),
              ColorSwatchButton(
                label: 'Fin',
                color: fill.secondary,
                brandColors: brandColors,
                allowTransparent: true,
                onChanged: (c) => onChanged(fill.withSecondary(c)),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Inverser',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => onChanged(
                  fill.withPrimary(fill.secondary).withSecondary(fill.primary),
                ),
              ),
            ],
          ],
        ),
        if (fill.kind == FillKind.linear) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Angle'),
              Expanded(
                child: Slider(
                  value: fill.angle % 360,
                  max: 359,
                  divisions: 72,
                  label: '${fill.angle.round()}°',
                  onChanged: (v) => onChanged(fill.withAngle(v)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OptionalFill extends StatelessWidget {
  const _OptionalFill({
    required this.fill,
    required this.brand,
    required this.onChanged,
  });

  final Fill? fill;
  final List<Color> brand;
  final ValueChanged<Fill?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = fill;
    if (current == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.format_color_fill),
          label: const Text('Ajouter un remplissage'),
          onPressed: () => onChanged(Fill.solid(PubColors.violet)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FillEditor(fill: current, brandColors: brand, onChanged: onChanged),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.format_color_reset),
            label: const Text('Aucun remplissage'),
            onPressed: () => onChanged(null),
          ),
        ),
      ],
    );
  }
}

/// Champ texte multi-ligne appliqué à chaque frappe ; toute la saisie forme
/// une seule étape d'historique tant que le champ garde le focus.
class _TextContentField extends StatefulWidget {
  const _TextContentField({
    super.key,
    required this.editor,
    required this.value,
    required this.onChanged,
  });

  final EditorController editor;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextContentField> createState() => _TextContentFieldState();
}

class _TextContentFieldState extends State<_TextContentField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_TextContentField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      final selection = _controller.selection;
      _controller.text = widget.value;
      if (selection.end <= widget.value.length) {
        _controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (focused) => focused
        ? widget.editor.beginTransaction()
        : widget.editor.endTransaction(),
    child: TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 6,
      onChanged: widget.onChanged,
    ),
  );
}

class _NameField extends StatefulWidget {
  const _NameField({
    super.key,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(hintText: widget.hint),
    onSubmitted: widget.onChanged,
    onTapOutside: (_) {
      if (_controller.text != widget.value) widget.onChanged(_controller.text);
    },
  );
}

/// Sélecteur de pictogramme avec recherche.
Future<String?> pickPictogram(BuildContext context) => showDialog<String>(
  context: context,
  builder: (context) => const _PictogramDialog(),
);

class _PictogramDialog extends StatefulWidget {
  const _PictogramDialog();

  @override
  State<_PictogramDialog> createState() => _PictogramDialogState();
}

class _PictogramDialogState extends State<_PictogramDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = IconCatalog.search(_query);
    return AlertDialog(
      title: const Text('Pictogrammes'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher (téléphone, jardin, promo…)',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.extent(
                maxCrossAxisExtent: 72,
                children: [
                  for (final p in results)
                    Tooltip(
                      message: p.label,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, p.key),
                        child: Icon(p.icon, size: 30, semanticLabel: p.label),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

/// Choix d'un format prédéfini, avec mise à l'échelle du contenu.
Future<void> pickFormatAndResize(
  BuildContext context,
  EditorController c,
) async {
  final format = await showDialog<DesignFormat>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Changer de format'),
      children: [
        for (final f in DesignFormats.all)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, f),
            child: Text('${f.label} — ${f.sizeLabel}'),
          ),
      ],
    ),
  );
  if (format == null) return;
  c.resizeDocument(format.widthMm, format.heightMm, formatId: format.id);
}
