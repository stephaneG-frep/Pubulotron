import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_client.dart';
import '../../app/providers.dart';
import '../../core/ids.dart';
import '../../editor/editor_controller.dart';
import '../../history/history_service.dart';
import '../../models/design_document.dart';
import '../../models/project.dart';
import '../../review/design_review.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/compare_view.dart';
import '../widgets/robopub.dart';

enum ImproveMode { advice, automatic }

Future<void> showImproveDialog(
  BuildContext context,
  EditorController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => ImproveDialog(controller: controller),
);

/// « Améliore mon design ».
class ImproveDialog extends ConsumerStatefulWidget {
  const ImproveDialog({super.key, required this.controller});

  final EditorController controller;

  @override
  ConsumerState<ImproveDialog> createState() => _ImproveDialogState();
}

class _ImproveDialogState extends ConsumerState<ImproveDialog> {
  final _instruction = TextEditingController();
  ImproveMode _mode = ImproveMode.advice;
  bool _busy = false;
  String? _error;
  ReviewReport? _report;

  static const _examples = [
    'Rends cette carte plus professionnelle, mais conserve mes textes et mon QR code.',
    'Modernise ce flyer avec des couleurs plus dynamiques.',
    'Améliore la lisibilité et l’équilibre graphique de cette affiche.',
  ];

  EditorController get c => widget.controller;

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  /// Rendu PNG (≈ 1024 px) pour les modèles capables d'analyser une image.
  Future<Uint8List?> _preview(DesignDocument doc) async {
    try {
      final dpi = 1024 / math.max(doc.widthMm, doc.heightMm) * 25.4;
      return await ref
          .read(servicesProvider)
          .raster
          .export(doc, pageIndex: c.pageIndex, dpi: dpi);
    } catch (_) {
      return null;
    }
  }

