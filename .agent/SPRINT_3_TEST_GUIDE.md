# 🧪 Sprint 3 Test Rehberi

**Tarih:** 25 Aralık 2024  
**Sprint:** SRS (Spaced Repetition System) Backend & Frontend  
**Durum:** ✅ Tamamlandı

---

## 📋 Test Edilecek Özellikler

### 1. Backend API Testleri
### 2. Frontend UI Testleri
### 3. End-to-End Testleri

---

## 🔧 Ön Hazırlık

### Backend Hazırlığı
```bash
# Backend'in çalıştığından emin olun
docker-compose up -d backend

# Logları kontrol edin
docker logs english-app-backend --tail 50
```

### Flutter Hazırlığı
```bash
# Flutter uygulamasını başlatın
cd flutter_app
flutter run
```

---

## 1️⃣ Backend API Testleri

### Test 1.1: SRS Stats Endpoint
**Endpoint:** `GET /api/srs/stats`

**Postman/cURL ile Test:**
```bash
curl http://localhost:8082/api/srs/stats
```

**Beklenen Sonuç:**
```json
{
  "dueToday": 0,
  "totalWords": 10,
  "reviewedWords": 0
}
```

**✅ Başarı Kriterleri:**
- Status Code: 200
- `dueToday`, `totalWords`, `reviewedWords` alanları var
- Değerler integer

---

### Test 1.2: Review Words Endpoint
**Endpoint:** `GET /api/srs/review-words`

**cURL ile Test:**
```bash
curl http://localhost:8082/api/srs/review-words
```

**Beklenen Sonuç:**
```json
[
  {
    "id": 1,
    "englishWord": "hello",
    "turkishMeaning": "merhaba",
    "nextReviewDate": "2024-12-25",
    "reviewCount": 0,
    "easeFactor": 2.5
  }
]
```

**✅ Başarı Kriterleri:**
- Status Code: 200
- Array dönüyor
- Her kelimede SRS alanları var

---

### Test 1.3: Submit Review Endpoint
**Endpoint:** `POST /api/srs/submit-review`

**cURL ile Test:**
```bash
curl -X POST http://localhost:8082/api/srs/submit-review \
  -H "Content-Type: application/json" \
  -d '{"wordId": 1, "quality": 4}'
```

**Beklenen Sonuç:**
```json
{
  "id": 1,
  "englishWord": "hello",
  "nextReviewDate": "2024-12-26",  // 1 gün sonra
  "reviewCount": 1,
  "easeFactor": 2.5
}
```

**✅ Başarı Kriterleri:**
- Status Code: 200
- `reviewCount` arttı
- `nextReviewDate` güncellendi
- `lastReviewDate` bugün

---

## 2️⃣ Frontend UI Testleri

### Test 2.1: Ana Sayfa - Review Kartı

**Adımlar:**
1. Uygulamayı açın
2. Ana sayfaya gidin
3. "Tekrar Zamanı!" kartını kontrol edin

**✅ Başarı Kriterleri:**
- [ ] Eğer review edilecek kelime varsa yeşil kart görünüyor
- [ ] Kart üzerinde kelime sayısı doğru
- [ ] Karta tıklandığında Review Screen açılıyor

**Ekran Görüntüsü Alın:** Ana sayfa review kartı

---

### Test 2.2: Review Screen - Flashcard

**Adımlar:**
1. Ana sayfadan "Tekrar Zamanı!" kartına tıklayın
2. Review Screen açılsın
3. Flashcard'ı test edin

**✅ Başarı Kriterleri:**
- [ ] İlk kelime İngilizce olarak gösteriliyor
- [ ] Karta tıklandığında Türkçe anlamı gösteriliyor
- [ ] Progress bar doğru (örn. 1/5)
- [ ] "Kartı çevirmek için dokunun" yazısı var

**Ekran Görüntüsü Alın:** Flashcard ön yüz ve arka yüz

---

### Test 2.3: Review Screen - Quality Rating

**Adımlar:**
1. Flashcard'ı çevirin (Türkçe anlamı gösterin)
2. Quality butonlarını kontrol edin
3. Bir butona tıklayın

