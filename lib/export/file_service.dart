import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileServiceException implements Exception {
  const FileServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PickedFile {
  const PickedFile(this.name, this.bytes, {this.path});
  final String name;
  final Uint8List bytes;
  final String? path;
}

/// Accès aux fichiers de la plateforme (enregistrement, partage, import).
abstract class FileService {
  /// Enregistre [bytes] ; renvoie l'emplacement choisi, ou `null` si annulé.
  Future<String?> save(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
  });

  /// Ouvre la feuille de partage du système (Android) ; enregistre sinon.
  Future<bool> share(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
    String? text,
  });

  Future<PickedFile?> pick({List<String>? extensions, bool images = false});

  bool get canShare;
}

class PlatformFileService implements FileService {
  const PlatformFileService();

  @override
  bool get canShare => Platform.isAndroid || Platform.isIOS;

  @override
  Future<String?> save(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        dialogTitle: 'Enregistrer $fileName',
      );
      if (uri == null) return null;
      if (uri.scheme == 'file') {
        final file = File(uri.toFilePath());
        // Sur certains bureaux, le sélecteur renvoie le chemin sans écrire le fichier.
        if (!await file.exists() || await file.length() != bytes.length) {
          await file.writeAsBytes(bytes, flush: true);
        }
        return file.path;
      }
      return uri.toString();
    } on UnimplementedError {
      return _saveToDocuments(bytes, fileName);
    } on FileSystemException {
      rethrow;
    } catch (_) {
      // Sélecteur indisponible (ex. pas de xdg-desktop-portal sous Linux) :
      // enregistrement dans Documents/Pubulotron plutôt qu'un échec.
      return _saveToDocuments(bytes, fileName);
    }
  }

  Future<String> _saveToDocuments(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(dir.path, 'Pubulotron'));
    await target.create(recursive: true);
    final file = File(p.join(target.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<bool> share(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
    String? text,
  }) async {
    if (!canShare) {
      return await save(bytes, fileName, mimeType: mimeType) != null;
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        text: text,
        subject: fileName,
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  @override
  Future<PickedFile?> pick({
    List<String>? extensions,
    bool images = false,
  }) async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        type: images
            ? FileType.image
            : (extensions == null ? FileType.any : FileType.custom),
        allowedExtensions: images ? null : extensions,
        dialogTitle: images ? 'Choisir une image' : 'Choisir un fichier',
      );
    } catch (error) {
      throw FileServiceException(
        'Impossible d’ouvrir le sélecteur de fichiers ($error). '
        'Sous Linux, installez xdg-desktop-portal et une implémentation (gtk, kde ou lxqt).',
      );
    }
    if (files.isEmpty) return null;
    final file = files.first;
    final bytes = await file.xFile.readAsBytes();
    return PickedFile(file.name, bytes, path: file.path);
  }
}

String safeFileName(String name, String extension) {
  final base = name
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), '_');
  return '${base.isEmpty ? 'pubulotron' : base}.$extension';
}
