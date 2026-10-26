import 'package:flutter/material.dart';

import '../../core/color_utils.dart';
import '../theme.dart';

const List<Color> _swatches = [
  PubColors.violet,
  PubColors.rose,
  PubColors.orange,
  PubColors.turquoise,
  PubColors.night,
  PubColors.white,
  Color(0xFF000000),
  Color(0xFF3A3A3A),
  Color(0xFF8A8A8A),
  Color(0xFFD9D9D9),
  Color(0xFFFFFFFF),
  Color(0xFFD7263D),
  Color(0xFFFF7A1A),
  Color(0xFFFFD166),
  Color(0xFF2F8F4E),
  Color(0xFFA8D672),
  Color(0xFF1E6BFF),
  Color(0xFF0A1F44),
  Color(0xFF8A4B2A),
  Color(0xFFC9A646),
  Color(0xFFE83E8C),
];

/// Pastille de couleur cliquable ouvrant le sélecteur.
class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    super.key,
    required this.color,
    required this.onChanged,
    this.label,
    this.brandColors = const [],
    this.allowTransparent = false,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final String? label;
  final List<Color> brandColors;
  final bool allowTransparent;

  @override
  Widget build(BuildContext context) {
    final swatch = Tooltip(
      message: '${label ?? 'Couleur'} ${colorToHex(color)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showColorPicker(
            context,
            initial: color,
            brandColors: brandColors,
            allowTransparent: allowTransparent,
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1.2,
            ),
          ),
          child: color.a < 0.05 ? const Icon(Icons.block, size: 18) : null,
        ),
      ),
    );
    if (label == null) return swatch;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(height: 4),
        Text(label!, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

Future<Color?> showColorPicker(
  BuildContext context, {
  required Color initial,
  List<Color> brandColors = const [],
  bool allowTransparent = false,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(
      initial: initial,
      brandColors: brandColors,
      allowTransparent: allowTransparent,
    ),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.initial,
    required this.brandColors,
    required this.allowTransparent,
  });

  final Color initial;
  final List<Color> brandColors;
  final bool allowTransparent;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial.withValues(alpha: 1));
  late double _alpha = widget.initial.a;
  late final TextEditingController _hex = TextEditingController(
    text: colorToHex(widget.initial),
  );

  Color get _color => _hsv.toColor().withValues(alpha: _alpha);

  void _set(Color c, {bool updateHex = true}) {
    setState(() {
      _hsv = HSVColor.fromColor(c.withValues(alpha: 1));
      _alpha = c.a;
      if (updateHex) _hex.text = colorToHex(c);
    });
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Widget _grid(String title, List<Color> colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in colors)
            InkWell(
              onTap: () => _set(c),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Couleur'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.brandColors.isNotEmpty)
                _grid('Couleurs de marque', widget.brandColors),
              _grid('Nuancier', _swatches),
              Text('Teinte', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: _hsv.hue,
                max: 360,
                onChanged: (v) => setState(() {
                  _hsv = _hsv.withHue(v);
                  _hex.text = colorToHex(_color);
                }),
              ),
              Text('Saturation', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: _hsv.saturation,
                onChanged: (v) => setState(() {
                  _hsv = _hsv.withSaturation(v);
                  _hex.text = colorToHex(_color);
                }),
              ),
              Text('Luminosité', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: _hsv.value,
                onChanged: (v) => setState(() {
                  _hsv = _hsv.withValue(v);
                  _hex.text = colorToHex(_color);
                }),
              ),
              if (widget.allowTransparent) ...[
                Text(
                  'Opacité de la couleur',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Slider(
                  value: _alpha,
                  onChanged: (v) => setState(() => _alpha = v),
                ),
              ],
              TextField(
                controller: _hex,
                decoration: const InputDecoration(
                  labelText: 'Code hexadécimal',
                  hintText: '#7545FF',
                ),
                onChanged: (v) {
                  final parsed = parseHexColor(v);
                  if (parsed != null) {
                    _set(parsed.withValues(alpha: _alpha), updateHex: false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}
