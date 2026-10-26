import 'package:flutter/material.dart';

import '../../engine/qr_payload.dart';
import '../../models/business_profile.dart';
import '../../models/design_document.dart';
import '../../models/design_element.dart';
import '../../models/fill.dart';
import '../../engine/flutter_canvas.dart';

/// Résultat du générateur : contenu et libellé.
class QrChoice {
  const QrChoice(this.kind, this.data);
  final QrKind kind;
  final String data;
}

/// Formulaire de génération de QR code, réutilisé par l'atelier et la rubrique QR.
class QrForm extends StatefulWidget {
  const QrForm({
    super.key,
    required this.profile,
    required this.onChanged,
    this.initialKind = QrKind.website,
  });

  final BusinessProfile? profile;
  final ValueChanged<QrChoice?> onChanged;
  final QrKind initialKind;

  @override
  State<QrForm> createState() => _QrFormState();
}

class _QrFormState extends State<QrForm> {
  late QrKind _kind = widget.initialKind;
  final _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    _custom.text = _defaultFor(_kind);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String _defaultFor(QrKind kind) {
    final p = widget.profile;
    if (p == null || kind == QrKind.contact || kind == QrKind.text) return '';
    return QrPayload.forKind(kind, p);
  }

  String get _data {
    if (_kind == QrKind.contact) {
      final p = widget.profile;
      return p == null ? '' : QrPayload.vCard(p);
    }
    final text = _custom.text.trim();
    return _kind == QrKind.text ? text : QrPayload.normalizeUrl(text);
  }

  void _emit() {
    final data = _data;
    widget.onChanged(
      QrPayload.isEncodable(data) ? QrChoice(_kind, data) : null,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final valid = QrPayload.isEncodable(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final kind in QrKind.values)
              ChoiceChip(
                label: Text(kind.label),
                selected: _kind == kind,
                onSelected: (_) {
                  _kind = kind;
                  _custom.text = _defaultFor(kind);
                  _emit();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_kind == QrKind.contact)
          widget.profile == null
              ? const Text(
                  'Renseignez d’abord votre fiche dans « Mon activité ».',
                )
              : Text(
                  'Carte de visite électronique (vCard) de « ${widget.profile!.name} » : nom, téléphone, e-mail, site et adresse.',
                )
        else
          TextField(
            controller: _custom,
            maxLines: _kind == QrKind.text ? 3 : 1,
            decoration: InputDecoration(
              labelText: _kind == QrKind.text ? 'Texte' : 'Adresse (URL)',
              hintText: _kind == QrKind.text ? 'Votre message' : 'https://…',
            ),
            onChanged: (_) => _emit(),
          ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 180,
            child: valid
                ? DesignPageView(
                    shadow: false,
                    document: DesignDocument(
                      widthMm: 30,
                      heightMm: 30,
                      pages: [
                        DesignPage(
                          elements: [
                            DesignElement(
                              type: ElementType.qr,
                              qrData: data,
                              x: 0,
                              y: 0,
                              width: 30,
                              height: 30,
                              fill: Fill.solid(const Color(0xFFFFFFFF)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Contenu à saisir',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (valid)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              data.length > 80 ? '${data.substring(0, 80)}…' : data,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

Future<QrChoice?> showQrDialog(BuildContext context, BusinessProfile? profile) {
  QrChoice? current;
  return showDialog<QrChoice>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Ajouter un QR code'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: QrForm(
              profile: profile,
              onChanged: (c) => setState(() => current = c),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: current == null
                ? null
                : () => Navigator.pop(context, current),
            child: const Text('Insérer'),
          ),
        ],
      ),
    ),
  );
}
