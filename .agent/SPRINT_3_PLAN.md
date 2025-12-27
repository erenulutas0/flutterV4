# 📚 Sprint 3: SRS (Spaced Repetition System) Backend

**Tarih:** 25 Aralık 2024  
**Durum:** 🚧 Başlatıldı  
**Öncelik:** Yüksek

---

## 🎯 Sprint Hedefi

Kelime öğrenme sürecini optimize etmek için **Spaced Repetition System (SRS)** backend'ini kurmak. Kullanıcılar kelimeleri belirli aralıklarla tekrar ederek kalıcı öğrenme sağlayacak.

---

## 📋 Görevler

### 1. Backend: SRS Entity ve Repository ✅ (Hazır)
- [x] `words` tablosuna SRS alanları eklendi (V002 migration)
  - `next_review_date`
  - `review_count`
  - `ease_factor`
  - `last_review_date`
- [x] `word_reviews` tablosu hazır
  - `was_correct`
  - `response_time_seconds`

### 2. Backend: SRS Service (Yeni) 🔨
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/service/SRSService.java`

**Görevler:**
- [ ] SM-2 algoritması implementasyonu
- [ ] `calculateNextReview()` metodu
- [ ] `updateEaseFactor()` metodu
- [ ] `getWordsForReview()` metodu (bugün review edilecek kelimeler)

**Algoritma:** SuperMemo SM-2
```
EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
- q: quality (0-5, kullanıcı cevabı)
- EF: ease factor (zorluk katsayısı)
```

**Interval Hesaplama:**
- İlk tekrar: 1 gün
- İkinci tekrar: 6 gün
- Sonraki: interval * EF

### 3. Backend: SRS Controller (Yeni) 🔨
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/controller/SRSController.java`

**Endpoints:**
```java
GET  /api/srs/review-words        // Bugün review edilecek kelimeler
POST /api/srs/submit-review        // Review sonucunu kaydet
GET  /api/srs/stats                // SRS istatistikleri
```

### 4. Backend: Word Entity Güncellemesi 🔨
**Dosya:** `backend/src/main/java/com/ingilizce/calismaapp/entity/Word.java`

**Eklenecek Alanlar:**
```java
@Column(name = "next_review_date")
private LocalDate nextReviewDate;

@Column(name = "review_count")
private Integer reviewCount = 0;

@Column(name = "ease_factor")
private Double easeFactor = 2.5;

@Column(name = "last_review_date")
private LocalDate lastReviewDate;
```

### 5. Frontend: SRS Service (Yeni) 🔨
**Dosya:** `flutter_app/lib/services/srs_service.dart`

**Görevler:**
- [ ] `getReviewWords()` - Backend'den review kelimelerini al
- [ ] `submitReview(wordId, quality)` - Review sonucunu gönder
- [ ] `getSRSStats()` - İstatistikleri al

### 6. Frontend: Review Screen (Yeni) 🔨
**Dosya:** `flutter_app/lib/screens/review_screen.dart`

**Özellikler:**
- [ ] Flashcard UI (ön yüz: İngilizce, arka yüz: Türkçe)
- [ ] Swipe gesture (sağa: kolay, sola: zor)
- [ ] Quality rating (0-5 butonlar)
- [ ] Progress bar (kaç kelime kaldı)
- [ ] Tebrik ekranı (review tamamlandığında)

### 7. Frontend: Ana Sayfa Entegrasyonu 🔨
**Dosya:** `flutter_app/lib/screens/home_screen.dart`

**Eklenecekler:**
- [ ] "Bugün X kelime review et" kartı
- [ ] Review butonu
- [ ] SRS istatistikleri widget'ı

---

## 🧪 Test Senaryoları

### Backend Tests
- [ ] Yeni kelime eklendiğinde `next_review_date` = bugün + 1 gün
- [ ] Doğru cevap verildiğinde interval artıyor
- [ ] Yanlış cevap verildiğinde interval sıfırlanıyor
- [ ] `ease_factor` doğru hesaplanıyor

### Frontend Tests
- [ ] Review ekranı açılıyor
- [ ] Flashcard çevirilebiliyor
- [ ] Quality rating kaydediliyor
- [ ] Progress bar güncelleniyor
- [ ] Tüm kelimeler bitince tebrik ekranı gösteriliyor

---

## 📊 Başarı Kriterleri

✅ Kullanıcı bugün review edilecek kelimeleri görebilmeli  
✅ Flashcard ile kelime çalışabilmeli  
✅ Cevap kalitesine göre bir sonraki review tarihi hesaplanmalı  
✅ SRS istatistikleri görüntülenebilmeli  

---

## 🚀 Implementasyon Sırası

1. **Backend Entity Güncellemesi** (10 dk)
2. **SRSService Implementasyonu** (30 dk)
3. **SRSController Oluşturma** (20 dk)
4. **Frontend SRSService** (15 dk)
5. **Review Screen UI** (45 dk)
6. **Ana Sayfa Entegrasyonu** (15 dk)
7. **Test ve Debug** (30 dk)

**Toplam Tahmini Süre:** ~2.5 saat

---

## 📝 Notlar

- SM-2 algoritması basit ama etkili
- İleri seviye: Anki'nin FSRS algoritmasına geçilebilir
- Review süresi (response_time) kaydediliyor ama şimdilik kullanılmıyor
- Gamification için review streak eklenebilir (sonraki sprint)

---

## 🔗 İlgili Dosyalar

- Migration: `backend/src/main/resources/db/migration/V002__srs_fields.sql`
- Genel Plan: `.agent/IMPLEMENTATION_PLAN.md`
- Sprint 1 Raporu: `.agent/SPRINT_1_REPORT.md`
- Sprint 2 Raporu: `.agent/SPRINT_2_REPORT.md`
