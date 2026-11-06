import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/kanji.dart';
import '../../shared/models/study_list.dart';

class AiService {
  static const String baseUrl = 'https://kanji-kr.onrender.com';

  Future<List<Kanji>> getSuggestions({
    required String text,
    required EntryKind kind,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/suggestions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'entry_type': kind == EntryKind.word ? 'word' : 'kanji',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['suggestions'] as List)
          .map((item) => Kanji.fromJson(item))
          .toList();
    } else {
      throw Exception('AI 추천 실패: ${response.statusCode}');
    }
  }
}
