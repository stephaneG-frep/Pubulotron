import 'package:flutter/material.dart';

import '../print/imposition.dart';

enum AiProvider { openai, anthropic, gemini, mistral }

extension AiProviderInfo on AiProvider {
  String get label => switch (this) {
    AiProvider.openai => 'OpenAI',
    AiProvider.anthropic => 'Anthropic Claude',
    AiProvider.gemini => 'Google Gemini',
    AiProvider.mistral => 'Mistral AI',
  };

  String get defaultModel => switch (this) {
    AiProvider.openai => 'gpt-4.1-mini',
    AiProvider.anthropic => 'claude-opus-5-5',
    AiProvider.gemini => 'gemini-2.5-flash',
    AiProvider.mistral => 'mistral-large-latest',
  };

  String get keyHint => switch (this) {
    AiProvider.openai => 'sk-…',
    AiProvider.anthropic => 'sk-ant-…',
    AiProvider.gemini => 'AIza…',
    AiProvider.mistral => 'Clé Mistral',
  };

  String get consoleUrl => switch (this) {
    AiProvider.openai => 'https://platform.openai.com/api-keys',
    AiProvider.anthropic => 'https://platform.claude.com/settings/keys',
    AiProvider.gemini => 'https://aistudio.google.com/apikey',
    AiProvider.mistral => 'https://console.mistral.ai/api-keys',
  };

  String get secretKey => 'pubulotron_api_key_$name';
}

/// Paramètres de l'application (hors secrets).
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.provider = AiProvider.anthropic,
    this.models = const {},
    this.activeProfileId,
    this.autosave = true,
    this.exportDpi = 300,
    this.print = const PrintSettings(),
  });

  final ThemeMode themeMode;
  final AiProvider provider;
  final Map<AiProvider, String> models;
  final String? activeProfileId;
  final bool autosave;
  final double exportDpi;
  final PrintSettings print;

  String modelFor(AiProvider p) {
    final value = models[p]?.trim();
    return value == null || value.isEmpty ? p.defaultModel : value;
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    AiProvider? provider,
    Map<AiProvider, String>? models,
    String? activeProfileId,
    bool? autosave,
    double? exportDpi,
    PrintSettings? print,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    provider: provider ?? this.provider,
    models: models ?? this.models,
    activeProfileId: activeProfileId ?? this.activeProfileId,
    autosave: autosave ?? this.autosave,
    exportDpi: exportDpi ?? this.exportDpi,
    print: print ?? this.print,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'provider': provider.name,
    'models': {for (final e in models.entries) e.key.name: e.value},
    if (activeProfileId != null) 'activeProfileId': activeProfileId,
    'autosave': autosave,
    'exportDpi': exportDpi,
    'print': print.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final models = <AiProvider, String>{};
    final rawModels = json['models'];
    if (rawModels is Map) {
      for (final p in AiProvider.values) {
        final v = rawModels[p.name];
        if (v is String && v.trim().isNotEmpty) models[p] = v.trim();
      }
    }
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      provider: AiProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => AiProvider.anthropic,
      ),
      models: models,
      activeProfileId: json['activeProfileId'] as String?,
      autosave: json['autosave'] as bool? ?? true,
      exportDpi: (json['exportDpi'] as num?)?.toDouble() ?? 300,
      print: json['print'] is Map
          ? PrintSettings.fromJson(
              (json['print'] as Map).cast<String, dynamic>(),
            )
          : const PrintSettings(),
    );
  }
}
