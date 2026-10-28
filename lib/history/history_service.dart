import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/ids.dart';
import '../data/app_database.dart';
import '../models/design_document.dart';
import '../models/project.dart';
import 'change_summary.dart';

/// Nature d'une version, pour l'affichage et la politique de conservation.
enum VersionKind { initial, edit, ai, sync, restore, restorePoint }

extension VersionKindLabel on VersionKind {
  String get label => switch (this) {
    VersionKind.initial => 'Création',
    VersionKind.edit => 'Modification',
    VersionKind.ai => 'IA',
    VersionKind.sync => 'Synchronisation',
    VersionKind.restore => 'Restauration',
    VersionKind.restorePoint => 'Point de restauration',
  };
}

/// Instantané complet du document d'une création à un instant donné.
/// Les médias (images, logos) sont référencés par identifiant : la
/// médiathèque ne supprime jamais un fichier, les références restent valides.
class VersionEntry {
  const VersionEntry({
    required this.id,
    required this.projectId,
    required this.number,
    required this.createdAt,
    required this.label,
    required this.kind,
    required this.document,
  });

  final String id;
  final String projectId;
  final int number;
  final DateTime createdAt;
  final String label;
  final VersionKind kind;
  final DesignDocument document;

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'number': number,
    'createdAt': createdAt.toIso8601String(),
    'label': label,
    'kind': kind.name,
    'document': document.toJson(),
  };

  factory VersionEntry.fromJson(Map<String, dynamic> json) => VersionEntry(
    id: json['id'] as String? ?? newId('ver'),
    projectId: json['projectId'] as String? ?? '',
    number: (json['number'] as num?)?.toInt() ?? 1,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    label: json['label'] as String? ?? '',
    kind: VersionKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => VersionKind.edit,
    ),
    document: DesignDocument.fromJson(
      Map<String, dynamic>.from(json['document'] as Map? ?? const {}),
    ),
  );
}

class VersionRepository {
  VersionRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<void> save(VersionEntry v) => _db.insert('versions', {
    'id': v.id,
    'project_id': v.projectId,
    'number': v.number,
    'created_at': v.createdAt.toIso8601String(),
    'label': v.label,
    'kind': v.kind.name,
    'payload': jsonEncode(v.document.toJson()),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  VersionEntry? _decode(Map<String, Object?> row) {
    try {
      return VersionEntry(
        id: row['id'] as String,
        projectId: row['project_id'] as String,
        number: (row['number'] as num).toInt(),
        createdAt: DateTime.parse(row['created_at'] as String),
        label: row['label'] as String? ?? '',
        kind: VersionKind.values.firstWhere(
          (k) => k.name == row['kind'],
          orElse: () => VersionKind.edit,
        ),
        document: DesignDocument.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Versions d'une création, la plus récente en premier.
  Future<List<VersionEntry>> list(String projectId) async {
    final rows = await _db.query(
      'versions',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'number DESC',
    );
    return rows.map(_decode).whereType<VersionEntry>().toList();
  }

  Future<List<VersionEntry>> all() async {
    final rows = await _db.query('versions', orderBy: 'project_id, number');
    return rows.map(_decode).whereType<VersionEntry>().toList();
  }

  Future<VersionEntry?> latest(String projectId) async {
    final rows = await _db.query(
      'versions',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'number DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  Future<int> count(String projectId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM versions WHERE project_id = ?',
      [projectId],
    );
    return (rows.first['n'] as num).toInt();
  }

  Future<void> delete(String id) =>
      _db.delete('versions', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteForProject(String projectId) =>
      _db.delete('versions', where: 'project_id = ?', whereArgs: [projectId]);
}

/// Politique d'enregistrement des versions.
class HistoryPolicy {
  const HistoryPolicy({
    this.maxVersions = 30,
    this.mergeWindow = const Duration(minutes: 3),
  });

  /// Nombre maximal de versions conservées par création.
  final int maxVersions;

  /// Les modifications ordinaires successives dans cette fenêtre enrichissent
  /// la dernière version au lieu d'en créer une nouvelle (limite le stockage).
  final Duration mergeWindow;
}

/// Historique persistant des créations.
class HistoryService {
  HistoryService(
    this.repository, {
    this.policy = const HistoryPolicy(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final VersionRepository repository;
  HistoryPolicy policy;
  final DateTime Function() _clock;

  static bool _same(DesignDocument a, DesignDocument b) =>
      jsonEncode(a.toJson()) == jsonEncode(b.toJson());

  /// Enregistre l'état courant d'une création si elle a changé.
  ///
  /// Une modification ordinaire proche de la précédente est fusionnée avec
  /// elle ; une opération notable ([force], IA, synchronisation,
  /// restauration…) crée toujours une nouvelle version.
  Future<VersionEntry?> record(
    Project project, {
    String? label,
    VersionKind kind = VersionKind.edit,
    bool force = false,
  }) async {
    final latest = await repository.latest(project.id);
    final now = _clock();
    if (latest == null) {
      final first = VersionEntry(
        id: newId('ver'),
        projectId: project.id,
        number: 1,
        createdAt: now,
        label: label ?? 'Création initiale',
        kind: kind == VersionKind.edit ? VersionKind.initial : kind,
        document: project.document,
      );
      await repository.save(first);
      return first;
    }
    if (_same(latest.document, project.document) &&
        kind != VersionKind.restorePoint) {
      return null;
    }
    final changes = describeChanges(latest.document, project.document);
    final notable = force || kind != VersionKind.edit;
    final mergeable =
        !notable &&
        latest.kind == VersionKind.edit &&
        now.difference(latest.createdAt) < policy.mergeWindow;
    if (mergeable) {
      final merged = VersionEntry(
        id: latest.id,
        projectId: project.id,
        number: latest.number,
        createdAt: now,
        label: _mergeLabels(latest.label, label ?? summarizeChanges(changes)),
        kind: VersionKind.edit,
        document: project.document,
      );
      await repository.save(merged);
      return merged;
    }
    final entry = VersionEntry(
      id: newId('ver'),
      projectId: project.id,
      number: latest.number + 1,
      createdAt: now,
      label: label ?? summarizeChanges(changes),
      kind: kind,
      document: project.document,
    );
    await repository.save(entry);
    await prune(project.id);
    return entry;
  }

  static String _mergeLabels(String a, String b) {
    final parts = <String>{
      ...a.split(', ').where((s) => s.isNotEmpty && !s.startsWith('Aucune')),
      ...b.split(', ').where((s) => s.isNotEmpty && !s.startsWith('Aucune')),
    }.toList();
    if (parts.isEmpty) return 'Modification';
    return parts.length > 4 ? '${parts.take(4).join(', ')}…' : parts.join(', ');
  }

  /// Applique la politique de conservation : garde la version initiale et
  /// les plus récentes, dans la limite de [keep] (ou de la politique).
  Future<int> prune(String projectId, {int? keep}) async {
    final max = (keep ?? policy.maxVersions).clamp(2, 1000);
    final versions = await repository.list(
      projectId,
    ); // la plus récente d'abord
    if (versions.length <= max) return 0;
    final initial = versions.last;
    final kept = {...versions.take(max - 1).map((v) => v.id), initial.id};
    var removed = 0;
    for (final v in versions.where((v) => !kept.contains(v.id))) {
      await repository.delete(v.id);
      removed++;
    }
    return removed;
  }

  Future<List<VersionEntry>> versions(String projectId) =>
      repository.list(projectId);

  Future<void> deleteVersion(String id) => repository.delete(id);

  Future<void> deleteForProject(String projectId) =>
      repository.deleteForProject(projectId);
}
