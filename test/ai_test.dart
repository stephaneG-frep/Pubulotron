import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubulotron/ai/ai_client.dart';
import 'package:pubulotron/ai/ai_design_service.dart';
import 'package:pubulotron/ai/design_schema.dart';
import 'package:pubulotron/layout/brand_kit.dart';
import 'package:pubulotron/models/app_settings.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_document.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/fill.dart';

const designsJson = '''
{"designs":[
 {"title":"Néon","style":"Futuriste","rationale":"Contraste fort.","palette":["#0A1F44","#00E5FF"],
  "front":{"background":{"kind":"linear","colors":["#0A1F44","#1E6BFF"],"angle":45},
   "elements":[
    {"type":"text","name":"Titre","role":"headline","x":5,"y":5,"width":50,"height":12,"text":"TechCare","fontFamily":"Montserrat","fontSize":16,"bold":true,"color":"#FFFFFF"},
    {"type":"qr","x":60,"y":30,"width":20,"height":18},
    {"type":"icon","x":5,"y":40,"width":6,"height":6,"iconKey":"laptop_chromebook","color":"#00E5FF"},
    {"type":"image","role":"logo","x":60,"y":5,"width":20,"height":20},
    {"type":"comet","x":1,"y":1,"width":1,"height":1},
    {"type":"text","x":5,"y":20,"width":40,"height":8,"text":"   "}
   ]},
  "back":{"background":{"kind":"solid","colors":["#00E5FF"]},"elements":[{"type":"shape","shape":"ellipse","x":10,"y":10,"width":20,"height":20,"fill":{"kind":"solid","colors":["#FFFFFF"]}}]}
 },
 {"title":"Vide","style":"x","rationale":"","palette":[],"front":{"background":{"kind":"solid","colors":["#fff"]},"elements":[]}}
]}''';

BusinessProfile get profile =>
    BusinessProfile.example().copyWith(logoAssetId: 'logo.png');

