import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline veri saklama servisi
/// İnternet olmadığında kelime ve cümleleri lokal olarak saklar
class OfflineStorageService {
  static const String _pendingWordsKey = 'pending_words';
  static const String _pendingSentencesKey = 'pending_sentences';
  
  // CACHE KEYS - Online'dan gelen verileri saklamak için
  static const String _cachedWordsKey = 'cached_words';
  static const String _cachedSentencesKey = 'cached_sentences';
  static const String _cachedDatesKey = 'cached_dates';

  // ==================== PENDING (Bekleyen) İşlemler ====================
  
  /// Offline kelime ekle
  static Future<void> addPendingWord(Map<String, dynamic> wordData) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingWords = await getPendingWords();
    
    // Benzersiz ID ekle (timestamp bazlı)
    wordData['tempId'] = DateTime.now().millisecondsSinceEpoch.toString();
    
    pendingWords.add(wordData);
    await prefs.setString(_pendingWordsKey, jsonEncode(pendingWords));
    
    print('📦 Offline word saved: ${wordData['englishWord']}');
  }
  
  /// Offline kelime ekle (belirli tempId ile)
  static Future<void> addPendingWordWithId(String tempId, Map<String, dynamic> wordData) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingWords = await getPendingWords();
    
    wordData['tempId'] = tempId;
    
    pendingWords.add(wordData);
    await prefs.setString(_pendingWordsKey, jsonEncode(pendingWords));
    
    print('📦 Offline word saved with tempId $tempId: ${wordData['englishWord']}');
  }

  /// Offline cümle ekle
  static Future<void> addPendingSentence(Map<String, dynamic> sentenceData) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSentences = await getPendingSentences();
    
    sentenceData['tempId'] = DateTime.now().millisecondsSinceEpoch.toString();
    
    pendingSentences.add(sentenceData);
    await prefs.setString(_pendingSentencesKey, jsonEncode(pendingSentences));
    
    print('📦 Offline sentence saved');
  }

  /// Bekleyen kelimeleri getir
  static Future<List<Map<String, dynamic>>> getPendingWords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pendingWordsKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('❌ Error decoding pending words: $e');
      return [];
    }
  }

  /// Bekleyen cümleleri getir
  static Future<List<Map<String, dynamic>>> getPendingSentences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pendingSentencesKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('❌ Error decoding pending sentences: $e');
      return [];
    }
  }

  /// Kelimeyi başarılı senkronizasyon sonrası sil
  static Future<void> removePendingWord(String tempId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingWords = await getPendingWords();
    
    pendingWords.removeWhere((word) => word['tempId'] == tempId);
    await prefs.setString(_pendingWordsKey, jsonEncode(pendingWords));
    
    print('✅ Pending word removed: $tempId');
  }

  /// Cümleyi başarılı senkronizasyon sonrası sil
  static Future<void> removePendingSentence(String tempId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingSentences = await getPendingSentences();
    
    pendingSentences.removeWhere((sentence) => sentence['tempId'] == tempId);
    await prefs.setString(_pendingSentencesKey, jsonEncode(pendingSentences));
    
    print('✅ Pending sentence removed: $tempId');
  }

  /// Tüm bekleyen verileri temizle
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingWordsKey);
    await prefs.remove(_pendingSentencesKey);
    print('🗑️ All pending data cleared');
  }

  /// Bekleyen veri sayısını getir
  static Future<int> getPendingCount() async {
    final words = await getPendingWords();
    final sentences = await getPendingSentences();
    return words.length + sentences.length;
  }
  
  // ==================== CACHE (Önbellek) İşlemleri ====================
  
  /// Kelimeleri cache'e kaydet (online'dan alındığında çağrılır)
  static Future<void> cacheWords(List<Map<String, dynamic>> words) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedWordsKey, jsonEncode(words));
    print('💾 ${words.length} words cached for offline use');
  }
  
  /// Cache'deki kelimeleri getir
  static Future<List<Map<String, dynamic>>> getCachedWords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cachedWordsKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('❌ Error decoding cached words: $e');
      return [];
    }
  }
  
  /// Cümleleri cache'e kaydet
  static Future<void> cacheSentences(List<Map<String, dynamic>> sentences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedSentencesKey, jsonEncode(sentences));
    print('💾 ${sentences.length} sentences cached for offline use');
  }
  
  /// Cache'deki cümleleri getir
  static Future<List<Map<String, dynamic>>> getCachedSentences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cachedSentencesKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('❌ Error decoding cached sentences: $e');
      return [];
    }
  }
  
  /// Tarihleri cache'e kaydet
  static Future<void> cacheDates(List<String> dates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedDatesKey, jsonEncode(dates));
    print('💾 ${dates.length} dates cached');
  }
  
  /// Cache'deki tarihleri getir
  static Future<List<String>> getCachedDates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cachedDatesKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      print('❌ Error decoding cached dates: $e');
      return [];
    }
  }
  
  // ==================== HOME STATS CACHE ====================
  static const String _homeStatsKey = 'home_stats_cache';
  
  /// Ana sayfa istatistiklerini cache'e kaydet
  static Future<void> cacheHomeStats({
    required int totalWords,
    required int todayWords,
    required int streakDays,
    required int xp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final statsData = {
      'totalWords': totalWords,
      'todayWords': todayWords,
      'streakDays': streakDays,
      'xp': xp,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_homeStatsKey, jsonEncode(statsData));
    print('💾 Home stats cached: $totalWords words, $xp XP');
  }
  
  /// Cache'deki ana sayfa istatistiklerini getir
  static Future<Map<String, dynamic>?> getCachedHomeStats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_homeStatsKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonString));
    } catch (e) {
      print('❌ Error decoding cached home stats: $e');
      return null;
    }
  }
}
