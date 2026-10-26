import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_client.dart';
import '../layout/brand_kit.dart';
import '../layout/layout_engine.dart';
import '../models/business_profile.dart';
import '../models/design_document.dart';
import '../models/formats.dart';
import '../models/project.dart';
import 'providers.dart';

/// Format sélectionné pour une nouvelle création.
class CreationFormatNotifier extends Notifier<DesignFormat> {
  @override
  DesignFormat build() => DesignFormats.businessCard;

  void set(DesignFormat format) => state = format;
}

final creationFormatProvider =
    NotifierProvider<CreationFormatNotifier, DesignFormat>(
      CreationFormatNotifier.new,
    );

/// Proposition affichée dans « Création avec l'IA ».
class DesignProposal {
  const DesignProposal({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.document,
    required this.source,
    this.warnings = const [],
    this.offline = false,
  });

  final String title;
  final String subtitle;
  final String description;
  final DesignDocument document;
  final String source;
  final List<String> warnings;
  final bool offline;
}

class AiCreationState {
  const AiCreationState({
    this.brief = 'Je suis réparateur informatique. Crée-moi une carte de visite futuriste avec un fond bleu électrique, mon téléphone, mon adresse e-mail et un QR code vers mon site internet.',
    this.loading = false,
    this.proposals = const [],
    this.error,
  });

  final String brief;
  final bool loading;
  final List<DesignProposal> proposals;
  final AiException? error;

  AiCreationState copyWith({
    String? brief,
    bool? loading,
    List<DesignProposal>? proposals,
    AiException? error,
    bool clearError = false,
  }) => AiCreationState(
    brief: brief ?? this.brief,
    loading: loading ?? this.loading,
    proposals: proposals ?? this.proposals,
    error: clearError ? null : error ?? this.error,
  );
}

class AiCreationNotifier extends Notifier<AiCreationState> {
  @override
  AiCreationState build() => const AiCreationState();

  void setBrief(String brief) => state = state.copyWith(brief: brief);

  Future<void> generate() async {
    final config = ref.read(aiConfigProvider);
    final format = ref.read(creationFormatProvider);
    final profile = ref.read(activeProfileProvider);
    if (config == null) {
      state = state.copyWith(
        error: const AiException(
          AiErrorKind.missingKey,
          'Aucune clé API n’est configurée. Choisissez un fournisseur et saisissez votre clé dans « Paramètres IA ».',
        ),
      );
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final proposals = await ref
          .read(servicesProvider)
          .aiDesign
          .generateDesigns(
            config: config,
            brief: state.brief,
            profile: profile,
            widthMm: format.widthMm,
            heightMm: format.heightMm,
            formatLabel: format.label,
            duplex: format.duplex,
          );
      state = state.copyWith(
        loading: false,
        proposals: [
          for (final p in proposals)
            DesignProposal(
              title: p.title,
              subtitle: p.style,
              description: p.rationale,
              document: _withFormat(p.document, format),
              source: '${p.provider} · ${config.model}',
              warnings: p.warnings,
            ),
        ],
      );
    } on AiException catch (e) {
      state = state.copyWith(loading: false, error: e);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: AiException(
          AiErrorKind.invalidResponse,
          'Erreur inattendue pendant la génération.',
          details: '$e',
        ),
      );
    }
  }

  /// Compositions automatiques sans IA (fonctionne hors ligne).
  void generateOffline() {
    final format = ref.read(creationFormatProvider);
    final profile =
        ref.read(activeProfileProvider) ?? BusinessProfile.example();
    final base = LayoutEngine.kitForBrief(
      BrandKit.fromProfile(profile, brief: state.brief),
      state.brief,
    );
    final styles = LayoutEngine.stylesForBrief(state.brief).take(4);
    state = state.copyWith(
      clearError: true,
      proposals: [
        for (final style in styles)
          DesignProposal(
            title: style.label,
            subtitle: 'Composition automatique',
            description: 'Mise en page générée localement à partir de votre fiche, sans intelligence artificielle.',
            source: 'Générateur hors ligne',
            offline: true,
            document: LayoutEngine.build(
              style: style,
              widthMm: format.widthMm,
              heightMm: format.heightMm,
              kit: base.copyWith(layout: style),
              profile: profile,
              formatId: format.id,
              duplex: format.duplex,
            ),
          ),
      ],
    );
  }

  DesignDocument _withFormat(DesignDocument doc, DesignFormat format) =>
      doc.formatId == format.id ? doc : doc.copyWith(formatId: format.id);
}

final aiCreationProvider =
    NotifierProvider<AiCreationNotifier, AiCreationState>(
      AiCreationNotifier.new,
    );

/// Crée, enregistre et ouvre un projet.
Future<Project> createAndOpen(
  WidgetRef ref, {
  required String name,
  required DesignDocument document,
  String brief = '',
}) async {
  final project = Project(
    name: name,
    document: document,
    brief: brief,
    profileId: ref.read(activeProfileProvider)?.id,
  );
  await ref.read(projectsProvider.notifier).save(project);
  openInStudio(ref, project);
  return project;
}
