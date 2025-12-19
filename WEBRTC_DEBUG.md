# WebRTC Debug Rehberi

## Yapılan Düzeltmeler

### 1. Socket Bağlantısı
- ✅ Reconnection mekanizması eklendi
- ✅ Socket disconnect durumunda otomatik yeniden bağlanma
- ✅ Queue'ya girme kullanıcı etkileşimi ile yapılıyor

### 2. Kamera İzni
- ✅ Kamera izni kullanıcı "Eşleşmeyi Başlat" butonuna bastığında isteniyor
- ✅ Video call ekranında daha düşük kalite ile başlatılıyor (tek cihazda iki tarayıcı için)

### 3. Test Senaryosu

#### Senaryo 1: İki Farklı Tarayıcı (Önerilen)
1. Chrome normal mod
2. Chrome incognito mod veya Edge/Firefox
3. Her ikisinde de "Eşleşmeyi Başlat" butonuna basın
4. Eşleşme sonrası video call başlamalı

#### Senaryo 2: Tek Cihazda İki Tarayıcı (Sınırlı)
- Windows'ta aynı kamerayı iki tarayıcı kullanmaya çalışmak sorun yaratabilir
- Chrome'u şu parametre ile başlatabilirsiniz: `--use-fake-ui-for-media-stream`
- Veya bir tarayıcıda kamera iznini reddedin, diğerinde verin

## Backend Log Kontrolü

Backend loglarını izlemek için:
```bash
docker-compose logs backend --follow
```

Kontrol edilecek loglar:
- `=== CLIENT CONNECTED ===` - Socket bağlantısı
- `=== join_queue event received ===` - Queue'ya giriş
- `Match found! Room: ...` - Eşleşme bulundu
- `=== WebRTC OFFER EVENT RECEIVED ===` - Offer alındı
- `=== WebRTC ANSWER EVENT RECEIVED ===` - Answer alındı
- `=== WebRTC ICE CANDIDATE EVENT RECEIVED ===` - ICE candidate alındı

## Frontend Console Kontrolü

Browser console'da kontrol edilecek:
- `Socket connected` - Socket bağlandı
- `Emitted webrtc_offer with data: ...` - Offer gönderildi
- `Emitted webrtc_answer with data: ...` - Answer gönderildi
- `Emitted webrtc_ice_candidate with data: ...` - ICE candidate gönderildi
- `WebRTC connection state: connected` - WebRTC bağlantısı kuruldu

## Sorun Giderme

### Socket Disconnected Hatası
- Backend loglarında client disconnect görünüyorsa, frontend'de reconnection çalışmıyor olabilir
- Browser console'da "Socket disconnected" görünüyorsa, backend'e bağlantı kurulamıyor olabilir

### Remote Video Görünmüyor
1. Backend loglarında `webrtc_answer` event'i görünüyor mu?
2. Frontend console'da `webrtc_answer` event'i alınıyor mu?
3. WebRTC connection state "connected" mi?

### Kamera İzni Sorunu
- Tarayıcı ayarlarından kamera iznini kontrol edin
- Başka bir uygulama kamerayı kullanıyor olabilir
- Tarayıcıyı yeniden başlatın


