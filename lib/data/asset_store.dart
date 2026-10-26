import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/ids.dart';

/// Médiathèque locale : chaque image importée est copiée dans le dossier de
/// l'application et désignée par un identifiant stable (nom de fichier).
class AssetStore {
  AssetStore(this.directory);

  final Directory directory;

  static const supportedImageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
  };

  static bool isValidId(String id) =>
      id.isNotEmpty &&
      !id.contains('/') &&
      !id.contains(r'\') &&
      !id.contains('..') &&
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(id);

  Future<void> _ensureDir() async {
    if (!await directory.exists()) await directory.create(recursive: true);
  }

  File fileFor(String id) {
    if (!isValidId(id)) {
      throw ArgumentError.value(id, 'id', 'Identifiant de média invalide');
    }
    return File(p.join(directory.path, id));
  }

  Future<bool> exists(String id) async =>
      isValidId(id) && await fileFor(id).exists();

  Future<Uint8List?> read(String id) async {
    if (!await exists(id)) return null;
    return fileFor(id).readAsBytes();
  }

  static String _extensionOf(String name) {
    final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    return supportedImageExtensions.contains(ext) ? ext : 'png';
  }

  Future<String> importBytes(
    Uint8List bytes, {
    String fileName = 'image.png',
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('Le fichier image est vide.');
    }
    await _ensureDir();
    final id = '${newId('img')}.${_extensionOf(fileName)}';
    await fileFor(id).writeAsBytes(bytes, flush: true);
    return id;
  }

  Future<String> importFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Fichier introuvable', path);
    }
    return importBytes(await file.readAsBytes(), fileName: p.basename(path));
  }

  /// Écrit un média avec un identifiant imposé (restauration de sauvegarde).
  Future<void> writeWithId(String id, List<int> bytes) async {
    await _ensureDir();
    await fileFor(id).writeAsBytes(bytes, flush: true);
  }

  Future<List<String>> list() async {
    if (!await directory.exists()) return const [];
    return directory
        .list()
        .where((entity) => entity is File)
        .map((entity) => p.basename(entity.path))
        .where(isValidId)
        .toList();
  }

  Future<void> delete(String id) async {
    if (await exists(id)) await fileFor(id).delete();
  }
}
