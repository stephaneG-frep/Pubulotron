import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../engine/flutter_canvas.dart';
import '../../models/design_document.dart';

class CompareItem {
  const CompareItem({
    required this.title,
    required this.document,
    this.subtitle = '',
    this.pageIndex = 0,
  });

  final String title;
  final String subtitle;
  final DesignDocument document;
  final int pageIndex;
}

/// Comparaison de 2 à 5 créations : côte à côte sur grand écran, carrousel
/// sur téléphone.
class CompareView extends ConsumerStatefulWidget {
  const CompareView({super.key, required this.items, this.footer});

  final List<CompareItem> items;

  /// Contenu affiché sous chaque création (ex. différences).
  final Widget Function(int index)? footer;

  @override
  ConsumerState<CompareView> createState() => _CompareViewState();
}

class _CompareViewState extends ConsumerState<CompareView> {
  final _pages = PageController(viewportFraction: 0.88);
  int _current = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Widget _tile(BuildContext context, int i) {
    final item = widget.items[i];
    final images = ref.watch(servicesProvider).images;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.subtitle.isNotEmpty)
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: DesignPageView(
                  document: item.document,
                  pageIndex: item.pageIndex,
                  images: images,
                  borderRadius: 4,
                ),
              ),
            ),
            if (widget.footer != null) ...[
              const SizedBox(height: 8),
              widget.footer!(i),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = widget.items.length;
        final wide = constraints.maxWidth / n >= 220;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _tile(context, i)),
              ],
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: n,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _tile(context, i),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < n; i++)
                  Container(
                    width: i == _current ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _current
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Ouvre le comparateur en plein écran ; [actions] s'affichent en bas.
Future<T?> showCompareDialog<T>(
  BuildContext context, {
  required String title,
  required List<CompareItem> items,
  Widget Function(int index)? footer,
  List<Widget> Function(BuildContext dialogContext)? actions,
  Widget? header,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                Expanded(
                  child: CompareView(items: items, footer: footer),
                ),
                if (actions != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: actions(dialogContext),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
