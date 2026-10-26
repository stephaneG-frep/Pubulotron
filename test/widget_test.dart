import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/main.dart';

void main() {
  testWidgets('Pubulotron app loads dashboard shell', (tester) async {
    await tester.pumpWidget(const PubulotronApp());

    expect(find.text('Pubulotron'), findsOneWidget);
    expect(find.text('Nouvelle création'), findsNWidgets(2));
  });

  testWidgets('AI concept opens its own composition in the studio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PubulotronApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Création avec l'IA"));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir ce design'), findsNWidgets(4));

    await tester.tap(find.text('Ouvrir ce design').first);
    await tester.pumpAndSettle();

    expect(find.text('Atelier graphique'), findsWidgets);
    expect(find.text('Je suis 1'), findsOneWidget);
  });

  testWidgets('AI settings expose save and connection test actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PubulotronApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paramètres IA').first);
    await tester.pumpAndSettle();

    expect(find.text('Sauvegarder les paramètres'), findsOneWidget);
    expect(find.text('Tester la connexion'), findsOneWidget);
  });
}