**✅ Başarı Kriterleri:**
- [ ] 4 buton var: "Hiç Bilmedim", "Zor", "İyi", "Kolay"
- [ ] Butonlar farklı renklerde (kırmızı, turuncu, açık yeşil, yeşil)
- [ ] Butona tıklandığında bir sonraki kelimeye geçiyor
- [ ] Loading durumunda butonlar disabled

**Ekran Görüntüsü Alın:** Quality butonları

---

### Test 2.4: Review Screen - Tamamlama

**Adımlar:**
1. Tüm kelimeleri review edin
2. Son kelimeye quality verin
3. Tebrik dialog'unu kontrol edin

**✅ Başarı Kriterleri:**
- [ ] Tebrik dialog'u açılıyor
- [ ] "Bugünün tekrarlarını tamamladınız! 🎉" yazısı var
- [ ] Kaç kelime review edildiği gösteriliyor
- [ ] "Tamam" butonuna basınca ana sayfaya dönüyor

**Ekran Görüntüsü Alın:** Tebrik dialog'u

---

### Test 2.5: Review Screen - Boş Durum

**Adımlar:**
1. Tüm kelimeleri review ettikten sonra
2. Tekrar Review Screen'e gidin

**✅ Başarı Kriterleri:**
- [ ] "Bugün tekrar edilecek kelime yok!" mesajı
- [ ] Yeşil check icon gösteriliyor
- [ ] "Ana Sayfaya Dön" butonu var

**Ekran Görüntüsü Alın:** Boş durum ekranı

---

## 3️⃣ End-to-End Testleri

### Test 3.1: Tam Akış - Kelime Ekle ve Review Et

**Senaryo:** Yeni bir kelime ekleyip review edin

**Adımlar:**
1. Kelimeler sayfasına gidin
2. Yeni kelime ekleyin: "test" - "test"
3. Ana sayfaya dönün
4. Review kartının güncellendiğini kontrol edin
5. Review ekranına gidin
6. Kelimeyi review edin (Quality: 4 - İyi)
7. Backend'de next_review_date'in güncellendiğini kontrol edin

**✅ Başarı Kriterleri:**
- [ ] Kelime eklendikten sonra review kartı gösteriliyor
- [ ] Review sonrası kelime listeden çıkıyor
- [ ] Backend'de `reviewCount = 1`
- [ ] Backend'de `nextReviewDate = bugün + 1 gün`

---

### Test 3.2: SM-2 Algoritması Testi

**Senaryo:** Farklı quality değerleri ile algoritma testi

**Adımlar:**
1. Bir kelime ekleyin
2. Quality 5 (Kolay) ile review edin
3. Backend'de `easeFactor` kontrol edin (artmalı)
4. Aynı kelimeyi tekrar review edin (ertesi gün)
5. Quality 0 (Hiç Bilmedim) verin
6. Backend'de `nextReviewDate`'in sıfırlandığını kontrol edin

**✅ Başarı Kriterleri:**
- [ ] Quality 5: `easeFactor` arttı (örn. 2.5 → 2.6)
- [ ] Quality 5: `nextReviewDate` uzun interval (örn. 6 gün)
- [ ] Quality 0: `nextReviewDate` = bugün + 1 gün (sıfırlandı)
- [ ] Quality 0: `easeFactor` azaldı

---

## 4️⃣ Database Testleri

### Test 4.1: SRS Alanları Kontrolü

**SQL Query ile Test:**
```sql
-- PostgreSQL container'a bağlanın
docker exec -it english-app-postgres psql -U postgres -d EnglishApp

-- Bir kelimeyi kontrol edin
SELECT id, english_word, next_review_date, review_count, ease_factor, last_review_date
FROM words
WHERE id = 1;
```

**Beklenen Sonuç:**
```
 id | english_word | next_review_date | review_count | ease_factor | last_review_date
----+--------------+------------------+--------------+-------------+------------------
  1 | hello        | 2024-12-26       |            1 |        2.50 | 2024-12-25
```

**✅ Başarı Kriterleri:**
- [ ] Tüm SRS alanları dolu
- [ ] `ease_factor` 1.3 ile 3.0 arasında
- [ ] `next_review_date` gelecek bir tarih

---

## 5️⃣ Performance Testleri

### Test 5.1: Çok Kelime ile Review

