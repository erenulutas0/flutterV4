# 🚀 VocabMaster - Implementation Plan

## Başlamadan Önce Hazırlık

### 1. Database Migration Setup
Backend projenizde Flyway veya Liquibase migration sistemi yok gibi görünüyor. Migration dosyalarını manuel çalıştırmanız gerekecek.

**Seçenek 1: Manuel SQL (Önerilen - Hızlı Başlangıç)**
```bash
# PostgreSQL'e bağlan
psql -U postgres -d englishapp

# Migration dosyalarını sırayla çalıştır
\i backend/src/main/resources/db/migration/V002__srs_fields.sql
\i backend/src/main/resources/db/migration/V003__gamification.sql
```

**Seçenek 2: Flyway Ekle (Production için önerilen)**
```xml
<!-- pom.xml'e ekle -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
```

```properties
# application.properties'e ekle
spring.flyway.enabled=true
spring.flyway.baseline-on-migrate=true
```

### 2. Git Branch Stratejisi
```bash
git checkout -b feature/srs-system
git checkout -b feature/gamification
git checkout -b feature/ui-improvements
```

---

## 📋 SPRINT 1: UI/UX Temelleri (3-5 Gün)

### Hedef
Kullanıcı deneyimini acil olarak iyileştir. Text overflow, empty states, loading states.

### Görevler

#### 1.1 Empty State Widget Oluştur
**Dosya:** `flutter_app/lib/widgets/empty_state.dart`

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Kullanım:**
```dart
// sentences_screen.dart içinde
if (sentences.isEmpty)
  EmptyState(
    icon: Icons.speaker_notes_off,
    title: 'Henüz cümle eklemedin!',
    message: '🦉 Owen seninle ilk cümlenizi kurmayı bekliyor!',
    actionText: 'İlk Cümleni Ekle',
    onAction: () => _showAddSentenceDialog(),
  )
```

#### 1.2 Text Overflow Düzeltmeleri
**Dosya:** `flutter_app/lib/screens/words_screen.dart`

Satır 411-614 arasındaki `_buildWordCard` metodunda:
- Sentence listesinde `maxLines: 2` ve `overflow: TextOverflow.ellipsis` ekle
- Uzun cümleler için "Devamını Gör" butonu

#### 1.3 Loading Skeleton
**Dosya:** `flutter_app/lib/widgets/loading_skeleton.dart`

```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class WordCardSkeleton extends StatelessWidget {
  const WordCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: AppTheme.darkSurfaceVariant,
          highlightColor: AppTheme.gray700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 20,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 16,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**pubspec.yaml'a ekle:**
```yaml
dependencies:
  shimmer: ^3.0.0
```

### Test Checklist
- [ ] Empty state'ler tüm ekranlarda çalışıyor mu?
- [ ] Uzun cümleler taşmıyor mu?
- [ ] Loading sırasında skeleton görünüyor mu?
- [ ] Hata durumları user-friendly mi?

---

## 📋 SPRINT 2: Grammar Check UI (3-4 Gün)

### Hedef
Mevcut `GrammarCheckService`'i UI'a entegre et. Kullanıcı cümle yazarken real-time feedback.

### Görevler

#### 2.1 Grammar Service Wrapper
**Dosya:** `flutter_app/lib/services/grammar_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

class GrammarService {
  static Future<GrammarCheckResult> checkGrammar(String sentence) async {
    try {
      final response = await http.post(
        Uri.parse('${BackendConfig.baseUrl}/api/grammar/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sentence': sentence}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GrammarCheckResult.fromJson(data);
      } else {
        return GrammarCheckResult.noError();
      }
    } catch (e) {
      print('Grammar check error: $e');
      return GrammarCheckResult.noError();
    }
  }
}

class GrammarCheckResult {
  final bool hasErrors;
  final List<GrammarError> errors;

  GrammarCheckResult({
    required this.hasErrors,
    required this.errors,
  });

  factory GrammarCheckResult.fromJson(Map<String, dynamic> json) {
    return GrammarCheckResult(
      hasErrors: json['hasErrors'] ?? false,
      errors: (json['errors'] as List?)
          ?.map((e) => GrammarError.fromJson(e))
          .toList() ?? [],
    );
  }

  factory GrammarCheckResult.noError() {
    return GrammarCheckResult(hasErrors: false, errors: []);
  }
}

class GrammarError {
  final String message;
  final String shortMessage;
  final int fromPos;
  final int toPos;
  final List<String> suggestions;

