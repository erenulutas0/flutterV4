# 🎮 Eşleşme ve Görüntülü Görüşme Sistemi

## Özellikler

✅ **League of Legends benzeri eşleşme sistemi**
- Kuyruk tabanlı eşleşme
- İki kişilik karşılıklı görüşme
- Gerçek zamanlı eşleşme bildirimleri

✅ **WebRTC görüntülü görüşme**
- Peer-to-peer video/audio streaming
- Mikrofon açma/kapama
- Kamera açma/kapama
- Bedava STUN server'ları kullanılıyor

✅ **Bedava altyapı**
- Socket.io (real-time communication)
- WebRTC (peer-to-peer, ücretsiz)
- Google STUN server'ları (ücretsiz)

## Kurulum

### 1. Backend Dependencies

Backend'e Socket.io dependency'si eklendi (`pom.xml`):
```xml
<dependency>
    <groupId>com.corundumstudio.socketio</groupId>
    <artifactId>netty-socketio</artifactId>
    <version>2.0.9</version>
</dependency>
```

### 2. Flutter Dependencies

Flutter'a WebRTC ve Socket.io paketleri eklendi (`pubspec.yaml`):
```yaml
socket_io_client: ^2.0.3+1
flutter_webrtc: ^0.9.48
```

**Paketleri yüklemek için:**
```bash
cd flutter_app
flutter pub get
```

### 3. Port Yapılandırması

- **Backend API**: Port `8082`
- **Socket.io**: Port `9092`
- **Docker**: Her iki port da expose edildi

### 4. CORS Yapılandırması

Socket.io için CORS ayarları eklendi (`CorsConfig.java`).

## Kullanım

### Kullanıcı Akışı

1. **Ana Sayfa** → "Eşleşme Başlat" butonuna tıkla
2. **Eşleşme Ekranı** → Eşleşme aranıyor...
3. **Eşleşme Bulundu** → Otomatik olarak video call ekranına geç
4. **Video Call** → Mikrofon/kamera kontrolü ile görüşme yap

### Backend API

**Socket.io Events:**

- `join_queue` - Eşleşme kuyruğuna katıl
- `leave_queue` - Kuyruktan çık
- `join_room` - Room'a katıl
- `webrtc_offer` - WebRTC offer gönder
- `webrtc_answer` - WebRTC answer gönder
- `webrtc_ice_candidate` - ICE candidate gönder
- `end_call` - Görüşmeyi sonlandır

**Socket.io Listeners:**

- `queue_status` - Kuyruk durumu
- `match_found` - Eşleşme bulundu
- `webrtc_offer` - Offer alındı
- `webrtc_answer` - Answer alındı
- `webrtc_ice_candidate` - ICE candidate alındı
- `call_ended` - Görüşme sonlandı

## Teknik Detaylar

### Eşleşme Algoritması

1. Kullanıcı `join_queue` event'i gönderir
2. Eğer kuyrukta bekleyen biri varsa → Eşleşme oluştur
3. Eğer yoksa → Kullanıcıyı kuyruğa ekle
4. Her iki kullanıcıya da `match_found` event'i gönderilir

### WebRTC Signaling

1. **Offer**: İlk kullanıcı offer oluşturur ve gönderir
2. **Answer**: İkinci kullanıcı answer oluşturur ve gönderir
3. **ICE Candidates**: Her iki taraf da ICE candidate'ları gönderir
4. **Connection**: Peer-to-peer bağlantı kurulur

### STUN/TURN Server'ları

Şu an sadece STUN server'ları kullanılıyor (bedava):
- `stun:stun.l.google.com:19302`
- `stun:stun1.l.google.com:19302`

**Not:** Bazı ağlarda TURN server gerekebilir. İhtiyaç olursa:
- Twilio'nun ücretsiz tier'ı
- Veya kendi TURN server'ınızı kurun

## Test Etme

### 1. Backend'i Başlat

```bash
docker-compose up -d
```

### 2. Flutter Uygulamasını Çalıştır

```bash
cd flutter_app
flutter run -d chrome
```

### 3. İki Farklı Browser'da Test Et

1. İlk browser'da: Ana sayfa → "Eşleşme Başlat"
2. İkinci browser'da: Ana sayfa → "Eşleşme Başlat"
3. Eşleşme bulununca otomatik olarak video call başlar

## Sorun Giderme

### Socket.io bağlanamıyor
- Backend'in port 9092'de çalıştığından emin olun
- CORS ayarlarını kontrol edin
- Browser console'da hata var mı bakın

### WebRTC bağlantısı kurulamıyor
- STUN server'larına erişilebilir mi kontrol edin
- Bazı ağlarda TURN server gerekebilir
- Browser console'da WebRTC hatalarını kontrol edin

### Kamera/mikrofon izni
- Browser'dan kamera/mikrofon izni verin
- HTTPS veya localhost kullanın (güvenlik gereksinimi)

## Gelecek Geliştirmeler

- [ ] TURN server desteği
- [ ] Çoklu oda desteği (3+ kişi)
- [ ] Ekran paylaşımı
- [ ] Chat mesajlaşma
- [ ] Eşleşme filtreleri (dil seviyesi, konu vb.)
- [ ] Eşleşme geçmişi