  Future<void> _run() async {
    final config = ref.read(aiConfigProvider);
    if (_mode == ImproveMode.automatic && config == null) {
      setState(
        () => _error = 'L’amélioration automatique nécessite une clé API (Paramètres IA). Le mode Conseils fonctionne sans IA.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _report = null;
    });
    final services = ref.read(servicesProvider);
    final profile = ref.read(activeProfileProvider);
    final document = c.document;
    try {
      final preview = config == null ? null : await _preview(document);
      if (_mode == ImproveMode.advice) {
        final report = await services.review.advise(
          config: config,
          document: document,
          pageIndex: c.pageIndex,
          instruction: _instruction.text,
          profile: profile,
          preview: preview,
        );
        setState(() => _report = report);
      } else {
        await _improve(document, _instruction.text, preview);
      }
    } on AiException catch (e) {
      setState(
        () => _error = e.details == null
            ? e.message
            : '${e.message}\n${e.details}',
      );
    } catch (e) {
      setState(() => _error = 'Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _improve(
    DesignDocument base,
    String instruction,
    Uint8List? preview,
  ) async {
    final config = ref.read(aiConfigProvider)!;
    final result = await ref
        .read(servicesProvider)
        .review
        .improve(
          config: config,
          document: base,
          pageIndex: c.pageIndex,
          instruction: instruction,
          profile: ref.read(activeProfileProvider),
          preview: preview,
        );
    if (!mounted) return;
    final candidate = base.replacePage(c.pageIndex, result.page);
    await _decide(
      original: c.document,
      candidate: candidate,
      result: result,
      instruction: instruction,
    );
  }

  Future<void> _decide({
    required DesignDocument original,
    required DesignDocument candidate,
    required ImprovementResult result,
    required String instruction,
  }) async {
    final choice = await showCompareDialog<String>(
      context,
      title: 'Avant / après',
      header: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message, style: Theme.of(context).textTheme.bodyLarge),
            if (result.guarded.isNotEmpty)
              Text(
                'Garde-fous : ${result.guarded.take(4).join(' · ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      items: [
        CompareItem(
          title: 'Original',
          subtitle: 'Version actuelle',
          document: original,
          pageIndex: c.pageIndex,
        ),
        CompareItem(
          title: 'Proposition',
          subtitle:
              '${result.applied} modification${result.applied > 1 ? 's' : ''}',
          document: candidate,
          pageIndex: c.pageIndex,
        ),
      ],
      actions: (dialogContext) => [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'refuse'),
          child: const Text('Refuser'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'more'),
          icon: const Icon(Icons.tune),
          label: const Text('Modifier davantage'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'variant'),
          icon: const Icon(Icons.auto_awesome_mosaic_outlined),
          label: const Text('Enregistrer comme nouvelle variante'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'accept'),
          icon: const Icon(Icons.check),
          label: const Text('Accepter'),
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'accept':
        await c.saveNow();
        c.replacePage(candidate.pages[c.pageIndex]);
        c.noteHistory(
          'Amélioration automatique par IA${instruction.trim().isEmpty ? '' : ' : ${instruction.trim()}'}',
          kind: VersionKind.ai,
        );
        await c.saveNow();
        if (mounted) {
          Navigator.pop(context);
          showMessage(
            context,
            'Amélioration appliquée. L’original reste dans l’historique.',
          );
        }
      case 'variant':
        await _saveAsVariant(candidate);
      case 'more':
        final more = await promptText(
          context,
          title: 'Que faut-il changer encore ?',
          label: 'Instruction complémentaire',
          maxLines: 3,
        );
        if (more == null || more.trim().isEmpty || !mounted) return;
        setState(() => _busy = true);
        try {
          await _improve(
            candidate,
            '$instruction\nPuis : ${more.trim()}',
            await _preview(candidate),
          );
        } on AiException catch (e) {
          setState(() => _error = e.message);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      default:
        break;
    }
  }

  Future<void> _saveAsVariant(DesignDocument candidate) async {
    var group = c.project.variantGroupId;
    if (group == null) {
      group = newId('var');
      final g = group;
      c.updateProject(
        (p) => p.copyWith(
          variantGroupId: g,
          variantIndex: 1,
          variantStyle: p.variantStyle ?? 'Original',
        ),
      );
      await c.saveNow();
    }
    final all = ref.read(projectsProvider).value ?? const <Project>[];
    final next =
        all
            .where((p) => p.variantGroupId == group)
            .map((p) => p.variantIndex ?? 0)
            .fold(1, math.max) +
        1;
    final variant = Project(
      name: '${c.project.name} — version améliorée',
      document: candidate,
      brief: c.project.brief,
      profileId: c.project.profileId,
      variantGroupId: group,
      variantIndex: next,
      variantStyle: 'Version améliorée par IA',
    );
    await ref
        .read(projectsProvider.notifier)
        .save(
          variant,
          historyLabel: 'Amélioration par IA de « ${c.project.name} »',
          kind: VersionKind.ai,
        );
    if (mounted) {
      showMessage(
        context,
        'Nouvelle variante enregistrée (Studio de variantes). L’original n’a pas été modifié.',
      );
    }
  }

  Color _color(FindingSeverity s) => switch (s) {
    FindingSeverity.critical => Theme.of(context).colorScheme.error,
    FindingSeverity.warning => PubColors.orange,
    FindingSeverity.info => PubColors.turquoise,
  };

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(aiConfigProvider);
    final report = _report;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_fix_high, color: PubColors.violet),
          SizedBox(width: 8),
          Text('Améliore mon design'),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ImproveMode>(
                segments: const [
                  ButtonSegment(
                    value: ImproveMode.advice,
                    label: Text('Conseils'),
                    icon: Icon(Icons.lightbulb_outline),
                  ),
                  ButtonSegment(
                    value: ImproveMode.automatic,
                    label: Text('Amélioration automatique'),
                    icon: Icon(Icons.auto_awesome),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                _mode == ImproveMode.advice
                    ? 'Analyse sans rien modifier${config == null ? ' (analyse locale, sans IA)' : ''}.'
                    : 'Propose une nouvelle version à comparer ; l’original n’est jamais écrasé. Vos coordonnées et vos QR codes sont protégés.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instruction,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Votre demande (facultatif)',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in _examples)
                    ActionChip(
                      label: Text(e, maxLines: 2),
                      onPressed: () => setState(() => _instruction.text = e),
                    ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: RoboPub(size: 72, mood: RoboMood.thinking)),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error!),
              ],
              if (report != null) ...[
                const SizedBox(height: 16),
                if (report.summary.isNotEmpty)
                  Text(
                    report.summary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 6),
                Text(
                  report.limits,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                if (report.findings.isEmpty)
                  const Text('Aucun problème relevé. Beau travail !'),
                for (final f in report.findings)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      f.severity == FindingSeverity.critical
                          ? Icons.error_outline
                          : f.severity == FindingSeverity.warning
                          ? Icons.warning_amber
                          : Icons.tips_and_updates_outlined,
                      color: _color(f.severity),
                    ),
                    title: Text('${f.title} · ${f.severity.label}'),
                    subtitle: Text('${f.detail}\n${f.source}'),
                    isThreeLine: true,
                    onTap:
                        f.elementId == null ||
                            c.page.elementById(f.elementId!) == null
                        ? null
                        : () {
                            c.select(f.elementId);
                            Navigator.pop(context);
                          },
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: Icon(
            _mode == ImproveMode.advice ? Icons.search : Icons.auto_awesome,
          ),
          label: Text(
            _mode == ImproveMode.advice
                ? 'Analyser'
                : 'Proposer une amélioration',
          ),
        ),
      ],
    );
  }
}
