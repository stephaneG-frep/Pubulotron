import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pubulotron/data/app_database.dart';
import 'package:pubulotron/data/asset_store.dart';
import 'package:pubulotron/data/backup_service.dart';
import 'package:pubulotron/data/repositories.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/project.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_support.dart';

class Env {
  Env(this.db, this.dir)
    : projects = ProjectRepository(db),
      profiles = ProfileRepository(db),
      templates = TemplateRepository(db),
      settings = SettingsRepository(db),
      assets = AssetStore(Directory(p.join(dir.path, 'assets')));

  final AppDatabase db;
  final Directory dir;
  final ProjectRepository projects;
  final ProfileRepository profiles;
  final TemplateRepository templates;
  final SettingsRepository settings;
  final AssetStore assets;

  BackupService get backup => BackupService(
    projects: projects,
    profiles: profiles,
    templates: templates,
    settings: settings,
    assets: assets,
  );

  static Future<Env> open([String name = 'db']) async {
    final dir = tempDir(name);
    final db = await AppDatabase.open(
      p.join(dir.path, 'test.db'),
      factory: databaseFactoryFfi,
    );
    return Env(db, dir);
  }
}

ArchiveFile jsonFile(String name, String content) =>
    ArchiveFile(name, content.length, content.codeUnits);