void main() {
  group('design parsing', () {
    test(
      'valid designs are sanitised and invalid parts dropped with warnings',
      () {
        final proposals = AiDesignService.parseDesigns(
          designsJson,
          size: const Size(85, 55),
          profile: profile,
          provider: 'Test',
          formatId: 'business-card',
        );
        expect(
          proposals,
          hasLength(1),
          reason: 'le design sans élément est rejeté',
        );
        final p = proposals.single;
        expect(p.title, 'Néon');
        expect(p.document.pages, hasLength(2));
        final els = p.document.front.elements;
        expect(els.map((e) => e.type), [
          ElementType.text,
          ElementType.qr,
          ElementType.icon,
          ElementType.image,
        ]);
        expect(
          els[0].fontFamily,
          'Ubuntu',
          reason: 'Montserrat → police embarquée la plus proche',
        );
        expect(els[1].qrData, 'https://techcare-repair.fr');
        expect(els[1].width, els[1].height, reason: 'QR carré');
        expect(els[2].iconKey, 'laptop');
        expect(els[3].assetId, 'logo.png');
        expect(p.document.front.background.kind, FillKind.linear);
        expect(p.warnings.any((w) => w.contains('comet')), isTrue);
        expect(p.warnings.any((w) => w.contains('Texte vide')), isTrue);
      },
    );

    test('markdown fences and surrounding text are tolerated', () {
      final raw =
          'Voici mes propositions :\n```json\n$designsJson\n```\nBonne journée !';
      expect(
        AiDesignService.parseDesigns(
          raw,
          size: const Size(85, 55),
          profile: profile,
          provider: 'Test',
        ),
        hasLength(1),
      );
    });

    test('garbage or empty responses raise invalidResponse', () {
      expect(
        () => AiDesignService.parseDesigns(
          'je ne sais pas',
          size: const Size(85, 55),
          profile: profile,
          provider: 'Test',
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiErrorKind.invalidResponse,
          ),
        ),
      );
      expect(
        () => AiDesignService.parseDesigns(
          '{"designs":[]}',
          size: const Size(85, 55),
          profile: profile,
          provider: 'Test',
        ),
        throwsA(isA<AiException>()),
      );
    });

    test('out of range geometry is clamped into the page', () {
      final s = ElementSanitizer(pageSize: const Size(85, 55), profile: null);
      final e = s.element({
        'type': 'shape',
        'x': 500,
        'y': -900,
        'width': 99999,
        'height': 'abc',
      });
      expect(e, isNull);
      final ok = s.element({
        'type': 'shape',
        'x': 500,
        'y': -900,
        'width': 10,
        'height': 10,
        'rotation': 9999,
        'cornerRadius': 50,
        'color': 'pas une couleur',
      });
      expect(ok!.x, 85);
      expect(ok.y, -10);
      expect(ok.rotation, 360);
      expect(ok.cornerRadius, 5);
      expect(ok.fill, isNotNull);
      expect(s.warnings, isNotEmpty);
    });
  });

  group('edit operations', () {
    final page = DesignPage(
      elements: [
        DesignElement(
          id: 'title',
          type: ElementType.text,
          text: 'Titre',
          x: 5,
          y: 5,
          width: 40,
          height: 10,
          fontSize: 12,
        ),
        DesignElement(
          id: 'phone',
          type: ElementType.text,
          text: '06',
          x: 5,
          y: 30,
          width: 40,
          height: 6,
        ),
        DesignElement(
          id: 'locked',
          type: ElementType.shape,
          x: 0,
          y: 0,
          width: 85,
          height: 55,
          locked: true,
          fill: Fill.solid(const Color(0xFF000000)),
        ),
        DesignElement(
          id: 'photo',
          type: ElementType.image,
          assetId: 'mine.jpg',
          x: 50,
          y: 5,
          width: 30,
          height: 30,
        ),
      ],
    );

    test(
      'update / add / delete / reorder / background are applied together',
      () {
        const raw =
            '''{"message":"Titre agrandi, téléphone en orange.","operations":[
        {"op":"update","id":"title","changes":{"fontSize":18,"height":14}},
        {"op":"update","id":"phone","changes":{"color":"#FFAA45"}},
        {"op":"update","id":"photo","changes":{"width":20}},
        {"op":"add","element":{"type":"image","role":"photo","x":50,"y":30,"width":30,"height":20}},
        {"op":"update","id":"locked","changes":{"x":10}},
        {"op":"delete","id":"ghost"},
        {"op":"reorder","id":"title","position":"back"},
        {"op":"background","fill":{"kind":"solid","colors":["#24C9C2"]}},
        {"op":"explode"}
      ]}''';
        final result = AiDesignService.applyEdit(raw, page, const Size(85, 55));
        expect(result.applied, 6);
        expect(result.message, contains('orange'));
        final els = result.page.elements;
        expect(els.first.id, 'title');
        expect(els.first.fontSize, 18);
        expect(
          els.firstWhere((e) => e.id == 'phone').color,
          const Color(0xFFFFAA45),
        );
        expect(
          els.firstWhere((e) => e.id == 'photo').assetId,
          'mine.jpg',
          reason: 'l’image existante est conservée',
        );
        expect(els.firstWhere((e) => e.id == 'locked').x, 0);
        expect(els.where((e) => e.type == ElementType.image), hasLength(2));
        expect(result.page.background.primary, const Color(0xFF24C9C2));
        expect(result.warnings.length, greaterThanOrEqualTo(3));
      },
    );

    test('advice-only answers keep the page unchanged', () {
      final result = AiDesignService.applyEdit(
        '{"message":"Utilisez un contraste plus fort.","operations":[]}',
        page,
        const Size(85, 55),
      );
      expect(result.applied, 0);
      expect(result.page.elements, page.elements);
    });

    test('responses with nothing usable are rejected', () {
      expect(
        () => AiDesignService.applyEdit(
          '{"operations":[{"op":"delete","id":"nope"}]}',
          page,
          const Size(85, 55),
        ),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('providers', () {
    const request = AiRequest(
      system: 'sys',
      user: 'brief',
      jsonSchema: {'type': 'object'},
    );

    Future<(http.Request, String)> run(
      AiProvider provider,
      Map<String, dynamic> response, {
      String model = 'model-x',
    }) async {
      late http.Request captured;
      final client = AiClient(
        httpClient: MockClient((req) async {
          captured = req;
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final text = await client.complete(
        AiConfig(provider: provider, apiKey: ' secret ', model: model),
        request,
      );
      return (captured, text);
    }

    test('OpenAI uses chat completions with JSON mode', () async {
      final (req, text) = await run(AiProvider.openai, {
        'choices': [
          {
            'message': {'content': '{"ok":true}'},
            'finish_reason': 'stop',
          },
        ],
      });
      expect(req.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(req.headers['Authorization'], 'Bearer secret');
      final body = jsonDecode(req.body) as Map;
      expect(body['response_format'], {'type': 'json_object'});
      expect(body['max_completion_tokens'], 16000);
      expect(text, '{"ok":true}');
    });

    test('Anthropic uses the Messages API with structured output', () async {
      final (req, text) = await run(AiProvider.anthropic, {
        'content': [
          {'type': 'thinking', 'thinking': ''},
          {'type': 'text', 'text': '{"ok":1}'},
        ],
        'stop_reason': 'end_turn',
      }, model: 'claude-opus-5-5');
      expect(req.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(req.headers['x-api-key'], 'secret');
      expect(req.headers['anthropic-version'], AiClient.anthropicVersion);
      expect(req.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
      final body = jsonDecode(req.body) as Map;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['system'], 'sys');
      expect(body['output_config']['format']['type'], 'json_schema');
      expect(body['fallbacks'], 'default');
      expect(body.containsKey('temperature'), isFalse);
      expect(text, '{"ok":1}');
    });

    test('Gemini sends the key in a header and asks for JSON', () async {
      final (req, text) = await run(AiProvider.gemini, {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '{"g":1}'},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      }, model: 'gemini-2.5-flash');
      expect(req.url.path, '/v1beta/models/gemini-2.5-flash:generateContent');
      expect(req.url.queryParameters.containsKey('key'), isFalse);
      expect(req.headers['x-goog-api-key'], 'secret');
      expect(
        (jsonDecode(req.body) as Map)['generationConfig']['responseMimeType'],
        'application/json',
      );
      expect(text, '{"g":1}');
    });

    test('Mistral uses its chat endpoint', () async {
      final (req, _) = await run(AiProvider.mistral, {
        'choices': [
          {
            'message': {'content': '{}'},
            'finish_reason': 'stop',
          },
        ],
      });
      expect(req.url.host, 'api.mistral.ai');
      expect((jsonDecode(req.body) as Map)['max_tokens'], 16000);
    });
  });

  group('errors', () {
    Future<AiException> failWith(
      http.Client client, {
      AiProvider provider = AiProvider.openai,
      String key = 'k',
    }) async {
      try {
        await AiClient(httpClient: client).complete(
          AiConfig(provider: provider, apiKey: key, model: 'm'),
          const AiRequest(system: 's', user: 'u'),
        );
      } on AiException catch (e) {
        return e;
      }
      fail('aucune erreur levée');
    }

    MockClient status(
      int code, [
      String body = '{"error":{"message":"détail fournisseur"}}',
    ]) => MockClient(
      (_) async => http.Response(
        body,
        code,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    test(
      'missing key, HTTP status codes and network failures are typed',
      () async {
        expect(
          (await failWith(status(200), key: '  ')).kind,
          AiErrorKind.missingKey,
        );
        final unauthorized = await failWith(status(401));
        expect(unauthorized.kind, AiErrorKind.unauthorized);
        expect(unauthorized.details, 'détail fournisseur');
        expect((await failWith(status(404))).kind, AiErrorKind.modelNotFound);
        expect((await failWith(status(429))).kind, AiErrorKind.rateLimited);
        expect((await failWith(status(400))).kind, AiErrorKind.badRequest);
        expect(
          (await failWith(status(200, 'pas du json'))).kind,
          AiErrorKind.invalidResponse,
        );
        expect(
          (await failWith(
            MockClient((_) async => throw const SocketException('dns')),
          )).kind,
          AiErrorKind.network,
        );
      },
    );

    test('server errors are retried once', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('{}', 529)
            : http.Response(
                '{"choices":[{"message":{"content":"{}"},"finish_reason":"stop"}]}',
                200,
              );
      });
      final text = await AiClient(httpClient: client).complete(
        const AiConfig(provider: AiProvider.openai, apiKey: 'k', model: 'm'),
        const AiRequest(system: 's', user: 'u'),
      );
      expect(text, '{}');
      expect(calls, 2);
    });

    test('refusals and truncation are detected for each provider', () async {
      final anthropicRefusal = await failWith(
        MockClient(
          (_) async => http.Response(
            '{"content":[],"stop_reason":"refusal","stop_details":{"explanation":"non"}}',
            200,
          ),
        ),
        provider: AiProvider.anthropic,
      );
      expect(anthropicRefusal.kind, AiErrorKind.refusal);
      final truncated = await failWith(
        MockClient(
          (_) async => http.Response(
            '{"choices":[{"message":{"content":"{"},"finish_reason":"length"}]}',
            200,
          ),
        ),
      );
      expect(truncated.kind, AiErrorKind.truncated);
      final geminiBlocked = await failWith(
        MockClient(
          (_) async =>
              http.Response('{"promptFeedback":{"blockReason":"SAFETY"}}', 200),
        ),
        provider: AiProvider.gemini,
      );
      expect(geminiBlocked.kind, AiErrorKind.refusal);
    });

    test('Anthropic retries without an option the server rejects', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        bodies.add(body);
        if (bodies.length == 1) {
          return http.Response(
            '{"error":{"type":"invalid_request_error","message":"fallbacks: unsupported for this account"}}',
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        if (bodies.length == 2) {
          return http.Response(
            '{"error":{"message":"output_config.format.schema: too complex"}}',
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"content":[{"type":"text","text":"{}"}],"stop_reason":"end_turn"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final text = await AiClient(httpClient: client).complete(
        const AiConfig(
          provider: AiProvider.anthropic,
          apiKey: 'k',
          model: 'claude-opus-5-5',
        ),
        const AiRequest(
          system: 'sys',
          user: 'u',
          jsonSchema: {'type': 'object'},
        ),
      );
      expect(text, '{}');
      expect(bodies, hasLength(3));
      expect(bodies[1].containsKey('fallbacks'), isFalse);
      expect((bodies[1]['output_config'] as Map).containsKey('format'), isTrue);
      expect(
        (bodies[2]['output_config'] as Map).containsKey('format'),
        isFalse,
      );
      expect(bodies[2]['system'], contains('schéma'));
    });

    test('unrelated bad requests are not retried', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          '{"error":{"message":"messages: invalid role"}}',
          400,
          headers: {'content-type': 'application/json'},
        );
      });
      await expectLater(
        AiClient(httpClient: client).complete(
          const AiConfig(
            provider: AiProvider.anthropic,
            apiKey: 'k',
            model: 'claude-opus-5-5',
          ),
          const AiRequest(system: 's', user: 'u'),
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.kind,
            'kind',
            AiErrorKind.badRequest,
          ),
        ),
      );
      expect(calls, 1);
    });

    test('model listing parses each provider format', () async {
      final openai = AiClient(
        httpClient: MockClient(
          (_) async => http.Response('{"data":[{"id":"b"},{"id":"a"}]}', 200),
        ),
      );
      expect(await openai.listModels(AiProvider.openai, 'k'), ['a', 'b']);
      final gemini = AiClient(
        httpClient: MockClient(
          (_) async => http.Response(
            '{"models":[{"name":"models/gemini-x","supportedGenerationMethods":["generateContent"]},{"name":"models/embed","supportedGenerationMethods":["embedContent"]}]}',
            200,
          ),
        ),
      );
      expect(await gemini.listModels(AiProvider.gemini, 'k'), ['gemini-x']);
    });
  });

  test('full generation round trip through a mocked provider, with retry on invalid JSON', () async {
    var calls = 0;
    final client = AiClient(
      httpClient: MockClient((req) async {
        calls++;
        final content = calls == 1 ? 'désolé' : designsJson;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': content},
            ],
            'stop_reason': 'end_turn',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final service = AiDesignService(client);
    final proposals = await service.generateDesigns(
      config: const AiConfig(
        provider: AiProvider.anthropic,
        apiKey: 'k',
        model: 'claude-opus-5-5',
      ),
      brief: 'Carte futuriste',
      profile: profile,
      widthMm: 85,
      heightMm: 55,
      formatLabel: 'Carte de visite',
      duplex: true,
    );
    expect(calls, 2);
    expect(proposals.single.provider, 'Anthropic Claude');
    expect(proposals.single.document.formatId, 'business-card');
  });

  test(
    'brand kit from AI JSON falls back to the profile for missing values',
    () {
      final kit = BrandKit.fromJson(
        {
          'headline': 'Réparé en 24 h',
          'primary': '#123456',
          'headingFont': 'Bebas Neue',
          'layout': 'futuriste',
          'iconKey': 'inconnu',
        },
        profile: BusinessProfile.example(),
        source: 'IA',
      );
      expect(kit.headline, 'Réparé en 24 h');
      expect(kit.primary, const Color(0xFF123456));
      expect(kit.headingFont, 'Ubuntu Condensed');
      expect(kit.layout, LayoutStyle.neon);
      expect(kit.iconKey, 'computer');
      expect(kit.slogan, 'Ton PC, notre obsession.');
    },
  );

  test('prompt helpers describe the profile and typography', () {
    expect(
      AiDesignService.profileSummary(profile),
      contains('Logo disponible : oui'),
    );
    expect(
      AiDesignService.typographyHint(const Size(85, 55)),
      contains('7 pt'),
    );
    expect(DesignSchema.designsSchema['required'], ['designs']);
  });
}
