import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/history_service.dart';
import '../models/formats.dart';
import '../models/project.dart';
import '../variants/variant_service.dart';
import 'providers.dart';

class VariantStudioState {
  const VariantStudioState({
    this.brief = 'Crée des cartes de visite différentes pour mon activité.',
    this.format = DesignFormats.businessCard,
    this.count = 5,
    this.running = false,
    this.progress,
    this.failures = const [],
    this.groupId,
    this.offline = false,
  });

  final String brief;
  final DesignFormat format;

  /// Nombre de variantes demandées (2 à 5).
  final int count;
  final bool running;
  final VariantProgress? progress;
  final List<String> failures;

  /// Groupe affiché (le dernier généré par défaut).
  final String? groupId;

  /// Dernière génération faite sans IA.
  final bool offline;

  VariantStudioState copyWith({
    String? brief,
    DesignFormat? format,
    int? count,
    bool? running,
    VariantProgress? progress,
    List<String>? failures,
    String? groupId,
    bool? offline,
  }) => VariantStudioState(
    brief: brief ?? this.brief,
    format: format ?? this.format,
    count: count ?? this.count,
    running: running ?? this.running,
    progress: progress ?? this.progress,
    failures: failures ?? this.failures,
    groupId: groupId ?? this.groupId,
    offline: offline ?? this.offline,
  );
}

class VariantStudioNotifier extends Notifier<VariantStudioState> {
  @override
  VariantStudioState build() => const VariantStudioState();

  void setBrief(String v) => state = state.copyWith(brief: v);

  void setFormat(DesignFormat f) => state = state.copyWith(format: f);

  void setCount(int n) => state = state.copyWith(count: n.clamp(2, 5));

  void showGroup(String id) => state = state.copyWith(groupId: id);

  /// Génère des variantes ; chacune est enregistrée dès qu'elle est prête.
  Future<VariantRunResult> generate({
    List<ArtDirection>? directions,
    String? groupId,
    bool useAi = true,
  }) async {
    final services = ref.read(servicesProvider);
    final config = useAi ? ref.read(aiConfigProvider) : null;
    final chosen =
        directions ?? ArtDirection.defaults.take(state.count).toList();
    final all = ref.read(projectsProvider).value ?? const <Project>[];
    final existing = groupId == null
        ? const <Project>[]
        : all.where((p) => p.variantGroupId == groupId).toList();
    state = state.copyWith(
      running: true,
      failures: const [],
      offline: config == null,
    );
    String? createdGroup = groupId;
    try {
      final result = await services.variants.generate(
        config: config,
        brief: state.brief,
        profile: ref.read(activeProfileProvider),
        format: state.format,
        directions: chosen,
        groupId: groupId,
        existing: existing,
        onVariant: (variant) async {
          createdGroup = variant.variantGroupId;
          await ref
              .read(projectsProvider.notifier)
              .save(
                variant,
                historyLabel: config == null
                    ? 'Création (générateur hors ligne)'
                    : 'Création initiale par IA',
                kind: config == null ? VersionKind.initial : VersionKind.ai,
              );
          state = state.copyWith(groupId: createdGroup);
        },
        onProgress: (p) => state = state.copyWith(progress: p),
      );
      state = state.copyWith(
        running: false,
        failures: result.failures,
        groupId: createdGroup,
      );
      return result;
    } catch (e) {
      state = state.copyWith(running: false, failures: ['$e']);
      rethrow;
    }
  }
}

final variantStudioProvider =
    NotifierProvider<VariantStudioNotifier, VariantStudioState>(
      VariantStudioNotifier.new,
    );

/// Groupes de variantes : identifiant → variantes triées par numéro.
final variantGroupsProvider = Provider<Map<String, List<Project>>>((ref) {
  final projects = ref.watch(projectsProvider).value ?? const <Project>[];
  final groups = <String, List<Project>>{};
  for (final p in projects.where((p) => p.variantGroupId != null)) {
    groups.putIfAbsent(p.variantGroupId!, () => []).add(p);
  }
  for (final list in groups.values) {
    list.sort((a, b) => (a.variantIndex ?? 0).compareTo(b.variantIndex ?? 0));
  }
  return groups;
});
