import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../app/providers.dart';
import '../core/units.dart';
import '../export/creations_zip.dart';
import '../export/file_service.dart';
import '../export/raster_exporter.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/formats.dart';
import '../models/project.dart';
import 'widgets/common.dart';

/// Opérations d'export communes aux différentes rubriques.
class ExportActions {
  static int emptyPhotoSlots(DesignDocument doc) => doc.pages
      .expand((p) => p.elements)
      .where(
        (e) => e.visible && e.type == ElementType.image && e.assetId == null,
      )
      .length;

  static void _warnPlaceholders(BuildContext context, DesignDocument doc) {
    final empty = emptyPhotoSlots(doc);
    if (empty > 0) {
      showMessage(
        context,
        '$empty emplacement${empty > 1 ? 's' : ''} photo vide${empty > 1 ? 's' : ''} : non exporté${empty > 1 ? 's' : ''}. Ajoutez vos images dans l’atelier.',
      );
    }
  }

  /// Enregistre (ou partage sur Android) un fichier produit.
  static Future<void> deliver(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    final files = ref.read(servicesProvider).files;
    try {
      if (files.canShare) {
        final choice = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Partager'),
                  subtitle: Text(fileName),
                  onTap: () => Navigator.pop(context, 'share'),
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('Enregistrer dans un dossier'),
                  onTap: () => Navigator.pop(context, 'save'),
                ),
              ],
            ),
          ),
        );
        if (choice == null) return;
        if (choice == 'share') {
          await files.share(bytes, fileName, mimeType: mimeType);
          return;
        }
      }
      final path = await files.save(bytes, fileName, mimeType: mimeType);
      if (path != null && context.mounted) {
        showMessage(context, 'Fichier enregistré : $path');
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, 'Échec de l’enregistrement : $error', error: true);
      }
    }
  }

  static Future<T?> _withProgress<T>(
    BuildContext context,
    String label,
    Future<T> Function() task,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
    try {
      return await task();
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  static Future<void> exportPdf(
    BuildContext context,
    WidgetRef ref,
    Project project, {
    double bleedMm = 0,
  }) async {
    try {
      final result = await _withProgress(
        context,
        'Génération du PDF vectoriel…',
        () => ref
            .read(servicesProvider)
            .pdf
            .exportDocument(
              project.document,
              title: project.name,
              bleedMm: bleedMm,
            ),
      );
      if (result == null || !context.mounted) return;
      _warnPlaceholders(context, project.document);
      if (result.missingImages.isNotEmpty) {
        showMessage(
          context,
          '${result.missingImages.length} image(s) introuvable(s) dans la médiathèque.',
          error: true,
        );
      }
      await deliver(
        context,
        ref,
        result.bytes,
        safeFileName(project.name, 'pdf'),
        'application/pdf',
      );
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          'Échec de la génération du PDF : $error',
          error: true,
        );
      }
    }
  }

  static Future<void> printProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    try {
      final result = await _withProgress(
        context,
        'Préparation de l’impression…',
        () => ref
            .read(servicesProvider)
            .pdf
            .exportDocument(project.document, title: project.name),
      );
      if (result == null) return;
      await Printing.layoutPdf(
        onLayout: (_) async => result.bytes,
        name: project.name,
      );
    } catch (error) {
      if (context.mounted) {
        showMessage(context, 'Impression impossible : $error', error: true);
      }
    }
  }

  static Future<void> exportRaster(
    BuildContext context,
    WidgetRef ref,
    Project project,
    RasterFormat format,
  ) async {
    final doc = project.document;
    final options = await showDialog<(double, int)>(
      context: context,
      builder: (context) => _RasterDialog(
        document: doc,
        format: format,
        defaultDpi: ref.read(settingsProvider).exportDpi,
      ),
    );
    if (options == null || !context.mounted) return;
    final (dpi, page) = options;
    try {
      final bytes = await _withProgress(
        context,
        'Rendu de l’image…',
        () => ref
            .read(servicesProvider)
            .raster
            .export(doc, pageIndex: page, dpi: dpi, format: format),
      );
      if (bytes == null || !context.mounted) return;
      _warnPlaceholders(context, doc);
      final suffix = doc.isDuplex ? (page == 0 ? '_recto' : '_verso') : '';
      final ext = format == RasterFormat.png ? 'png' : 'jpg';
      await deliver(
        context,
        ref,
        bytes,
        safeFileName('${project.name}$suffix', ext),
        format == RasterFormat.png ? 'image/png' : 'image/jpeg',
      );
    } catch (error) {
      if (context.mounted) {
        showMessage(context, 'Échec de l’export : $error', error: true);
      }
    }
  }

  static Future<void> exportProjectArchive(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    try {
      final bytes = await ref
          .read(servicesProvider)
          .backup
          .exportProject(project);
      if (!context.mounted) return;
      await deliver(
        context,
        ref,
        bytes,
        safeFileName(project.name, 'zip'),
        'application/zip',
      );
    } catch (error) {
      if (context.mounted) {
        showMessage(context, 'Échec de l’archive : $error', error: true);
      }
    }
  }

  static Future<void> exportZip(
    BuildContext context,
    WidgetRef ref,
    List<Project> projects,
    String name,
  ) async {
    if (projects.isEmpty) return;
    try {
      final bytes = await _withProgress(
        context,
        'Préparation de l’archive (${projects.length} création${projects.length > 1 ? 's' : ''})…',
        () {
          final services = ref.read(servicesProvider);
          return buildCreationsZip(
            projects,
            pdf: services.pdf,
            raster: services.raster,
          );
        },
      );
      if (bytes == null || !context.mounted) return;
      await deliver(
        context,
        ref,
        bytes,
        safeFileName(name, 'zip'),
        'application/zip',
      );
    } catch (error) {
      if (context.mounted) {
        showMessage(context, 'Échec de l’archive : $error', error: true);
      }
    }
  }

  static Future<void> saveAsTemplate(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final name = await promptText(
      context,
      title: 'Enregistrer comme modèle',
      initial: project.name,
      label: 'Nom du modèle',
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(customTemplatesProvider.notifier)
        .save(
          CustomTemplate(
            name: name.trim(),
            category: 'Mes modèles',
            document: project.document,
          ),
        );
    if (context.mounted) {
      showMessage(
        context,
        'Modèle « ${name.trim()} » ajouté à la bibliothèque.',
      );
    }
  }
}

