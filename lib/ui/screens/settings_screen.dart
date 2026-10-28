import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_client.dart';
import '../../app/providers.dart';
import '../../data/secret_store.dart';
import '../../models/app_settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _key = TextEditingController();
  final _model = TextEditingController();
  AiProvider? _loadedFor;
  bool _obscure = true;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;
  List<String> _models = const [];

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  void _syncFields(AiProvider provider) {
    if (_loadedFor == provider) return;
    final keys = ref.read(apiKeysProvider).value;
    if (keys == null) return;
    _loadedFor = provider;
    _key.text = keys[provider] ?? '';
    _model.text = ref.read(settingsProvider).modelFor(provider);
    _models = const [];
    _testMessage = null;
  }

  Future<void> _save(AiProvider provider) async {
    try {
      await ref.read(apiKeysProvider.notifier).setKey(provider, _key.text);
      final model = _model.text.trim();
      await ref
          .read(settingsProvider.notifier)
          .update(
            (s) => s.copyWith(
              provider: provider,
              models: {
                ...s.models,
                provider: model.isEmpty ? provider.defaultModel : model,
              },
            ),
          );
      if (mounted) {
        showMessage(
          context,
          'Paramètres ${provider.label} enregistrés (clé dans le trousseau sécurisé).',
        );
      }
    } on SecretStoreException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _test(AiProvider provider) async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final models = await ref
          .read(servicesProvider)
          .aiClient
          .listModels(provider, _key.text);
      final current = _model.text.trim();
      setState(() {
        _models = models;
        _testOk = true;
        _testMessage =
            'Connexion réussie : ${models.length} modèle(s) disponible(s).'
            '${current.isNotEmpty && models.isNotEmpty && !models.contains(current) ? ' Attention : « $current » n’apparaît pas dans la liste.' : ''}';
      });
    } on AiException catch (e) {
      setState(() {
        _testOk = false;
        _testMessage = e.details == null
            ? e.message
            : '${e.message} — ${e.details}';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final keys = ref.watch(apiKeysProvider);
    final provider = settings.provider;
    _syncFields(provider);

    return SectionPage(
      title: 'Paramètres IA',
      subtitle: 'Choisissez votre fournisseur d’intelligence artificielle. Les clés sont stockées dans le trousseau sécurisé du système.',
      icon: Icons.settings_suggest_outlined,
      accent: PubColors.violet,
      children: [
        PanelCard(
          title: 'Fournisseur',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in AiProvider.values)
                ChoiceChip(
                  avatar: Icon(
                    keys.value?.containsKey(p) == true
                        ? Icons.vpn_key
                        : Icons.vpn_key_off_outlined,
                    size: 18,
                  ),
                  label: Text(p.label),
                  selected: p == provider,
                  onSelected: (_) async {
                    await ref
                        .read(settingsProvider.notifier)
                        .update((s) => s.copyWith(provider: p));
                    setState(() => _loadedFor = null);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (keys.hasError)
          ErrorBanner(
            message: 'Trousseau sécurisé indisponible',
            details: '${keys.error}',
          ),
        PanelCard(
          title: provider.label,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _key,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Clé API',
                  hintText: provider.keyHint,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Obtenir une clé : ${provider.consoleUrl}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copier l’adresse',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: provider.consoleUrl),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _model,
                decoration: InputDecoration(
                  labelText: 'Modèle',
                  helperText: 'Par défaut : ${provider.defaultModel}',
                ),
              ),
              if (_models.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Choisir parmi les modèles disponibles',
                  ),
                  initialValue: _models.contains(_model.text.trim())
                      ? _model.text.trim()
                      : null,
                  items: [
                    for (final m in _models)
                      DropdownMenuItem(
                        value: m,
                        child: Text(m, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (m) =>
                      setState(() => _model.text = m ?? _model.text),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _save(provider),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Enregistrer'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : () => _test(provider),
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Tester la connexion'),
                  ),
                  if (keys.value?.containsKey(provider) == true)
                    TextButton.icon(
                      onPressed: () async {
                        _key.clear();
                        await ref
                            .read(apiKeysProvider.notifier)
                            .setKey(provider, '');
                        if (context.mounted) {
                          showMessage(
                            context,
                            'Clé ${provider.label} supprimée.',
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer la clé'),
                    ),
                ],
              ),
              if (_testMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _testMessage!,
                  style: TextStyle(
                    color: _testOk
                        ? PubColors.turquoise
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PanelCard(
          title: 'Confidentialité',
          child: const Text(
            'Lorsque vous utilisez l’IA, votre demande, le contenu de la création et les informations de votre fiche sont envoyés '
            'au fournisseur choisi, avec votre clé. Les images importées ne sont jamais envoyées. Sans clé, aucune donnée ne quitte l’appareil.',
          ),
        ),
        const SizedBox(height: 16),
        PanelCard(
          title: 'Préférences',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Apparence'),
              const SizedBox(height: 6),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Système'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Clair'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Sombre'),
                    icon: Icon(Icons.dark_mode),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => ref
                    .read(settingsProvider.notifier)
                    .update((x) => x.copyWith(themeMode: s.first)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sauvegarde automatique des projets'),
                subtitle: const Text(
                  'Enregistre chaque modification après une courte pause.',
                ),
                value: settings.autosave,
                onChanged: (v) {
                  ref
                      .read(settingsProvider.notifier)
                      .update((x) => x.copyWith(autosave: v));
                  ref.read(editorProvider)?.autosave = v;
                },
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<double>(
                isExpanded: true,
                initialValue:
                    const [150.0, 300.0, 600.0].contains(settings.exportDpi)
                    ? settings.exportDpi
                    : 300.0,
                decoration: const InputDecoration(
                  labelText: 'Résolution par défaut des exports PNG/JPEG',
                ),
                items: const [
                  DropdownMenuItem(value: 150.0, child: Text('150 ppp')),
                  DropdownMenuItem(
                    value: 300.0,
                    child: Text('300 ppp (impression)'),
                  ),
                  DropdownMenuItem(value: 600.0, child: Text('600 ppp')),
                ],
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .update((x) => x.copyWith(exportDpi: v)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue:
                    const [
                      10,
                      20,
                      30,
                      50,
                      100,
                    ].contains(settings.historyMaxVersions)
                    ? settings.historyMaxVersions
                    : 30,
                decoration: const InputDecoration(
                  labelText: 'Historique : versions conservées par création',
                  helperText: 'Au-delà, les plus anciennes sont supprimées (la version initiale est toujours gardée).',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 10,
                    child: Text('10 versions (économe)'),
                  ),
                  DropdownMenuItem(value: 20, child: Text('20 versions')),
                  DropdownMenuItem(
                    value: 30,
                    child: Text('30 versions (recommandé)'),
                  ),
                  DropdownMenuItem(value: 50, child: Text('50 versions')),
                  DropdownMenuItem(value: 100, child: Text('100 versions')),
                ],
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .update((x) => x.copyWith(historyMaxVersions: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
