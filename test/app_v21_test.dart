import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/app/providers.dart';
import 'package:pubulotron/app/variant_state.dart';
import 'package:pubulotron/layout/brand_kit.dart';
import 'package:pubulotron/layout/pack_builder.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/project.dart';
import 'package:pubulotron/ui/editor/history_panel.dart';
import 'package:pubulotron/ui/editor/sync_banner.dart';

import 'helpers/app_harness.dart';

void main() {
  testWidgets(
    'variant studio generates, keeps, compares and duplicates variants',
    (tester) async {
      final h = await pumpPubulotron(tester);
      await tapText(tester, 'Studio de variantes', last: true);
      await tapText(tester, '3');
      await tester.tap(find.text('Hors ligne (sans IA)'));
      await settle(tester, rounds: 10);
      var groups = h.container.read(variantGroupsProvider);
      expect(groups.values.single, hasLength(3));
      expect(find.text('Moderne et minimaliste'), findsWidgets);
      final stored = await tester.runAsync(h.services.projects.list);
      expect(
        stored!.where((p) => p.variantGroupId != null),
        hasLength(3),
        reason: 'chaque variante est enregistrée',
      );

      // Deuxième série : la première est conservée.
      await tester.tap(find.text('Hors ligne (sans IA)'));
      await settle(tester, rounds: 10);
      groups = h.container.read(variantGroupsProvider);
      expect(groups, hasLength(2));
      expect(groups.values.every((g) => g.length == 3), isTrue);

      // Comparer deux variantes.
      final boxes = find.byType(Checkbox);
      for (final i in [0, 1]) {
        await tester.ensureVisible(boxes.at(i));
        await tester.pump();
        await tester.tap(boxes.at(i));
        await tester.pump();
      }
      await tapText(tester, 'Comparer (2)');
      expect(find.text('Comparer 2 variantes'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await settle(tester);

      // Dupliquer.
      final group = h.container.read(
        variantGroupsProvider,
      )[h.container.read(variantStudioProvider).groupId]!;
      await tapText(tester, 'Dupliquer');
      expect(
        h.container.read(variantGroupsProvider)[group.first.variantGroupId],
        hasLength(4),
      );
    },
  );

  testWidgets(
    'surprise me proposes directions and creates the chosen designs',
    (tester) async {
      final h = await pumpPubulotron(tester);
      await tapText(tester, 'Surprends-moi !', last: true);
      await tester.enterText(
        find.widgetWithText(TextField, 'Votre activité'),
        'Je suis artisan menuisier.',
      );
      await tapText(tester, 'Proposer des directions artistiques');
      expect(find.text('Directions par défaut (hors ligne)'), findsOneWidget);
      await tapText(tester, 'Créer 3 créations (Carte de visite)');
      await settle(tester, rounds: 10);
      expect(h.container.read(navigationProvider), AppSection.variants);
      expect(
        h.container.read(variantGroupsProvider).values.single,
        hasLength(3),
      );
    },
  );

  testWidgets('history lists versions and restores an older one', (
    tester,
  ) async {
    final h = await pumpPubulotron(tester);
    final project = Project(
      name: 'Carte historique',
      document: PackBuilder.build(
        kit: BrandKit.fromProfile(BusinessProfile.example()),
        profile: BusinessProfile.example(),
      ).first.document,
    );
    await tester.runAsync(() => h.services.projects.save(project));
    await h.container.read(projectsProvider.notifier).refresh();
    final c = h.container.read(editorProvider.notifier).open(project);
    h.container.read(navigationProvider.notifier).go(AppSection.studio);
    await settle(tester);
    await tester.runAsync(c.saveNow);
    final title = c.page.elements.firstWhere((e) => e.type == ElementType.text);
    c.updateElement(title.id, (e) => e.copyWith(text: 'Titre modifié'));
    c.noteHistory('Modification du titre');
    await tester.runAsync(c.saveNow);
    await tester.tap(find.byTooltip('Historique des versions (Ctrl+H)'));
    await settle(tester, rounds: 6);
    expect(find.byType(HistoryPanel), findsOneWidget);
    expect(find.text('Version 2'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Actions').last);
    await settle(tester);
    await tapText(tester, 'Restaurer');
    await tapText(tester, 'Restaurer', last: true);
    await settle(tester, rounds: 6);
    expect(
      c.page.elementById(title.id)!.text,
      title.text,
      reason: 'version 1 restaurée',
    );
    final versions = await tester.runAsync(
      () => h.services.history.versions(project.id),
    );
    expect(versions!.first.label, 'Restauration de la version 1');
    expect(
      versions.any(
        (v) => v.document.front.elementById(title.id)!.text == 'Titre modifié',
      ),
      isTrue,
      reason: 'la version 2 reste disponible',
    );
  });

  testWidgets(
    'editing the phone on a card offers to update the other formats',
    (tester) async {
      final h = await pumpPubulotron(tester);
      final profile = BusinessProfile.example();
      final pack = PackBuilder.build(
        kit: BrandKit.fromProfile(profile),
        profile: profile,
        supports: PackSupport.standard.take(3).toList(),
      );
      await tester.runAsync(() async {
        for (final p in pack) {
          await h.services.projects.save(p);
        }
      });
      await h.container.read(projectsProvider.notifier).refresh();
      final c = h.container.read(editorProvider.notifier).open(pack.first);
      h.container.read(navigationProvider.notifier).go(AppSection.studio);
      await settle(tester);
      final phone = c.page.elements.firstWhere((e) => e.role == 'phone');
      c.updateElement(phone.id, (e) => e.copyWith(text: '07 00 00 00 01'));
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      expect(find.byType(SyncBanner), findsOneWidget);
      expect(
        find.textContaining(
          'Souhaites-tu appliquer cette modification aux autres formats ?',
        ),
        findsOneWidget,
      );
      await tapText(tester, 'Toutes les déclinaisons');
      expect(find.text('Synchroniser les créations liées'), findsOneWidget);
      await tapText(tester, 'Appliquer à 2 créations');
      await settle(tester, rounds: 8);
      for (final target in pack.skip(1)) {
        final stored = await tester.runAsync(
          () => h.services.projects.get(target.id),
        );
        final texts = stored!.document.front.elements
            .where((e) => e.type == ElementType.text)
            .map((e) => e.text)
            .join(' ');
        expect(texts, contains('07 00 00 00 01'), reason: target.name);
        final versions = await tester.runAsync(
          () => h.services.history.versions(target.id),
        );
        expect(
          versions!.map((v) => v.label).join(' | '),
          contains('Point de restauration'),
        );
      }
      expect(find.textContaining('Souhaites-tu appliquer'), findsNothing);
    },
  );

  testWidgets(
    'choosing "only this creation" leaves the other formats untouched',
    (tester) async {
      final h = await pumpPubulotron(tester);
      final profile = BusinessProfile.example();
      final pack = PackBuilder.build(
        kit: BrandKit.fromProfile(profile),
        profile: profile,
        supports: PackSupport.standard.take(2).toList(),
      );
      await tester.runAsync(() async {
        for (final p in pack) {
          await h.services.projects.save(p);
        }
      });
      await h.container.read(projectsProvider.notifier).refresh();
      final c = h.container.read(editorProvider.notifier).open(pack.first);
      h.container.read(navigationProvider.notifier).go(AppSection.studio);
      await settle(tester);
      final phone = c.page.elements.firstWhere((e) => e.role == 'phone');
      c.updateElement(phone.id, (e) => e.copyWith(text: '07 11 11 11 11'));
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      await tapText(tester, 'Uniquement cette création');
      expect(find.textContaining('Souhaites-tu appliquer'), findsNothing);
      final other = await tester.runAsync(
        () => h.services.projects.get(pack[1].id),
      );
      expect(
        other!.document.front.elements.map((e) => e.text).join(' '),
        isNot(contains('07 11 11 11 11')),
      );
    },
  );

  testWidgets(
    'improve my design gives offline advice without modifying the creation',
    (tester) async {
      final h = await pumpPubulotron(tester);
      final project = Project(
        name: 'À analyser',
        document: PackBuilder.build(
          kit: BrandKit.fromProfile(BusinessProfile.example()),
          profile: BusinessProfile.example(),
        ).first.document,
      );
      await tester.runAsync(() => h.services.projects.save(project));
      final c = h.container.read(editorProvider.notifier).open(project);
      h.container.read(navigationProvider.notifier).go(AppSection.studio);
      await settle(tester);
      final before = c.document;
      await tapText(tester, 'Améliore mon design');
      expect(find.text('Conseils'), findsOneWidget);
      await tapText(tester, 'Analyser');
      await settle(tester, rounds: 6);
      expect(find.textContaining('Analyse locale uniquement'), findsOneWidget);
      expect(
        identical(c.document, before),
        isTrue,
        reason: 'aucune modification en mode conseils',
      );
      // L'amélioration automatique demande une clé.
      await tapText(tester, 'Amélioration automatique');
      await tapText(tester, 'Proposer une amélioration');
      expect(find.textContaining('nécessite une clé API'), findsOneWidget);
    },
  );
}
