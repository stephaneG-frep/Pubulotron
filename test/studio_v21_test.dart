import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pubulotron/ai/ai_client.dart';
import 'package:pubulotron/ai/ai_design_service.dart';
import 'package:pubulotron/data/app_database.dart';
import 'package:pubulotron/data/asset_store.dart';
import 'package:pubulotron/data/backup_service.dart';
import 'package:pubulotron/data/repositories.dart';
import 'package:pubulotron/history/change_summary.dart';
import 'package:pubulotron/history/history_service.dart';
import 'package:pubulotron/layout/brand_kit.dart';
import 'package:pubulotron/layout/pack_builder.dart';
import 'package:pubulotron/models/app_settings.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_document.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/fill.dart';
import 'package:pubulotron/models/formats.dart';
import 'package:pubulotron/models/project.dart';
import 'package:pubulotron/review/design_review.dart';
import 'package:pubulotron/sync/sync_engine.dart';
import 'package:pubulotron/variants/variant_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_support.dart';

const _fonts = [
  'Ubuntu',
  'Liberation Serif',
  'Ubuntu Condensed',
  'DejaVu Sans',
  'Liberation Sans',
];
const _bgs = ['#FFFFFF', '#0A1F44', '#2B1B2E', '#FFE066', '#1E6BFF'];

