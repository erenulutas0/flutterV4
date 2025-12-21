# 🎮 Eşleşme Test Rehberi

## İki Emülatör ile Eşleşme Testi

### 1. İkinci Emülatörü Başlatma

İkinci emülatör başlatılıyor... Emülatör açıldıktan sonra (1-2 dakika sürebilir):

```powershell
# Mevcut cihazları kontrol et
flutter devices

# İkinci emülatörde uygulamayı başlat
flutter run -d <device-id>
```

### 2. Test Adımları

#### Adım 1: İlk Emülatör (Zaten Çalışıyor)
- Uygulama açık olmalı
- "Eşleşme" ekranına gidin
- "Eşleşmeyi Başlat" butonuna tıklayın
- "Eşleşme aranıyor..." mesajını görmelisiniz

#### Adım 2: İkinci Emülatör (Yeni Başlatılan)
- İkinci emülatör açıldıktan sonra:
  ```powershell
  flutter devices  # Device ID'yi bulun
  flutter run -d <ikinci-emülatör-id>
  ```
- Uygulama açıldıktan sonra:
  - "Eşleşme" ekranına gidin
  - "Eşleşmeyi Başlat" butonuna tıklayın

#### Adım 3: Eşleşme Beklenen Sonuç
- İlk emülatör: "Eşleşme aranıyor..." → Eşleşme bulundu → Video call ekranına geçer
- İkinci emülatör: "Eşleşme aranıyor..." → Eşleşme bulundu → Video call ekranına geçer
- Her iki emülatör de aynı room'a bağlanır

### 3. Hızlı Komutlar

```powershell
# Tüm cihazları listele
flutter devices

# İlk emülatörde çalıştır (zaten çalışıyor olabilir)
flutter run -d emulator-5554

# İkinci emülatörde çalıştır (emülatör ID'si değişebilir)
flutter run -d emulator-5556  # veya başka bir ID

# Backend loglarını izle
docker-compose logs -f backend
```

### 4. Sorun Giderme

#### Emülatör Bağlanmıyor
```powershell
# ADB'yi yeniden başlat
adb kill-server
adb start-server
flutter devices
```

#### Eşleşme Bulunmuyor
1. Backend'in çalıştığını kontrol edin:
   ```powershell
   docker-compose ps
   docker-compose logs backend --tail=50
   ```

2. Socket.io bağlantısını kontrol edin:
   - Backend loglarında "join_queue event received" mesajını görmelisiniz
   - Her iki emülatörden de "Socket connected" mesajı gelmeli

3. Port kontrolü:
   ```powershell
   netstat -an | Select-String ":9092"
   ```

#### İki Uygulama Aynı Emülatörde Açılıyor
- Her uygulamayı farklı terminal penceresinde çalıştırın
- Veya farklı device ID'leri kullanın:
  ```powershell
  # Terminal 1
  flutter run -d emulator-5554
  
  # Terminal 2 (yeni terminal)
  flutter run -d emulator-5556
  ```

### 5. Beklenen Backend Logları

Eşleşme başarılı olduğunda backend loglarında şunları görmelisiniz:

```
=== join_queue event received ===
User ID: <timestamp1>
Match result: WAITING
Queue size: 1

=== join_queue event received ===
User ID: <timestamp2>
Match result: FOUND
Match found! Room: room_<timestamp1>_<timestamp2>
Sent match_found event to user: <timestamp1> with role: caller
Sent match_found event to user: <timestamp2> with role: callee
```

### 6. Test Senaryoları

1. **Normal Eşleşme**: İki kullanıcı sırayla kuyruğa girer → Eşleşme bulunur
2. **İptal Etme**: Bir kullanıcı "İptal" butonuna basar → Kuyruktan çıkar
3. **Yeniden Eşleşme**: İptal eden kullanıcı tekrar başlatır → Yeni eşleşme bulur
4. **Çoklu Eşleşme**: Üçüncü bir emülatör başlatıp test edin

### 7. Notlar

- Her emülatör farklı bir `userId` kullanır (timestamp bazlı)
- Backend'de kuyruk sistemi çalışır (ilk giren bekler, ikinci gelen eşleşir)
- Video call ekranına geçiş otomatik olur
- WebRTC sadece web platformunda çalışır, Android'de placeholder gösterilir


