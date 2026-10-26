import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/units.dart';
import '../../engine/flutter_canvas.dart';
import '../../models/design_document.dart';
import '../../models/formats.dart';
import '../../models/project.dart';

String formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String formatLabel(DesignDocument doc) {
  final format = DesignFormats.byId(doc.formatId);
  return format?.label ??
      '${formatMm(doc.widthMm)} × ${formatMm(doc.heightMm)} mm';
}

enum ProjectAction { open, rename, duplicate, export, delete, print }

/// Aperçu d'un document dans une boîte de hauteur fixe.
class DocumentThumbnail extends ConsumerWidget {
  const DocumentThumbnail({
    super.key,
    required this.document,
    this.height = 150,
    this.pageIndex = 0,
  });

  final DesignDocument document;
  final double height;
  final int pageIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(servicesProvider).images;
    return Container(
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: DesignPageView(
        document: document,
        images: images,
        pageIndex: pageIndex,
        borderRadius: 4,
      ),
    );
  }
}

class ProjectGrid extends StatelessWidget {
  const ProjectGrid({
    super.key,
    required this.projects,
    required this.onOpen,
    this.onAction,
  });

  final List<Project> projects;
  final ValueChanged<Project> onOpen;
  final void Function(Project, ProjectAction)? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 240).floor().clamp(1, 6);
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final p in projects)
              SizedBox(
                width: width,
                child: ProjectCard(
                  project: p,
                  onOpen: () => onOpen(p),
                  onAction: onAction == null ? null : (a) => onAction!(p, a),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onOpen,
    this.onAction,
  });

  final Project project;
  final VoidCallback onOpen;
  final ValueChanged<ProjectAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final doc = project.document;
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DocumentThumbnail(document: doc),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${formatLabel(doc)}${doc.isDuplex ? ' · recto verso' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Modifié le ${formatDate(project.updatedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onAction != null)
                    PopupMenuButton<ProjectAction>(
                      tooltip: 'Actions',
                      onSelected: onAction,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: ProjectAction.open,
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Ouvrir dans l’atelier'),
                          ),
                        ),
                        PopupMenuItem(
                          value: ProjectAction.rename,
                          child: ListTile(
                            leading: Icon(Icons.drive_file_rename_outline),
                            title: Text('Renommer'),
                          ),
                        ),
                        PopupMenuItem(
                          value: ProjectAction.duplicate,
                          child: ListTile(
                            leading: Icon(Icons.copy),
                            title: Text('Dupliquer'),
                          ),
                        ),
                        PopupMenuItem(
                          value: ProjectAction.print,
                          child: ListTile(
                            leading: Icon(Icons.print_outlined),
                            title: Text('Imprimerie PDF'),
                          ),
                        ),
                        PopupMenuItem(
                          value: ProjectAction.export,
                          child: ListTile(
                            leading: Icon(Icons.folder_zip_outlined),
                            title: Text('Exporter (ZIP)'),
                          ),
                        ),
                        PopupMenuItem(
                          value: ProjectAction.delete,
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
          ],
        ),
      ),
    );
  }
}