/// Réponse Anthropic contenant un design différent à chaque appel.
http.Response _design(int n) {
  final x = n.isEven ? 5 : 40;
  final design = {
    'designs': [
      {
        'title': 'Variante $n',
        'style': 'Style $n',
        'rationale': 'Composition $n.',
        'palette': [_bgs[n % 5]],
        'front': {
          'background': {
            'kind': 'solid',
            'colors': [_bgs[n % 5]],
          },
          'elements': [
            {
              'type': 'text',
              'role': 'name',
              'x': x,
              'y': 5 + n * 3,
              'width': 40,
              'height': 10,
              'text': 'TechCare Réparations',
              'fontFamily': _fonts[n % 5],
              'fontSize': 12,
              'color': '#000000',
            },
            {
              'type': 'text',
              'role': 'phone',
              'x': 5,
              'y': 40,
              'width': 40,
              'height': 6,
              'text': '06 12 34 56 78',
              'fontSize': 8,
              'color': '#000000',
            },
            {
              'type': 'qr',
              'role': 'qr',
              'x': n.isEven ? 60 : 5,
              'y': 25,
              'width': 20,
              'height': 20,
              'qrData': 'https://techcare-repair.fr',
            },
          ],
        },
      },
    ],
  };
  return http.Response(
    jsonEncode({
      'content': [
        {'type': 'text', 'text': jsonEncode(design)},
      ],
      'stop_reason': 'end_turn',
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

const _config = AiConfig(
  provider: AiProvider.anthropic,
  apiKey: 'k',
  model: 'claude-opus-5-5',
);

class _Env {
  _Env(this.db, this.dir)
    : projects = ProjectRepository(db),
      versions = VersionRepository(db),
      assets = AssetStore(Directory(p.join(dir.path, 'media')));

  final AppDatabase db;
  final Directory dir;
  final ProjectRepository projects;
  final VersionRepository versions;
  final AssetStore assets;

  static Future<_Env> open([String name = 'v21']) async {
    final dir = tempDir(name);
    return _Env(
      await AppDatabase.open(
        p.join(dir.path, 'app.db'),
        factory: databaseFactoryFfi,
      ),
      dir,
    );
  }
}

DesignDocument _card(
  String phone, {
  String? assetId,
  Color accent = const Color(0xFF7545FF),
}) => DesignDocument(
  widthMm: 85,
  heightMm: 55,
  pages: [
    DesignPage(
      background: Fill.solid(const Color(0xFFFFFFFF)),
      elements: [
        DesignElement(
          id: 'band',
          type: ElementType.shape,
          x: 0,
          y: 0,
          width: 85,
          height: 10,
          fill: Fill.solid(accent),
        ),
        DesignElement(
          id: 'phone',
          type: ElementType.text,
          role: 'phone',
          text: phone,
          x: 5,
          y: 40,
          width: 40,
          height: 6,
          fontSize: 8,
        ),
        if (assetId != null)
          DesignElement(
            id: 'logo',
            type: ElementType.image,
            role: 'logo',
            assetId: assetId,
            x: 60,
            y: 5,
            width: 20,
            height: 20,
          ),
      ],
    ),
  ],
);

void main() {
  sqfliteFfiInit();

  group('1-2-9. Variantes', () {
    test(
      'several variants are generated, saved one by one, with progress',
      () async {
        var calls = 0;
        final service = VariantService(
          AiDesignService(
            AiClient(httpClient: MockClient((_) async => _design(calls++))),
          ),
        );
        final saved = <Project>[];
        final progress = <VariantProgress>[];
        final result = await service.generate(
          config: _config,
          brief: 'Cinq cartes de visite pour mon dépannage informatique',
          profile: BusinessProfile.example(),
          format: DesignFormats.businessCard,
          directions: ArtDirection.defaults,
          onVariant: (v) async => saved.add(v),
          onProgress: progress.add,
        );
        expect(result.created, hasLength(5));
        expect(saved.map((v) => v.id), result.created.map((v) => v.id));
        expect(
          result.created.map((v) => v.variantGroupId).toSet(),
          hasLength(1),
        );
        expect(result.created.map((v) => v.variantIndex), [1, 2, 3, 4, 5]);
        expect(
          result.created.map((v) => v.variantStyle),
          ArtDirection.defaults.map((d) => d.name),
        );
        expect(
          result.created.every(
            (v) =>
                v.document.widthMm == 85 &&
                v.document.formatId == 'business-card',
          ),
          isTrue,
        );
        expect(progress.first.done, 0);
        expect(progress.last.done, 5);
        expect(calls, greaterThanOrEqualTo(5));
      },
    );

    test(
      'a second run keeps previous variants and continues numbering',
      () async {
        final env = await _Env.open('keep');
        var calls = 0;
        final service = VariantService(
          AiDesignService(
            AiClient(httpClient: MockClient((_) async => _design(calls++))),
          ),
        );
        final first = await service.generate(
          config: _config,
          brief: 'b',
          profile: null,
          format: DesignFormats.businessCard,
          directions: ArtDirection.defaults.take(2).toList(),
          onVariant: env.projects.save,
        );
        final second = await service.generate(
          config: _config,
          brief: 'b',
          profile: null,
          format: DesignFormats.businessCard,
          directions: ArtDirection.defaults.skip(2).take(2).toList(),
          groupId: first.created.first.variantGroupId,
          existing: first.created,
          onVariant: env.projects.save,
        );
        expect(second.created.map((v) => v.variantIndex), [3, 4]);
        final all = await env.projects.list();
        expect(all, hasLength(4));
        for (final v in first.created) {
          final stored = await env.projects.get(v.id);
          expect(
            jsonEncode(stored!.document.toJson()),
            jsonEncode(v.document.toJson()),
            reason: 'non écrasée',
          );
        }
        await env.db.close();
      },
    );

    test('network failure keeps the variants already produced', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 2) throw const SocketException('réseau coupé');
        return _design(calls);
      });
      final saved = <Project>[];
      final result =
          await VariantService(AiDesignService(AiClient(httpClient: client)))
              .generate(
                config: _config,
                brief: 'b',
                profile: null,
                format: DesignFormats.businessCard,
                directions: ArtDirection.defaults.take(3).toList(),
                onVariant: (v) async => saved.add(v),
              );
      expect(result.created, hasLength(2));
      expect(saved, hasLength(2));
      expect(result.failures.single, contains('Connexion Internet impossible'));
      expect(result.aborted, isFalse);
    });

    test(
      'an invalid key aborts the run instead of retrying every variant',
      () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response(
            '{"error":{"message":"invalid x-api-key"}}',
            401,
          );
        });
        final result =
            await VariantService(AiDesignService(AiClient(httpClient: client)))
                .generate(
                  config: _config,
                  brief: 'b',
                  profile: null,
                  format: DesignFormats.businessCard,
                  directions: ArtDirection.defaults,
                  onVariant: (_) async {},
                );
        expect(result.aborted, isTrue);
        expect(result.created, isEmpty);
        expect(calls, 1);
      },
    );

    testWidgets('offline variants use different layouts', (tester) async {
      await tester.runAsync(() async {
        await loadAppFonts();
        final result = await VariantService(AiDesignService(AiClient()))
            .generate(
              config: null,
              brief: 'b',
              profile: BusinessProfile.example(),
              format: DesignFormats.businessCard,
              directions: ArtDirection.defaults,
              onVariant: (_) async {},
            );
        expect(result.created, hasLength(5));
        final docs = result.created.map((v) => v.document).toList();
        for (var i = 0; i < docs.length; i++) {
          for (var j = i + 1; j < docs.length; j++) {
            expect(
              variantSimilarity(docs[i], docs[j]),
              lessThan(VariantService.similarityLimit),
              reason: '$i/$j trop proches',
            );
          }
        }
      });
    });

    test('similarity detects near-identical compositions', () {
      final a = _card('06 00 00 00 00');
      expect(variantSimilarity(a, a), greaterThan(0.95));
      final b = DesignDocument(
        widthMm: 85,
        heightMm: 55,
        pages: [
          DesignPage(
            background: Fill.solid(const Color(0xFF000000)),
            elements: [
              DesignElement(
                type: ElementType.text,
                role: 'headline',
                fontFamily: 'Liberation Serif',
                text: 'x',
                x: 60,
                y: 45,
                width: 20,
                height: 5,
              ),
            ],
          ),
        ],
      );
      expect(variantSimilarity(a, b), lessThan(0.6));
      expect(layoutSummary(b), contains('headline en bas-droite'));
    });

    test('AI art directions are parsed and validated', () {
      final dirs = VariantService.parseDirections(
        '{"directions":[{"name":"Bois et nature","description":"Tons chauds","palette":["#8A4B2A","bad"],"layout":"nature"},{"name":""}]}',
      );
      expect(dirs.single.name, 'Bois et nature');
      expect(dirs.single.palette, [const Color(0xFF8A4B2A)]);
      expect(
        () => VariantService.parseDirections('{"directions":[]}'),
        throwsA(isA<AiException>()),
      );
    });
  });

  test('3. a variant is edited independently of the others', () async {
    final env = await _Env.open('independent');
    final a = Project(
      name: 'A',
      document: _card('06 11'),
      variantGroupId: 'g',
      variantIndex: 1,
    );
    final b = Project(
      name: 'B',
      document: _card('06 11'),
      variantGroupId: 'g',
      variantIndex: 2,
    );
    await env.projects.save(a);
    await env.projects.save(b);
    final edited = a.copyWith(document: _card('07 99'));
    await env.projects.save(edited);
    expect(
      (await env.projects.get(a.id))!.document.front.elementById('phone')!.text,
      '07 99',
    );
    expect(
      (await env.projects.get(b.id))!.document.front.elementById('phone')!.text,
      '06 11',
    );
    await env.db.close();
  });

  group('4-5. Synchronisation', () {
    testWidgets(
      'phone change propagates to every format without moving elements',
      (tester) async {
        await tester.runAsync(() async {
          await loadAppFonts();
          final profile = BusinessProfile.example();
          final pack = PackBuilder.build(
            kit: BrandKit.fromProfile(profile),
            profile: profile,
          );
          final card = pack.first;
          final phoneEl = card.document.front.elements.firstWhere(
            (e) => e.role == 'phone',
          );
          final edited = card.document.replacePage(
            0,
            card.document.front.copyWith(
              elements: [
                for (final e in card.document.front.elements)
                  e.id == phoneEl.id ? e.copyWith(text: '07 00 11 22 33') : e,
              ],
            ),
          );
          final changes = SyncEngine.detect(card.document, edited);
          expect(changes.single, isA<TextSyncChange>());
          expect(changes.single.label, startsWith('Téléphone'));

          final targets = SyncEngine.siblings(card, pack);
          expect(targets, hasLength(4));
          for (final preview in SyncEngine.previewAll(targets, changes)) {
            expect(preview.affected, isTrue, reason: preview.project.name);
            final before = preview.project.document.front.elements;
            final after = preview.document.front.elements;
            expect(after.length, before.length);
            for (var i = 0; i < before.length; i++) {
              expect(after[i].id, before[i].id);
              expect(after[i].x, before[i].x, reason: 'position conservée');
              expect(after[i].y, before[i].y);
              expect(after[i].width, before[i].width);
            }
            final texts = after
                .where((e) => e.type == ElementType.text)
                .map((e) => e.text)
                .join('\n');
            expect(texts, contains('07 00 11 22 33'));
            expect(texts, isNot(contains(profile.phone)));
          }
        });
      },
    );

    test('segment of a combined contact line, QR, logo and colour changes are detected', () {
      final before = DesignDocument(
        widthMm: 85,
        heightMm: 55,
        pages: [
          DesignPage(
            elements: [
              DesignElement(
                id: 'c',
                type: ElementType.text,
                text: '06 12 34 56 78  ·  contact@a.fr',
                x: 0,
                y: 0,
                width: 80,
                height: 5,
              ),
              DesignElement(
                id: 'q',
                type: ElementType.qr,
                qrData: 'https://a.fr',
                x: 0,
                y: 10,
                width: 20,
                height: 20,
              ),
              DesignElement(
                id: 'l',
                type: ElementType.image,
                role: 'logo',
                assetId: 'old.png',
                x: 40,
                y: 10,
                width: 20,
                height: 20,
              ),
              DesignElement(
                id: 's',
                type: ElementType.shape,
                fill: Fill.solid(const Color(0xFF7545FF)),
                x: 0,
                y: 40,
                width: 85,
                height: 15,
              ),
            ],
          ),
        ],
      );
      final after = before.replacePage(
        0,
        before.front.copyWith(
          elements: [
            before.front.elements[0].copyWith(
              text: '06 12 34 56 78  ·  bonjour@a.fr',
            ),
            before.front.elements[1].copyWith(qrData: 'https://b.fr'),
            before.front.elements[2].copyWith(assetId: 'new.png'),
            before.front.elements[3].copyWith(
              fill: Fill.solid(const Color(0xFFFF6384)),
            ),
          ],
        ),
      );
      final changes = SyncEngine.detect(before, after);
      expect(
        changes.whereType<TextSyncChange>().single.oldText,
        'contact@a.fr',
      );
      expect(changes.whereType<QrSyncChange>(), hasLength(1));
      expect(changes.whereType<ImageSyncChange>().single.logo, isTrue);
      expect(
        changes.whereType<ColorSyncChange>().single.newColor,
        const Color(0xFFFF6384),
      );

      final target = Project(
        name: 't',
        document: DesignDocument(
          widthMm: 148,
          heightMm: 210,
          pages: [
            DesignPage(
              background: Fill.linear(
                const Color(0xFF7545FF),
                const Color(0xFF000000),
              ),
              elements: [
                DesignElement(
                  id: 'm',
                  type: ElementType.text,
                  role: 'email',
                  text: 'contact@a.fr',
                  x: 10,
                  y: 10,
                  width: 60,
                  height: 10,
                ),
                DesignElement(
                  id: 'q2',
                  type: ElementType.qr,
                  qrData: 'https://a.fr',
                  x: 10,
                  y: 30,
                  width: 30,
                  height: 30,
                ),
                DesignElement(
                  id: 'l2',
                  type: ElementType.image,
                  assetId: 'old.png',
                  x: 50,
                  y: 30,
                  width: 30,
                  height: 30,
                ),
              ],
            ),
          ],
        ),
      );
      final preview = SyncEngine.apply(target, changes);
      final els = preview.document.front.elements;
      expect(els[0].text, 'bonjour@a.fr');
      expect(els[1].qrData, 'https://b.fr');
      expect(els[2].assetId, 'new.png');
      expect(
        preview.document.front.background.primary,
        const Color(0xFFFF6384),
      );
      expect(preview.total, 4);
    });

    test('selective synchronisation only touches chosen formats and records restore points', () async {
      final env = await _Env.open('selective');
      final history = HistoryService(env.versions);
      final source = Project(
        name: 'Carte',
        document: _card('06 11 11 11 11'),
        packId: 'pack',
      );
      final t1 = Project(
        name: 'Flyer',
        document: _card('06 11 11 11 11'),
        packId: 'pack',
      );
      final t2 = Project(
        name: 'Affiche',
        document: _card('06 11 11 11 11'),
        packId: 'pack',
      );
      for (final pr in [source, t1, t2]) {
        await env.projects.save(pr);
        await history.record(pr);
      }
      final edited = _card('07 22 22 22 22');
      final changes = SyncEngine.detect(source.document, edited);
      final chosen = [t1];
      for (final preview in SyncEngine.previewAll(chosen, changes)) {
        await history.record(
          preview.project,
          label: 'Avant synchronisation',
          kind: VersionKind.restorePoint,
          force: true,
        );
        final updated = preview.project.copyWith(document: preview.document);
        await env.projects.save(updated);
        await history.record(
          updated,
          label: 'Synchronisation',
          kind: VersionKind.sync,
          force: true,
        );
      }
      expect(
        (await env.projects.get(t1.id))!.document.front
            .elementById('phone')!
            .text,
        '07 22 22 22 22',
      );
      expect(
        (await env.projects.get(t2.id))!.document.front
            .elementById('phone')!
            .text,
        '06 11 11 11 11',
        reason: 'non choisie',
      );
      final versions = await history.versions(t1.id);
      expect(versions.map((v) => v.kind), [
        VersionKind.sync,
        VersionKind.restorePoint,
        VersionKind.initial,
      ]);
      expect(
        versions[1].document.front.elementById('phone')!.text,
        '06 11 11 11 11',
        reason: 'point de restauration',
      );
      await env.db.close();
    });
  });

  group('6-7. Historique', () {
    test('restoring version 2 keeps version 5 available', () async {
      final env = await _Env.open('restore');
      var now = DateTime(2026, 10, 27, 9);
      final history = HistoryService(env.versions, clock: () => now);
      var project = Project(name: 'Carte', document: _card('v1'));
      await history.record(
        project,
        label: 'Création initiale par IA',
        kind: VersionKind.ai,
      );
      for (var i = 2; i <= 5; i++) {
        now = now.add(const Duration(minutes: 10));
        project = project.copyWith(document: _card('v$i'));
        await history.record(project);
      }
      var versions = await history.versions(project.id);
      expect(versions.map((v) => v.number), [5, 4, 3, 2, 1]);
      expect(versions.first.label, contains('Modification du texte « v5 »'));
      final v2 = versions.firstWhere((v) => v.number == 2);
      now = now.add(const Duration(minutes: 1));
      project = project.copyWith(document: v2.document);
      await history.record(
        project,
        label: 'Restauration de la version 2',
        kind: VersionKind.restore,
        force: true,
      );
      versions = await history.versions(project.id);
      expect(versions.first.number, 6);
      expect(versions.first.document.front.elementById('phone')!.text, 'v2');
      expect(
        versions.any(
          (v) =>
              v.number == 5 &&
              v.document.front.elementById('phone')!.text == 'v5',
        ),
        isTrue,
      );
      await env.db.close();
    });

    test('close edits are merged, notable operations always create a version, retention is applied', () async {
      final env = await _Env.open('policy');
      var now = DateTime(2026, 10, 27, 9);
      final history = HistoryService(
        env.versions,
        policy: const HistoryPolicy(maxVersions: 4),
        clock: () => now,
      );
      var project = Project(name: 'x', document: _card('a'));
      await history.record(project);
      now = now.add(const Duration(minutes: 5));
      project = project.copyWith(document: _card('b'));
      await history.record(project);
      now = now.add(const Duration(seconds: 30));
      project = project.copyWith(document: _card('c'));
      await history.record(project);
      expect(
        await history.versions(project.id),
        hasLength(2),
        reason: 'modifications rapprochées fusionnées',
      );
      expect(
        (await history.versions(project.id)).first.document.front
            .elementById('phone')!
            .text,
        'c',
      );
      expect(await history.record(project), isNull, reason: 'rien n’a changé');
      for (final t in ['d', 'e', 'f', 'g']) {
        now = now.add(const Duration(seconds: 5));
        project = project.copyWith(document: _card(t));
        await history.record(project, label: 'IA', kind: VersionKind.ai);
      }
      final versions = await history.versions(project.id);
      expect(versions, hasLength(4));
      expect(
        versions.last.kind,
        VersionKind.initial,
        reason: 'la version initiale est toujours gardée',
      );
      expect(versions.first.document.front.elementById('phone')!.text, 'g');
    });

    test(
      'versions keep their media, survive a ZIP backup and a restore',
      () async {
        final env = await _Env.open('media');
        final logo = await env.assets.importBytes(
          samplePhotoPng(),
          fileName: 'logo.png',
        );
        final history = HistoryService(env.versions);
        var project = Project(
          name: 'Logo',
          document: _card('06', assetId: logo),
        );
        await env.projects.save(project);
        await history.record(project);
        project = project.copyWith(document: _card('06'));
        await env.projects.save(project);
        await history.record(
          project,
          label: 'Logo retiré',
          kind: VersionKind.edit,
          force: true,
        );

        final old = (await history.versions(project.id)).last;
        expect(old.document.assetIds, {logo});
        expect(
          await env.assets.read(logo),
          isNotNull,
          reason: 'le média reste disponible pour l’ancienne version',
        );

        BackupService backupOf(_Env e) => BackupService(
          projects: e.projects,
          profiles: ProfileRepository(e.db),
          templates: TemplateRepository(e.db),
          settings: SettingsRepository(e.db),
          assets: e.assets,
          versions: e.versions,
        );
        final zip = await backupOf(env).exportAll();
        final target = await _Env.open('media-restore');
        final report = await backupOf(target).import(zip);
        expect(report.versions, 2);
        final restored = await HistoryService(target.versions)
            .versions(project.id);
        expect(restored.last.document.assetIds, {logo});
        expect(await target.assets.read(logo), await env.assets.read(logo));
        await env.db.close();
        await target.db.close();
      },
    );

    test('change summary describes edits in French', () {
      final before = _card('06');
      final after = before.replacePage(
        0,
        before.front.copyWith(
          background: Fill.solid(const Color(0xFF000000)),
          elements: [
            ...before.front.elements.map(
              (e) => e.id == 'phone' ? e.copyWith(text: '07', x: 10) : e,
            ),
            DesignElement(
              type: ElementType.qr,
              qrData: 'x',
              x: 0,
              y: 0,
              width: 20,
              height: 20,
            ),
          ],
        ),
      );
      final changes = describeChanges(before, after);
      expect(
        changes,
        containsAll([
          'Changement du fond',
          'Ajout : QR code',
          'Modification du texte « 07 »',
          'Mise en page (1 élément)',
        ]),
      );
      expect(summarizeChanges(changes, max: 2), endsWith('(+2)'));
    });
  });

  group('8. Améliore mon design', () {
    final profile = BusinessProfile.example();
    DesignDocument doc() => DesignDocument(
      widthMm: 85,
      heightMm: 55,
      pages: [
        DesignPage(
          background: Fill.solid(const Color(0xFFFFFFFF)),
          elements: [
            DesignElement(
              id: 'title',
              type: ElementType.text,
              role: 'name',
              text: 'TechCare Réparations',
              x: 5,
              y: 5,
              width: 50,
              height: 10,
              fontSize: 9,
              color: const Color(0xFFDDDDDD),
            ),
            DesignElement(
              id: 'phone',
              type: ElementType.text,
              role: 'phone',
              text: profile.phone,
              x: 1,
              y: 45,
              width: 40,
              height: 6,
              fontSize: 5,
            ),
            DesignElement(
              id: 'qr',
              type: ElementType.qr,
              qrData: 'https://techcare-repair.fr',
              x: 70,
              y: 40,
              width: 12,
              height: 12,
            ),
            DesignElement(
              id: 'deco',
              type: ElementType.shape,
              fill: Fill.solid(const Color(0xFF7545FF)),
              x: 0,
              y: 52,
              width: 85,
              height: 3,
            ),
          ],
        ),
      ],
    );

    test(
      'local analysis finds contrast, size, margin and QR problems offline',
      () {
        final findings = LocalDesignAnalyzer.analyze(doc());
        final titles = findings.map((f) => f.title).toSet();
        expect(
          titles,
          containsAll([
            'Contraste insuffisant',
            'Texte trop petit',
            'Texte trop près du bord',
            'QR code trop petit',
          ]),
        );
        expect(
          findings.firstWhere((f) => f.title == 'Texte trop petit').severity,
          FindingSeverity.critical,
          reason: 'coordonnée illisible',
        );
        expect(
          contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
          closeTo(21, 0.01),
        );
      },
    );

    test(
      'advice without AI explains its limits; with AI the image is sent',
      () async {
        final offline = await DesignReviewService(AiDesignService(AiClient()))
            .advise(config: null, document: doc());
        expect(offline.imagesUsed, isFalse);
        expect(offline.limits, contains('Analyse locale'));
        late Map<String, dynamic> body;
        final client = MockClient((req) async {
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'type': 'text',
                  'text': '{"summary":"Titre peu lisible.","findings":[{"severity":"warning","title":"Titre pâle","detail":"Assombrir le titre."}]}',
                },
              ],
              'stop_reason': 'end_turn',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });
        final report =
            await DesignReviewService(
              AiDesignService(AiClient(httpClient: client)),
            ).advise(
              config: _config,
              document: doc(),
              profile: profile,
              preview: samplePhotoPng(),
            );
        final content =
            ((body['messages'] as List).first as Map)['content'] as List;
        expect(content.first['type'], 'image');
        expect(report.imagesUsed, isTrue);
        expect(report.summary, 'Titre peu lisible.');
        expect(
          report.findings
              .where((f) => f.source == 'Anthropic Claude')
              .single
              .title,
          'Titre pâle',
        );
        expect(
          report.findings.where((f) => f.source == 'analyse locale'),
          isNotEmpty,
        );
      },
    );

    test('automatic improvement never overwrites and keeps contacts and QR content', () async {
      final original = doc();
      final originalJson = jsonEncode(original.toJson());
      const ops =
          '{"message":"Titre renforcé, coordonnées agrandies.","operations":['
          '{"op":"update","id":"title","changes":{"color":"#17213B","fontSize":14}},'
          '{"op":"update","id":"phone","changes":{"text":"01 00 00 00 00","fontSize":8,"x":5}},'
          '{"op":"update","id":"qr","changes":{"qrData":"https://autre.fr","width":18,"height":18}},'
          '{"op":"delete","id":"deco"},'
          '{"op":"add","element":{"type":"shape","x":0,"y":0,"width":85,"height":4,"fill":{"kind":"solid","colors":["#24C9C2"]}}}]}';
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': ops},
            ],
            'stop_reason': 'end_turn',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final result =
          await DesignReviewService(
            AiDesignService(AiClient(httpClient: client)),
          ).improve(
            config: _config,
            document: original,
            instruction: 'Rends cette carte plus professionnelle, mais conserve mes textes et mon QR code.',
            profile: profile,
          );
      expect(
        jsonEncode(original.toJson()),
        originalJson,
        reason: 'original intact',
      );
      final page = result.page;
      expect(page.elementById('title')!.fontSize, 14);
      expect(
        page.elementById('phone')!.text,
        profile.phone,
        reason: 'coordonnée non inventée',
      );
      expect(
        page.elementById('phone')!.fontSize,
        8,
        reason: 'le style peut changer',
      );
      expect(page.elementById('qr')!.qrData, 'https://techcare-repair.fr');
      expect(page.elementById('qr')!.width, 18);
      expect(
        page.elementById('deco'),
        isNotNull,
        reason: 'suppression non demandée : rétabli',
      );
      expect(page.elements, hasLength(5));
      expect(result.guarded, isNotEmpty);
    });

    test(
      'network errors during improvement are reported, nothing is changed',
      () async {
        final client = MockClient(
          (_) async => throw const SocketException('hors ligne'),
        );
        await expectLater(
          DesignReviewService(
            AiDesignService(AiClient(httpClient: client)),
          ).improve(config: _config, document: doc(), instruction: 'Modernise'),
          throwsA(
            isA<AiException>().having(
              (e) => e.kind,
              'kind',
              AiErrorKind.network,
            ),
          ),
        );
      },
    );

    test('a model refusing images is asked again without them', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        final body = req.body;
        if (body.contains('image_url')) {
          return http.Response(
            '{"error":{"message":"model does not support images"}}',
            400,
          );
        }
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"summary\\":\\"ok\\",\\"findings\\":[]}"},"finish_reason":"stop"}]}',
          200,
        );
      });
      final report =
          await DesignReviewService(
            AiDesignService(AiClient(httpClient: client)),
          ).advise(
            config: const AiConfig(
              provider: AiProvider.mistral,
              apiKey: 'k',
              model: 'mistral-large-latest',
            ),
            document: doc(),
            preview: samplePhotoPng(),
          );
      expect(calls, 2);
      expect(report.imagesUsed, isFalse);
      expect(report.limits, contains('ne lit pas les images'));
    });
  });

  test('10. projects with variants and history survive closing and reopening the database', () async {
    final dir = tempDir('reopen-v21');
    final path = p.join(dir.path, 'app.db');
    var db = await AppDatabase.open(path, factory: databaseFactoryFfi);
    final project = Project(
      name: 'V',
      document: _card('06'),
      variantGroupId: 'g1',
      variantIndex: 3,
      variantStyle: 'Futuriste avec dégradés',
    );
    await ProjectRepository(db).save(project);
    await HistoryService(
      VersionRepository(db),
    ).record(project, label: 'Création initiale par IA', kind: VersionKind.ai);
    await db.close();
    db = await AppDatabase.open(path, factory: databaseFactoryFfi);
    final reopened = (await ProjectRepository(db).get(project.id))!;
    expect(
      [reopened.variantGroupId, reopened.variantIndex, reopened.variantStyle],
      ['g1', 3, 'Futuriste avec dégradés'],
    );
    final versions = await HistoryService(VersionRepository(db))
        .versions(project.id);
    expect(versions.single.label, 'Création initiale par IA');
    await db.close();
  });

  test(
    'database from version 2.0 (schema 3) is migrated to the history schema',
    () async {
      final dir = tempDir('migrate-v4');
      final path = p.join(dir.path, 'old.db');
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT, description TEXT, created_at TEXT, updated_at TEXT, payload TEXT, format_id TEXT, pack_id TEXT)',
            );
            await db.execute(
              'CREATE TABLE profiles (id TEXT PRIMARY KEY, payload TEXT)',
            );
            await db.execute(
              'CREATE TABLE templates (id TEXT PRIMARY KEY, name TEXT, category TEXT, created_at TEXT, payload TEXT)',
            );
            await db.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)',
            );
            await db.insert('projects', {
              'id': 'p1',
              'name': 'Ancienne',
              'updated_at': '2026-10-26',
              'payload': jsonEncode(
                Project(
                  id: 'p1',
                  name: 'Ancienne',
                  document: _card('06'),
                ).toJson(),
              ),
            });
          },
        ),
      );
      await old.close();
      final db = await AppDatabase.open(path, factory: databaseFactoryFfi);
      expect((await ProjectRepository(db).list()).single.name, 'Ancienne');
      expect(await VersionRepository(db).list('p1'), isEmpty);
      await HistoryService(VersionRepository(db))
          .record((await ProjectRepository(db).get('p1'))!);
      expect(await VersionRepository(db).count('p1'), 1);
      await db.close();
    },
  );
}
