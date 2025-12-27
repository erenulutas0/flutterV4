# 🎮 Sprint 5: UI/UX Polish, Achievements & Analytics

**Tarih:** 26 Aralık 2024  
**Durum:** 🚧 Başlatılıyor  
**Öncelik:** Yüksek

---

## 🎯 Sprint Hedefi

Uygulamanın kullanıcı deneyimini iyileştirmek (UI Polish), Gamification'ın eksik parçası olan Achievements ekranını eklemek ve kullanıcılara ilerlemelerini gösterecek Analytics özelliklerini entegre etmek. Ayrıca cümle içinde kelime vurgulama sorununu çözmek.

---

## 📋 Görevler

### Phase 1: Highlighting Fix (Hemen) ⚡
**Hedef:** Cümlelerdeki hedef kelimenin her zaman mor kutu içine alınması.
**Dosya:** `flutter_app/lib/screens/sentences_screen.dart`
**Çözüm:** Regex'i esnekleştirip, kelimenin çekimli hallerini (ek almış hallerini) de kapsayacak hale getirmek.
```dart
// Eski
RegExp(r'\b' + escape(word) + r'\b')
// Yeni
RegExp(r'\b' + escape(word) + r'\w*\b')
```

### Phase 2: Achievements Screen (UI) 🏆
**Dosya:** `flutter_app/lib/screens/achievements_screen.dart`
**Özellikler:**
- [ ] Grid layout (2 sütun)
- [ ] Locked/Unlocked görsel ayrımı (Color vs Grayscale)
- [ ] Rozet detay dialog'u (Nasıl kazanılır?)
- [ ] Unlock tarihi gösterimi
- [ ] Confetti animasyonu (yeni kazanıldığında)

**Servis:** `ProgressService` (zaten hazır)

### Phase 3: Analytics Dashboard 📊
**Dosya:** `flutter_app/lib/screens/stats_screen.dart`
**Özellikler:**
- [ ] Haftalık aktivite grafiği (BarChart - `fl_chart` paketi ile)
- [ ] Günlük kelime öğrenme sayısı
- [ ] SRS dağılımı (PieChart - Bekleyen, Öğrenilen, Zorlanan)
- [ ] Toplam çalışma süresi (tahmini)

**Backend:**
- [ ] `UserActivity` tablosu (günlük detaylı log için gerekirse) veya mevcut verilerden aggregate etme.
- [ ] `StatsController` güncellemesi gerekebilir.

---

### Phase 4: UI Polish 🎨
**Genel İyileştirmeler:**
- [ ] Transition animasyonları (Sayfa geçişleri)
- [ ] Loading skeleton'ları (her yerde tutarlı olsun)
- [ ] Boş durum (Empty State) tasarımları
- [ ] Buton efektleri

---

## 🛠 Teknik Detaylar

### Paketler:
- `fl_chart`: Grafikler için (eklenmesi gerekebilir)
- `confetti`: Kutlama efekti için (opsiyonel) -> Şimdilik manuel animasyon veya basit overlay.

---

## 🚀 Implementasyon Sırası

1.  **Regex Fix:** `SentencesScreen.dart` güncellemesi. (Hemen)
2.  **Achievements UI:** Yeni ekran tasarımı ve `home_screen.dart`'a linklenmesi.
3.  **Analytics:** Basit grafikler.

---

## 📝 Notlar
- AI özellikleri (Groq API, Chat) bir sonraki sprint'e (Sprint 6) bırakıldı.
- `word` entity'si ile `sentence` arasındaki ilişki, backend'de `Sentence` tablosunda `word_id` ile kurulu.

BAŞLAYALIM! 🚀
