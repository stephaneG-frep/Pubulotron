import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/business_profile.dart';
import '../models/project.dart';
import 'asset_store.dart';
import 'legacy_converter.dart';
import 'repositories.dart';

class BackupReport {
  const BackupReport({
    this.projects = 0,
    this.profiles = 0,
    this.templates = 0,
    this.assets = 0,
    this.settings = 0,
    this.skipped = const [],
  });

  final int projects;
  final int profiles;
  final int templates;
  final int assets;
  final int settings;
  final List<String> skipped;

  String get summary {
    final parts = [
      if (projects > 0) '$projects projet${projects > 1 ? 's' : ''}',
      if (profiles > 0) '$profiles profil${profiles > 1 ? 's' : ''}',
      if (templates > 0) '$templates modèle${templates > 1 ? 's' : ''}',
      if (assets > 0) '$assets image${assets > 1 ? 's' : ''}',
    ];
    return parts.isEmpty ? 'Aucun élément' : parts.join(', ');
  }
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Export et import d'archives ZIP de sauvegarde.
class BackupService {
  BackupService({
    required this.projects,
    required this.profiles,
    required this.templates,
    required this.settings,
    required this.assets,
  });

  final ProjectRepository projects;
  final ProfileRepository profiles;
  final TemplateRepository templates;
  final SettingsRepository settings;
  final AssetStore assets;

  static const String format = 'pubulotron-backup';
  static const int formatVersion = 1;

  void _addJson(Archive archive, String name, Object json) {
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  Future<int> _addAssets(Archive archive, Set<String> ids) async {
    var count = 0;
    for (final id in ids) {
      final bytes = await assets.read(id);
      if (bytes == null) continue;
      archive.addFile(ArchiveFile('assets/$id', bytes.length, bytes));
      count++;
    }
    return count;
  }

  /// Sauvegarde complète de l'application.
  Future<Uint8List> exportAll() async {
    final archive = Archive();
    final allProjects = await projects.list();
    final allProfiles = await profiles.list();
    final allTemplates = await templates.list();
    final allSettings = await settings.readAll();
    final assetIds = <String>{
      for (final p in allProjects) ...p.document.assetIds,
      for (final t in allTemplates) ...t.document.assetIds,
      for (final p in allProfiles)
        if (p.logoAssetId != null) p.logoAssetId!,
    };
    for (final p in allProjects) {
      _addJson(archive, 'projects/${p.id}.json', p.toJson());
    }
    for (final p in allProfiles) {
      _addJson(archive, 'profiles/${p.id}.json', p.toJson());
    }
    for (final t in allTemplates) {
      _addJson(archive, 'templates/${t.id}.json', t.toJson());
    }
    _addJson(archive, 'settings.json', allSettings);
    final assetCount = await _addAssets(archive, assetIds);
    _addJson(archive, 'manifest.json', {
      'format': format,
      'version': formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'projects': allProjects.length,
      'profiles': allProfiles.length,
      'templates': allTemplates.length,
      'assets': assetCount,
    });
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Archive d'un seul projet (avec ses images), réimportable.
  Future<Uint8List> exportProject(Project project) async {
    final archive = Archive();
    _addJson(archive, 'projects/${project.id}.json', project.toJson());
    final count = await _addAssets(archive, project.document.assetIds);
    _addJson(archive, 'manifest.json', {
      'format': format,
      'version': formatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'projects': 1,
      'assets': count,
    });
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Restaure une archive. Les éléments existants de même identifiant sont
  /// remplacés ; les autres données sont conservées.
  Future<BackupReport> import(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const BackupException(
        'Le fichier n’est pas une archive ZIP valide.',
      );
    }
    Map<String, dynamic>? readJson(ArchiveFile file) {
      try {
        final decoded = jsonDecode(utf8.decode(file.content as List<int>));
        return decoded is Map ? decoded.cast<String, dynamic>() : null;
      } catch (_) {
        return null;
      }
    }

    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile != null) {
      final manifest = readJson(manifestFile);
      if (manifest == null || manifest['format'] != format) {
        throw const BackupException(
          'Cette archive ne provient pas de Pubulotron.',
        );
      }
      if ((manifest['version'] as num? ?? 1) > formatVersion) {
        throw const BackupException(
          'Archive créée par une version plus récente de Pubulotron.',
        );
      }
    }

    var projectCount = 0;
    var profileCount = 0;
    var templateCount = 0;
    var assetCount = 0;
    var settingsCount = 0;
    final skipped = <String>[];
    final isLegacy = manifestFile == null;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      if (name.startsWith('assets/') ||
          (isLegacy && name.contains('/assets/'))) {
        final id = name.split('/').last;
        if (AssetStore.isValidId(id)) {
          await assets.writeWithId(id, file.content as List<int>);
          assetCount++;
        } else {
          skipped.add(name);
        }
        continue;
      }
      if (!name.endsWith('.json') || name == 'manifest.json') continue;
      final json = readJson(file);
      if (json == null) {
        skipped.add(name);
        continue;
      }
      try {
        if (name.startsWith('projects/') || name == 'project.json') {
          await projects.save(LegacyConverter.readProject(json));
          projectCount++;
        } else if (name.startsWith('profiles/')) {
          await profiles.save(BusinessProfile.fromJson(json));
          profileCount++;
        } else if (name.startsWith('templates/')) {
          await templates.save(CustomTemplate.fromJson(json));
          templateCount++;
        } else if (name == 'settings.json') {
          for (final entry in json.entries) {
            if (entry.value is Map) {
              await settings.write(
                entry.key,
                (entry.value as Map).cast<String, dynamic>(),
              );
              settingsCount++;
            }
          }
        } else {
          skipped.add(name);
        }
      } catch (_) {
        skipped.add(name);
      }
    }
    if (projectCount +
            profileCount +
            templateCount +
            assetCount +
            settingsCount ==
        0) {
      throw const BackupException(
        'L’archive ne contient aucune donnée Pubulotron.',
      );
    }
    return BackupReport(
      projects: projectCount,
      profiles: profileCount,
      templates: templateCount,
      assets: assetCount,
      settings: settingsCount,
      skipped: skipped,
    );
  }
}
