import 'package:flutter/foundation.dart';
import '../models/word.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/offline_storage_service.dart';

class WordProvider with ChangeNotifier {
  final ApiService apiService;
  
  List<Word> _words = [];
  List<String> _dates = [];
  bool _isLoading = false;
  String? _error;

  WordProvider({required this.apiService});

  List<Word> get words => _words;
  List<String> get dates => _dates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllWords() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (await SyncService.hasInternet()) {
        _words = await apiService.getAllWords();
        // Cache'e kaydet (offline için)
        await OfflineStorageService.cacheWords(
          _words.map((w) => w.toJson()).toList()
        );
      } else {
        // Offline: Cache'den yükle
        final cachedWords = await OfflineStorageService.getCachedWords();
        _words = cachedWords.map((json) => Word.fromJson(json)).toList();
        print('📦 Loaded ${_words.length} words from cache');
      }
      
      // Pending kelimeleri de ekle
      final pendingWords = await OfflineStorageService.getPendingWords();
      for (var wordMap in pendingWords) {
        _words.add(Word(
          id: wordMap['tempId'].hashCode,
          englishWord: wordMap['englishWord'],
          turkishMeaning: wordMap['turkishMeaning'],
          learnedDate: DateTime.parse(wordMap['learnedDate']),
          difficulty: wordMap['difficulty'] ?? 'easy',
          notes: wordMap['notes'],
          sentences: [],
        ));
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Word?> loadWordById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Word? resultWord;
      bool fromApi = false;

      // 1. Online Dene (İnternet varsa)
      if (await SyncService.hasInternet()) {
        try {
          final word = await apiService.getWordById(id);
          
          // API'den geldi, _words listesini güncelle
          final index = _words.indexWhere((w) => w.id == id);
          if (index != -1) {
            _words[index] = word;
          }
          
          resultWord = word;
          fromApi = true;
        } catch (e) {
          print("API error in loadWordById, falling back to cache: $e");
          // Hata durumunda (404 vs) devam et -> Offline/Cache bakacak
        }
      }

      // 2. Eğer API'den gelmediyse (veya hata verdiyse), Offline/Cache'den bak
      if (resultWord == null) {
        // Önce ram'deki listede ara
        final existingWord = _words.firstWhere(
          (w) => w.id == id,
          orElse: () => Word(id: -1, englishWord: '', turkishMeaning: '', learnedDate: DateTime.now(), difficulty: 'easy'),
        );
        
        if (existingWord.id != -1) {
          resultWord = existingWord;
        } else {
          // Cache'den ara
          final cachedWords = await OfflineStorageService.getCachedWords();
          final cachedWord = cachedWords.firstWhere(
            (w) => w['id'] == id,
            orElse: () => {},
          );
          
          if (cachedWord.isNotEmpty) {
            resultWord = Word.fromJson(cachedWord);
            
            // Pending listesinde bu kelimenin offline hali var mı? (Offline eklenip henüz sync olmamış)
            // Bu kısım çok kritik değil çünkü loadWordsByDate zaten pendingleri _words'e ekliyor.
          }
        }
      }

      // 3. Pending Cümleleri Merge Et (Çok Önemli!)
      // Kelime API'den gelse bile, offline'da eklediğimiz ve henüz gitmemiş cümleler olabilir.
      if (resultWord != null) {
        final pendingSentences = await OfflineStorageService.getPendingSentences();
        
        // Bu kelimeye ait pending cümleleri bul
        // Hem gerçek ID hem de varsa tempID kontrolü gerekebilir ama sentence wordId'si genelde int tutuluyor.
        // Eğer kelime offline ise ID'si tempID olabilir.
        
        final wordSentences = pendingSentences.where((s) {
          final sWordId = s['wordId'];
          // String/int dönüşümüne dikkat
          return sWordId.toString() == resultWord!.id.toString();
        }).toList();
        
        if (wordSentences.isNotEmpty) {
           print('📦 Merging ${wordSentences.length} pending sentences into word ${resultWord.id}');
           
           final currentSentences = List<Sentence>.from(resultWord.sentences);
           
           for (var ps in wordSentences) {
             // Duplicate check
             final sText = ps['sentence'] as String;
             if (!currentSentences.any((s) => s.sentence.trim().toLowerCase() == sText.trim().toLowerCase())) {
               currentSentences.add(Sentence(
                 id: int.tryParse(ps['tempId'] ?? '0') ?? 0, // Geçici ID
                 wordId: resultWord.id,
                 sentence: sText,
                 translation: ps['translation'],
                 difficulty: ps['difficulty'],
               ));
             }
           }
           
           // Kelimeyi güncel cümle listesiyle yeniden oluştur
           resultWord = Word(
             id: resultWord.id,
             englishWord: resultWord.englishWord,
             turkishMeaning: resultWord.turkishMeaning,
             learnedDate: resultWord.learnedDate,
             notes: resultWord.notes,
             difficulty: resultWord.difficulty,
             sentences: currentSentences,
           );
           
           // Bellekteki listeyi de güncelle ki UI yenilensin
            final index = _words.indexWhere((w) => w.id == resultWord!.id);
            if (index != -1) {
              _words[index] = resultWord!;
            }
        }
      }

      return resultWord;

    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWordsByDate(DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Online verileri çekmeye çalış (İnternet varsa)
      if (await SyncService.hasInternet()) {
        try {
          _words = await apiService.getWordsByDate(date);
          // Cache'e kaydet
          final allWords = await apiService.getAllWords();
          await OfflineStorageService.cacheWords(
            allWords.map((w) => w.toJson()).toList()
          );
        } catch (e) {
          print("API fetch failed: $e");
          // Online başarısız, cache'den dene
          final cachedWords = await OfflineStorageService.getCachedWords();
          _words = cachedWords
              .map((json) => Word.fromJson(json))
              .where((w) => w.learnedDate.year == date.year && 
                           w.learnedDate.month == date.month && 
                           w.learnedDate.day == date.day)
              .toList();
        }
      } else {
        // Offline: Cache'den yükle
        final cachedWords = await OfflineStorageService.getCachedWords();
        _words = cachedWords
            .map((json) => Word.fromJson(json))
            .where((w) => w.learnedDate.year == date.year && 
                         w.learnedDate.month == date.month && 
                         w.learnedDate.day == date.day)
            .toList();
        print('📦 Offline: Loaded ${_words.length} cached words for date');
      }

      // 2. Offline (bekleyen) kelimeleri listeye ekle
      final pendingWords = await OfflineStorageService.getPendingWords();
      print('📦 Offline: ${pendingWords.length} pending words found');
      
      final pendingForDate = pendingWords.where((wordMap) {
         try {
           final wDate = DateTime.parse(wordMap['learnedDate']);
           return wDate.year == date.year && 
                  wDate.month == date.month && 
                  wDate.day == date.day;
         } catch (e) {
           return false;
         }
      }).map((wordMap) {
         // TempId'yi ID olarak kullan
         int id = 0;
         if (wordMap['tempId'] != null) {
            // String hash code'u int ID olarak kullan (unique olması için)
            id = wordMap['tempId'].hashCode;
         }
         
         return Word(
            id: id,
            englishWord: wordMap['englishWord'],
            turkishMeaning: wordMap['turkishMeaning'],
            learnedDate: DateTime.parse(wordMap['learnedDate']),
            difficulty: wordMap['difficulty'] ?? 'easy',
            notes: wordMap['notes'],
            sentences: [] // Şimdilik boş cümle listesi
         );
      }).toList();
      
      print('📦 Offline: ${pendingForDate.length} words for selected date');
      for (var pw in pendingForDate) {
         if (!_words.any((w) => w.englishWord.toLowerCase() == pw.englishWord.toLowerCase())) {
            _words.add(pw);
         }
      }
      
      // Eğer listede veri varsa hatayı temizle, kullanıcı içeriği görsün
      if (_words.isNotEmpty) {
        _error = null;
      } else if (!await SyncService.hasInternet()) {
        // Liste boş ve internet yoksa bilgilendirme yap
        // _error = "İnternet yok. Offline kelime ekleyebilirsiniz."; 
        // Hata yerine boş liste göstermek daha temiz
      }
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDistinctDates() async {
    try {
      List<String> apiDates = [];
      
      // 1. Online tarihleri çek
      if (await SyncService.hasInternet()) {
        try {
          apiDates = await apiService.getAllDistinctDates();
          // Cache'e kaydet
          await OfflineStorageService.cacheDates(apiDates);
        } catch (e) {
          print("API date fetch failed: $e");
          // Cache'den dene
          apiDates = await OfflineStorageService.getCachedDates();
        }
      } else {
        // Offline: Cache'den yükle
        apiDates = await OfflineStorageService.getCachedDates();
        print('📦 Offline: Loaded ${apiDates.length} cached dates');
      }
      
      _dates = apiDates;
      
      // 2. Offline kelimelerin tarihlerini ekle
      final pendingWords = await OfflineStorageService.getPendingWords();
      for (var w in pendingWords) {
         try {
           final dt = DateTime.parse(w['learnedDate']);
           final dateStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
           if (!_dates.contains(dateStr)) {
              _dates.add(dateStr);
           }
         } catch (e) {
           // Tarih parse hatası olursa atla
         }
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addWord({
    required String english,
    required String turkish,
    required DateTime addedDate,
    String difficulty = 'easy',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // İnternet kontrolü
      final hasInternet = await SyncService.hasInternet();
      
      if (hasInternet) {
        // Online: Direkt backend'e gönder
        final newWord = await apiService.createWord(
          english: english,
          turkish: turkish,
          addedDate: addedDate,
          difficulty: difficulty,
        );
        _words.add(newWord);
        await loadDistinctDates();
        _error = null;
      } else {
        // Offline: Lokal olarak kaydet
        // Aynı tempId'yi hem storage hem UI için kullan
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        
        await OfflineStorageService.addPendingWordWithId(tempId, {
          'englishWord': english,
          'turkishMeaning': turkish,
          'learnedDate': addedDate.toIso8601String(),
          'difficulty': difficulty,
          'notes': '',
        });
        
        // UI'da göster (aynı tempId ile)
        _words.add(Word(
          id: tempId.hashCode, // tempId.hashCode = consistent ID
          englishWord: english,
          turkishMeaning: turkish,
          learnedDate: addedDate,
          difficulty: difficulty,
          notes: '',
          sentences: [],
        ));
        
        print('🔍 DEBUG: Offline kelime eklendi - tempId: $tempId, UI id: ${tempId.hashCode}');
        
        // Tarihleri güncelle (takvimde nokta çıksın)
        await loadDistinctDates();
        
        _error = null;
        // Kullanıcıya bilgi ver
        print('📦 Kelime offline olarak kaydedildi. İnternet bağlantısı gelince otomatik gönderilecek.');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteWord(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.deleteWord(id);
      _words.removeWhere((word) => word.id == id);
      await loadDistinctDates();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSentenceToWord({
    required int wordId,
    required String sentence,
    required String translation,
    String difficulty = 'easy',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // İnternet kontrolü
      final hasInternet = await SyncService.hasInternet();
      
      if (hasInternet) {
        // Online: Direkt backend'e gönder
        final updatedWord = await apiService.addSentenceToWord(
          wordId: wordId,
          sentence: sentence,
          translation: translation,
          difficulty: difficulty,
        );
        final index = _words.indexWhere((w) => w.id == wordId);
        if (index != -1) {
          _words[index] = updatedWord;
        }
        _error = null;
      } else {
        // Offline: Lokal olarak kaydet
        print('🔍 DEBUG: Offline cümle ekleniyor - wordId: $wordId');
        
        await OfflineStorageService.addPendingSentence({
          'wordId': wordId,
          'sentence': sentence,
          'translation': translation,
          'difficulty': difficulty,
        });
        
        // UI'da da göster (geçici olarak kelimeye ekle)
        final wordIndex = _words.indexWhere((w) => w.id == wordId);
        print('🔍 DEBUG: wordIndex: $wordIndex, _words count: ${_words.length}');
        
        if (wordIndex != -1) {
          final word = _words[wordIndex];
          final updatedSentences = List<Sentence>.from(word.sentences);
          updatedSentences.add(Sentence(
            id: DateTime.now().millisecondsSinceEpoch,
            wordId: wordId,
            sentence: sentence,
            translation: translation,
            difficulty: difficulty,
          ));
          _words[wordIndex] = Word(
            id: word.id,
            englishWord: word.englishWord,
            turkishMeaning: word.turkishMeaning,
            learnedDate: word.learnedDate,
            notes: word.notes,
            difficulty: word.difficulty,
            sentences: updatedSentences,
          );
          print('✅ DEBUG: Cümle kelimeye eklendi - yeni cümle sayısı: ${updatedSentences.length}');
          
          // CRITICAL FIX: Offline cache'i güncelle!
          // Sadece ram'deki _words listesini güncellemek yetmez, tekrar cache'e yazmalıyız.
          await OfflineStorageService.cacheWords(
            _words.map((w) => w.toJson()).toList()
          );
          print('✅ DEBUG: Offline cache güncellendi.');
          
        } else {
          print('❌ DEBUG: Kelime bulunamadı! wordId: $wordId');
        }
        
        _error = null;
        print('📦 Cümle offline olarak kaydedildi. İnternet bağlantısı gelince otomatik gönderilecek.');
      }
    } catch (e) {
      print('❌ DEBUG: addSentenceToWord hatası: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSentenceFromWord(int wordId, int sentenceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.deleteSentenceFromWord(wordId, sentenceId);
      final wordIndex = _words.indexWhere((w) => w.id == wordId);
      if (wordIndex != -1) {
        final word = _words[wordIndex];
        final updatedSentences = word.sentences
            .where((s) => s.id != sentenceId)
            .toList();
        _words[wordIndex] = Word(
          id: word.id,
          englishWord: word.englishWord,
          turkishMeaning: word.turkishMeaning,
          learnedDate: word.learnedDate,
          notes: word.notes,
          difficulty: word.difficulty,
          sentences: updatedSentences,
        );
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

