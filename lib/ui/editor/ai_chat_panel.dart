import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_client.dart';
import '../../ai/ai_design_service.dart';
import '../../app/providers.dart';
import '../../editor/editor_controller.dart';
import '../../models/app_settings.dart';
import '../theme.dart';
import '../widgets/robopub.dart';

class ChatEntry {
  const ChatEntry({
    required this.fromUser,
    required this.text,
    this.warnings = const [],
    this.error = false,
    this.canUndo = false,
  });

  final bool fromUser;
  final String text;
  final List<String> warnings;
  final bool error;
  final bool canUndo;
}

/// Conversations avec l'agent, par projet (le temps de la session).
class ChatHistoryNotifier extends Notifier<Map<String, List<ChatEntry>>> {
  @override
  Map<String, List<ChatEntry>> build() => {};

  void add(String projectId, ChatEntry entry) {
    state = {
      ...state,
      projectId: [...?state[projectId], entry],
    };
  }

  void clear(String projectId) => state = {...state}..remove(projectId);
}

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, Map<String, List<ChatEntry>>>(
      ChatHistoryNotifier.new,
    );

class AiChatPanel extends ConsumerStatefulWidget {
  const AiChatPanel({super.key, required this.controller});

  final EditorController controller;

  @override
  ConsumerState<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends ConsumerState<AiChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  static const _suggestions = [
    'Agrandis le titre et mets-le en gras',
    'Mets le numéro de téléphone en orange',
    'Ajoute une photo à droite',
    'Propose un fond en dégradé plus moderne',
    'Que penses-tu de la lisibilité ?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final instruction = text.trim();
    if (instruction.isEmpty || _busy) return;
    final config = ref.read(aiConfigProvider);
    final c = widget.controller;
    final projectId = c.project.id;
    final history = ref.read(chatHistoryProvider)[projectId] ?? const [];
    final chat = ref.read(chatHistoryProvider.notifier);
    chat.add(projectId, ChatEntry(fromUser: true, text: instruction));
    _input.clear();
    if (config == null) {
      chat.add(
        projectId,
        const ChatEntry(
          fromUser: false,
          error: true,
          text: 'Aucune clé API n’est configurée. Ouvrez « Paramètres IA » pour choisir un fournisseur et saisir votre clé.',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final pageIndex = c.pageIndex;
    final documentAtRequest = c.document;
    try {
      final result = await ref
          .read(servicesProvider)
          .aiDesign
          .editPage(
            config: config,
            document: documentAtRequest,
            pageIndex: pageIndex,
            instruction: instruction,
            profile: ref.read(activeProfileProvider),
            selectedIds: c.selection,
            history: [
              for (final h
                  in history
                      .where((h) => !h.error)
                      .toList()
                      .reversed
                      .take(10)
                      .toList()
                      .reversed)
                AiChatTurn(fromUser: h.fromUser, text: h.text),
            ],
          );
      if (!mounted) return;
      if (result.applied > 0) {
        if (!identical(c.document, documentAtRequest)) {
          chat.add(
            projectId,
            const ChatEntry(
              fromUser: false,
              error: true,
              text: 'La création a été modifiée pendant la réflexion de l’agent : renvoyez votre demande.',
            ),
          );
        } else {
          if (c.pageIndex != pageIndex) c.setPage(pageIndex);
          c.replacePage(result.page);
          chat.add(
            projectId,
            ChatEntry(
              fromUser: false,
              text: result.message,
              warnings: result.warnings,
              canUndo: true,
            ),
          );
        }
      } else {
        chat.add(
          projectId,
          ChatEntry(
            fromUser: false,
            text: result.message,
            warnings: result.warnings,
          ),
        );
      }
    } on AiException catch (e) {
      chat.add(
        projectId,
        ChatEntry(
          fromUser: false,
          error: true,
          text: e.details == null ? e.message : '${e.message}\n${e.details}',
        ),
      );
    } catch (e) {
      chat.add(
        projectId,
        ChatEntry(fromUser: false, error: true, text: 'Erreur inattendue : $e'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(aiConfigProvider);
    final entries =
        ref.watch(chatHistoryProvider)[widget.controller.project.id] ??
        const <ChatEntry>[];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: entries.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Center(
                      child: RoboPub(size: 96, mood: RoboMood.thinking),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Décrivez la modification souhaitée : je modifie les éléments de la création, qui restent entièrement éditables.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config == null
                          ? 'Aucun fournisseur IA configuré (connexion Internet et clé API requises).'
                          : '${config.provider.label} · ${config.model}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in _suggestions)
                          ActionChip(label: Text(s), onPressed: () => _send(s)),
                      ],
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  itemBuilder: (context, i) =>
                      _bubble(context, entries[i], scheme),
                ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_busy,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Ex. : agrandis le titre, fond vert…',
                  ),
                  onSubmitted: _send,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Envoyer',
                onPressed: _busy ? null : () => _send(_input.text),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(BuildContext context, ChatEntry entry, ColorScheme scheme) {
    final user = entry.fromUser;
    final background = entry.error
        ? scheme.errorContainer
        : user
        ? PubColors.violet
        : scheme.surfaceContainerHigh;
    final foreground = entry.error
        ? scheme.onErrorContainer
        : user
        ? Colors.white
        : scheme.onSurface;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(entry.text, style: TextStyle(color: foreground)),
            if (entry.warnings.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final w in entry.warnings.take(5))
                Text(
                  '⚠ $w',
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
            ],
            if (entry.canUndo)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.controller.canUndo
                      ? widget.controller.undo
                      : null,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Annuler'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
