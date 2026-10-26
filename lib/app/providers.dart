import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_client.dart';
import '../data/secret_store.dart';
import '../editor/editor_controller.dart';
import '../models/app_settings.dart';
import '../models/business_profile.dart';
import '../models/project.dart';
import 'app_services.dart';

/// Services injectés au démarrage (remplacés dans les tests).
final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('AppServices non initialisés'),
);

// ------------------------------------------------------------------ réglages

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(servicesProvider).initialSettings;

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await ref.read(servicesProvider).saveSettings(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// ------------------------------------------------------------------ projets

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() => ref.read(servicesProvider).projects.list();

  Future<void> refresh() async {
    state = AsyncData(await ref.read(servicesProvider).projects.list());
  }

  Future<void> save(Project project) async {
    await ref.read(servicesProvider).projects.save(project);
    await refresh();
  }

  Future<void> saveAll(Iterable<Project> projects) async {
    for (final p in projects) {
      await ref.read(servicesProvider).projects.save(p);
    }
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(servicesProvider).projects.delete(id);
    await refresh();
  }

  Future<Project> duplicate(String id) async {
    final copy = await ref.read(servicesProvider).projects.duplicate(id);
    await refresh();
    return copy;
  }

  Future<void> rename(String id, String name) async {
    await ref.read(servicesProvider).projects.rename(id, name);
    await refresh();
  }
}

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

// ------------------------------------------------------------------ profils

class ProfilesNotifier extends AsyncNotifier<List<BusinessProfile>> {
  @override
  Future<List<BusinessProfile>> build() =>
      ref.read(servicesProvider).profiles.list();

  Future<void> save(BusinessProfile profile) async {
    await ref
        .read(servicesProvider)
        .profiles
        .save(profile.copyWith(updatedAt: DateTime.now()));
    state = AsyncData(await ref.read(servicesProvider).profiles.list());
  }

  Future<void> delete(String id) async {
    await ref.read(servicesProvider).profiles.delete(id);
    state = AsyncData(await ref.read(servicesProvider).profiles.list());
  }

  Future<void> reload() async {
    state = AsyncData(await ref.read(servicesProvider).profiles.list());
  }
}

final profilesProvider =
    AsyncNotifierProvider<ProfilesNotifier, List<BusinessProfile>>(
      ProfilesNotifier.new,
    );

/// Fiche active : celle choisie dans les réglages, sinon la première,
/// sinon `null` (aucune fiche enregistrée).
final activeProfileProvider = Provider<BusinessProfile?>((ref) {
  final profiles =
      ref.watch(profilesProvider).value ?? const <BusinessProfile>[];
  if (profiles.isEmpty) return null;
  final id = ref.watch(settingsProvider.select((s) => s.activeProfileId));
  return profiles.firstWhere((p) => p.id == id, orElse: () => profiles.first);
});

// ------------------------------------------------------------------ modèles

class CustomTemplatesNotifier extends AsyncNotifier<List<CustomTemplate>> {
  @override
  Future<List<CustomTemplate>> build() =>
      ref.read(servicesProvider).templates.list();

  Future<void> save(CustomTemplate template) async {
    await ref.read(servicesProvider).templates.save(template);
    state = AsyncData(await ref.read(servicesProvider).templates.list());
  }

  Future<void> delete(String id) async {
    await ref.read(servicesProvider).templates.delete(id);
    state = AsyncData(await ref.read(servicesProvider).templates.list());
  }

  Future<void> reload() async {
    state = AsyncData(await ref.read(servicesProvider).templates.list());
  }
}

final customTemplatesProvider =
    AsyncNotifierProvider<CustomTemplatesNotifier, List<CustomTemplate>>(
      CustomTemplatesNotifier.new,
    );

// ------------------------------------------------------------------ clés API

class ApiKeysNotifier extends AsyncNotifier<Map<AiProvider, String>> {
  @override
  Future<Map<AiProvider, String>> build() async {
    final secrets = ref.read(servicesProvider).secrets;
    await _migrateLegacyKey(secrets);
    final keys = <AiProvider, String>{};
    for (final provider in AiProvider.values) {
      final value = await secrets.read(provider.secretKey);
      if (value != null && value.isNotEmpty) keys[provider] = value;
    }
    return keys;
  }

