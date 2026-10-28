import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../models/app_settings.dart';
import '../../models/project.dart';
import '../sections.dart';
import '../theme.dart';
import '../widgets/project_card.dart';
import '../widgets/robopub.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final profile = ref.watch(activeProfileProvider);
    final config = ref.watch(aiConfigProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    final hero = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PubColors.night, Color(0xFF2B1C6B), PubColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: PubColors.violet.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (r) => PubColors.brandGradient.createShader(r),
                child: Text(
                  'Pubulotron',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'La machine à fabriquer des pubs qui ont du génie !',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: PubColors.orange,
                      foregroundColor: PubColors.night,
                    ),
                    onPressed: () => ref
                        .read(navigationProvider.notifier)
                        .go(AppSection.aiCreation),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Créer avec l’IA'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: () => ref
                        .read(navigationProvider.notifier)
                        .go(AppSection.newCreation),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle création'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: PubColors.rose,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => ref
                        .read(navigationProvider.notifier)
                        .go(AppSection.surprise),
                    icon: const Icon(Icons.celebration_outlined),
                    label: const Text('Surprends-moi !'),
                  ),
                ],
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: RoboPub(size: 110)),
                const SizedBox(height: 8),
                text,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const RoboPub(size: 150),
            ],
          );
        },
      ),
    );

    final status = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatusChip(
          icon: Icons.business_center_outlined,
          ok: profile != null,
          label: profile == null
              ? 'Aucune fiche professionnelle'
              : 'Fiche : ${profile.name}',
          onTap: () =>
              ref.read(navigationProvider.notifier).go(AppSection.identity),
        ),
        _StatusChip(
          icon: Icons.auto_awesome,
          ok: config != null,
          label: config == null
              ? 'IA non configurée (fonctions hors ligne disponibles)'
              : 'IA : ${settings.provider.label}',
          onTap: () =>
              ref.read(navigationProvider.notifier).go(AppSection.aiSettings),
        ),
        _StatusChip(
          icon: Icons.folder_outlined,
          ok: true,
          label: '${projects.length} projet${projects.length > 1 ? 's' : ''}',
          onTap: () =>
              ref.read(navigationProvider.notifier).go(AppSection.projects),
        ),
      ],
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            hero,
            const SizedBox(height: 16),
            status,
            const SizedBox(height: 24),
            Text('Rubriques', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 260).floor().clamp(
                  1,
                  4,
                );
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final s in sections.where(
                      (s) => s.section != AppSection.home,
                    ))
                      SizedBox(
                        width: width,
                        child: _SectionTile(info: s),
                      ),
                  ],
                );
              },
            ),
            if (projects.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Projets récents', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              ProjectGrid(
                projects: projects.take(4).toList(),
                onOpen: (p) => openInStudio(ref, p),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends ConsumerWidget {
  const _SectionTile({required this.info});

  final SectionInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () => ref.read(navigationProvider.notifier).go(info.section),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      info.color,
                      Color.lerp(info.color, PubColors.rose, 0.4)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(info.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      info.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: info.offline
                    ? 'Disponible hors ligne'
                    : 'Nécessite Internet et une clé API',
                child: Icon(
                  info.offline
                      ? Icons.offline_pin_outlined
                      : Icons.cloud_outlined,
                  size: 18,
                  color: info.offline ? PubColors.turquoise : PubColors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.ok,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final bool ok;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(
      icon,
      size: 18,
      color: ok ? PubColors.turquoise : PubColors.orange,
    ),
    label: Text(label),
    onPressed: onTap,
  );
}
