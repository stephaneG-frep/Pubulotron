import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../engine/flutter_canvas.dart';
import '../../engine/image_cache.dart';
import '../../models/business_profile.dart';
import '../../models/design_document.dart';
import '../../models/design_element.dart';
import '../theme.dart';
import '../widgets/color_picker.dart';
import '../widgets/common.dart';

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  String? _editingId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profilesProvider);
    final profiles = async.value ?? const <BusinessProfile>[];
    final active = ref.watch(activeProfileProvider);
    final editing = profiles
        .where((p) => p.id == (_editingId ?? active?.id))
        .firstOrNull;

    final list = PanelCard(
      title: 'Mes fiches',
      trailing: IconButton(
        tooltip: 'Nouvelle fiche',
        icon: const Icon(Icons.add),
        onPressed: () async {
          final profile = BusinessProfile(name: 'Nouvelle activité');
          await ref.read(profilesProvider.notifier).save(profile);
          setState(() => _editingId = profile.id);
        },
      ),
      child: Column(
        children: [
          if (profiles.isEmpty) ...[
            const Text('Aucune fiche. Créez-en une, ou partez de l’exemple.'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final example = BusinessProfile.example();
                await ref.read(profilesProvider.notifier).save(example);
                await ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(activeProfileId: example.id));
              },
              child: const Text('Charger la fiche d’exemple'),
            ),
          ],
          for (final p in profiles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: p.id == editing?.id,
              leading: CircleAvatar(
                backgroundColor: p.brandColors.isEmpty
                    ? PubColors.violet
                    : p.brandColors.first,
                foregroundColor: Colors.white,
                child: Text(
                  p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(),
                ),
              ),
              title: Text(p.name),
              subtitle: Text(
                p.id == active?.id
                    ? 'Fiche active'
                    : (p.activity.isEmpty ? '—' : p.activity),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: p.id == active?.id
                  ? const Icon(Icons.check_circle, color: PubColors.turquoise)
                  : TextButton(
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .update((s) => s.copyWith(activeProfileId: p.id)),
                      child: const Text('Activer'),
                    ),
              onTap: () => setState(() => _editingId = p.id),
            ),
        ],
      ),
    );

    return SectionPage(
      title: 'Mon activité professionnelle',
      subtitle: 'Vos informations sont insérées automatiquement dans les modèles, l’IA, les QR codes et les packs.',
      icon: Icons.business_center_outlined,
      accent: PubColors.turquoise,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final form = editing == null
                ? const SizedBox.shrink()
                : _ProfileForm(
                    key: ValueKey(editing.id),
                    profile: editing,
                    onDeleted: () => setState(() => _editingId = null),
                  );
            if (constraints.maxWidth < 900) {
              return Column(children: [list, const SizedBox(height: 16), form]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 320, child: list),
                const SizedBox(width: 16),
                Expanded(child: form),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({
    super.key,
    required this.profile,
    required this.onDeleted,
  });

  final BusinessProfile profile;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final Map<String, TextEditingController> _c = {
    'name': TextEditingController(text: widget.profile.name),
    'activity': TextEditingController(text: widget.profile.activity),
    'contactName': TextEditingController(text: widget.profile.contactName),
    'jobTitle': TextEditingController(text: widget.profile.jobTitle),
    'slogan': TextEditingController(text: widget.profile.slogan),
    'description': TextEditingController(text: widget.profile.description),
    'services': TextEditingController(text: widget.profile.services.join('\n')),
    'address': TextEditingController(text: widget.profile.address),
    'phone': TextEditingController(text: widget.profile.phone),
    'email': TextEditingController(text: widget.profile.email),
    'website': TextEditingController(text: widget.profile.website),
    'bookingUrl': TextEditingController(text: widget.profile.bookingUrl),
    'portfolioUrl': TextEditingController(text: widget.profile.portfolioUrl),
    'catalogUrl': TextEditingController(text: widget.profile.catalogUrl),
    'hours': TextEditingController(text: widget.profile.hours),
  };
  late List<Color> _colors = [...widget.profile.brandColors];
  late List<SocialLink> _socials = [...widget.profile.socials];
  late String? _logo = widget.profile.logoAssetId;
  bool _dirty = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  BusinessProfile get _current => widget.profile.copyWith(
    name: _c['name']!.text.trim().isEmpty
        ? 'Mon activité'
        : _c['name']!.text.trim(),
    activity: _c['activity']!.text.trim(),
    contactName: _c['contactName']!.text.trim(),
    jobTitle: _c['jobTitle']!.text.trim(),
    slogan: _c['slogan']!.text.trim(),
    description: _c['description']!.text.trim(),
    services: _c['services']!.text
        .split(RegExp(r'[\n;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    address: _c['address']!.text.trim(),
    phone: _c['phone']!.text.trim(),
    email: _c['email']!.text.trim(),
    website: _c['website']!.text.trim(),
    bookingUrl: _c['bookingUrl']!.text.trim(),
    portfolioUrl: _c['portfolioUrl']!.text.trim(),
    catalogUrl: _c['catalogUrl']!.text.trim(),
    hours: _c['hours']!.text.trim(),
    brandColors: _colors,
    socials: _socials.where((s) => s.url.trim().isNotEmpty).toList(),
    logoAssetId: _logo,
  );

  Future<void> _save() async {
    final email = _c['email']!.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      showMessage(context, 'Adresse e-mail invalide.', error: true);
      return;
    }
    await ref.read(profilesProvider.notifier).save(_current);
    if (ref.read(settingsProvider).activeProfileId == null) {
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(activeProfileId: widget.profile.id));
    }
    setState(() => _dirty = false);
    if (mounted) {
      showMessage(context, 'Fiche « ${_current.name} » enregistrée.');
    }
  }

  Future<void> _pickLogo() async {
    final services = ref.read(servicesProvider);
    try {
      final picked = await services.files.pick(images: true);
      if (picked == null) return;
      final image = await DesignImageCache.decode(
        picked.bytes,
        maxDimension: 256,
      );
      image.dispose();
      final id = await services.assets.importBytes(
        picked.bytes,
        fileName: picked.name,
      );
      setState(() {
        _logo = id;
        _dirty = true;
      });
    } catch (e) {
      if (mounted) showMessage(context, 'Image illisible : $e', error: true);
    }
  }

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    String? hint,
    TextInputType? keyboard,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _c[key],
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      onChanged: (_) {
        if (!_dirty) setState(() => _dirty = true);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(servicesProvider).images;
    final twoCols = MediaQuery.sizeOf(context).width > 1200;
    Widget pair(Widget a, Widget b) => twoCols
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 10),
              Expanded(child: b),
            ],
          )
        : Column(children: [a, b]);
    return PanelCard(
      title: 'Fiche « ${widget.profile.name} »',
      trailing: Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: 'Supprimer la fiche',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirm(
                context,
                title: 'Supprimer cette fiche ?',
                message: 'Les créations existantes ne sont pas modifiées.',
                destructive: true,
                confirmLabel: 'Supprimer',
              )) {
                return;
              }
              await ref
                  .read(profilesProvider.notifier)
                  .delete(widget.profile.id);
              widget.onDeleted();
            },
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(_dirty ? 'Enregistrer*' : 'Enregistrer'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(8),
                child: _logo == null
                    ? const Icon(Icons.image_outlined, size: 36)
                    : DesignPageView(
                        shadow: false,
                        images: images,
                        showPlaceholders: false,
                        document: DesignDocument(
                          widthMm: 40,
                          heightMm: 40,
                          pages: [
                            DesignPage(
                              background: _transparentWhite,
                              elements: [
                                DesignElement(
                                  type: ElementType.image,
                                  assetId: _logo,
                                  imageFit: ImageFit.contain,
                                  x: 0,
                                  y: 0,
                                  width: 40,
                                  height: 40,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.upload),
                      label: Text(
                        _logo == null ? 'Importer un logo' : 'Changer le logo',
                      ),
                    ),
                    if (_logo != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _logo = null;
                          _dirty = true;
                        }),
                        child: const Text('Retirer'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          pair(
            _field('name', 'Nom de l’activité', icon: Icons.storefront),
            _field(
              'activity',
              'Secteur d’activité',
              hint: 'Ex. : réparation informatique',
            ),
          ),
          pair(
            _field('contactName', 'Nom du contact', icon: Icons.person_outline),
            _field('jobTitle', 'Fonction'),
          ),
          _field('slogan', 'Slogan', icon: Icons.format_quote),
          _field('description', 'Description', lines: 2),
          _field('services', 'Prestations (une par ligne)', lines: 3),
          pair(
            _field(
              'phone',
              'Téléphone',
              keyboard: TextInputType.phone,
              icon: Icons.phone,
            ),
            _field(
              'email',
              'E-mail',
              keyboard: TextInputType.emailAddress,
              icon: Icons.email_outlined,
            ),
          ),
          pair(
            _field(
              'website',
              'Site internet',
              keyboard: TextInputType.url,
              icon: Icons.language,
            ),
            _field('address', 'Adresse', icon: Icons.place_outlined),
          ),
          _field('hours', 'Horaires', icon: Icons.schedule),
          Text(
            'Liens pour les QR codes',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          pair(
            _field(
              'bookingUrl',
              'Page de réservation',
              keyboard: TextInputType.url,
            ),
            _field('portfolioUrl', 'Portfolio', keyboard: TextInputType.url),
          ),
          _field('catalogUrl', 'Catalogue', keyboard: TextInputType.url),
          Text(
            'Réseaux sociaux',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _socials.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: TextFormField(
                      initialValue: _socials[i].network,
                      decoration: const InputDecoration(labelText: 'Réseau'),
                      onChanged: (v) => setState(() {
                        _socials[i] = SocialLink(
                          network: v,
                          url: _socials[i].url,
                        );
                        _dirty = true;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _socials[i].url,
                      decoration: const InputDecoration(labelText: 'Adresse'),
                      onChanged: (v) => setState(() {
                        _socials[i] = SocialLink(
                          network: _socials[i].network,
                          url: v,
                        );
                        _dirty = true;
                      }),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retirer',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _socials = [..._socials]..removeAt(i);
                      _dirty = true;
                    }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _socials = [
                  ..._socials,
                  const SocialLink(network: 'Instagram', url: ''),
                ],
              ),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un réseau'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Couleurs de marque',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < _colors.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ColorSwatchButton(
                      color: _colors[i],
                      onChanged: (c) => setState(() {
                        _colors = [..._colors]..[i] = c;
                        _dirty = true;
                      }),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      child: InkWell(
                        onTap: () => setState(() {
                          _colors = [..._colors]..removeAt(i);
                          _dirty = true;
                        }),
                        child: const CircleAvatar(
                          radius: 9,
                          child: Icon(Icons.close, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_colors.length < 6)
                OutlinedButton.icon(
                  onPressed: () async {
                    final c = await showColorPicker(
                      context,
                      initial: PubColors.violet,
                    );
                    if (c != null) {
                      setState(() {
                        _colors = [..._colors, c];
                        _dirty = true;
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Couleur'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer la fiche'),
          ),
        ],
      ),
    );
  }
}

final _transparentWhite = DesignPage().background.withPrimary(
  const Color(0x00FFFFFF),
);
