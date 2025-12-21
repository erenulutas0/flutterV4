import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/word.dart';
import '../models/sentence_practice.dart';
import '../models/word_review.dart';
import '../utils/backend_config.dart';

class ApiService {
  // Backend URL'i BackendConfig'den al
  static String get baseUrl {
    return BackendConfig.apiBaseUrl;
  }

  Future<List<Word>> getAllWords() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/words'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Word.fromJson(json)).toList();
      }
      throw Exception('Failed to load words: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching words: $e');
    }
  }

  Future<Word> getWordById(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/words/$id'));
      if (response.statusCode == 200) {
        return Word.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to load word: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching word: $e');
    }
  }

  Future<List<Word>> getWordsByDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await http.get(Uri.parse('$baseUrl/words/date/$dateStr'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Word.fromJson(json)).toList();
      }
      throw Exception('Failed to load words: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching words by date: $e');
    }
  }

  Future<List<String>> getAllDistinctDates() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/words/dates'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((date) => date.toString()).toList();
      }
      throw Exception('Failed to load dates: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching dates: $e');
    }
  }

  Future<Word> createWord({
    required String english,
    required String turkish,
    required DateTime addedDate,
    String difficulty = 'easy',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/words'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'englishWord': english,
          'turkishMeaning': turkish,
          'learnedDate': addedDate.toIso8601String().split('T')[0],
          'notes': '',
          'difficulty': difficulty,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Word.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to create word: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error creating word: $e');
    }
  }

  Future<void> deleteWord(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/words/$id'));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete word: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting word: $e');
    }
  }

  Future<Word> addSentenceToWord({
    required int wordId,
    required String sentence,
    required String translation,
    String difficulty = 'easy',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/words/$wordId/sentences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sentence': sentence,
          'translation': translation,
          'difficulty': difficulty,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Word.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to add sentence: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error adding sentence: $e');
    }
  }

  Future<void> deleteSentenceFromWord(int wordId, int sentenceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/words/$wordId/sentences/$sentenceId'),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete sentence: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting sentence: $e');
    }
  }

  Future<List<SentencePractice>> getAllSentences() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sentences'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => SentencePractice.fromJson(json)).toList();
      }
      throw Exception('Failed to load sentences: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching sentences: $e');
    }
  }

  Future<SentencePractice> createSentence({
    required String englishSentence,
    required String turkishTranslation,
    required String difficulty,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sentences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'englishSentence': englishSentence,
          'turkishTranslation': turkishTranslation,
          'difficulty': difficulty.toUpperCase(),
          'createdDate': DateTime.now().toIso8601String().split('T')[0],
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return SentencePractice.fromJson({
          'id': 'practice_${responseData['id']}',
          'englishSentence': responseData['englishSentence'],
          'turkishTranslation': responseData['turkishTranslation'],
          'difficulty': responseData['difficulty'],
          'createdDate': responseData['createdDate'],
          'source': 'practice',
        });
      }
      throw Exception('Failed to create sentence: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error creating sentence: $e');
    }
  }

  Future<void> deleteSentence(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/sentences/$id'));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete sentence: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting sentence: $e');
    }
  }

  Future<Map<String, dynamic>> getSentenceStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sentences/stats'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load stats: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching stats: $e');
    }
  }
}

