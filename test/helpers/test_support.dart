import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pubulotron/engine/font_catalog.dart';
import 'package:pubulotron/models/design_document.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/fill.dart';

bool _fontsLoaded = false;

/// Charge les vraies polices de l'application (les tests Flutter utilisent
/// sinon une police de substitution).
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  for (final def in FontCatalog.families) {
    final loader = FontLoader(def.family);
    for (final asset in [
      def.regular,
      def.bold,
      def.italic,
      def.boldItalic,
    ].whereType<String>()) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  _fontsLoaded = true;
}

Directory tempDir(String name) =>
    Directory.systemTemp.createTempSync('pubulotron_$name');

/// Image PNG de test (dégradé + damier), générée sans fichier externe.
Uint8List samplePhotoPng({int width = 240, int height = 160}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final checker = ((x ~/ 20) + (y ~/ 20)).isEven;
      image.setPixelRgb(
        x,
        y,
        (x * 255 ~/ width),
        checker ? 180 : 60,
        (y * 255 ~/ height),
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// Document d'exemple couvrant tous les types d'éléments.
DesignDocument richSampleDocument({String? photoAssetId}) {
  return DesignDocument(
    widthMm: 85,
    heightMm: 55,
    formatId: 'business-card',
    pages: [
      DesignPage(
        name: 'Recto',
        background: Fill.linear(
          const Color(0xFF17213B),
          const Color(0xFF7545FF),
          angle: 35,
        ),
        elements: [
          DesignElement(
            type: ElementType.shape,
            x: 52,
            y: -6,
            width: 40,
            height: 40,
            shape: ShapeKind.ellipse,
            fill: Fill.radial(const Color(0xFFFF6384), const Color(0xFF7545FF)),
          ),
          DesignElement(
            type: ElementType.shape,
            x: 4,
            y: 40,
            width: 30,
            height: 10,
            cornerRadius: 3,
            fill: Fill.solid(const Color(0xFFFFAA45)),
            strokeColor: const Color(0xFFFFFFFF),
            strokeWidth: 0.5,
          ),
          DesignElement(
            type: ElementType.shape,
            x: 70,
            y: 38,
            width: 10,
            height: 10,
            shape: ShapeKind.star,
            fill: Fill.solid(const Color(0xFF24C9C2)),
            rotation: 15,
          ),
          DesignElement(
            type: ElementType.shape,
            x: 40,
            y: 42,
            width: 8,
            height: 8,
            shape: ShapeKind.triangle,
            fill: Fill.solid(const Color(0xFFFFFFFF)),
            opacity: 0.6,
          ),
          DesignElement(
            type: ElementType.text,
            x: 5,
            y: 5,
            width: 50,
            height: 12,
            text: 'TechCare Réparations',
            fontFamily: 'Ubuntu',
            fontSize: 14,
            bold: true,
            color: const Color(0xFFFFFFFF),
          ),
          DesignElement(
            type: ElementType.text,
            x: 5,
            y: 18,
            width: 42,
            height: 14,
            text:
                'Diagnostic, réparation et récupération de données à domicile.',
            fontFamily: 'Liberation Serif',
            italic: true,
            fontSize: 8,
            color: const Color(0xFF24C9C2),
            lineHeight: 1.25,
          ),
          DesignElement(
            type: ElementType.text,
            x: 4,
            y: 40,
            width: 30,
            height: 10,
            text: '06 12 34 56 78',
            fontSize: 8,
            bold: true,
            textAlign: TextAlignH.center,
            verticalAlign: TextAlignV.middle,
            color: const Color(0xFF17213B),
          ),
          DesignElement(
            type: ElementType.text,
            x: 30,
            y: 33,
            width: 25,
            height: 6,
            text: 'À droite',
            fontSize: 7,
            textAlign: TextAlignH.right,
            color: const Color(0xFFFFFFFF),
            rotation: -8,
          ),
          DesignElement(
            type: ElementType.qr,
            x: 60,
            y: 6,
            width: 20,
            height: 20,
            qrData: 'https://techcare-repair.fr',
            fill: Fill.solid(const Color(0xFFFFFFFF)),
            color: const Color(0xFF17213B),
            cornerRadius: 1.5,
          ),
          DesignElement(
            type: ElementType.icon,
            x: 50,
            y: 41,
            width: 8,
            height: 8,
            iconKey: 'phone',
            color: const Color(0xFFFFAA45),
          ),
          if (photoAssetId != null)
            DesignElement(
              type: ElementType.image,
              x: 58,
              y: 30,
              width: 12,
              height: 22,
              assetId: photoAssetId,
              cornerRadius: 2,
              imageFit: ImageFit.cover,
            ),
        ],
      ),
      DesignPage(
        name: 'Verso',
        background: Fill.solid(const Color(0xFFF8F7FC)),
        elements: [
          DesignElement(
            type: ElementType.text,
            x: 0,
            y: 20,
            width: 85,
            height: 15,
            text: 'VERSO',
            fontFamily: 'Ubuntu Condensed',
            fontSize: 30,
            textAlign: TextAlignH.center,
            verticalAlign: TextAlignV.middle,
            color: const Color(0xFF7545FF),
          ),
        ],
      ),
    ],
  );
}
