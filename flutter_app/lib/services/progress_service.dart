import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/backend_config.dart';

/// Progress and Achievement Service
class ProgressService {
  static final String _baseUrl = '${BackendConfig.apiBaseUrl}/progress';
  static const String _progressCacheKey = 'progress_stats_cache';

  /// Get user progress stats (with offline cache)
  static Future<ProgressStats?> getStats() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/stats'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = ProgressStats.fromJson(data);
        
        // Cache'e kaydet
        await _cacheStats(stats);
        
        return stats;
      } else {
        print('Failed to get progress stats: ${response.statusCode}');
        // Offline: Cache'den yükle
        return await getCachedStats();
      }
    } catch (e) {
      print('Error getting progress stats: $e');
      // Offline: Cache'den yükle
      return await getCachedStats();
    }
  }
  
  /// Cache'e kaydet
  static Future<void> _cacheStats(ProgressStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'totalXp': stats.totalXp,
      'level': stats.level,
      'currentStreak': stats.currentStreak,
      'longestStreak': stats.longestStreak,
      'xpForNextLevel': stats.xpForNextLevel,
      'levelProgress': stats.levelProgress,
      'achievementsUnlocked': stats.achievementsUnlocked,
      'achievementsTotal': stats.achievementsTotal,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_progressCacheKey, jsonEncode(cacheData));
    print('💾 Progress stats cached: Level ${stats.level}, ${stats.totalXp} XP');
  }
  
  /// Cache'den oku
  static Future<ProgressStats?> getCachedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_progressCacheKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    
    try {
      final data = Map<String, dynamic>.from(jsonDecode(jsonString));
      print('📦 Loaded progress stats from cache');
      return ProgressStats.fromJson(data);
    } catch (e) {
      print('❌ Error decoding cached progress: $e');
      return null;
    }
  }

  /// Get all achievements (locked and unlocked)
  static Future<List<AchievementModel>> getAllAchievements() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/achievements'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AchievementModel.fromJson(json)).toList();
      } else {
        print('Failed to get achievements: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting achievements: $e');
      return [];
    }
  }

  /// Get only unlocked achievements
  static Future<List<AchievementModel>> getUnlockedAchievements() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/achievements/unlocked'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AchievementModel.fromJson(json)).toList();
      } else {
        print('Failed to get unlocked achievements: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting unlocked achievements: $e');
      return [];
    }
  }

  /// Check for new achievements
  static Future<List<AchievementModel>> checkAchievements() async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/check-achievements'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AchievementModel.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error checking achievements: $e');
      return [];
    }
  }
}

/// Progress Stats Model
class ProgressStats {
  final int totalXp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final int xpForNextLevel;
  final double levelProgress;
  final int achievementsUnlocked;
  final int achievementsTotal;

  ProgressStats({
    required this.totalXp,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.xpForNextLevel,
    required this.levelProgress,
    required this.achievementsUnlocked,
    required this.achievementsTotal,
  });

  factory ProgressStats.fromJson(Map<String, dynamic> json) {
    return ProgressStats(
      totalXp: json['totalXp'] ?? 0,
      level: json['level'] ?? 1,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      xpForNextLevel: json['xpForNextLevel'] ?? 100,
      levelProgress: (json['levelProgress'] ?? 0.0).toDouble(),
      achievementsUnlocked: json['achievementsUnlocked'] ?? 0,
      achievementsTotal: json['achievementsTotal'] ?? 0,
    );
  }

  /// Get XP in current level
  int get xpInCurrentLevel => (xpForNextLevel * levelProgress).round();
}

/// Achievement Model
class AchievementModel {
  final String code;
  final String title;
  final String description;
  final int xpReward;
  final String icon;
  final bool unlocked;
  final DateTime? unlockedAt;

  AchievementModel({
    required this.code,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.icon,
    this.unlocked = false,
    this.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      code: json['code'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      xpReward: json['xpReward'] ?? 0,
      icon: json['icon'] ?? '🏆',
      unlocked: json['unlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.parse(json['unlockedAt']) 
          : null,
    );
  }
}
