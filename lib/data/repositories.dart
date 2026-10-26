import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/business_profile.dart';
import '../models/project.dart';
import 'app_database.dart';
import 'legacy_converter.dart';

class ProjectRepository {
  ProjectRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  Future<void> save(Project project) async {
    await _db.insert('projects', {
      'id': project.id,
      'name': project.name,
      'description': project.brief,
      'created_at': project.createdAt.toIso8601String(),
      'updated_at': project.updatedAt.toIso8601String(),
      'format_id': project.document.formatId,
      'pack_id': project.packId,
      'payload': jsonEncode(project.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Project? _decode(Map<String, Object?> row) {
    try {
      final json = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return LegacyConverter.readProject(json);
    } catch (_) {
      return null;
    }
  }

  Future<List<Project>> list() async {
    final rows = await _db.query('projects', orderBy: 'updated_at DESC');
    return rows.map(_decode).whereType<Project>().toList();
  }

  Future<List<Project>> listPack(String packId) async {
    final rows = await _db.query(
      'projects',
      where: 'pack_id = ?',
      whereArgs: [packId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_decode).whereType<Project>().toList();
  }

  Future<Project?> get(String id) async {
    final rows = await _db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  Future<void> delete(String id) =>
      _db.delete('projects', where: 'id = ?', whereArgs: [id]);

  Future<Project> rename(String id, String name) async {
    final project = await get(id);
    if (project == null) throw StateError('Projet introuvable');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Le nom ne peut pas être vide.');
    final renamed = project.copyWith(name: trimmed, updatedAt: DateTime.now());
    await save(renamed);
    return renamed;
  }

  Future<Project> duplicate(String id) async {
    final project = await get(id);
    if (project == null) throw StateError('Projet introuvable');
    final now = DateTime.now();
    final copy = Project(
      name: '${project.name} (copie)',
      document: project.document,
      brief: project.brief,
      profileId: project.profileId,
      createdAt: now,
      updatedAt: now,
    );
    await save(copy);
    return copy;
  }
}

class ProfileRepository {
  ProfileRepository(this._database);

  final AppDatabase _database;

  Future<void> save(BusinessProfile profile) => _database.db.insert(
    'profiles',
    {'id': profile.id, 'payload': jsonEncode(profile.toJson())},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<List<BusinessProfile>> list() async {
    final rows = await _database.db.query('profiles');
    final profiles = <BusinessProfile>[];
    for (final row in rows) {
      try {
        profiles.add(
          BusinessProfile.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Fiche illisible : ignorée plutôt que de bloquer l'application.
      }
    }
    profiles.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return profiles;
  }

  Future<void> delete(String id) =>
      _database.db.delete('profiles', where: 'id = ?', whereArgs: [id]);
}

class TemplateRepository {
  TemplateRepository(this._database);

  final AppDatabase _database;

  Future<void> save(CustomTemplate template) =>
      _database.db.insert('templates', {
        'id': template.id,
        'name': template.name,
        'category': template.category,
        'created_at': template.createdAt.toIso8601String(),
        'payload': jsonEncode(template.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<CustomTemplate>> list() async {
    final rows = await _database.db.query(
      'templates',
      orderBy: 'created_at DESC',
    );
    final result = <CustomTemplate>[];
    for (final row in rows) {
      try {
        result.add(
          CustomTemplate.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          ),
        );
      } catch (_) {}
    }
    return result;
  }

  Future<void> delete(String id) =>
      _database.db.delete('templates', where: 'id = ?', whereArgs: [id]);
}

/// Paramètres non secrets, stockés en JSON par clé.
class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  Future<Map<String, dynamic>?> read(String key) async {
    final rows = await _database.db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> value) =>
      _database.db.insert('settings', {
        'key': key,
        'value': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Map<String, Map<String, dynamic>>> readAll() async {
    final rows = await _database.db.query('settings');
    return {
      for (final row in rows)
        row['key'] as String: (jsonDecode(row['value'] as String) as Map)
            .cast<String, dynamic>(),
    };
  }
}
