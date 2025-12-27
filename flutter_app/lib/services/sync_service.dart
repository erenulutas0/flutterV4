import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/backend_config.dart';
import 'offline_storage_service.dart';

/// Offline verileri otomatik senkronize eden servis
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;

  /// Senkronizasyonu başlat (uygulama açılışında çağrılmalı)
  void initialize() {
    // İnternet bağlantısı değişikliklerini dinle
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        print('🌐 Internet connection detected, starting sync...');
        syncPendingData();
      }
    });

    // İlk açılışta da kontrol et
    checkAndSync();
  }

  /// İnternet varsa senkronize et
  Future<void> checkAndSync() async {
    final result = await Connectivity().checkConnectivity();
    if (result != ConnectivityResult.none) {
      await syncPendingData();
    }
  }

  /// Bekleyen tüm verileri senkronize et
  Future<void> syncPendingData() async {
    if (_isSyncing) {
      print('⏳ Sync already in progress, skipping...');
      return;
    }

    _isSyncing = true;

    try {
      await _syncPendingWords();
      await _syncPendingSentences();
      print('✅ Sync completed successfully');
    } catch (e) {
      print('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Bekleyen kelimeleri senkronize et
  Future<void> _syncPendingWords() async {
    final pendingWords = await OfflineStorageService.getPendingWords();
    
    if (pendingWords.isEmpty) {
      return;
    }

    print('📤 Syncing ${pendingWords.length} pending words...');

    for (final wordData in pendingWords) {
      try {
        final tempId = wordData['tempId'];
        final tempWordId = tempId.hashCode; // Offline'da kullanılan geçici ID
        
        // Backend'e gönder
        final response = await http.post(
          Uri.parse('${BackendConfig.apiBaseUrl}/words'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'englishWord': wordData['englishWord'],
            'turkishMeaning': wordData['turkishMeaning'],
            'learnedDate': wordData['learnedDate'],
            'difficulty': wordData['difficulty'] ?? 'medium',
            'notes': wordData['notes'] ?? '',
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          // Backend'den gerçek wordId'yi al
          final responseData = jsonDecode(response.body);
          final realWordId = responseData['id'];
          
          print('✅ Word synced: ${wordData['englishWord']} (realId: $realWordId)');
          
          // Bu kelimeye ait pending cümleleri de senkronize et
          if (realWordId != null) {
            await _syncSentencesForWord(tempWordId, realWordId);
          }
          
          // Kelimeyi pending listesinden sil
          await OfflineStorageService.removePendingWord(tempId);
        } else {
          print('❌ Failed to sync word: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error syncing word: $e');
        // Hata olursa devam et, bir sonraki sync'te tekrar denenecek
      }
    }
  }
  
  /// Belirli bir kelimeye ait cümleleri senkronize et
  Future<void> _syncSentencesForWord(int tempWordId, int realWordId) async {
    final pendingSentences = await OfflineStorageService.getPendingSentences();
    
    print('🔍 DEBUG _syncSentencesForWord: tempWordId=$tempWordId, realWordId=$realWordId');
    print('🔍 DEBUG: ${pendingSentences.length} pending sentences found');
    
    for (final sentenceData in pendingSentences) {
      final wordId = sentenceData['wordId'];
      
      print('🔍 DEBUG: Checking sentence wordId=$wordId (type: ${wordId.runtimeType}) vs tempWordId=$tempWordId');
      
      // Bu cümle bu kelimeye mi ait?
      final isMatch = wordId == tempWordId || 
                      wordId == tempWordId.toString() ||
                      wordId.toString() == tempWordId.toString();
      
      if (isMatch) {
        try {
          final tempId = sentenceData['tempId'];
          print('✅ DEBUG: Match found! Syncing sentence for word $realWordId');
          
          final response = await http.post(
            Uri.parse('${BackendConfig.apiBaseUrl}/words/$realWordId/sentences'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sentence': sentenceData['sentence'],
              'translation': sentenceData['translation'],
              'difficulty': sentenceData['difficulty'] ?? 'medium',
            }),
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            await OfflineStorageService.removePendingSentence(tempId);
            print('✅ Word sentence synced for word $realWordId');
          } else {
            print('❌ Failed to sync word sentence: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('❌ Error syncing word sentence: $e');
        }
      }
    }
  }

  /// Bekleyen cümleleri senkronize et (sadece genel cümleler)
  Future<void> _syncPendingSentences() async {
    final pendingSentences = await OfflineStorageService.getPendingSentences();
    
    if (pendingSentences.isEmpty) {
      return;
    }

    print('📤 Syncing pending sentences...');

    for (final sentenceData in pendingSentences) {
      try {
        final tempId = sentenceData['tempId'];
        final wordId = sentenceData['wordId'];
        
        // wordId kontrolü - hem int hem string kontrol et
        final isGeneralSentence = wordId == -1 || wordId == '-1' || wordId == null;
        
        if (!isGeneralSentence) {
          // Kelimeye bağlı cümle - _syncSentencesForWord ile senkronize edilecek
          // Burada atla
          continue;
        }
        
        // Genel cümle - SentencePractice endpoint'ine gönder
        final response = await http.post(
          Uri.parse('${BackendConfig.apiBaseUrl}/sentences'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'englishSentence': sentenceData['sentence'],
            'turkishTranslation': sentenceData['translation'],
            'difficulty': sentenceData['difficulty'] ?? 'medium',
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Başarılı, lokal kaydı sil
          await OfflineStorageService.removePendingSentence(tempId);
          print('✅ General sentence synced');
        } else {
          print('❌ Failed to sync sentence: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('❌ Error syncing sentence: $e');
      }
    }
  }

  /// Servisi durdur
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// İnternet bağlantısını kontrol et
  static Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
