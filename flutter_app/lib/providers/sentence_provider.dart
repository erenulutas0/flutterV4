import 'package:flutter/foundation.dart';
import '../models/sentence_practice.dart';
import '../services/api_service.dart';
import '../services/offline_storage_service.dart';
import '../models/word.dart';
import '../services/sync_service.dart';

class SentenceProvider with ChangeNotifier {
  final ApiService apiService;
  
  List<SentencePractice> _sentences = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _stats;

  SentenceProvider({required this.apiService});

  List<SentencePractice> get sentences => _sentences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get stats => _stats;

  Future<void> loadAllSentences() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Set<String> uniqueContents = {}; // Duplicate check
      List<SentencePractice> allSentences = [];
      
      // 1. Genel Cümleleri Yükle (API veya Cache)
      if (await SyncService.hasInternet()) {
        try {
          final apiSentences = await apiService.getAllSentences();
          await OfflineStorageService.cacheSentences(
            apiSentences.map((s) => s.toJson()).toList()
          );
          
          for (var s in apiSentences) {
             if (!uniqueContents.contains(s.englishSentence.trim().toLowerCase())) {
               allSentences.add(s);
               uniqueContents.add(s.englishSentence.trim().toLowerCase());
             }
          }
        } catch (e) {
          print("API fetch failed: $e");
          final cachedSentences = await OfflineStorageService.getCachedSentences();
          for (var json in cachedSentences) {
             final s = SentencePractice.fromJson(json);
             if (!uniqueContents.contains(s.englishSentence.trim().toLowerCase())) {
               allSentences.add(s);
               uniqueContents.add(s.englishSentence.trim().toLowerCase());
             }
          }
        }
      } else {
        final cachedSentences = await OfflineStorageService.getCachedSentences();
        for (var json in cachedSentences) {
           final s = SentencePractice.fromJson(json);
           if (!uniqueContents.contains(s.englishSentence.trim().toLowerCase())) {
             allSentences.add(s);
             uniqueContents.add(s.englishSentence.trim().toLowerCase());
           }
        }
      }

      // 2. Kelimelerdeki Cümleleri Yükle ve Birleştir
      try {
        List<Word> words = [];
        if (await SyncService.hasInternet()) {
           words = await apiService.getAllWords();
        } else {
           final cachedWords = await OfflineStorageService.getCachedWords();
           words = cachedWords.map((json) => Word.fromJson(json)).toList();
        }
        
        for (var word in words) {
          for (var s in word.sentences) {
            // Duplicate kontrolü
            if (uniqueContents.contains(s.sentence.trim().toLowerCase())) {
              continue;
            }
            
            allSentences.add(SentencePractice(
              id: 'word_${word.id}_${s.id}', // Benzersiz ID
              englishSentence: s.sentence,
              turkishTranslation: s.translation,
              difficulty: s.difficulty ?? 'medium',
              createdDate: word.learnedDate,
              source: 'word', // Kaynak: kelime
            ));
            uniqueContents.add(s.sentence.trim().toLowerCase());
          }
        }
      } catch (e) {
        print("Error merging word sentences: $e");
      }

      // 3. Offline (Pending) Genel Cümleleri Ekle
      final pendingSentences = await OfflineStorageService.getPendingSentences();
      
