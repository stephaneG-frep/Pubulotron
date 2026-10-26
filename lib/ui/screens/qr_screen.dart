import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/creation_state.dart';
import '../../app/providers.dart';
import '../../editor/element_factory.dart';
import '../../engine/qr_payload.dart';
import '../../models/design_document.dart';
import '../../models/design_element.dart';
import '../../models/fill.dart';
import '../editor/qr_dialog.dart';
import '../export_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';

class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});

  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  QrChoice? _choice;

  /// Document carré de [sizeMm] contenant uniquement le QR code.
  DesignDocument _qrDocument(String data, double sizeMm) => DesignDocument(
    widthMm: sizeMm,
    heightMm: sizeMm,
    pages: [
      DesignPage(
        background: Fill.solid(const Color(0xFFFFFFFF)),
        elements: [
          DesignElement(
            type: ElementType.qr,
            name: 'QR code',
            qrData: data,
            x: 0,
            y: 0,
            width: sizeMm,
            height: sizeMm,
            fill: Fill.solid(const Color(0xFFFFFFFF)),
          ),
        ],
      ),
    ],
  );

  Future<void> _exportPng(QrChoice choice) async {
    final bytes = await ref
        .read(servicesProvider)
        .raster
        .export(_qrDocument(choice.data, 40), dpi: 600);
    if (mounted) {
      await ExportActions.deliver(
        context,
        ref,
        bytes,
        'qr_${choice.kind.name}.png',
        'image/png',
      );
    }
  }

  Future<void> _exportSvg(QrChoice choice) async {
    final svg = QrPayload.svg(choice.data, size: 400, color: 0x17213B);
    if (mounted) {
      await ExportActions.deliver(
        context,
        ref,
        Uint8List.fromList(utf8.encode(svg)),
        'qr_${choice.kind.name}.svg',
        'image/svg+xml',
      );
    }
  }

  Future<void> _exportPdf(QrChoice choice) async {
    final result = await ref
        .read(servicesProvider)
        .pdf
        .exportDocument(_qrDocument(choice.data, 40), title: 'QR code');
    if (mounted) {
      await ExportActions.deliver(
        context,
        ref,
        result.bytes,
        'qr_${choice.kind.name}.pdf',
        'application/pdf',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    final editor = ref.watch(editorProvider);
    final choice = _choice;
    return SectionPage(
      title: 'Générateur de QR codes',
      subtitle: 'Site, réservation, coordonnées, portfolio, catalogue ou réseau social. Fonctionne hors ligne.',
      icon: Icons.qr_code_2,
      accent: PubColors.night,
      maxWidth: 800,
      children: [
        PanelCard(
          child: QrForm(
            profile: profile,
            onChanged: (c) => setState(() => _choice = c),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: choice == null || editor == null
                  ? null
                  : () {
                      editor.addElement(
                        ElementFactory(editor.pageSize)
                            .qr(choice.data, name: 'QR ${choice.kind.label}'),
                      );
                      ref
                          .read(navigationProvider.notifier)
                          .go(AppSection.studio);
                    },
              icon: const Icon(Icons.add_box_outlined),
              label: Text(
                editor == null
                    ? 'Aucune création ouverte'
                    : 'Insérer dans « ${editor.project.name} »',
              ),
            ),
            OutlinedButton.icon(
              onPressed: choice == null
                  ? null
                  : () => createAndOpen(
                      ref,
                      name: 'Étiquette QR — ${choice.kind.label}',
                      document: _labelDocument(choice),
                    ),
              icon: const Icon(Icons.label_outline),
              label: const Text('Créer une étiquette avec ce QR'),
            ),
            OutlinedButton.icon(
              onPressed: choice == null ? null : () => _exportPng(choice),
              icon: const Icon(Icons.image_outlined),
              label: const Text('PNG'),
            ),
            OutlinedButton.icon(
              onPressed: choice == null ? null : () => _exportSvg(choice),
              icon: const Icon(Icons.polyline),
              label: const Text('SVG'),
            ),
            OutlinedButton.icon(
              onPressed: choice == null ? null : () => _exportPdf(choice),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF'),
            ),
          ],
        ),
      ],
    );
  }

  DesignDocument _labelDocument(QrChoice choice) {
    const size = Size(70, 37);
    final qr = ElementFactory(size)
        .qr(choice.data)
        .copyWith(x: 3, y: 3, width: 31, height: 31);
    return DesignDocument(
      widthMm: 70,
      heightMm: 37,
      formatId: 'label-rect',
      pages: [
        DesignPage(
          background: Fill.solid(const Color(0xFFFFFFFF)),
          elements: [
            qr,
            DesignElement(
              type: ElementType.text,
              name: 'Légende',
              text: 'Scannez-moi !\n${choice.kind.label}',
              x: 37,
              y: 8,
              width: 30,
              height: 21,
              fontFamily: 'Ubuntu',
              fontSize: 10,
              bold: true,
              color: PubColors.night,
              verticalAlign: TextAlignV.middle,
            ),
          ],
        ),
      ],
    );
  }
}
