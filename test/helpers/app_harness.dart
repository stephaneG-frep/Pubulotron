import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubulotron/app/app_services.dart';
import 'package:pubulotron/app/providers.dart';
import 'package:pubulotron/app/pubulotron_app.dart';
import 'package:pubulotron/data/secret_store.dart';
import 'package:pubulotron/export/file_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_support.dart';

class FakeFileService implements FileService {
  final Map<String, Uint8List> saved = {};
  PickedFile? nextPick;

  @override
  bool get canShare => false;

  @override
  Future<String?> save(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
  }) async {
    saved[fileName] = bytes;
    return '/tmp/$fileName';
  }

  @override
  Future<bool> share(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
    String? text,
  }) async {
    saved[fileName] = bytes;
    return true;
  }

  @override
  Future<PickedFile?> pick({
    List<String>? extensions,
    bool images = false,
  }) async => nextPick;
}

class Harness {
  Harness(this.services, this.files, this.secrets);

  final AppServices services;
  final FakeFileService files;
  final MemorySecretStore secrets;
  late ProviderContainer container;
}

/// Démarre l'application complète sur une base temporaire.
Future<Harness> pumpPubulotron(
  WidgetTester tester, {
  Size size = const Size(1440, 960),
  http.Client? httpClient,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final files = FakeFileService();
  final secrets = MemorySecretStore();
  final services = (await tester.runAsync(
    () => AppServices.open(
      baseDirectory: tempDir('app'),
      factory: databaseFactoryFfiNoIsolate,
      secrets: secrets,
      files: files,
      httpClient:
          httpClient ?? MockClient((_) async => http.Response('{}', 500)),
    ),
  ))!;
  addTearDown(() => tester.runAsync(services.database.close));
  final harness = Harness(services, files, secrets);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const PubulotronApp(),
    ),
  );
  await settle(tester);
  harness.container = ProviderScope.containerOf(
    tester.element(find.byType(PubulotronApp)),
  );
  return harness;
}

/// Laisse les opérations asynchrones réelles (SQLite) se terminer.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// Fait défiler les listes verticales jusqu'à rendre [finder] construit.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  final scrollables = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  for (final scrollable in scrollables.evaluate().toList()) {
    try {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byWidget(scrollable.widget),
        maxScrolls: 40,
      );
      return;
    } catch (_) {
      // Essayer la liste suivante.
    }
  }
}

Future<void> tapText(
  WidgetTester tester,
  String text, {
  bool last = false,
}) async {
  final finder = find.text(text);
  await scrollTo(tester, finder);
  final target = last ? finder.last : finder.first;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await settle(tester);
}
