import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/pubulotron_models.dart';

class ProjectRepository {
  static Database? _database;

  static void initializeFfi() {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    initializeFfi();
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'pubulotron_projects.db');
    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            name TEXT,
            description TEXT,
            created_at TEXT,
            updated_at TEXT,
            payload TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE profiles (
            id TEXT PRIMARY KEY,
            payload TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS profiles (
              id TEXT PRIMARY KEY,
              payload TEXT
            )
          ''');
        }
      },
    );
    return _database!;
  }

  Future<void> saveProject(GraphicProject project) async {
    final db = await database;
    await db.insert(
      'projects',
      {
        'id': project.id,
        'name': project.name,
        'description': project.description,
        'created_at': project.createdAt.toIso8601String(),
        'updated_at': project.updatedAt.toIso8601String(),
        'payload': jsonEncode(project.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<GraphicProject>> loadProjects() async {
    final db = await database;
    final rows = await db.query('projects', orderBy: 'updated_at DESC');
    return rows
        .map((row) => GraphicProject.fromJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveProfile(BusinessProfile profile) async {
    final db = await database;
    await db.insert(
      'profiles',
      {'id': profile.id, 'payload': jsonEncode(profile.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BusinessProfile>> loadProfiles() async {
    final db = await database;
    final rows = await db.query('profiles', orderBy: 'id ASC');
    return rows
        .map((row) => BusinessProfile.fromJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>))
        .toList();
  }

  Future<void> restoreProjectFromArchive(File archiveFile) async {
    final bytes = await archiveFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.name.endsWith('project.json')) {
        final payload = utf8.decode(file.content as List<int>);
        final map = jsonDecode(payload) as Map<String, dynamic>;
        final project = GraphicProject.fromJson(map);
        await saveProject(project);
      }
    }
  }

  Future<String> exportAllProjectsArchive() async {
    final projects = await loadProjects();
    final archive = Archive();

    for (final project in projects) {
      final payload = utf8.encode(jsonEncode(project.toJson()));
      archive.addFile(ArchiveFile('projects/${project.id}.json', payload.length, payload));
      for (final element in project.elements) {
        final imagePath = element.imagePath;
        if (imagePath == null || !File(imagePath).existsSync()) continue;
        final imageBytes = await File(imagePath).readAsBytes();
        final fileName = p.basename(imagePath);
        archive.addFile(ArchiveFile('projects/${project.id}/assets/$fileName', imageBytes.length, imageBytes));
      }
    }

    final zipBytes = ZipEncoder().encode(archive);

    final dir = await getApplicationDocumentsDirectory();
    final outputFile = File(p.join(dir.path, 'pubulotron_projects_backup.zip'));
    await outputFile.writeAsBytes(zipBytes);
    return outputFile.path;
  }

  Future<void> exportProjectArchive(String projectId) async {
    final db = await database;
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    if (rows.isEmpty) return;

    final project = GraphicProject.fromJson(jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>);
    final archive = Archive();
    final payload = utf8.encode(jsonEncode(project.toJson()));
    archive.addFile(ArchiveFile('project.json', payload.length, payload));
    for (final element in project.elements) {
      final imagePath = element.imagePath;
      if (imagePath == null || !File(imagePath).existsSync()) continue;
      final imageBytes = await File(imagePath).readAsBytes();
      final fileName = p.basename(imagePath);
      archive.addFile(ArchiveFile('assets/$fileName', imageBytes.length, imageBytes));
    }

    final zipBytes = ZipEncoder().encode(archive);

    final dir = await getApplicationDocumentsDirectory();
    final output = File(p.join(dir.path, '${project.name}.zip'));
    await output.writeAsBytes(zipBytes);
  }
}