  /// La version 1 stockait une seule clé et son fournisseur sous d'autres
  /// noms : ils sont repris (puis effacés) au premier démarrage.
  Future<void> _migrateLegacyKey(SecretStore secrets) async {
    const legacyKey = 'pubulotron_api_key';
    const legacyProvider = 'pubulotron_ai_provider';
    final key = (await secrets.read(legacyKey))?.trim();
    if (key == null || key.isEmpty) return;
    final provider = switch (await secrets.read(legacyProvider)) {
      'OpenAI' => AiProvider.openai,
      'Gemini' => AiProvider.gemini,
      'Mistral' => AiProvider.mistral,
      _ => AiProvider.anthropic,
    };
    final existing = await secrets.read(provider.secretKey);
    if (existing == null || existing.isEmpty) {
      await secrets.write(provider.secretKey, key);
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(provider: provider));
    }
    await secrets.delete(legacyKey);
    await secrets.delete(legacyProvider);
  }

  Future<void> setKey(AiProvider provider, String key) async {
    final secrets = ref.read(servicesProvider).secrets;
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await secrets.delete(provider.secretKey);
    } else {
      await secrets.write(provider.secretKey, trimmed);
    }
    final current = Map<AiProvider, String>.of(state.value ?? const {});
    if (trimmed.isEmpty) {
      current.remove(provider);
    } else {
      current[provider] = trimmed;
    }
    state = AsyncData(current);
  }
}

final apiKeysProvider =
    AsyncNotifierProvider<ApiKeysNotifier, Map<AiProvider, String>>(
      ApiKeysNotifier.new,
    );

/// Configuration IA prête à l'emploi (fournisseur, clé et modèle actifs).
final aiConfigProvider = Provider<AiConfig?>((ref) {
  final settings = ref.watch(settingsProvider);
  final key = ref.watch(apiKeysProvider).value?[settings.provider];
  if (key == null || key.isEmpty) return null;
  return AiConfig(
    provider: settings.provider,
    apiKey: key,
    model: settings.modelFor(settings.provider),
  );
});

// ------------------------------------------------------------------ navigation

enum AppSection {
  home,
  newCreation,
  aiCreation,
  studio,
  templates,
  projects,
  pack,
  print,
  identity,
  aiSettings,
  help,
  qr,
}

class NavigationNotifier extends Notifier<AppSection> {
  @override
  AppSection build() => AppSection.home;

  void go(AppSection section) => state = section;
}

final navigationProvider = NotifierProvider<NavigationNotifier, AppSection>(
  NavigationNotifier.new,
);

// ------------------------------------------------------------------ édition

/// Projet ouvert dans l'atelier (un seul à la fois).
class EditorSessionNotifier extends Notifier<EditorController?> {
  EditorController? _current;

  @override
  EditorController? build() {
    ref.onDispose(() {
      _current?.dispose();
      _current = null;
    });
    return null;
  }

  void _set(EditorController? controller) {
    _current = controller;
    state = controller;
  }

  EditorController open(Project project) {
    final previous = _current;
    if (previous != null && previous.project.id == project.id) return previous;
    final settings = ref.read(settingsProvider);
    // Capturés ici : la sauvegarde finale peut survenir après la fermeture.
    final services = ref.read(servicesProvider);
    final controller = EditorController(
      project: project,
      autosave: settings.autosave,
      onSave: (p) async {
        await services.projects.save(p);
        if (ref.mounted) await ref.read(projectsProvider.notifier).refresh();
      },
    );
    _set(controller);
    // Le précédent est sauvegardé (si besoin) lors de sa libération.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    return controller;
  }

  Future<void> close() async {
    final current = _current;
    if (current == null) return;
    await current.saveNow();
    _set(null);
    WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
  }
}

final editorProvider =
    NotifierProvider<EditorSessionNotifier, EditorController?>(
      EditorSessionNotifier.new,
    );

/// Ouvre un projet dans l'atelier et y navigue.
void openInStudio(WidgetRef ref, Project project) {
  ref.read(editorProvider.notifier).open(project);
  ref.read(navigationProvider.notifier).go(AppSection.studio);
}
