import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubulotron/app/creation_state.dart';
import 'package:pubulotron/app/providers.dart';
import 'package:pubulotron/editor/editor_controller.dart';
import 'package:pubulotron/models/app_settings.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/project.dart';
import 'package:pubulotron/ui/sections.dart';

import 'helpers/app_harness.dart';
import 'helpers/test_support.dart';

void main() {
  testWidgets('dashboard lists every section and navigation works', (
    tester,
  ) async {
    await pumpPubulotron(tester);
    expect(
      find.text('La machine à fabriquer des pubs qui ont du génie !'),
      findsOneWidget,
    );
    for (final s in sections) {
      expect(find.text(s.label), findsWidgets, reason: s.label);
    }
    await tapText(tester, 'Mode d’emploi', last: true);
    expect(
      find.text('Imprimer plusieurs cartes sur une feuille'),
      findsOneWidget,
    );
    expect(find.text('Disponible hors ligne ?'), findsOneWidget);
  });

  testWidgets(
    'blank creation opens the studio, editing is saved and survives reopening',
    (tester) async {
      final h = await pumpPubulotron(tester);
      await tapText(tester, 'Nouvelle création', last: true);
      expect(find.text('1. Format'), findsOneWidget);
      await tapText(tester, 'Page blanche');
      final controller = h.container.read(editorProvider)!;
      expect(controller.document.widthMm, 85);
      expect(find.text('Insérer'), findsWidgets);

      await tapText(tester, 'Titre');
      expect(controller.page.elements.single.type, ElementType.text);
      expect(controller.selection, hasLength(1));

      // Modification par le panneau de propriétés.
      await tester.tap(find.text('Propriétés').first);
      await settle(tester);
      expect(find.text('Police'), findsOneWidget);
      controller.updateElement(
        controller.page.elements.single.id,
        (e) => e.copyWith(text: 'Bonjour Pubulotron'),
      );
      await settle(tester);

      await tester.runAsync(controller.saveNow);
      expect(controller.saveState, SaveState.saved);
      final stored = (await tester.runAsync(
        () => h.services.projects.get(controller.project.id),
      ))!;
      expect(stored.document.front.elements.single.text, 'Bonjour Pubulotron');

      // Annuler depuis la barre d'outils.
      await tester.tap(find.byTooltip('Annuler (Ctrl+Z)'));
      await settle(tester);
      expect(controller.page.elements.single.text, isNot('Bonjour Pubulotron'));

      // Fermer puis rouvrir depuis « Mes projets ».
      await tester.tap(find.byTooltip('Fermer le projet'));
      await settle(tester, rounds: 6);
      expect(h.container.read(editorProvider), isNull);
      await tapText(tester, 'Mes projets', last: true);
      expect(find.text(controller.project.name), findsWidgets);
    },
  );

  testWidgets('template library creates a project from a model', (
    tester,
  ) async {
    final h = await pumpPubulotron(tester);
    await tapText(tester, 'Bibliothèque de modèles', last: true);
    await tapText(tester, 'Jardinage');
    expect(find.text('Flyer jardin'), findsOneWidget);
    await tapText(tester, 'Utiliser ce modèle');
    final controller = h.container.read(editorProvider)!;
    expect(controller.project.name, 'Flyer jardin');
    expect(controller.document.formatId, 'flyer-a5');
    final projects = await tester.runAsync(h.services.projects.list);
    expect(projects!.map((p) => p.name), contains('Flyer jardin'));
  });

  testWidgets('AI settings store the key securely and select the provider', (
    tester,
  ) async {
    final h = await pumpPubulotron(tester);
    await tapText(tester, 'Paramètres IA', last: true);
    await tapText(tester, 'Mistral AI');
    await tester.enterText(
      find.widgetWithText(TextField, 'Clé API'),
      'cle-mistral-test',
    );
    await tapText(tester, 'Enregistrer');
    expect(h.secrets.values[AiProvider.mistral.secretKey], 'cle-mistral-test');
    expect(h.container.read(settingsProvider).provider, AiProvider.mistral);
    expect(
      h.container.read(aiConfigProvider)!.model,
      AiProvider.mistral.defaultModel,
    );
    final stored = await tester.runAsync(() => h.services.settings.read('app'));
    expect(stored!['provider'], 'mistral');
  });

  testWidgets('API key saved by the first version is migrated', (tester) async {
    final h = await pumpPubulotron(tester);
    h.secrets.values['pubulotron_api_key'] = 'sk-ancienne';
    h.secrets.values['pubulotron_ai_provider'] = 'OpenAI';
    h.container.invalidate(apiKeysProvider);
    await settle(tester);
    h.container.read(apiKeysProvider);
    await settle(tester);
    expect(h.secrets.values[AiProvider.openai.secretKey], 'sk-ancienne');
    expect(h.secrets.values.containsKey('pubulotron_api_key'), isFalse);
    expect(h.container.read(settingsProvider).provider, AiProvider.openai);
    expect(h.container.read(aiConfigProvider)!.apiKey, 'sk-ancienne');
  });

  testWidgets('AI creation calls the provider and opens a proposal', (
    tester,
  ) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.host, 'api.anthropic.com');
      const designs =
          '{"designs":[{"title":"Néon tech","style":"Futuriste","rationale":"Lisible.","palette":["#0A1F44"],'
          '"front":{"background":{"kind":"solid","colors":["#0A1F44"]},"elements":[{"type":"text","x":5,"y":5,"width":60,"height":12,"text":"TechCare","fontSize":14,"color":"#FFFFFF"}]}}]}';
      return http.Response(
        jsonEncode({
          'content': [
            {'type': 'text', 'text': designs},
          ],
          'stop_reason': 'end_turn',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final h = await pumpPubulotron(tester, httpClient: client);
    h.secrets.values[AiProvider.anthropic.secretKey] = 'sk-ant-test';
    h.container.invalidate(apiKeysProvider);
    await settle(tester);
    await tapText(tester, 'Création avec l’IA', last: true);
    await tester.tap(find.text('Générer 4 designs avec l’IA'));
    await settle(tester, rounds: 8);
    expect(calls, 1);
    expect(find.text('Néon tech'), findsOneWidget);
    await tapText(tester, 'Ouvrir dans l’atelier');
    expect(
      h.container.read(editorProvider)!.page.elements.single.text,
      'TechCare',
    );
  });

  testWidgets('AI creation without a key shows an actionable error', (
    tester,
  ) async {
    await pumpPubulotron(tester);
    await tapText(tester, 'Création avec l’IA', last: true);
    await tester.tap(find.text('Générer 4 designs avec l’IA'));
    await settle(tester);
    expect(find.textContaining('Aucune clé API'), findsOneWidget);
    // Le générateur hors ligne reste disponible.
    await tester.tap(find.text('Compositions hors ligne (sans IA)'));
    await settle(tester);
    expect(find.text('Composition automatique'), findsWidgets);
  });

  testWidgets('print screen computes the multipose layout', (tester) async {
    final h = await pumpPubulotron(tester);
    await tester.runAsync(
      () => h.services.projects.save(
        Project(name: 'Carte à imprimer', document: richSampleDocument()),
      ),
    );
    await h.container.read(projectsProvider.notifier).refresh();
    await settle(tester);
    await tapText(tester, 'Imprimerie PDF', last: true);
    expect(find.text('Aperçu des feuilles'), findsOneWidget);
    expect(find.textContaining('par feuille'), findsWidgets);
    expect(find.text('Exporter le PDF'), findsOneWidget);
  });

  testWidgets('business profile is created and becomes active', (tester) async {
    final h = await pumpPubulotron(tester);
    await tapText(tester, 'Mon activité', last: true);
    await tapText(tester, 'Charger la fiche d’exemple');
    expect(
      h.container.read(activeProfileProvider)!.name,
      BusinessProfile.example().name,
    );
    await tester.tap(find.byTooltip('Nouvelle fiche'));
    await settle(tester);
    final profiles = await tester.runAsync(h.services.profiles.list);
    expect(profiles, hasLength(2));
  });

  testWidgets('phone layout uses a drawer and bottom tool bar', (tester) async {
    final h = await pumpPubulotron(tester, size: const Size(400, 860));
    expect(find.byType(Drawer), findsNothing);
    await tester.tap(find.byTooltip('Ouvrir le menu de navigation'));
    await settle(tester);
    expect(find.byType(Drawer), findsOneWidget);
    await tapText(tester, 'Nouvelle création', last: true);
    h.container.read(creationFormatProvider);
    await tapText(tester, 'Page blanche');
    expect(find.text('Propriétés'), findsOneWidget);
    expect(find.text('Agent IA'), findsOneWidget);
  });
}
