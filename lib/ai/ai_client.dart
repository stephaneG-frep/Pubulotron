import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';

enum AiErrorKind {
  missingKey,
  network,
  timeout,
  unauthorized,
  modelNotFound,
  rateLimited,
  server,
  badRequest,
  refusal,
  truncated,
  invalidResponse,
}

class AiException implements Exception {
  const AiException(this.kind, this.message, {this.details});

  final AiErrorKind kind;
  final String message;
  final String? details;

  bool get isRetryable =>
      kind == AiErrorKind.network ||
      kind == AiErrorKind.timeout ||
      kind == AiErrorKind.server ||
      kind == AiErrorKind.rateLimited ||
      kind == AiErrorKind.truncated ||
      kind == AiErrorKind.invalidResponse;

  @override
  String toString() => details == null ? message : '$message ($details)';
}

class AiRequest {
  const AiRequest({
    required this.system,
    required this.user,
    this.jsonSchema,
    this.maxTokens = 16000,
    this.images = const [],
  });

  final String system;
  final String user;

  /// Images PNG jointes (analyse visuelle), pour les modèles qui les lisent.
  final List<Uint8List> images;

  AiRequest withoutImages() => AiRequest(
    system: system,
    user: user,
    jsonSchema: jsonSchema,
    maxTokens: maxTokens,
  );

  /// Schéma JSON de la réponse attendue (sortie structurée si le
  /// fournisseur la prend en charge, sinon décrit dans le prompt).
  final Map<String, dynamic>? jsonSchema;
  final int maxTokens;
}

class AiResponse {
  const AiResponse(this.text, {required this.imagesUsed});

  final String text;

  /// Vrai si le modèle a effectivement reçu les images jointes.
  final bool imagesUsed;
}

class AiConfig {
  const AiConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
  });

  final AiProvider provider;
  final String apiKey;
  final String model;
}

