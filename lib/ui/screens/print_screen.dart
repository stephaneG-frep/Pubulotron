import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../app/providers.dart';
import '../../core/units.dart';
import '../../engine/design_canvas.dart';
import '../../engine/flutter_canvas.dart';
import '../../engine/image_cache.dart';
import '../../export/file_service.dart';
import '../../models/design_document.dart';
import '../../models/formats.dart';
import '../../models/project.dart';
import '../../print/imposition.dart';
import '../../print/sheet_renderer.dart';
import '../export_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/project_card.dart';

/// Projet visé par l'imprimerie (sinon celui ouvert dans l'atelier).
class PrintTargetNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final printTargetProvider = NotifierProvider<PrintTargetNotifier, String?>(
  PrintTargetNotifier.new,
);

class PrintScreen extends ConsumerStatefulWidget {
  const PrintScreen({super.key});

  @override
  ConsumerState<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends ConsumerState<PrintScreen> {
  int _sheet = 0;
  bool _showBack = false;
  bool _busy = false;

  PrintSettings get _settings => ref.read(settingsProvider).print;

  void _update(PrintSettings Function(PrintSettings) change) {
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(print: change(s.print)));
    setState(() => _sheet = 0);
  }

  Project? _target(List<Project> projects) {
    final editor = ref.watch(editorProvider);
    final id = ref.watch(printTargetProvider) ?? editor?.project.id;
    if (editor != null && editor.project.id == id) return editor.project;
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return editor?.project ?? (projects.isEmpty ? null : projects.first);
  }