**Adımlar:**
1. 50+ kelime ekleyin (toplu import veya script ile)
2. Hepsini bugün review edilecek şekilde ayarlayın
3. Review Screen'i açın
4. Performance'ı gözlemleyin

**✅ Başarı Kriterleri:**
- [ ] Review Screen 2 saniyeden kısa sürede açılıyor
- [ ] Flashcard geçişleri smooth (lag yok)
- [ ] Progress bar doğru güncelleniyor

---

## 6️⃣ Edge Case Testleri

### Test 6.1: Invalid Quality Value

**Backend Test:**
```bash
curl -X POST http://localhost:8082/api/srs/submit-review \
  -H "Content-Type: application/json" \
  -d '{"wordId": 1, "quality": 10}'  # Invalid (>5)
```

**✅ Başarı Kriterleri:**
- [ ] Status Code: 400 (Bad Request)
- [ ] Hata mesajı dönüyor

---

### Test 6.2: Olmayan Kelime Review

**Backend Test:**
```bash
curl -X POST http://localhost:8082/api/srs/submit-review \
  -H "Content-Type: application/json" \
  -d '{"wordId": 99999, "quality": 4}'  # Olmayan ID
```

**✅ Başarı Kriterleri:**
- [ ] Status Code: 500 veya 404
- [ ] Hata mesajı: "Word not found"

---

## 📊 Test Sonuçları Tablosu

| Test ID | Test Adı | Durum | Notlar |
|---------|----------|-------|--------|
| 1.1 | SRS Stats API | ⬜ | |
| 1.2 | Review Words API | ⬜ | |
| 1.3 | Submit Review API | ⬜ | |
| 2.1 | Ana Sayfa Review Kartı | ⬜ | |
| 2.2 | Flashcard UI | ⬜ | |
| 2.3 | Quality Rating | ⬜ | |
| 2.4 | Tamamlama Dialog | ⬜ | |
| 2.5 | Boş Durum | ⬜ | |
| 3.1 | End-to-End Akış | ⬜ | |
| 3.2 | SM-2 Algoritması | ⬜ | |
| 4.1 | Database Alanları | ⬜ | |
| 5.1 | Performance (50+ kelime) | ⬜ | |
| 6.1 | Invalid Quality | ⬜ | |
| 6.2 | Olmayan Kelime | ⬜ | |

**Durum Kodları:**
- ⬜ Henüz test edilmedi
- ✅ Başarılı
- ❌ Başarısız
- ⚠️ Kısmen başarılı

---

## 🐛 Bilinen Sorunlar

*(Test sırasında bulunan sorunlar buraya eklenecek)*

---

## 📝 Test Notları

### Önemli Noktalar:
1. **İlk Kullanım:** Yeni kelime eklendiğinde `nextReviewDate` otomatik olarak bugün + 1 gün olmalı
2. **Quality 0-2:** Interval sıfırlanır, kelime başa döner
3. **Quality 3-5:** Interval artarak devam eder
4. **Ease Factor:** 1.3 ile 3.0 arasında kalmalı

### Test Ortamı:
- **Backend:** Docker (Spring Boot 3.2.0)
- **Frontend:** Flutter Web/Android Emulator
- **Database:** PostgreSQL 15
- **Browser:** Chrome (Flutter Web için)

---

## ✅ Sprint 3 Tamamlanma Kriterleri

Sprint 3'ün başarılı sayılması için:

- [x] Backend SRS Service çalışıyor
- [x] Backend SRS Controller endpoint'leri çalışıyor
- [x] Frontend SRS Service backend'e bağlanıyor
- [x] Review Screen UI tamamlandı
- [x] Ana sayfa entegrasyonu yapıldı
- [ ] Tüm testler başarılı ✅
- [ ] Kullanıcı akışı sorunsuz

---

## 🚀 Sonraki Adımlar (Sprint 4)

Test tamamlandıktan sonra:
1. Bulunan bug'ları düzelt
2. Performance optimizasyonları
3. Sprint 4: Gamification (XP, Badges, Leaderboard)

---

**Test Tarihi:** _______________  
**Test Eden:** _______________  
**Sonuç:** ⬜ Başarılı / ⬜ Başarısız  
**Notlar:** _______________