      for (var sentenceMap in pendingSentences) {
        final sentenceText = sentenceMap['sentence'] as String? ?? '';
        
        // Duplicate kontrolü
        if (uniqueContents.contains(sentenceText.trim().toLowerCase())) {
          continue;
        }

        final wordId = sentenceMap['wordId'];
        final isGeneralSentence = wordId == -1 || wordId == '-1' || wordId == null;
        final now = DateTime.now();

        if (isGeneralSentence) { 
          allSentences.add(SentencePractice(
            id: sentenceMap['tempId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            englishSentence: sentenceText,
            turkishTranslation: sentenceMap['translation'] ?? '',
            difficulty: sentenceMap['difficulty'] ?? 'medium',
            createdDate: now,
            source: 'practice',
          ));
        } else {
           allSentences.add(SentencePractice(
            id: sentenceMap['tempId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            englishSentence: sentenceText,
            turkishTranslation: sentenceMap['translation'] ?? '',
            difficulty: sentenceMap['difficulty'] ?? 'medium',
            createdDate: now,
            source: 'word',
          ));
        }
        uniqueContents.add(sentenceText.trim().toLowerCase());
      }
      
      // SORTING (Akıllı Sıralama - Tarih Odaklı)
      // 1. Önce oluşturulma/öğrenilme tarihine göre (En yeni en üstte)
      // 2. Tarih yoksa veya eşitse, ID'ye göre (Offline ID'ler en üstte)
      
      allSentences.sort((a, b) {
        // Tarih karşılaştırması
        if (a.createdDate != null && b.createdDate != null) {
           final dateCompare = b.createdDate!.compareTo(a.createdDate!);
           if (dateCompare != 0) return dateCompare;
        } else if (a.createdDate != null) {
           return -1; // a (tarihli) daha yeni / üstte
        } else if (b.createdDate != null) {
           return 1; // b (tarihli) daha yeni / üstte
        }
        
        // ID karşılaştırması (Fallback)
        int idA = _parseId(a.id);
        int idB = _parseId(b.id);
        return idB.compareTo(idA); // Descending (Büyükten küçüğe)
      });
      
      _sentences = allSentences;
      
      if (_sentences.isNotEmpty) {
        _error = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Helper to parse IDs from strings like 'word_422_15' or 'practice_123' or '1703...'
  int _parseId(String id) {
    // Timestamp kontrolü (direkt string timestamp ise)
    if (double.tryParse(id) != null) {
      return double.parse(id).toInt();
    }
    
    // Prefixli ID'ler
    if (id.startsWith('word_')) {
      final parts = id.split('_');
      // word_WORDID_SENTENCEID -> SENTENCEID döndür
      if (parts.length >= 3) {
         return int.tryParse(parts[2]) ?? 0;
      }
    }
    
    if (id.startsWith('practice_')) {
      final parts = id.split('_');
      if (parts.length >= 2) {
        return int.tryParse(parts[1]) ?? 0;
      }
    }
    
    // Normal int ID
    return int.tryParse(id) ?? 0;
  }


  Future<void> addSentence({
    required String englishSentence,
    required String turkishTranslation,
    required String difficulty,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final hasInternet = await SyncService.hasInternet();
      print('🔍 DEBUG SentenceProvider: hasInternet = $hasInternet');
      
      if (hasInternet) {
        // Online: Backend'e gönder
        final newSentence = await apiService.createSentence(
          englishSentence: englishSentence,
          turkishTranslation: turkishTranslation,
          difficulty: difficulty,
        );
        _sentences.add(newSentence);
        await loadStats();
        _error = null;
        print('✅ DEBUG: Online cümle eklendi');
      } else {
        // Offline: Lokal kaydet (genel cümle için wordId yok, -1 kullan)
        print('🔍 DEBUG: Offline cümle kaydediliyor...');
        
        await OfflineStorageService.addPendingSentence({
          'wordId': -1, // Genel cümle (kelimeye bağlı değil)
          'sentence': englishSentence,
          'translation': turkishTranslation,
          'difficulty': difficulty,
        });
        
        // UI'da göster
        final newSentence = SentencePractice(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          englishSentence: englishSentence,
          turkishTranslation: turkishTranslation,
          difficulty: difficulty,
          source: 'practice',
        );
        _sentences.add(newSentence);
        
        print('✅ DEBUG: Cümle listeye eklendi - toplam: ${_sentences.length}');
        
        _error = null;
        print('📦 Cümle offline olarak kaydedildi.');
      }
    } catch (e) {
      print('❌ DEBUG: addSentence hatası: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSentence(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (id.startsWith('word_')) {
        // Kelimeye ait bir cümle: word_WORDID_SENTENCEID
        final parts = id.split('_');
        if (parts.length >= 3) {
          final wordId = int.tryParse(parts[1]);
          final sentenceId = int.tryParse(parts[2]);
          
          if (wordId != null && sentenceId != null) {
            // Timestamp kontrolü (Offline ID mi?)
            // Normal ID'ler genelde küçüktür. Timestamp 13+ hanelidir.
            final isOfflineId = sentenceId > 1000000000;
            
            if (isOfflineId) {
              print('📦 Offline sentence deletion detected. Skipping API call.');
              // Pending'den sil (eğer varsa)
              await OfflineStorageService.removePendingSentence(sentenceId.toString());
            } else if (await SyncService.hasInternet()) {
               await apiService.deleteSentenceFromWord(wordId, sentenceId);
            } else {
               print('⚠️ Offline modda backend cümlesi silinemez, sadece listeden kaldırılıyor.');
            }
          }
        }
      } else {
        // Genel cümle silme
        String rawId = id;
        // 'practice_' prefix'i varsa temizle (SentencePractice.fromJson ekliyor)
        if (id.startsWith('practice_')) {
           final parts = id.split('_');
           if (parts.length >= 2) rawId = parts[1];
        }
        
        // 1. ID Kontrolü: Backend Long ID bekliyor, o yüzden sayısal olmalı.
        final numId = double.tryParse(rawId);
        if (numId == null) {
           print("❌ Invalid ID format (not numeric): $rawId. Skipping API call.");
           // API'ye gönderme, sadece listeden sil (aşağıda)
        } else {
           // 2. Timestamp (Offline ID) kontrolü
           // 1000000000'dan büyükse (yaklaşık 2001 yılı), timestamp kabul et
           final isOfflineId = numId > 1000000000;
           
           if (isOfflineId) {
             print('📦 Offline sentence deletion detected. Skipping API call.');
             await OfflineStorageService.removePendingSentence(id);
           } else if (await SyncService.hasInternet()) {
             try {
               // Düzeltilmiş numeric ID gönder
               await apiService.deleteSentence(rawId);
             } catch (e) {
               // Eğer 404 (yok) veya 400 (bad request) gelirse, zaten silinmiş veya geçersizdir.
               // Hatayı yut ve listeden silmeye devam et.
               print("⚠️ API delete failed ($e), but removing from list.");
               if (!e.toString().contains("400") && !e.toString().contains("404")) {
                  // Diğer hataları (örn 500) yeniden fırlatabiliriz veya kullanıcıya gösterebiliriz
                  // Şimdilik yutuyoruz, kullanıcı deneyimi bozulmasın.
               }
             }
           }
        }
      }
      
      _sentences.removeWhere((s) => s.id == id);
      await loadStats();
      
      // CRITICAL FIX: Cache'i güncelle! Silinen cümle geri gelmesin.
      await OfflineStorageService.cacheSentences(
         _sentences.map((s) => s.toJson()).toList()
      );
      
      _error = null;
    } catch (e) {
      print('❌ Error deleting sentence: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    try {
      _stats = await apiService.getSentenceStats();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

