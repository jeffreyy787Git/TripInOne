import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiChatService {
  final String? _apiKey = dotenv.env['AZURE_OPENAI_KEY'];
  final String? _endpoint = dotenv.env['AZURE_OPENAI_ENDPOINT'];
  final List<Map<String, String>> _messages = [];

  AiChatService() {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('AZURE_OPENAI_KEY not found in .env file');
    }
    if (_endpoint == null || _endpoint!.isEmpty) {
      throw Exception('AZURE_OPENAI_ENDPOINT not found in .env file');
    }

    _messages.add({
      'role': 'system',
      'content': 'You are a professional travel planner. Please help the user plan their trip, providing specific suggestions and schedule。'
            'Follow these guidelines:\n'
            '1. Provide a reasonable schedule\n'
            '2. Consider traffic times\n'
            '3. Suggest suitable dining times and locations\n'
            '4. Consider the opening hours of the attractions\n'
            '5. Provide specific suggestions for attractions\n'
            'Please answer in English.'
    });
  }

  Future<String> sendMessage(String message) async {
    try {
      _messages.add({
        'role': 'user',
        'content': message,
      });

      final url = Uri.parse('https://tripinoneai.openai.azure.com/openai/deployments/gpt-35-turbo/chat/completions?api-version=2024-08-01-preview');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': _apiKey!,
        },
        body: jsonEncode({
          'messages': _messages,
          'temperature': 0.7,
          'max_tokens': 800,
        }),
      );

      if (response.statusCode != 200) {
        print('Error response: ${response.body}');
        printLastResponse(response);
        throw Exception('API call failed with status: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['choices'] == null || 
          jsonResponse['choices'].isEmpty ||
          jsonResponse['choices'][0]['message'] == null) {
        throw Exception('Invalid response format');
      }

      final responseMessage = jsonResponse['choices'][0]['message']['content'];
      
      _messages.add({
        'role': 'assistant',
        'content': responseMessage,
      });

      return responseMessage;
    } catch (e) {
      print('Error sending message to AI: $e');
      throw Exception('Failed to get AI response: ${e.toString()}');
    }
  }

  void printLastResponse(http.Response response) {
    print('Status code: ${response.statusCode}');
    print('Headers: ${response.headers}');
    print('Body: ${response.body}');
  }
} 