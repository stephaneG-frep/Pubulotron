import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_client.dart';
import '../../app/providers.dart';
import '../../core/color_utils.dart';
import '../../layout/brand_kit.dart';
import '../../layout/pack_builder.dart';
import '../../models/business_profile.dart';
import '../../models/project.dart';
import '../export_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/project_card.dart';
import '../widgets/robopub.dart';

class PackScreen extends ConsumerStatefulWidget {
  const PackScreen({super.key});

  @override
  ConsumerState<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends ConsumerState<PackScreen> {
  final _brief = TextEditingController(
    text:
        'Crée toute la publicité de mon activité, avec une offre de bienvenue.',
  );
  final Set<String> _roles = PackSupport.standard.map((s) => s.role).toSet();
  LayoutStyle? _style;
  bool _loading = false;
  AiException? _error;
  BrandKit? _kit;

  @override
  void dispose() {
    _brief.dispose();
    super.dispose();
  }

  Future<void> _generate({required bool useAi}) async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) {
      showMessage(
        context,
        'Renseignez d’abord votre fiche dans « Mon activité ».',
      );
      ref.read(navigationProvider.notifier).go(AppSection.identity);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      BrandKit kit;
      if (useAi) {
        final config = ref.read(aiConfigProvider);
        if (config == null) {
          throw const AiException(
            AiErrorKind.missingKey,
            'Aucune clé API configurée : utilisez la génération hors ligne ou configurez l’IA.',
          );
        }
        kit = await ref
            .read(servicesProvider)
            .aiDesign
            .brandKit(config: config, brief: _brief.text, profile: profile);
      } else {
        kit = BrandKit.fromProfile(
          profile,
          brief: _brief.text,
          layout: _style ?? LayoutStyle.split,
        );
      }
      if (_style != null) kit = kit.copyWith(layout: _style);
      final supports = PackSupport.standard
          .where((s) => _roles.contains(s.role))
          .toList();
      final projects = PackBuilder.build(
        kit: kit,
        profile: profile,
        brief: _brief.text,
        supports: supports,
      );
      await ref.read(projectsProvider.notifier).saveAll(projects);
      if (mounted) {
        setState(() => _kit = kit);
        showMessage(
          context,
          'Pack de ${projects.length} supports créé et enregistré dans « Mes projets ».',
        );
      }
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = AiException(
            AiErrorKind.invalidResponse,
            'Erreur pendant la création du pack.',
            details: '$e',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final packs = <String, List<Project>>{};
    for (final p in projects.where((p) => p.packId != null)) {
      packs.putIfAbsent(p.packId!, () => []).add(p);
    }
    final ordered = packs.values.toList()
      ..sort((a, b) => b.first.createdAt.compareTo(a.first.createdAt));
    for (final pack in ordered) {
      pack.sort(
        (a, b) => PackSupport.standard
            .indexWhere((s) => s.role == a.packRole)
            .compareTo(
              PackSupport.standard.indexWhere((s) => s.role == b.packRole),
            ),
      );
    }

    return SectionPage(
      title: 'Pack publicitaire',
      subtitle: 'Tous vos supports avec la même identité : couleurs, typographies et informations professionnelles.',
      icon: Icons.collections_bookmark_outlined,
      accent: PubColors.rose,
      children: [
        PanelCard(
          title: 'Brief du pack',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _brief,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Ex. : Crée toute la publicité pour mon activité de dépannage informatique.',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                profile == null
                    ? 'Aucune fiche : créez-la dans « Mon activité ».'
                    : 'Fiche utilisée : ${profile.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Text('Supports', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in PackSupport.standard)
                    FilterChip(
                      label: Text('${s.label} (${s.format.sizeLabel})'),
                      selected: _roles.contains(s.role),
                      onSelected: (v) => setState(
                        () => v ? _roles.add(s.role) : _roles.remove(s.role),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Style graphique',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Choisi par l’IA'),
                    selected: _style == null,
                    onSelected: (_) => setState(() => _style = null),
                  ),
                  for (final s in LayoutStyle.values.where(
                    (s) => s != LayoutStyle.menu && s != LayoutStyle.ticket,
                  ))
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _style == s,
                      onSelected: (_) => setState(() => _style = s),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _loading || _roles.isEmpty
                        ? null
                        : () => _generate(useAi: true),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Créer le pack avec l’IA'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading || _roles.isEmpty
                        ? null
                        : () => _generate(useAi: false),
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: const Text('Créer hors ligne (depuis ma fiche)'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Column(
              children: [
                RoboPub(size: 100, mood: RoboMood.thinking),
                LinearProgressIndicator(),
              ],
            ),
          ),
        if (_error != null)
          ErrorBanner(
            message: _error!.message,
            details: _error!.details,
            action: TextButton(
              onPressed: () => ref
                  .read(navigationProvider.notifier)
                  .go(AppSection.aiSettings),
              child: const Text('Paramètres IA'),
            ),
          ),
        if (_kit != null) ...[
          _KitSummary(kit: _kit!, profile: profile),
          const SizedBox(height: 16),
        ],
        if (ordered.isEmpty)
          const EmptyState(
            icon: Icons.collections_bookmark_outlined,
            title: 'Aucun pack pour le moment',
            message: 'Votre premier pack apparaîtra ici.',
          )
        else
          for (final pack in ordered) ...[
            const SizedBox(height: 8),
            PanelCard(
              title:
                  'Pack du ${formatDate(pack.first.createdAt)} — ${pack.length} supports',
              trailing: Wrap(
                spacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ExportActions.exportZip(
                      context,
                      ref,
                      pack,
                      'Pack_${pack.first.name.split(' — ').first}',
                    ),
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: const Text('Exporter (ZIP)'),
                  ),
                ],
              ),
              child: ProjectGrid(
                projects: pack,
                onOpen: (p) => openInStudio(ref, p),
              ),
            ),
          ],
      ],
    );
  }
}

class _KitSummary extends StatelessWidget {
  const _KitSummary({required this.kit, required this.profile});

  final BrandKit kit;
  final BusinessProfile? profile;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title:
          'Identité du pack (${kit.source == 'local' ? 'générée hors ligne' : 'proposée par ${kit.source}'})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kit.palette)
                Tooltip(
                  message: colorToHex(c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            kit.headline,
            style: TextStyle(
              fontFamily: kit.headingFont,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(kit.slogan, style: TextStyle(fontFamily: kit.bodyFont)),
          const SizedBox(height: 6),
          Text(
            'Typographies : ${kit.headingFont} / ${kit.bodyFont} · Style : ${kit.layout.label}${kit.offer.isEmpty ? '' : ' · Offre : ${kit.offer}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (kit.rationale.isNotEmpty)
            Text(
              kit.rationale,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}