void main() {
  sqfliteFfiInit();

  test(
    'project is saved, modified and reopened after closing the database',
    () async {
      final dir = tempDir('reopen');
      final path = p.join(dir.path, 'app.db');
      var db = await AppDatabase.open(path, factory: databaseFactoryFfi);
      final project = Project(
        name: 'Carte TechCare',
        document: richSampleDocument(photoAssetId: 'img-a.png'),
      );
      await ProjectRepository(db).save(project);
      final modified = project.copyWith(
        document: project.document.replacePage(
          0,
          project.document.front.copyWith(
            elements: [
              ...project.document.front.elements.map(
                (e) => e.type == ElementType.text
                    ? e.copyWith(
                        text: 'Modifié',
                        color: const Color(0xFF00FF00),
                      )
                    : e,
              ),
            ],
          ),
        ),
      );
      await ProjectRepository(db).save(modified);
      await db.close();

      db = await AppDatabase.open(path, factory: databaseFactoryFfi);
      final reopened = await ProjectRepository(db).get(project.id);
      expect(reopened, isNotNull);
      expect(reopened!.name, 'Carte TechCare');
      final texts = reopened.document.front.elements.where(
        (e) => e.type == ElementType.text,
      );
      expect(
        texts.every(
          (e) => e.text == 'Modifié' && e.color == const Color(0xFF00FF00),
        ),
        isTrue,
      );
      expect(reopened.document.pages, hasLength(2));
      expect(reopened.document.assetIds, {'img-a.png'});
      expect(await ProjectRepository(db).list(), hasLength(1));
      await db.close();
    },
  );

  test('duplicate, rename, delete and pack listing', () async {
    final env = await Env.open('crud');
    final project = Project(
      name: 'Flyer',
      document: richSampleDocument(),
      packId: 'pack-1',
    );
    await env.projects.save(project);
    final copy = await env.projects.duplicate(project.id);
    expect(copy.name, 'Flyer (copie)');
    expect(copy.id, isNot(project.id));
    expect(copy.packId, isNull);
    await env.projects.rename(copy.id, '  Flyer été  ');
    expect((await env.projects.get(copy.id))!.name, 'Flyer été');
    expect(() => env.projects.rename(copy.id, '   '), throwsArgumentError);
    expect(await env.projects.listPack('pack-1'), hasLength(1));
    await env.projects.delete(project.id);
    expect((await env.projects.list()).map((p) => p.id), [copy.id]);
    await env.db.close();
  });

  test('several business profiles, custom templates and settings', () async {
    final env = await Env.open('profiles');
    await env.profiles.save(BusinessProfile.example());
    await env.profiles.save(
      BusinessProfile(name: 'Autre activité', phone: '01 00 00 00 00'),
    );
    expect((await env.profiles.list()).map((p) => p.name), [
      'Autre activité',
      'TechCare Réparations',
    ]);
    await env.templates.save(
      CustomTemplate(
        name: 'Mon modèle',
        category: 'Mes modèles',
        document: richSampleDocument(),
      ),
    );
    expect((await env.templates.list()).single.document.pages, hasLength(2));
    await env.settings.write('app', {'themeMode': 'dark'});
    expect(await env.settings.read('app'), {'themeMode': 'dark'});
    await env.db.close();
  });

  test('database created by the first version is migrated', () async {
    final dir = tempDir('migrate');
    final path = p.join(dir.path, 'old.db');
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT, description TEXT, created_at TEXT, updated_at TEXT, payload TEXT)',
          );
          await db.execute(
            'CREATE TABLE profiles (id TEXT PRIMARY KEY, payload TEXT)',
          );
          await db.insert('projects', {
            'id': 'legacy',
            'name': 'Ancien projet',
            'updated_at': '2026-01-01T00:00:00.000',
            'payload': '{"id":"legacy","name":"Ancien projet","elements":[{"name":"Titre","x":0.1,"y":0.1,"width":200,"height":50,"color":4285875711,"kind":"text","textContent":"Salut"}]}',
          });
          await db.insert('profiles', {
            'id': 'p1',
            'payload': '{"id":"p1","name":"Profil","brandColors":[4285875711]}',
          });
        },
      ),
    );
    await old.close();
    final db = await AppDatabase.open(path, factory: databaseFactoryFfi);
    final projects = await ProjectRepository(db).list();
    expect(projects.single.document.front.elements.single.text, 'Salut');
    expect(
      (await ProfileRepository(db).list()).single.brandColors.single,
      const Color(0xFF7545FF),
    );
    await TemplateRepository(db).list();
    await db.close();
  });

  test(
    'ZIP backup restores projects, profiles, templates, settings and images',
    () async {
      final source = await Env.open('backup-src');
      final logo = await source.assets.importBytes(
        samplePhotoPng(),
        fileName: 'logo.png',
      );
      final photo = await source.assets.importBytes(
        samplePhotoPng(width: 50, height: 50),
        fileName: 'photo.jpg',
      );
      await source.projects.save(
        Project(
          name: 'Avec photo',
          document: richSampleDocument(photoAssetId: photo),
        ),
      );
      await source.profiles.save(
        BusinessProfile.example().copyWith(logoAssetId: logo),
      );
      await source.templates.save(
        CustomTemplate(
          name: 'Modèle',
          category: 'Mes modèles',
          document: richSampleDocument(),
        ),
      );
      await source.settings.write('app', {'themeMode': 'light'});
      final zip = await source.backup.exportAll();

      final archive = ZipDecoder().decodeBytes(zip);
      expect(archive.findFile('manifest.json'), isNotNull);
      expect(
        archive.files.where((f) => f.name.startsWith('assets/')),
        hasLength(2),
      );

      final target = await Env.open('backup-dst');
      final report = await target.backup.import(zip);
      expect(report.projects, 1);
      expect(report.profiles, 1);
      expect(report.templates, 1);
      expect(report.assets, 2);
      expect(report.settings, 1);
      final restored = (await target.projects.list()).single;
      expect(restored.name, 'Avec photo');
      expect(await target.assets.read(photo), await source.assets.read(photo));
      expect((await target.profiles.list()).single.logoAssetId, logo);
      expect(await target.settings.read('app'), {'themeMode': 'light'});

      // Réimporter la même archive remplace sans dupliquer.
      await target.backup.import(zip);
      expect(await target.projects.list(), hasLength(1));
      await source.db.close();
      await target.db.close();
    },
  );

  test('single project archive and invalid archives', () async {
    final env = await Env.open('single');
    final project = Project(name: 'Seul', document: richSampleDocument());
    final zip = await env.backup.exportProject(project);
    final other = await Env.open('single-dst');
    final report = await other.backup.import(zip);
    expect(report.summary, '1 projet');
    expect(
      () => other.backup.import(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<BackupException>()),
    );
    final foreign = Archive()
      ..addFile(jsonFile('manifest.json', '{"format":"x"}'));
    expect(
      () =>
          other.backup.import(Uint8List.fromList(ZipEncoder().encode(foreign))),
      throwsA(isA<BackupException>()),
    );
    await env.db.close();
    await other.db.close();
  });

  test('asset ids cannot escape the media folder', () async {
    final env = await Env.open('assets');
    expect(AssetStore.isValidId('../etc/passwd'), isFalse);
    expect(AssetStore.isValidId('img-1.png'), isTrue);
    expect(() => env.assets.fileFor('../x'), throwsArgumentError);
    final evil = Archive()
      ..addFile(
        jsonFile('manifest.json', '{"format":"pubulotron-backup","version":1}'),
      )
      ..addFile(ArchiveFile('assets/..', 1, [1]))
      ..addFile(jsonFile('projects/x.json', '{}'));
    final report = await env.backup.import(
      Uint8List.fromList(ZipEncoder().encode(evil)),
    );
    expect(report.skipped, contains('assets/..'));
    await env.db.close();
  });
}