class _RasterDialog extends StatefulWidget {
  const _RasterDialog({
    required this.document,
    required this.format,
    required this.defaultDpi,
  });

  final DesignDocument document;
  final RasterFormat format;
  final double defaultDpi;

  @override
  State<_RasterDialog> createState() => _RasterDialogState();
}

class _RasterDialogState extends State<_RasterDialog> {
  late final bool _screen = DesignFormats.isScreen(widget.document.formatId);
  late double _dpi = _screen ? screenFormatDpi : widget.defaultDpi;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final (w, h) = RasterExporter.pixelSize(widget.document, _dpi);
    final options = <(double, String)>[
      if (_screen) (screenFormatDpi, 'Réseaux sociaux (taille exacte)'),
      (96, '96 ppp — écran'),
      (150, '150 ppp — brouillon'),
      (300, '300 ppp — impression'),
      (600, '600 ppp — haute définition'),
    ];
    return AlertDialog(
      title: Text(
        'Exporter en ${widget.format == RasterFormat.png ? 'PNG' : 'JPEG'}',
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Résolution'),
            RadioGroup<double>(
              groupValue: _dpi,
              onChanged: (v) => setState(() => _dpi = v ?? _dpi),
              child: Column(
                children: [
                  for (final (dpi, label) in options)
                    RadioListTile<double>(
                      dense: true,
                      value: dpi,
                      title: Text(label),
                    ),
                ],
              ),
            ),
            if (widget.document.isDuplex) ...[
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Recto')),
                  ButtonSegment(value: 1, label: Text('Verso')),
                ],
                selected: {_page},
                onSelectionChanged: (s) => setState(() => _page = s.first),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '$w × $h pixels — ${formatMm(widget.document.widthMm)} × ${formatMm(widget.document.heightMm)} mm',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (w * h > RasterExporter.maxPixels)
              Text(
                'Trop grand : choisissez une résolution plus faible.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: w * h > RasterExporter.maxPixels
              ? null
              : () => Navigator.pop(context, (_dpi, _page)),
          child: const Text('Exporter'),
        ),
      ],
    );
  }
}
