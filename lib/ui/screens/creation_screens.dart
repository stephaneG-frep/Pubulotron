import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_client.dart';
import '../../app/creation_state.dart';
import '../../app/providers.dart';
import '../../models/app_settings.dart';
import '../../models/design_document.dart';
import '../../models/fill.dart';
import '../../models/formats.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/project_card.dart';
import '../widgets/robopub.dart';

/// Sélecteur de format, groupé par famille, avec format personnalisé.
class FormatPicker extends ConsumerWidget {
  const FormatPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(creationFormatProvider);
    final groups = <String, List<DesignFormat>>{};
    for (final f in DesignFormats.all) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in entry.value)
                ChoiceChip(
                  avatar: _FormatGlyph(format: f),
                  label: Text('${f.label} · ${f.sizeLabel}'),
                  selected: selected.id == f.id,
                  onSelected: (_) =>
                      ref.read(creationFormatProvider.notifier).set(f),
                ),
              if (entry.key == groups.keys.last)
                ActionChip(
                  avatar: const Icon(Icons.straighten, size: 18),
                  label: Text(
                    selected.id == 'custom'
                        ? 'Personnalisé · ${selected.sizeLabel}'
                        : 'Format personnalisé…',
                  ),
                  onPressed: () async {
                    final format = await _customFormatDialog(context);
                    if (format != null) {
                      ref.read(creationFormatProvider.notifier).set(format);
                    }
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  static Future<DesignFormat?> _customFormatDialog(BuildContext context) {
    var w = 100.0;
    var h = 150.0;
    return showDialog<DesignFormat>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Format personnalisé'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            NumberField(
              label: 'Largeur',
              suffix: 'mm',
              value: w,
              min: 10,
              max: 2000,
              onChanged: (v) => w = v,
            ),
            NumberField(
              label: 'Hauteur',
              suffix: 'mm',
              value: h,
              min: 10,
              max: 2000,
              onChanged: (v) => h = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(
                context,
                DesignFormat(
                  id: 'custom',
                  label: 'Format personnalisé',
                  group: 'Personnalisé',
                  widthMm: w,
                  heightMm: h,
                ),
              );
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}

class _FormatGlyph extends StatelessWidget {
  const _FormatGlyph({required this.format});

  final DesignFormat format;

  @override
  Widget build(BuildContext context) {
    final ratio = format.widthMm / format.heightMm;
    final w = ratio >= 1 ? 18.0 : 18.0 * ratio;
    final h = ratio >= 1 ? 18.0 / ratio : 18.0;
    return SizedBox.square(
      dimension: 18,
      child: Center(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class NewCreationScreen extends ConsumerWidget {
  const NewCreationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(creationFormatProvider);
    Widget action(
      IconData icon,
      String title,
      String text,
      Color color,
      VoidCallback onTap,
    ) => SizedBox(
      width: 300,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  child: Icon(icon),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
    return SectionPage(
      title: 'Nouvelle création',
      subtitle: 'Choisissez un format, puis partez d’une page blanche, d’un modèle ou d’une proposition de l’IA.',
      icon: Icons.add_box_outlined,
      children: [
        const PanelCard(title: '1. Format', child: FormatPicker()),
        const SizedBox(height: 16),
        Text(
          '2. Point de départ — ${format.label} (${format.sizeLabel})',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            action(
              Icons.note_add_outlined,
              'Page blanche',
              'Un document vierge au bon format, à composer librement dans l’atelier.',
              PubColors.night,
              () {
                createAndOpen(
                  ref,
                  name: '${format.label} sans titre',
                  document: DesignDocument(
                    widthMm: format.widthMm,
                    heightMm: format.heightMm,
                    formatId: format.id,
                    pages: [
                      DesignPage(
                        background: Fill.solid(const Color(0xFFFFFFFF)),
                      ),
                    ],
                  ),
                );
              },
            ),
            action(
              Icons.auto_awesome,
              'Avec l’IA',
              'Décrivez votre besoin : l’agent propose quatre designs éditables.',
              PubColors.violet,
              () => ref
                  .read(navigationProvider.notifier)
                  .go(AppSection.aiCreation),
            ),
            action(
              Icons.grid_view_rounded,
              'À partir d’un modèle',
              'Plus de vingt modèles par métier, personnalisables avec votre fiche.',
              PubColors.turquoise,
              () => ref
                  .read(navigationProvider.notifier)
                  .go(AppSection.templates),
            ),
            action(
              Icons.collections_bookmark_outlined,
              'Pack publicitaire',
              'Carte, flyer, affiche, publication et story assortis.',
              PubColors.rose,
              () => ref.read(navigationProvider.notifier).go(AppSection.pack),
            ),
          ],
        ),
      ],
    );
  }
}

class AiCreationScreen extends ConsumerStatefulWidget {
  const AiCreationScreen({super.key});

  @override
  ConsumerState<AiCreationScreen> createState() => _AiCreationScreenState();
}

class _AiCreationScreenState extends ConsumerState<AiCreationScreen> {
  late final TextEditingController _brief = TextEditingController(
    text: ref.read(aiCreationProvider).brief,
  );

  @override
  void dispose() {
    _brief.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiCreationProvider);
    final notifier = ref.read(aiCreationProvider.notifier);
    final config = ref.watch(aiConfigProvider);
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(activeProfileProvider);
    final format = ref.watch(creationFormatProvider);
    final error = state.error;

    return SectionPage(
      title: 'Création avec l’IA',
      subtitle: 'L’agent analyse votre activité et propose quatre compositions différentes, entièrement modifiables.',
      icon: Icons.auto_awesome,
      children: [
        PanelCard(
          title: 'Votre demande',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _brief,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Ex. : Crée-moi un flyer A5 pour mon activité de jardinage, couleurs vertes, promotion de 15 %.',
                ),
                onChanged: notifier.setBrief,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: const Icon(Icons.aspect_ratio, size: 18),
                    label: Text('${format.label} · ${format.sizeLabel}'),
                  ),
                  Chip(
                    avatar: const Icon(
                      Icons.business_center_outlined,
                      size: 18,
                    ),
                    label: Text(
                      profile == null
                          ? 'Aucune fiche (contenu générique)'
                          : 'Fiche : ${profile.name}',
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      config == null
                          ? Icons.cloud_off
                          : Icons.cloud_done_outlined,
                      size: 18,
                      color: config == null
                          ? Theme.of(context).colorScheme.error
                          : PubColors.turquoise,
                    ),
                    label: Text(
                      config == null
                          ? 'IA non configurée'
                          : '${settings.provider.label} · ${config.model}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Changer de format'),
                children: const [FormatPicker()],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: state.loading ? null : notifier.generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      state.proposals.isEmpty
                          ? 'Générer 4 designs avec l’IA'
                          : 'Régénérer avec l’IA',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.loading ? null : notifier.generateOffline,
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: const Text('Compositions hors ligne (sans IA)'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.loading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  RoboPub(size: 110, mood: RoboMood.thinking),
                  SizedBox(height: 8),
                  Text(
                    'RoboPub dessine vos propositions… (cela peut prendre une à deux minutes)',
                  ),
                  SizedBox(height: 12),
                  LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        if (error != null)
          ErrorBanner(
            message: error.message,
            details: error.details,
            action:
                error.kind == AiErrorKind.missingKey ||
                    error.kind == AiErrorKind.unauthorized ||
                    error.kind == AiErrorKind.modelNotFound
                ? TextButton(
                    onPressed: () => ref
                        .read(navigationProvider.notifier)
                        .go(AppSection.aiSettings),
                    child: const Text('Paramètres IA'),
                  )
                : TextButton(
                    onPressed: notifier.generate,
                    child: const Text('Réessayer'),
                  ),
          ),
        if (state.proposals.isNotEmpty) ...[
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1000
                  ? 4
                  : constraints.maxWidth > 640
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final p in state.proposals)
                    SizedBox(
                      width: width,
                      child: _ProposalCard(proposal: p, brief: state.brief),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ProposalCard extends ConsumerWidget {
  const _ProposalCard({required this.proposal, required this.brief});

  final DesignProposal proposal;
  final String brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = proposal.document;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocumentThumbnail(document: doc, height: 200),
          if (doc.isDuplex)
            DocumentThumbnail(document: doc, height: 110, pageIndex: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal.title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (proposal.subtitle.isNotEmpty)
                  Text(
                    proposal.subtitle,
                    style: const TextStyle(
                      color: PubColors.rose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  proposal.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      proposal.offline
                          ? Icons.offline_bolt_outlined
                          : Icons.auto_awesome,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        proposal.source,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                if (proposal.warnings.isNotEmpty)
                  Tooltip(
                    message: proposal.warnings.join('\n'),
                    child: Text(
                      '${proposal.warnings.length} correction(s) automatique(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PubColors.orange,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => createAndOpen(
                    ref,
                    name: proposal.title,
                    document: doc,
                    brief: brief,
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Ouvrir dans l’atelier'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