/// Client des API d'IA générative, appelées directement en HTTPS.
class AiClient {
  AiClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 240),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  static const anthropicVersion = '2026-10-21';

  /// Modèles Claude acceptant la bascule automatique côté serveur en cas de refus.
  static bool _supportsFallback(String model) =>
      model.startsWith('claude-opus-5') ||
      model.startsWith('claude-sonnet-5-5') ||
      model.startsWith('claude-fable-5');

  Future<String> complete(AiConfig config, AiRequest request) async =>
      (await completeDetailed(config, request)).text;

  /// Comme [complete], en indiquant si les images ont été acceptées.
  /// Un modèle qui refuse les images est réinterrogé sans elles.
  Future<AiResponse> completeDetailed(
    AiConfig config,
    AiRequest request,
  ) async {
    if (request.images.isEmpty) {
      return AiResponse(
        await _completeWithRetry(config, request),
        imagesUsed: false,
      );
    }
    try {
      return AiResponse(
        await _completeWithRetry(config, request),
        imagesUsed: true,
      );
    } on AiException catch (e) {
      if (e.kind != AiErrorKind.badRequest) rethrow;
      return AiResponse(
        await _completeWithRetry(config, request.withoutImages()),
        imagesUsed: false,
      );
    }
  }

  Future<String> _completeWithRetry(AiConfig config, AiRequest request) async {
    final key = config.apiKey.trim();
    if (key.isEmpty) {
      throw AiException(
        AiErrorKind.missingKey,
        'Aucune clé API ${config.provider.label} n’est configurée. Ajoutez-la dans Paramètres IA.',
      );
    }
    if (config.model.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.badRequest,
        'Aucun modèle n’est sélectionné.',
      );
    }
    AiException? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _completeOnce(config.copyWithKey(key), request);
      } on AiException catch (e) {
        last = e;
        if (e.kind != AiErrorKind.server || attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    throw last!;
  }

  Future<String> _completeOnce(AiConfig config, AiRequest request) {
    return switch (config.provider) {
      AiProvider.openai => _openAiCompatible(
        config,
        request,
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        tokenField: 'max_completion_tokens',
      ),
      AiProvider.mistral => _openAiCompatible(
        config,
        request,
        Uri.parse('https://api.mistral.ai/v1/chat/completions'),
        tokenField: 'max_tokens',
      ),
      AiProvider.anthropic => _anthropic(config, request),
      AiProvider.gemini => _gemini(config, request),
    };
  }

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(
        AiErrorKind.timeout,
        'Le fournisseur IA n’a pas répondu à temps. Réessayez ou choisissez un modèle plus rapide.',
      );
    } on SocketException catch (e) {
      throw AiException(
        AiErrorKind.network,
        'Connexion Internet impossible.',
        details: e.message,
      );
    } on http.ClientException catch (e) {
      throw AiException(
        AiErrorKind.network,
        'Impossible de joindre le fournisseur IA.',
        details: e.message,
      );
    } on HandshakeException catch (e) {
      throw AiException(
        AiErrorKind.network,
        'Échec de la connexion sécurisée.',
        details: e.message,
      );
    }
    return _decodeResponse(response);
  }

  static String? _errorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final error = json['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (error is String) return error;
        if (json['message'] is String) return json['message'] as String;
        if (json['detail'] is String) return json['detail'] as String;
      }
      if (json is List && json.isNotEmpty && json.first is Map) {
        final error = (json.first as Map)['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
      }
    } catch (_) {}
    final trimmed = body.trim();
    return trimmed.isEmpty
        ? null
        : trimmed.substring(0, trimmed.length.clamp(0, 300));
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final status = response.statusCode;
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (status >= 200 && status < 300) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
      throw const AiException(
        AiErrorKind.invalidResponse,
        'Réponse illisible du fournisseur IA.',
      );
    }
    final detail = _errorMessage(body);
    if (status == 401 || status == 403) {
      throw AiException(
        AiErrorKind.unauthorized,
        'Clé API refusée. Vérifiez la clé dans Paramètres IA.',
        details: detail,
      );
    }
    if (status == 404) {
      throw AiException(
        AiErrorKind.modelNotFound,
        'Modèle introuvable. Vérifiez le nom du modèle dans Paramètres IA.',
        details: detail,
      );
    }
    if (status == 429) {
      throw AiException(
        AiErrorKind.rateLimited,
        'Quota ou limite de débit atteint chez le fournisseur. Patientez avant de réessayer.',
        details: detail,
      );
    }
    if (status >= 500) {
      throw AiException(
        AiErrorKind.server,
        'Le service IA est momentanément indisponible (HTTP $status).',
        details: detail,
      );
    }
    throw AiException(
      AiErrorKind.badRequest,
      'Requête refusée par le fournisseur (HTTP $status).',
      details: detail,
    );
  }

  Future<String> _openAiCompatible(
    AiConfig config,
    AiRequest request,
    Uri uri, {
    required String tokenField,
  }) async {
    final system = request.jsonSchema == null
        ? request.system
        : '${request.system}\n\nRéponds uniquement par un objet JSON conforme à ce schéma :\n${jsonEncode(request.jsonSchema)}';
    final json = await _post(
      uri,
      {'Authorization': 'Bearer ${config.apiKey}'},
      {
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': system},
          {
            'role': 'user',
            'content': request.images.isEmpty
                ? request.user
                : [
                    {'type': 'text', 'text': request.user},
                    for (final png in request.images)
                      {
                        'type': 'image_url',
                        'image_url': config.provider == AiProvider.mistral
                            ? 'data:image/png;base64,${base64Encode(png)}'
                            : {
                                'url':
                                    'data:image/png;base64,${base64Encode(png)}',
                              },
                      },
                  ],
          },
        ],
        'response_format': {'type': 'json_object'},
        tokenField: request.maxTokens,
      },
    );
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const AiException(AiErrorKind.invalidResponse, 'Réponse IA vide.');
    }
    final choice = choices.first as Map;
    final message = choice['message'];
    if (message is Map && message['refusal'] is String) {
      throw AiException(
        AiErrorKind.refusal,
        'Le modèle a refusé la demande.',
        details: message['refusal'] as String,
      );
    }
    if (choice['finish_reason'] == 'length') {
      throw const AiException(
        AiErrorKind.truncated,
        'Réponse IA tronquée (limite de longueur atteinte).',
      );
    }
    final content = message is Map ? message['content'] : null;
    if (content is String && content.trim().isNotEmpty) return content;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((c) => c['text'])
          .whereType<String>()
          .join();
    }
    throw const AiException(AiErrorKind.invalidResponse, 'Réponse IA vide.');
  }

  Future<String> _anthropic(AiConfig config, AiRequest request) async {
    var fallback = _supportsFallback(config.model);
    var structured = request.jsonSchema != null;
    Map<String, dynamic>? json;
    // Si le serveur refuse une option (schéma ou bascule de secours), on
    // réessaie sans elle : le schéma est alors décrit dans le prompt.
    for (var attempt = 0; json == null; attempt++) {
      final system = structured || request.jsonSchema == null
          ? request.system
          : '${request.system}\n\nRéponds uniquement par un objet JSON conforme à ce schéma :\n${jsonEncode(request.jsonSchema)}';
      try {
        json = await _post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          {
            'x-api-key': config.apiKey,
            'anthropic-version': anthropicVersion,
            if (fallback) 'anthropic-beta': 'server-side-fallback-2026-07-01',
          },
          {
            'model': config.model,
            'max_tokens': request.maxTokens,
            'system': system,
            'messages': [
              {
                'role': 'user',
                'content': request.images.isEmpty
                    ? request.user
                    : [
                        for (final png in request.images)
                          {
                            'type': 'image',
                            'source': {
                              'type': 'base64',
                              'media_type': 'image/png',
                              'data': base64Encode(png),
                            },
                          },
                        {'type': 'text', 'text': request.user},
                      ],
              },
            ],
            'output_config': {
              'effort': 'medium',
              if (structured)
                'format': {'type': 'json_schema', 'schema': request.jsonSchema},
            },
            if (fallback) 'fallbacks': 'default',
          },
        );
      } on AiException catch (e) {
        final details = (e.details ?? '').toLowerCase();
        if (e.kind != AiErrorKind.badRequest || attempt >= 2) rethrow;
        if (fallback && details.contains('fallback')) {
          fallback = false;
        } else if (structured &&
            (details.contains('schema') ||
                details.contains('output_config') ||
                details.contains('format'))) {
          structured = false;
        } else {
          rethrow;
        }
      }
    }
    final stop = json['stop_reason'];
    if (stop == 'refusal') {
      final details = json['stop_details'];
      throw AiException(
        AiErrorKind.refusal,
        'Le modèle a refusé la demande.',
        details: details is Map ? details['explanation'] as String? : null,
      );
    }
    if (stop == 'max_tokens') {
      throw const AiException(
        AiErrorKind.truncated,
        'Réponse IA tronquée (limite de longueur atteinte).',
      );
    }
    final content = json['content'];
    if (content is List) {
      final text = content
          .whereType<Map>()
          .where((block) => block['type'] == 'text')
          .map((block) => block['text'])
          .whereType<String>()
          .join();
      if (text.trim().isNotEmpty) return text;
    }
    throw const AiException(AiErrorKind.invalidResponse, 'Réponse IA vide.');
  }

  Future<String> _gemini(AiConfig config, AiRequest request) async {
    final model = config.model.startsWith('models/')
        ? config.model.substring(7)
        : config.model;
    final system = request.jsonSchema == null
        ? request.system
        : '${request.system}\n\nRéponds uniquement par un objet JSON conforme à ce schéma :\n${jsonEncode(request.jsonSchema)}';
    final json = await _post(
      Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$model:generateContent',
      ),
      {'x-goog-api-key': config.apiKey},
      {
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              for (final png in request.images)
                {
                  'inline_data': {
                    'mime_type': 'image/png',
                    'data': base64Encode(png),
                  },
                },
              {'text': request.user},
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'maxOutputTokens': request.maxTokens,
        },
      },
    );
    final feedback = json['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw AiException(
        AiErrorKind.refusal,
        'La demande a été bloquée par le fournisseur.',
        details: '${feedback['blockReason']}',
      );
    }
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      throw const AiException(AiErrorKind.invalidResponse, 'Réponse IA vide.');
    }
    final candidate = candidates.first as Map;
    final reason = candidate['finishReason'];
    if (reason == 'SAFETY' ||
        reason == 'PROHIBITED_CONTENT' ||
        reason == 'RECITATION') {
      throw AiException(
        AiErrorKind.refusal,
        'Le modèle a refusé la demande.',
        details: '$reason',
      );
    }
    if (reason == 'MAX_TOKENS') {
      throw const AiException(
        AiErrorKind.truncated,
        'Réponse IA tronquée (limite de longueur atteinte).',
      );
    }
    final parts = (candidate['content'] as Map?)?['parts'];
    if (parts is List) {
      final text = parts
          .whereType<Map>()
          .map((p) => p['text'])
          .whereType<String>()
          .join();
      if (text.trim().isNotEmpty) return text;
    }
    throw const AiException(AiErrorKind.invalidResponse, 'Réponse IA vide.');
  }

  /// Vérifie la clé et renvoie les modèles disponibles.
  Future<List<String>> listModels(AiProvider provider, String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw AiException(
        AiErrorKind.missingKey,
        'Saisissez une clé API ${provider.label}.',
      );
    }
    final (uri, headers) = switch (provider) {
      AiProvider.openai => (
        Uri.parse('https://api.openai.com/v1/models'),
        {'Authorization': 'Bearer $key'},
      ),
      AiProvider.mistral => (
        Uri.parse('https://api.mistral.ai/v1/models'),
        {'Authorization': 'Bearer $key'},
      ),
      AiProvider.anthropic => (
        Uri.parse('https://api.anthropic.com/v1/models?limit=100'),
        {'x-api-key': key, 'anthropic-version': anthropicVersion},
      ),
      AiProvider.gemini => (
        Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {
          'pageSize': '200',
        }),
        {'x-goog-api-key': key},
      ),
    };
    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const AiException(
        AiErrorKind.timeout,
        'Le fournisseur ne répond pas.',
      );
    } on SocketException catch (e) {
      throw AiException(
        AiErrorKind.network,
        'Connexion Internet impossible.',
        details: e.message,
      );
    } on http.ClientException catch (e) {
      throw AiException(
        AiErrorKind.network,
        'Impossible de joindre le fournisseur IA.',
        details: e.message,
      );
    }
    final json = _decodeResponse(response);
    final ids = <String>[];
    if (provider == AiProvider.gemini) {
      for (final m in (json['models'] as List? ?? const []).whereType<Map>()) {
        final methods = (m['supportedGenerationMethods'] as List?) ?? const [];
        final name = m['name'] as String? ?? '';
        if (methods.contains('generateContent') && name.isNotEmpty) {
          ids.add(name.startsWith('models/') ? name.substring(7) : name);
        }
      }
    } else {
      for (final m in (json['data'] as List? ?? const []).whereType<Map>()) {
        final id = m['id'];
        if (id is String) ids.add(id);
      }
    }
    ids.sort();
    return ids;
  }

  void close() => _http.close();
}

extension on AiConfig {
  AiConfig copyWithKey(String key) =>
      AiConfig(provider: provider, apiKey: key, model: model);
}
