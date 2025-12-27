# 🎮 Sprint 4: Gamification & Polish

**Tarih:** 25 Aralık 2024  
**Durum:** 🚧 Başlatıldı  
**Öncelik:** Yüksek

---

## 🎯 Sprint Hedefi

Kullanıcı engagement'ını artırmak için **Gamification** özellikleri eklemek ve uygulamayı production-ready hale getirmek. Kullanıcılar XP kazanacak, rozetler toplayacak ve ilerleme grafiklerini görebilecek.

---

## 📋 Görevler

### 1. Backend: Achievement System ✅ (Kısmen Hazır)
**Mevcut Durum:**
- XP sistemi temel olarak var (her kelime 5 XP)
- Streak hesaplaması var

**Eklenecekler:**
- [ ] Badge/Achievement entity
- [ ] Achievement tanımları (First Word, 10 Words, 7 Day Streak, etc.)
- [ ] Achievement unlock logic
- [ ] Leaderboard (opsiyonel)

---

### 2. Backend: User Progress Tracking 🔨

**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/entity/UserProgress.java` (Yeni)

**Alanlar:**
```java
@Entity
@Table(name = "user_progress")
public class UserProgress {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    private Long userId; // Şimdilik default user
    private Integer totalXP = 0;
    private Integer level = 1;
    private Integer currentStreak = 0;
    private Integer longestStreak = 0;
    private LocalDate lastActivityDate;
    
    // Achievement tracking
    @ElementCollection
    private List<String> unlockedAchievements = new ArrayList<>();
}
```

**Görevler:**
- [ ] Entity oluştur
- [ ] Repository oluştur
- [ ] Migration script (V003)
- [ ] Service metodları (updateXP, checkAchievements, etc.)

---

### 3. Backend: Achievement Definitions 🔨

**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/model/Achievement.java`

**Achievement Örnekleri:**
```java
public enum Achievement {
    FIRST_WORD("İlk Kelime", "İlk kelimeni öğrendin!", 10),
    WORD_COLLECTOR_10("Kelime Koleksiyoncusu", "10 kelime öğrendin!", 50),
    WORD_COLLECTOR_50("Kelime Ustası", "50 kelime öğrendin!", 100),
    WORD_COLLECTOR_100("Kelime Dehası", "100 kelime öğrendin!", 200),
    STREAK_3("3 Günlük Seri", "3 gün üst üste çalıştın!", 30),
    STREAK_7("Haftalık Seri", "7 gün üst üste çalıştın!", 70),
    STREAK_30("Aylık Seri", "30 gün üst üste çalıştın!", 300),
    PERFECT_REVIEW("Mükemmel Tekrar", "Tüm kelimeleri 'Kolay' ile geçtin!", 50),
    EARLY_BIRD("Erken Kuş", "Sabah 8'den önce çalıştın!", 20),
    NIGHT_OWL("Gece Kuşu", "Gece 11'den sonra çalıştın!", 20);
    
    private final String title;
    private final String description;
    private final int xpReward;
}
```

---

### 4. Backend: Progress Controller 🔨

