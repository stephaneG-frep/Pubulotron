import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pubulotron/services/ai_service.dart';

void main() {
  const apiKey = 'test-secret-key';

  test('connection test calls the provider model-list endpoint', () async {
    final providers = {
      'OpenAI': 'api.openai.com',
      'Claude': 'api.anthropic.com',
      'Gemini': 'generativelanguage.googleapis.com',
      'Mistral': 'api.mistral.ai',
    };

    for (final entry in providers.entries) {
      http.Request? capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200);
      });

      await AiService.testConnection(entry.key, apiKey, client: client);

      expect(capturedRequest?.url.host, entry.value);
      expect(capturedRequest?.method, 'GET');
      if (entry.key == 'Gemini') {
        expect(capturedRequest?.url.queryParameters['key'], apiKey);
      } else if (entry.key == 'Claude') {
        expect(capturedRequest?.headers['x-api-key'], apiKey);
      } else {
        expect(capturedRequest?.headers['authorization'], 'Bearer $apiKey');
      }
      client.close();
    }
  });

  test('connection test reports rejected credentials', () {
    final client = MockClient((_) async => http.Response('unauthorized', 401));

    expect(
      AiService.testConnection('OpenAI', apiKey, client: client),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          contains('401'),
        ),
      ),
    );
    client.close();
  });

  test('connection test requires a key and known provider', () {
    expect(AiService.testConnection('OpenAI', ''), throwsFormatException);
    expect(AiService.testConnection('Unknown', apiKey), throwsFormatException);
  });
}