  GrammarError({
    required this.message,
    required this.shortMessage,
    required this.fromPos,
    required this.toPos,
    required this.suggestions,
  });

  factory GrammarError.fromJson(Map<String, dynamic> json) {
    return GrammarError(
      message: json['message'] ?? '',
      shortMessage: json['shortMessage'] ?? '',
      fromPos: json['fromPos'] ?? 0,
      toPos: json['toPos'] ?? 0,
      suggestions: (json['suggestions'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }
}
```

#### 2.2 Backend Controller Ekle
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/controller/GrammarController.java`

```java
package com.ingilizce.calismaapp.controller;

import com.ingilizce.calismaapp.service.GrammarCheckService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/grammar")
@CrossOrigin(origins = "*")
public class GrammarController {
    
    @Autowired
    private GrammarCheckService grammarCheckService;
    
    @PostMapping("/check")
    public Map<String, Object> checkGrammar(@RequestBody Map<String, String> request) {
        String sentence = request.get("sentence");
        return grammarCheckService.checkGrammar(sentence);
    }
}
```

#### 2.3 Grammar Suggestion Widget
**Dosya:** `flutter_app/lib/widgets/grammar_suggestion.dart`

```dart
import 'package:flutter/material.dart';
import '../services/grammar_service.dart';
import '../theme/app_theme.dart';

class GrammarSuggestion extends StatelessWidget {
  final GrammarError error;
  final VoidCallback onApply;

  const GrammarSuggestion({
    super.key,
    required this.error,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withOpacity(0.1),
        border: Border.all(color: AppTheme.accentOrange, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: AppTheme.accentOrange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.shortMessage.isNotEmpty 
                    ? error.shortMessage 
                    : error.message,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (error.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: error.suggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion),
                  onPressed: onApply,
                  backgroundColor: AppTheme.accentGreen.withOpacity(0.2),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
```

#### 2.4 Sentences Screen'e Entegre Et
**Dosya:** `flutter_app/lib/screens/sentences_screen.dart`

Cümle ekleme dialog'unda:
```dart
// _showAddSentenceDialog metoduna ekle:
GrammarCheckResult? _grammarResult;
Timer? _debounceTimer;

TextField(
  controller: sentenceController,
  onChanged: (text) {
    // Debounce - 1 saniye sonra check et
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(seconds: 1), () async {
      if (text.trim().isNotEmpty) {
        final result = await GrammarService.checkGrammar(text);
        setState(() {
          _grammarResult = result;
        });
      }
    });
  },
  // ...
),

// Grammar suggestions göster
if (_grammarResult != null && _grammarResult!.hasErrors)
  ...(_grammarResult!.errors.map((error) => 
    GrammarSuggestion(
      error: error,
      onApply: () {
        // Apply suggestion
        if (error.suggestions.isNotEmpty) {
          String text = sentenceController.text;
          String newText = text.substring(0, error.fromPos) +
              error.suggestions.first +
              text.substring(error.toPos);
          sentenceController.text = newText;
        }
      },
    ),
  )),
```

### Test Checklist
- [ ] Backend grammar endpoint çalışıyor mu?
- [ ] Frontend'den request gidiyor mu?
- [ ] Hatalı cümle yazınca suggestion geliyor mu?
- [ ] "Düzelt" butonu çalışıyor mu?

---

## 📋 SPRINT 3: SRS Backend (5-7 Gün)

### Hedef
SM-2 algoritmasını backend'e implemente et. Kelime tekrar sisteminin temelini oluştur.

### Görevler

#### 3.1 Database Migration Çalıştır
```bash
# PostgreSQL'e bağlan ve migration'ı çalıştır
psql -U postgres -d englishapp -f backend/src/main/resources/db/migration/V002__srs_fields.sql
```

#### 3.2 Word Entity Güncelle
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/entity/Word.java`

```java
// Mevcut sınıfa ekle:

@Column(name = "next_review_date")
private LocalDate nextReviewDate;

@Column(name = "review_count")
private Integer reviewCount = 0;

@Column(name = "ease_factor")
private Float easeFactor = 2.5f;

@Column(name = "last_review_date")
private LocalDate lastReviewDate;

// Getters and Setters ekle
```

#### 3.3 SRS Service Oluştur
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/service/SRSService.java`

```java
package com.ingilizce.calismaapp.service;

import com.ingilizce.calismaapp.entity.Word;
import com.ingilizce.calismaapp.entity.WordReview;
import com.ingilizce.calismaapp.repository.WordRepository;
import com.ingilizce.calismaapp.repository.WordReviewRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
public class SRSService {
    
    @Autowired
    private WordRepository wordRepository;
    
    @Autowired
    private WordReviewRepository wordReviewRepository;
    
    /**
     * SM-2 Algorithm implementation
     * Based on: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
     */
    @Transactional
    public Word reviewWord(Long wordId, int quality) {
        /*
         * quality: 0-5 scale
         * 0 - Total blackout
         * 1 - Incorrect response, but correct one seemed familiar
         * 2 - Incorrect response, correct one remembered
         * 3 - Correct response, but with difficulty
         * 4 - Correct response, after some hesitation
         * 5 - Perfect response
         */
        
        Word word = wordRepository.findById(wordId)
            .orElseThrow(() -> new RuntimeException("Word not found"));
        
        boolean wasCorrect = quality >= 3;
        int reviewCount = word.getReviewCount() != null ? word.getReviewCount() : 0;
        float easeFactor = word.getEaseFactor() != null ? word.getEaseFactor() : 2.5f;
        
        // Update ease factor
        easeFactor = easeFactor + (0.1f - (5 - quality) * (0.08f + (5 - quality) * 0.02f));
        if (easeFactor < 1.3f) {
            easeFactor = 1.3f;
        }
        
        // Calculate interval
        int interval;
        if (quality < 3) {
            // Failed - start over
            interval = 1;
            reviewCount = 0;
        } else {
            reviewCount++;
            if (reviewCount == 1) {
                interval = 1;
            } else if (reviewCount == 2) {
                interval = 6;
            } else {
                interval = Math.round((reviewCount - 1) * easeFactor);
            }
        }
        
        // Update word
        word.setReviewCount(reviewCount);
        word.setEaseFactor(easeFactor);
        word.setLastReviewDate(LocalDate.now());
        word.setNextReviewDate(LocalDate.now().plusDays(interval));
        
        // Save review record
        WordReview review = new WordReview(word, LocalDate.now());
        review.setReviewType("srs");
        review.setWasCorrect(wasCorrect);
        wordReviewRepository.save(review);
        
        return wordRepository.save(word);
    }
    
    /**
     * Get words due for review today
     */
    public List<Word> getWordsDueToday() {
        return wordRepository.findByNextReviewDateLessThanEqual(LocalDate.now());
    }
    
    /**
     * Get review statistics
     */
    public ReviewStats getReviewStats(Long userId) {
        // For now, we don't have user system, so get all
        List<Word> dueToday = getWordsDueToday();
        List<Word> allWords = wordRepository.findAll();
        
        int totalWords = allWords.size();
        int reviewedWords = (int) allWords.stream()
            .filter(w -> w.getReviewCount() != null && w.getReviewCount() > 0)
            .count();
        int dueCount = dueToday.size();
        
        return new ReviewStats(totalWords, reviewedWords, dueCount);
    }
    
    // Inner class for stats
    public static class ReviewStats {
        public final int totalWords;
        public final int reviewedWords;
        public final int dueToday;
        
        public ReviewStats(int totalWords, int reviewedWords, int dueToday) {
            this.totalWords = totalWords;
            this.reviewedWords = reviewedWords;
            this.dueToday = dueToday;
        }
    }
}
```

#### 3.4 WordRepository Güncelle
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/repository/WordRepository.java`

```java
// Ekle:
List<Word> findByNextReviewDateLessThanEqual(LocalDate date);
List<Word> findByNextReviewDateBetween(LocalDate start, LocalDate end);
```

#### 3.5 WordReview Entity Güncelle
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/entity/WordReview.java`

```java
// Ekle:
@Column(name = "was_correct")
private Boolean wasCorrect;

@Column(name = "response_time_seconds")
private Integer responseTimeSeconds;

// Getters and Setters
```

#### 3.6 SRS Controller
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/controller/SRSController.java`

```java
package com.ingilizce.calismaapp.controller;

import com.ingilizce.calismaapp.entity.Word;
import com.ingilizce.calismaapp.service.SRSService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/srs")
@CrossOrigin(origins = "*")
public class SRSController {
    
    @Autowired
    private SRSService srsService;
    
    @GetMapping("/due-today")
    public List<Word> getDueToday() {
        return srsService.getWordsDueToday();
    }
    
    @PostMapping("/review/{wordId}")
    public Word reviewWord(
        @PathVariable Long wordId,
        @RequestBody Map<String, Integer> request
    ) {
        int quality = request.getOrDefault("quality", 3);
        return srsService.reviewWord(wordId, quality);
    }
    
    @GetMapping("/stats")
    public SRSService.ReviewStats getStats() {
        return srsService.getReviewStats(null);
    }
}
```

### Test Checklist
- [ ] Migration başarılı mı?
- [ ] Yeni Word field'ları dolu mu?
- [ ] `/api/srs/due-today` endpoint çalışıyor mu?
- [ ] `/api/srs/review/{id}` endpoint kelimeyi güncelliyor mu?
- [ ] Ease factor doğru hesaplanıyor mu?

---

## 📋 SPRINT 4: SRS Frontend (4-5 Gün)

### Hedef
Review ekranı oluştur, flashcard UI, bildirimler.

### Görevler

#### 4.1 Review Provider
**Dosya:** `flutter_app/lib/providers/review_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/word.dart';

class ReviewProvider with ChangeNotifier {
  List<Word> _dueWords = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  String? _error;
  
  // Stats
  int _totalWords = 0;
  int _reviewedWords = 0;
  int _dueToday = 0;

  List<Word> get dueWords => _dueWords;
  Word? get currentWord => _currentIndex < _dueWords.length 
      ? _dueWords[_currentIndex] 
      : null;
  int get currentIndex => _currentIndex;
  int get totalDue => _dueWords.length;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get dueToday => _dueToday;
  
  bool get hasMore => _currentIndex < _dueWords.length;
  double get progress => _dueWords.isEmpty 
      ? 0 
      : (_currentIndex / _dueWords.length);

  Future<void> loadDueWords() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/srs/due-today');
      _dueWords = (response as List)
          .map((json) => Word.fromJson(json))
          .toList();
      _currentIndex = 0;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reviewWord(int quality) async {
    if (currentWord == null) return;

    try {
      await ApiService.post('/srs/review/${currentWord!.id}', {
        'quality': quality,
      });
      
      // Move to next
      _currentIndex++;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    try {
      final stats = await ApiService.get('/srs/stats');
      _totalWords = stats['totalWords'] ?? 0;
      _reviewedWords = stats['reviewedWords'] ?? 0;
      _dueToday = stats['dueToday'] ?? 0;
      notifyListeners();
    } catch (e) {
      print('Failed to load stats: $e');
    }
  }

  void reset() {
    _currentIndex = 0;
    notifyListeners();
  }
}
```

#### 4.2 Review Screen
**Dosya:** `flutter_app/lib/screens/review_screen.dart`

[Kod çok uzun olacağı için outline veriyorum - detaylı implementasyon için ayrı dosya]

Özellikler:
- Flashcard UI (flip animation)
- Önce İngilizce kelime
- "Göster" butonu → Türkçe anlamı
- 3 buton: "Zor", "İyi", "Kolay"
- Progress bar
- Motivasyon mesajları

#### 4.3 Ana Sayfaya "Due Today" Kartı
**Dosya:** `flutter_app/lib/screens/home_screen.dart`

```dart
// initState'te:
Provider.of<ReviewProvider>(context, listen: false).loadStats();

// Build içinde:
Consumer<ReviewProvider>(
  builder: (context, reviewProvider, _) {
    if (reviewProvider.dueToday > 0) {
      return Card(
        color: AppTheme.accentOrange.withOpacity(0.1),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReviewScreen()),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.notifications_active, 
                  color: AppTheme.accentOrange, size: 40),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bugün ${reviewProvider.dueToday} kelime seni bekliyor!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Tekrar etmeye başla 🎯'),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox.shrink();
  },
),
```

### Test Checklist
- [ ] Due words yükleniyor mu?
- [ ] Flashcard flip animasyonu çalışıyor mu?
- [ ] Review butonları çalışıyor mu?
- [ ] Progress doğru görünüyor mu?
- [ ] Ana sayfada bildirim kartı var mı?

---

## 🎯 Sonraki Adımlar

Sprint 5-10 için detaylı implementation dokümantasyonu gerekirse ayrı dosyalar hazırlayabilirim.

### Öncelikler:
1. ✅ SPRINT 1-2: UI iyileştirmeleri ve Grammar (Hemen başlayabilirsin)
2. ✅ SPRINT 3-4: SRS sistemi (Core feature)
3. ⏳ SPRINT 5-6: Gamification (Engagement)
4. ⏳ SPRINT 7-10: Advanced features

### Önemli Notlar:
- Her sprint bittikten sonra test et
- Git commit'lerini düzenli yap
- Database backup al
- README.md'yi güncelle