**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/controller/ProgressController.java`

**Endpoints:**
```java
GET  /api/progress/stats          // XP, level, streak
GET  /api/progress/achievements   // Unlocked achievements
POST /api/progress/check-achievements // Check and unlock new achievements
GET  /api/progress/leaderboard    // Top users (opsiyonel)
```

---

### 5. Frontend: Progress Service 🔨

**Dosya:** `flutter_app/lib/services/progress_service.dart`

**Metodlar:**
```dart
Future<ProgressStats> getStats();
Future<List<Achievement>> getAchievements();
Future<void> checkAchievements();
```

---

### 6. Frontend: Achievements Screen 🔨

**Dosya:** `flutter_app/lib/screens/achievements_screen.dart`

**Özellikler:**
- [ ] Grid view ile rozetler
- [ ] Locked/Unlocked durumu
- [ ] Progress bar (her rozet için)
- [ ] Animasyonlu unlock efekti
- [ ] XP gösterimi

**UI Design:**
- Locked: Gri, siluet
- Unlocked: Renkli, parlak
- Recent unlock: Glow efekti

---

### 7. Frontend: Progress Widget (Ana Sayfa) 🔨

**Dosya:** `flutter_app/lib/widgets/progress_widget.dart`

**Özellikler:**
- [ ] XP bar (circular progress)
- [ ] Level gösterimi
- [ ] Next level için kalan XP
- [ ] Mini achievement showcase (son 3 rozet)

**Ana Sayfaya Entegrasyon:**
- Daily Progress Card'ın altına eklenecek
- Compact design

---

### 8. Frontend: Achievement Notification 🔨

**Dosya:** `flutter_app/lib/widgets/achievement_notification.dart`

**Özellikler:**
- [ ] Bottom sheet veya dialog
- [ ] Animasyonlu rozet gösterimi
- [ ] Confetti efekti (opsiyonel)
- [ ] XP kazanım gösterimi
- [ ] "Paylaş" butonu (opsiyonel)

---

### 9. Polish: Loading States & Error Handling 🔨

**Tüm Ekranlar:**
- [ ] Skeleton loaders
- [ ] Empty states
- [ ] Error states
- [ ] Retry buttons
- [ ] Pull-to-refresh

---

### 10. Polish: Animations & Transitions 🔨

**Eklenecekler:**
- [ ] Page transitions (Hero animations)
- [ ] List item animations (staggered)
- [ ] Button press animations
- [ ] XP gain animation
- [ ] Level up animation

---

### 11. Polish: Onboarding 🔨

**Dosya:** `flutter_app/lib/screens/onboarding_screen.dart`

**Özellikler:**
- [ ] 3-4 sayfalık intro
- [ ] Uygulama özelliklerini tanıt
- [ ] "Başla" butonu
- [ ] Skip butonu
- [ ] Shared preferences ile "ilk açılış" kontrolü

---

### 12. Testing & Bug Fixes 🧪

**Test Edilecekler:**
- [ ] SRS review flow
- [ ] Achievement unlock logic
- [ ] XP calculation
- [ ] Streak calculation
- [ ] Edge cases (0 kelime, network error, etc.)

---

## 📊 Başarı Kriterleri

✅ Kullanıcı XP kazanabiliyor  
✅ Rozetler unlock ediliyor  
✅ Streak doğru hesaplanıyor  
✅ Animasyonlar smooth  
✅ Error handling eksiksiz  
✅ Onboarding akışı çalışıyor  

---

## 🚀 Implementasyon Sırası

### Phase 1: Core Gamification (2-3 saat)
1. UserProgress entity & migration
2. Achievement definitions
3. ProgressController
4. Frontend ProgressService
5. Ana sayfaya XP widget

### Phase 2: Achievements (2 saat)
6. Achievements screen
7. Achievement unlock logic
8. Achievement notifications

### Phase 3: Polish (2-3 saat)
9. Loading states
10. Animations
11. Onboarding
12. Bug fixes

**Toplam Tahmini Süre:** ~6-8 saat

---

## 🎨 Design Mockup Ideas

### XP Widget (Ana Sayfa)
```
┌─────────────────────────┐
│  Level 5    ⭐ 250 XP   │
│  ████████░░░░  (80%)    │
│  50 XP to Level 6       │
└─────────────────────────┘
```

### Achievement Card
```
┌──────────────────┐
│   🏆 [Icon]      │
│   Kelime Ustası  │
│   50/50 kelime   │
│   +100 XP        │
└──────────────────┘
```

---

## 📝 Notlar

### XP Kazanım Kuralları:
- Yeni kelime ekleme: +5 XP
- Review (Quality 3+): +3 XP
- Review (Quality 5): +5 XP
- Daily streak bonus: +10 XP
- Achievement unlock: Variable XP

### Level Sistemi:
- Level 1: 0-100 XP
- Level 2: 100-250 XP
- Level 3: 250-500 XP
- Level 4: 500-1000 XP
- Level 5+: Previous * 1.5

### Streak Kuralları:
- Her gün en az 1 kelime ekle veya 1 review yap
- Gece yarısında reset
- Longest streak kaydedilir

---

## 🔗 İlgili Dosyalar

- Sprint 3 Raporu: `.agent/SPRINT_3_REPORT.md`
- Genel Plan: `.agent/IMPLEMENTATION_PLAN.md`
- Test Rehberi: `.agent/SPRINT_3_TEST_GUIDE.md`

---

## 🐛 Bilinen Sorunlar (Sprint 3'ten)

1. Grammar check devre dışı (Groq API)
2. İlk kelime SRS initialization manuel

**Sprint 4'te Düzeltilecek mi?**
- Hayır, bunlar Sprint 5 veya 6'ya ertelenebilir
- Şimdi odak: Gamification

---

## 🎯 Sprint 4 Sonrası Durum

**Kullanıcı Deneyimi:**
- ✅ Motivasyon artışı (XP, rozetler)
- ✅ Görsel feedback (animasyonlar)
- ✅ İlerleme takibi (level, streak)
- ✅ Professional görünüm (polish)

**Teknik Durum:**
- ✅ Production-ready backend
- ✅ Polished frontend
- ✅ Comprehensive error handling
- ✅ User onboarding

---

**Sprint Başlangıç Tarihi:** 25 Aralık 2024  
**Tahmini Bitiş:** 26 Aralık 2024  
**Durum:** 🚧 Başlatıldı
