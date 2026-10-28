import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pubulotron/app/providers.dart';
import 'package:pubulotron/app/variant_state.dart';
import 'package:pubulotron/layout/brand_kit.dart';
import 'package:pubulotron/layout/pack_builder.dart';
import 'package:pubulotron/layout/template_catalog.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/project.dart';
import 'package:pubulotron/ui/theme.dart';
import 'package:pubulotron/ui/widgets/robopub.dart';

import 'helpers/app_harness.dart';
import 'helpers/test_support.dart';

/// Captures d'écran de chaque rubrique, pour contrôle visuel.
/// Lancement : SCREENSHOTS_OUT=dossier flutter test test/visual_tour_test.dart
final _out = Platform.environment['SCREENSHOTS_OUT'];

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  final element = tester.binding.rootElement!;
  final image = await captureImage(element);
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  File(p.join(_out!, '$name.png'))
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _visitAll(WidgetTester tester, Harness h, String prefix) async {
  final nav = h.container.read(navigationProvider.notifier);
  for (final section in AppSection.values) {
    nav.go(section);
    await settle(tester, rounds: 3);
    await _capture(
      tester,
      '${prefix}_${section.index.toString().padLeft(2, '0')}_${section.name}',
    );
  }
}

void main() {
  testWidgets('visual tour (desktop and phone)', skip: _out == null, (
    tester,
  ) async {
    Directory(_out!).createSync(recursive: true);
    await tester.runAsync(loadAppFonts);
    final h = await pumpPubulotron(tester);
    final profile = BusinessProfile.example();
    await tester.runAsync(() async {
      await h.services.profiles.save(profile);
      for (final id in ['it-card', 'garden-flyer', 'shop-poster']) {
        final t = TemplateCatalog.byId(id)!;
        await h.services.projects.save(
          Project(
            name: t.title,
            document: TemplateCatalog.instantiate(t, profile: profile),
          ),
        );
      }
    });
    await h.container.read(profilesProvider.notifier).reload();
    await h.container.read(projectsProvider.notifier).refresh();
    await settle(tester);
    await _visitAll(tester, h, 'desktop');

    // Atelier avec un projet ouvert et un élément sélectionné.
    final projects = h.container.read(projectsProvider).value!;
    final controller = h.container
        .read(editorProvider.notifier)
        .open(projects.last);
    h.container.read(navigationProvider.notifier).go(AppSection.studio);
    await settle(tester);
    controller.select(
      controller.page.elements.firstWhere((e) => e.role == 'headline').id,
    );
    await settle(tester);
    await _capture(tester, 'desktop_studio_selection');

    // Nouveautés 2.1 : variantes, synchronisation, historique, amélioration.
    await h.container
        .read(variantStudioProvider.notifier)
        .generate(useAi: false);
    await settle(tester, rounds: 8);
    h.container.read(navigationProvider.notifier).go(AppSection.variants);
    await settle(tester);
    await _capture(tester, 'v21_variants');

    final pack = PackBuilder.build(
      kit: BrandKit.fromProfile(profile),
      profile: profile,
      supports: PackSupport.standard.take(3).toList(),
    );
    await tester.runAsync(() async {
      for (final pr in pack) {
        await h.services.projects.save(pr);
      }
    });
    await h.container.read(projectsProvider.notifier).refresh();
    final card = h.container.read(editorProvider.notifier).open(pack.first);
    h.container.read(navigationProvider.notifier).go(AppSection.studio);
    await settle(tester);
    final phone = card.page.elements.firstWhere((e) => e.role == 'phone');
    card.updateElement(phone.id, (e) => e.copyWith(text: '07 00 11 22 33'));
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    await _capture(tester, 'v21_sync_banner');
    await tester.tap(find.text('Toutes les déclinaisons'));
    await settle(tester, rounds: 6);
    await _capture(tester, 'v21_sync_dialog');
    await tester.tap(find.textContaining('Appliquer à'));
    await settle(tester, rounds: 8);
    await tester.tap(find.byTooltip('Historique des versions (Ctrl+H)'));
    await settle(tester, rounds: 6);
    await _capture(tester, 'v21_history');
    await tester.tap(find.byTooltip('Fermer').last);
    await settle(tester);
    await tester.tap(find.text('Améliore mon design'));
    await settle(tester);
    await tester.tap(find.text('Analyser'));
    await settle(tester, rounds: 6);
    await _capture(tester, 'v21_improve');
    await tester.tap(find.text('Fermer').last);
    await settle(tester);
    h.container.read(navigationProvider.notifier).go(AppSection.surprise);
    await settle(tester);
    await tester.tap(find.text('Proposer des directions artistiques'));
    await settle(tester, rounds: 4);
    await _capture(tester, 'v21_surprise');

    // Format téléphone.
    tester.view.physicalSize = const Size(412, 892);
    await settle(tester);
    await _capture(tester, 'phone_studio');
    h.container.read(navigationProvider.notifier).go(AppSection.home);
    await settle(tester);
    await _capture(tester, 'phone_home');
    h.container.read(navigationProvider.notifier).go(AppSection.print);
    await settle(tester);
    await _capture(tester, 'phone_print');
    h.container.read(navigationProvider.notifier).go(AppSection.variants);
    await settle(tester);
    await _capture(tester, 'phone_variants');
  });

  testWidgets('application icon', skip: _out == null, (tester) async {
    Directory(_out!).createSync(recursive: true);
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.runAsync(loadAppFonts);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: Container(
            width: 512,
            height: 512,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [PubColors.white, Color(0xFFE6DCFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(112),
            ),
            alignment: Alignment.center,
            child: const RoboPub(size: 440),
          ),
        ),
      ),
    );
    await tester.pump();
    final image = await captureImage(
      find.byType(RepaintBoundary).first.evaluate().single,
    );
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.png),
    );
    File(p.join(_out!, 'icon_512.png'))
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
