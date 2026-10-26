import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/pubulotron_models.dart';

class AiService {
  static Future<void> testConnection(
    String provider,
    String apiKey, {
    http.Client? client,
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const FormatException(
        'Saisissez une clé API avant de tester la connexion.',
      );
    }

    final endpoint = _modelsEndpoint(provider, trimmedKey);
    if (endpoint == null) {
      throw const FormatException('Fournisseur IA non reconnu.');
    }

    final ownsClient = client == null;
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .get(endpoint, headers: _providerHeaders(provider, trimmedKey))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Le fournisseur a répondu avec le code HTTP ${response.statusCode}.',
        );
      }
    } finally {
      if (ownsClient) requestClient.close();
    }
  }

  static Future<List<DesignConcept>> generateConcepts(
    String prompt,
    String provider,
    String apiKey,
  ) async {
    final lower = prompt.toLowerCase();
    final hasBlue =
        lower.contains('bleu') ||
        lower.contains('cyan') ||
        lower.contains('electric');
    final hasRose =
        lower.contains('rose') ||
        lower.contains('pink') ||
        lower.contains('fuchsia');
    final hasOrange = lower.contains('orange') || lower.contains('jaune');
    final hasGreen =
        lower.contains('vert') ||
        lower.contains('nature') ||
        lower.contains('jardin');
    final palette = hasBlue
        ? 'Bleu électrique / violet'
        : hasGreen
        ? 'Vert / blanc / orange'
        : hasRose
        ? 'Rose / violet / bleu nuit'
        : hasOrange
        ? 'Orange / noir / blanc'
        : 'Violet / turquoise / blanc';

    final trimmedKey = apiKey.trim();
    if (trimmedKey.isNotEmpty) {
      try {
        final remote = await _fetchFromProvider(
          prompt,
          provider,
          trimmedKey,
          palette,
        );
        if (remote.length >= 4) return remote.take(4).toList();
      } catch (_) {
        // Keep concept creation available offline when the provider is unavailable.
      }
    }

    return _localConcepts(prompt, palette, 'local');
  }

  static List<DesignConcept> _localConcepts(
    String prompt,
    String palette,
    String provider,
  ) {
    final keywords = prompt
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(6)
        .join(' ');
    final seed = keywords.isNotEmpty ? keywords : 'Création publicitaire';
    final styles = ['Futuriste', 'Premium', 'Digital', 'Pop'];
    final slogans = [
      'Votre message monte en puissance.',
      'Une présence professionnelle qui rassure.',
      'Le bon visuel pour la bonne conversion.',
      'Des idées qui parlent avant le premier clic.',
    ];
    final summaries = [
      'Composition à forte lisibilité, avec point focal marketing clair.',
      'Mise en scène premium orientée identité de marque et conversion.',
      'Approche dynamique pensée pour les réseaux sociaux et flyers print.',
      'Palette vibrante et storytelling visuel pour capter l’attention.',
    ];

    return List.generate(4, (index) {
      final title = '${seed.split(' ').take(2).join(' ')} ${index + 1}';
      return DesignConcept(
        title: title.trim().isNotEmpty ? title : 'Concept ${index + 1}',
        style: styles[index % styles.length],
        palette: palette,
        slogan: slogans[index % slogans.length],
        summary: summaries[index % summaries.length],
        provider: provider,
      );
    });
  }

  static Future<List<DesignConcept>> _fetchFromProvider(
    String prompt,
    String provider,
    String apiKey,
    String palette,
  ) async {
    final endpoint = _providerEndpoint(provider, apiKey);
    if (endpoint == null) return <DesignConcept>[];

    final response = await http.post(
      endpoint,
      headers: _providerHeaders(provider, apiKey),
      body: jsonEncode(_providerPayload(provider, prompt, palette)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'AI provider response failed: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    final content = _extractContent(provider, decoded);
    if (content.isEmpty) return <DesignConcept>[];

    final parts = _parseConcepts(content, provider);
    return parts.isNotEmpty ? parts : <DesignConcept>[];
  }

  static Uri? _providerEndpoint(String provider, String apiKey) {
    switch (provider) {
      case 'OpenAI':
        return Uri.parse('https://api.openai.com/v1/chat/completions');
      case 'Claude':
        return Uri.parse('https://api.anthropic.com/v1/messages');
      case 'Gemini':
        return Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
        );
      case 'Mistral':
        return Uri.parse('https://api.mistral.ai/v1/chat/completions');
      default:
        return null;
    }
  }

  static Uri? _modelsEndpoint(String provider, String apiKey) {
    switch (provider) {
      case 'OpenAI':
        return Uri.parse('https://api.openai.com/v1/models');
      case 'Claude':
        return Uri.parse('https://api.anthropic.com/v1/models');
      case 'Gemini':
        return Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models',
          {'key': apiKey},
        );
      case 'Mistral':
        return Uri.parse('https://api.mistral.ai/v1/models');
      default:
        return null;
    }
  }

  static Map<String, String> _providerHeaders(String provider, String apiKey) {
    switch (provider) {
      case 'OpenAI':
      case 'Mistral':
        return {
          'Content-Type': 'application/json',
          'Authorization': ['Bearer ', apiKey].join(),
        };
      case 'Claude':
        return {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        };
      case 'Gemini':
      default:
        return {'Content-Type': 'application/json'};
    }
  }

  static Map<String, dynamic> _providerPayload(
    String provider,
    String prompt,
    String palette,
  ) {
    if (provider == 'Claude') {
      return {
        'model': 'claude-3-5-sonnet-20241022',
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content':
                'Tu es un directeur artistique. Donne exactement 4 concepts de création publicitaire, avec des compositions nettement différentes, pour ce brief: $prompt. Palette de départ: $palette. Utilise ces styles dans l’ordre: Futuriste, Premium, Digital, Pop. Réponds en JSON avec une liste de 4 objets: title, style, palette, slogan, summary.',
          },
        ],
      };
    }
    if (provider == 'Gemini') {
      return {
        'contents': [
          {
            'parts': [
              {
                'text':
                    'Tu es un directeur artistique. Donne exactement 4 concepts de création publicitaire, avec des compositions nettement différentes, pour ce brief: $prompt. Palette de départ: $palette. Utilise ces styles dans l’ordre: Futuriste, Premium, Digital, Pop. Réponds exclusivement au format JSON avec quatre objets: title, style, palette, slogan, summary.',
              },
            ],
          },
        ],
      };
    }

    return {
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'system',
          'content': 'Tu es un directeur artistique. Réponds uniquement en JSON avec exactement 4 objets {title, style, palette, slogan, summary}. Ils représentent quatre compositions visuelles distinctes, dans cet ordre de style : Futuriste, Premium, Digital, Pop.',
        },
        {'role': 'user', 'content': 'Brief: $prompt. Palette: $palette.'},
      ],
      'temperature': 0.7,
    };
  }

  static String _extractContent(String provider, dynamic decoded) {
    if (provider == 'Claude') {
      final text = decoded['content'];
      if (text is List) {
        final first = text.firstWhere(
          (item) => item is Map && item['type'] == 'text',
          orElse: () => <String, dynamic>{},
        );
        if (first is Map) return (first['text'] as String?) ?? '';
      }
      return '';
    }

    if (provider == 'Gemini') {
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';
      final candidate = candidates.first as Map<String, dynamic>;
      final parts = candidate['content']['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';
      final text = parts.first['text'];
      return text is String ? text : '';
    }

    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    final message = (choices.first as Map<String, dynamic>)['message'];
    if (message is Map) {
      final content = message['content'];
      if (content is String) return content;
    }
    return '';
  }

  static List<DesignConcept> _parseConcepts(String rawText, String provider) {
    final cleaned = rawText
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    try {
      final decoded = jsonDecode(cleaned);
      final List<dynamic> values = decoded is List
          ? decoded
          : decoded['concepts'] ?? decoded['items'] ?? [];
      return values.map((entry) {
        final item = entry as Map<String, dynamic>;
        return DesignConcept(
          title: (item['title'] as String?) ?? 'Concept',
          style: (item['style'] as String?) ?? 'Premium',
          palette: (item['palette'] as String?) ?? '',
          slogan: (item['slogan'] as String?) ?? '',
          summary: (item['summary'] as String?) ?? '',
          provider: provider,
        );
      }).toList();
    } catch (_) {
      return <DesignConcept>[];
    }
  }
}
