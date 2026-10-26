import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/formats.dart';
import '../models/project.dart';
import '../print/pdf_exporter.dart';
import 'file_service.dart';
import 'raster_exporter.dart';

/// Archive ZIP de plusieurs créations : un PDF et un PNG par face pour chaque
/// création, plus un PDF qui les regroupe toutes.
Future<Uint8List> buildCreationsZip(
  List<Project> projects, {
  required PdfExporter pdf,
  required RasterExporter raster,
  double dpi = 200,
}) async {
  final archive = Archive();
  final used = <String>{};
  String unique(String name) {
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var candidate = name;
    for (var i = 2; !used.add(candidate); i++) {
      candidate = '${base}_$i$ext';
    }
    return candidate;
  }

  void add(String name, List<int> bytes) =>
      archive.addFile(ArchiveFile(unique(name), bytes.length, bytes));

  for (final project in projects) {
    final doc = project.document;
    final result = await pdf.exportDocument(doc, title: project.name);
    add(safeFileName(project.name, 'pdf'), result.bytes);
    final screen = DesignFormats.isScreen(doc.formatId);
    for (var i = 0; i < doc.pages.length; i++) {
      final png = await raster.export(
        doc,
        pageIndex: i,
        dpi: screen ? screenFormatDpi : dpi,
      );
      final suffix = doc.isDuplex ? (i == 0 ? '_recto' : '_verso') : '';
      add(safeFileName('${project.name}$suffix', 'png'), png);
    }
  }
  final all = await pdf.exportDocuments(
    projects.map((p) => p.document).toList(),
  );
  add('Toutes_les_creations.pdf', all.bytes);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