  Future<void> _export(
    Project project,
    Imposition imposition, {
    required String mode,
  }) async {
    setState(() => _busy = true);
    try {
      final duplex = _settings.duplex && project.document.isDuplex;
      final result = await ref
          .read(servicesProvider)
          .pdf
          .exportImposed(
            project.document,
            imposition,
            duplex: duplex,
            title: '${project.name} — ${imposition.copies} exemplaires',
          );
      if (!mounted) return;
      if (ExportActions.emptyPhotoSlots(project.document) > 0) {
        showMessage(
          context,
          'Des emplacements photo sont vides : ils ne seront pas imprimés.',
        );
      }
      final fileName = safeFileName(
        '${project.name}_${imposition.copies}ex',
        'pdf',
      );
      switch (mode) {
        case 'print':
          await Printing.layoutPdf(
            onLayout: (_) async => result.bytes,
            name: fileName,
          );
        default:
          await ExportActions.deliver(
            context,
            ref,
            result.bytes,
            fileName,
            'application/pdf',
          );
      }
    } catch (error) {
      if (mounted) showMessage(context, 'Échec : $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final settings = ref.watch(settingsProvider).print;
    final project = _target(projects);
    if (project == null) {
      return SectionPage(
        title: 'Imprimerie PDF',
        icon: Icons.local_printshop_outlined,
        accent: PubColors.orange,
        children: [
          EmptyState(
            icon: Icons.print_disabled_outlined,
            title: 'Aucune création à imprimer',
            message: 'Créez ou ouvrez un projet, puis revenez ici pour en placer plusieurs exemplaires sur une feuille.',
            action: FilledButton(
              onPressed: () => ref
                  .read(navigationProvider.notifier)
                  .go(AppSection.newCreation),
              child: const Text('Nouvelle création'),
            ),
          ),
        ],
      );
    }
    final doc = project.document;
    Imposition? imposition;
    String? error;
    try {
      imposition = Imposition.compute(
        settings: settings,
        cardWidthMm: doc.widthMm,
        cardHeightMm: doc.heightMm,
      );
    } on PrintLayoutException catch (e) {
      error = e.message;
    }
    final sheet = imposition == null
        ? 0
        : _sheet.clamp(0, imposition.sheetCount - 1);
    final canDuplex = doc.isDuplex;

    final controls = PanelCard(
      title: 'Réglages d’impression',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: projects.any((p) => p.id == project.id)
                ? project.id
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Création à imprimer'),
            items: [
              for (final p in projects)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    '${p.name} — ${formatLabel(p.document)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              ref.read(printTargetProvider.notifier).set(id);
              setState(() => _sheet = 0);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: settings.paperId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Papier'),
                  items: [
                    for (final p in PaperFormat.standard)
                      DropdownMenuItem(value: p.id, child: Text(p.label)),
                    const DropdownMenuItem(
                      value: 'custom',
                      child: Text('Format personnalisé'),
                    ),
                  ],
                  onChanged: (id) {
                    final paper = PaperFormat.byId(id ?? 'A4');
                    _update(
                      (s) => s.copyWith(
                        paperId: id,
                        paperWidthMm: paper?.widthMm ?? s.paperWidthMm,
                        paperHeightMm: paper?.heightMm ?? s.paperHeightMm,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (settings.paperId == 'custom') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                NumberField(
                  label: 'Largeur papier',
                  suffix: 'mm',
                  width: 150,
                  value: settings.paperWidthMm,
                  min: 20,
                  max: 2000,
                  onChanged: (v) => _update((s) => s.copyWith(paperWidthMm: v)),
                ),
                NumberField(
                  label: 'Hauteur papier',
                  suffix: 'mm',
                  width: 150,
                  value: settings.paperHeightMm,
                  min: 20,
                  max: 2000,
                  onChanged: (v) =>
                      _update((s) => s.copyWith(paperHeightMm: v)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<SheetOrientation>(
            segments: const [
              ButtonSegment(
                value: SheetOrientation.auto,
                label: Text('Auto'),
                icon: Icon(Icons.auto_fix_high),
              ),
              ButtonSegment(
                value: SheetOrientation.portrait,
                label: Text('Portrait'),
                icon: Icon(Icons.crop_portrait),
              ),
              ButtonSegment(
                value: SheetOrientation.landscape,
                label: Text('Paysage'),
                icon: Icon(Icons.crop_landscape),
              ),
            ],
            selected: {settings.orientation},
            onSelectionChanged: (s) =>
                _update((x) => x.copyWith(orientation: s.first)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              NumberField(
                label: 'Exemplaires',
                value: settings.copies.toDouble(),
                decimals: 0,
                min: 1,
                max: 100000,
                onChanged: (v) => _update((s) => s.copyWith(copies: v.round())),
              ),
              NumberField(
                label: 'Marges',
                suffix: 'mm',
                value: settings.marginMm,
                min: 0,
                max: 100,
                onChanged: (v) => _update((s) => s.copyWith(marginMm: v)),
              ),
              NumberField(
                label: 'Espacement',
                suffix: 'mm',
                value: settings.gapMm,
                min: 0,
                max: 100,
                onChanged: (v) => _update((s) => s.copyWith(gapMm: v)),
              ),
              NumberField(
                label: 'Fond perdu',
                suffix: 'mm',
                value: settings.bleedMm,
                min: 0,
                max: 10,
                onChanged: (v) => _update((s) => s.copyWith(bleedMm: v)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Traits de découpe'),
            value: settings.cutMarks,
            onChanged: (v) => _update((s) => s.copyWith(cutMarks: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Centrer sur la feuille'),
            value: settings.center,
            onChanged: (v) => _update((s) => s.copyWith(center: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recto verso'),
            subtitle: Text(
              canDuplex
                  ? 'Une page verso suit chaque page recto'
                  : 'Cette création n’a pas de verso',
            ),
            value: settings.duplex && canDuplex,
            onChanged: canDuplex
                ? (v) => _update((s) => s.copyWith(duplex: v))
                : null,
          ),
          if (settings.duplex && canDuplex)
            SegmentedButton<DuplexFlip>(
              segments: const [
                ButtonSegment(
                  value: DuplexFlip.longEdge,
                  label: Text('Retournement bord long'),
                ),
                ButtonSegment(
                  value: DuplexFlip.shortEdge,
                  label: Text('Bord court'),
                ),
              ],
              selected: {settings.flip},
              onSelectionChanged: (s) =>
                  _update((x) => x.copyWith(flip: s.first)),
            ),
          if (settings.duplex && canDuplex)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Choisissez le même réglage dans la boîte de dialogue de votre imprimante.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );

    final summary = imposition == null
        ? ErrorBanner(message: 'Disposition impossible', details: error)
        : _Summary(imposition: imposition, document: doc);

    final preview = PanelCard(
      title: 'Aperçu des feuilles',
      trailing: imposition == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Feuille précédente',
                  onPressed: sheet > 0
                      ? () => setState(() => _sheet = sheet - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${sheet + 1} / ${imposition.sheetCount}'),
                IconButton(
                  tooltip: 'Feuille suivante',
                  onPressed: sheet < imposition.sheetCount - 1
                      ? () => setState(() => _sheet = sheet + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imposition != null && settings.duplex && canDuplex)
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Recto')),
                  ButtonSegment(value: true, label: Text('Verso')),
                ],
                selected: {_showBack},
                onSelectionChanged: (s) => setState(() => _showBack = s.first),
              ),
            ),
          const SizedBox(height: 10),
          if (imposition != null)
            SizedBox(
              height: 460,
              child: SheetPreview(
                document: doc,
                imposition: imposition,
                sheet: sheet,
                back: _showBack && settings.duplex && canDuplex,
                images: ref.watch(servicesProvider).images,
              ),
            )
          else
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('Ajustez les réglages pour voir l’aperçu.'),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: imposition == null || _busy
                    ? null
                    : () => _export(project, imposition!, mode: 'save'),
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  ref.read(servicesProvider).files.canShare
                      ? 'Exporter / partager le PDF'
                      : 'Exporter le PDF',
                ),
              ),
              OutlinedButton.icon(
                onPressed: imposition == null || _busy
                    ? null
                    : () => _export(project, imposition!, mode: 'print'),
                icon: const Icon(Icons.print),
                label: const Text('Imprimer'),
              ),
              if (_busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
            ],
          ),
        ],
      ),
    );

    return SectionPage(
      title: 'Imprimerie PDF',
      subtitle: 'Plusieurs exemplaires par feuille, calculés au dixième de millimètre. PDF vectoriel, sans capture d’écran.',
      icon: Icons.local_printshop_outlined,
      accent: PubColors.orange,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 900;
            if (!wide) {
              return Column(
                children: [
                  controls,
                  const SizedBox(height: 16),
                  summary,
                  const SizedBox(height: 16),
                  preview,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 400, child: controls),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [summary, const SizedBox(height: 16), preview],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.imposition, required this.document});

  final Imposition imposition;
  final DesignDocument document;

  @override
  Widget build(BuildContext context) {
    final i = imposition;
    Widget stat(String value, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            stat(
              '${i.perSheet}',
              'par feuille (${i.columns} × ${i.rows})',
              PubColors.violet,
            ),
            stat(
              '${i.sheetCount}',
              'feuille${i.sheetCount > 1 ? 's' : ''}',
              PubColors.orange,
            ),
            stat(
              '${(i.paperUsage * 100).round()} %',
              'du papier utilisé',
              PubColors.turquoise,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${i.copies} exemplaires de ${formatMm(document.widthMm)} × ${formatMm(document.heightMm)} mm sur '
          '${formatMm(i.sheetWidthMm)} × ${formatMm(i.sheetHeightMm)} mm (${i.landscape ? 'paysage' : 'portrait'}). '
          'Dernière feuille : ${i.lastSheetCount} exemplaire${i.lastSheetCount > 1 ? 's' : ''}.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Aperçu fidèle d'une feuille, peint par le même moteur que le PDF.
class SheetPreview extends StatelessWidget {
  const SheetPreview({
    super.key,
    required this.document,
    required this.imposition,
    required this.sheet,
    required this.back,
    this.images,
  });

  final DesignDocument document;
  final Imposition imposition;
  final int sheet;
  final bool back;
  final DesignImageCache? images;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / imposition.sheetWidthMm,
          constraints.maxHeight / imposition.sheetHeightMm,
        );
        final size = Size(
          imposition.sheetWidthMm * scale,
          imposition.sheetHeightMm * scale,
        );
        return Center(
          child: Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: RepaintBoundary(
              child: ListenableBuilder(
                listenable: images ?? Listenable.merge(const []),
                builder: (context, _) => CustomPaint(
                  size: size,
                  painter: _SheetPainter(
                    document,
                    imposition,
                    sheet,
                    back,
                    scale,
                    images,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter(
    this.document,
    this.imposition,
    this.sheet,
    this.back,
    this.scale,
    this.images,
  );

  final DesignDocument document;
  final Imposition imposition;
  final int sheet;
  final bool back;
  final double scale;
  final DesignImageCache? images;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    SheetRenderer.paint(
      FlutterDesignCanvas(canvas),
      document: document,
      imposition: imposition,
      sheet: sheet,
      back: back,
      resolveImage: images == null
          ? null
          : (id) {
              final img = images!.get(id);
              return img == null
                  ? null
                  : DesignImage(
                      id: id,
                      width: img.width,
                      height: img.height,
                      decoded: img,
                    );
            },
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheetPainter old) =>
      old.document != document ||
      old.imposition != imposition ||
      old.sheet != sheet ||
      old.back != back ||
      old.scale != scale;
}
