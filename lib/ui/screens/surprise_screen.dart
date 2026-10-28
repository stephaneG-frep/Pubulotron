import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_client.dart';
import '../../app/providers.dart';
import '../../app/variant_state.dart';
import '../../models/formats.dart';
import '../../variants/variant_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/robopub.dart';

/// « Surprends-moi ! » : l'agent propose des directions artistiques à partir
/// d'une simple description de l'activité, puis crée les variantes choisies.
class SurpriseScreen extends ConsumerStatefulWidget {
  const SurpriseScreen({super.key});

  @override
  ConsumerState<SurpriseScreen> createState() => _SurpriseScreenState();
}

class _SurpriseScreenState extends ConsumerState<SurpriseScreen> {
  late final TextEditingController _activity = TextEditingController(
    text: _defaultActivity(),
  );
  DesignFormat _format = DesignFormats.businessCard;
  int _count = 3;
  List<ArtDirection> _directions = const [];
  final Set<int> _chosen = {};
  bool _loading = false;
  bool _offline = false;
  String? _error;

  String _defaultActivity() {
    final profile = ref.read(activeProfileProvider);
    final activity = profile?.activity.trim() ?? '';
    return activity.isEmpty
        ? 'Je suis artisan menuisier.'
        : 'Je suis ${activity[0].toLowerCase()}${activity.substring(1)}.';
  }

  @override
  void dispose() {
    _activity.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final config = ref.read(aiConfigProvider);
    try {
      final directions = await ref
          .read(servicesProvider)
          .variants
          .suggestDirections(
            config: config,
            activity: _activity.text,
            profile: ref.read(activeProfileProvider),
          );
      setState(() {
        _directions = directions;
        _offline = config == null;
        _chosen
          ..clear()
          ..addAll(List.generate(_count.clamp(1, directions.length), (i) => i));
      });
    } on AiException catch (e) {
      setState(
        () => _error = e.details == null
            ? e.message
            : '${e.message} (${e.details})',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final chosen = [for (final i in _chosen.toList()..sort()) _directions[i]];
    if (chosen.isEmpty) return;
    final notifier = ref.read(variantStudioProvider.notifier)
      ..setFormat(_format)
      ..setBrief(
        '${_activity.text.trim()} Surprends-moi avec ${chosen.length} créations originales au format ${_format.label} (${_format.sizeLabel}).',
      )
      ..setCount(chosen.length.clamp(2, 5));
    ref.read(navigationProvider.notifier).go(AppSection.variants);
    try {
      await notifier.generate(
        directions: chosen,
        useAi: !_offline && ref.read(aiConfigProvider) != null,
      );
    } catch (_) {
      // L'erreur est affichée dans le Studio de variantes.
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(aiConfigProvider);
    return SectionPage(
      title: 'Surprends-moi !',
      subtitle: 'Décrivez votre activité en une phrase : RoboPub imagine plusieurs directions artistiques et crée les designs.',
      icon: Icons.celebration_outlined,
      accent: PubColors.orange,
      children: [
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const RoboPub(size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _activity,
                      decoration: const InputDecoration(
                        labelText: 'Votre activité',
                        hintText: 'Je suis artisan menuisier.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      initialValue: _format.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Format souhaité',
                      ),
                      items: [
                        for (final f in DesignFormats.all)
                          DropdownMenuItem(
                            value: f.id,
                            child: Text(
                              '${f.label} · ${f.sizeLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) =>
                          setState(() => _format = DesignFormats.byId(id!)!),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre de créations',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          for (var n = 2; n <= 5; n++)
                            ButtonSegment(value: n, label: Text('$n')),
                        ],
                        selected: {_count},
                        onSelectionChanged: (s) =>
                            setState(() => _count = s.first),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: PubColors.orange,
                      foregroundColor: PubColors.night,
                    ),
                    onPressed: _loading ? null : _suggest,
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(
                      _directions.isEmpty
                          ? 'Proposer des directions artistiques'
                          : 'Nouvelles idées',
                    ),
                  ),
                ],
              ),
              if (config == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'IA non configurée : directions par défaut et créations hors ligne.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Column(
              children: [
                RoboPub(size: 90, mood: RoboMood.thinking),
                SizedBox(height: 8),
                Text('RoboPub réfléchit…'),
                SizedBox(height: 8),
                LinearProgressIndicator(),
              ],
            ),
          ),
        if (_error != null)
          ErrorBanner(
            message: 'Impossible d’obtenir des directions',
            details: _error,
          ),
        if (_directions.isNotEmpty) ...[
          Text(
            _offline
                ? 'Directions par défaut (hors ligne)'
                : 'Directions proposées — choisissez-en ${_count == 1 ? 'une' : 'jusqu’à $_count'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 280).floor().clamp(1, 3);
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < _directions.length; i++)
                    SizedBox(
                      width: width,
                      child: Card(
                        shape: _chosen.contains(i)
                            ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                                side: const BorderSide(
                                  color: PubColors.orange,
                                  width: 2,
                                ),
                              )
                            : null,
                        child: CheckboxListTile(
                          value: _chosen.contains(i),
                          onChanged: (v) => setState(() {
                            if (v == true && _chosen.length < 5) {
                              _chosen.add(i);
                            } else {
                              _chosen.remove(i);
                            }
                          }),
                          title: Text(
                            _directions[i].name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_directions[i].description),
                              if (_directions[i].palette.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    for (final c in _directions[i].palette)
                                      Container(
                                        width: 22,
                                        height: 22,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: c,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _chosen.length < 2 ? null : _create,
            icon: const Icon(Icons.auto_awesome),
            label: Text('Créer ${_chosen.length} créations (${_format.label})'),
          ),
          if (_chosen.length < 2)
            Text(
              'Choisissez au moins deux directions.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}
