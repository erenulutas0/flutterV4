import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/backend_config.dart';
import '../models/word.dart';

/// Spaced Repetition System (SRS) Service
/// Handles communication with backend SRS endpoints
class SRSService {
  static final String _baseUrl = '${BackendConfig.apiBaseUrl}/srs';

  /// Get words that need review today
  static Future<List<Word>> getReviewWords() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/review-words'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Word.fromJson(json)).toList();
      } else {
        print('Failed to get review words: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting review words: $e');
      return [];
    }
  }

  /// Submit a review result
  /// 
  /// [wordId] - ID of the word being reviewed
  /// [quality] - Quality of recall (0-5)
  ///   0: Complete blackout
  ///   1: Incorrect, but correct answer remembered
  ///   2: Incorrect, but correct answer seemed easy
  ///   3: Correct, but required significant difficulty
  ///   4: Correct, after some hesitation
  ///   5: Perfect response
  static Future<Word?> submitReview(int wordId, int quality) async {
    if (quality < 0 || quality > 5) {
      print('Invalid quality: $quality (must be 0-5)');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/submit-review'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'wordId': wordId,
          'quality': quality,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Word.fromJson(data);
      } else {
        print('Failed to submit review: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error submitting review: $e');
      return null;
    }
  }

  /// Get SRS statistics
  /// Returns a map with:
  ///   - dueToday: Number of words due for review today
  ///   - totalWords: Total number of words
  ///   - reviewedWords: Number of words that have been reviewed at least once
  static Future<SRSStats?> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SRSStats.fromJson(data);
      } else {
        print('Failed to get SRS stats: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting SRS stats: $e');
      return null;
    }
  }
}

/// SRS Statistics Model
class SRSStats {
  final int dueToday;
  final int totalWords;
  final int reviewedWords;

  SRSStats({
    required this.dueToday,
    required this.totalWords,
    required this.reviewedWords,
  });

  factory SRSStats.fromJson(Map<String, dynamic> json) {
    return SRSStats(
      dueToday: json['dueToday'] ?? 0,
      totalWords: json['totalWords'] ?? 0,
      reviewedWords: json['reviewedWords'] ?? 0,
    );
  }

  /// Calculate review progress percentage
  double get progressPercentage {
    if (totalWords == 0) return 0.0;
    return (reviewedWords / totalWords) * 100;
  }

  /// Get remaining words to review today
  int get remainingToday => dueToday;

  /// Check if there are words to review
  bool get hasWordsToReview => dueToday > 0;
}
