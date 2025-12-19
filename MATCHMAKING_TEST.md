# Eşleşme Sistemi Test Rehberi

## Test Yöntemleri

### Yöntem 1: Farklı Tarayıcılar (Önerilen)
1. **Chrome**'da `http://localhost:8080` açın
2. **Firefox** veya **Edge**'de `http://localhost:8080` açın
3. Her iki tarayıcıda da "Eşleşme Başlat" butonuna basın
4. İki kullanıcı otomatik olarak eşleşmeli

### Yöntem 2: Incognito/Private Mode
1. **Chrome** normal pencerede `http://localhost:8080` açın
2. **Chrome Incognito** (Ctrl+Shift+N) pencerede `http://localhost:8080` açın
3. Her iki pencerede de "Eşleşme Başlat" butonuna basın
4. İki kullanıcı otomatik olarak eşleşmeli

### Yöntem 3: Farklı Cihazlar
1. Bilgisayarınızın **yerel IP adresini** öğrenin:
   - Windows: `ipconfig` komutu ile (IPv4 Address)
   - Örnek: `192.168.1.100`
2. Aynı ağdaki başka bir cihazdan (telefon, tablet, başka bilgisayar) `http://192.168.1.100:8080` adresine gidin
3. Her iki cihazda da "Eşleşme Başlat" butonuna basın

## Test Adımları

1. **İlk Kullanıcı:**
   - Tarayıcı 1'de `http://localhost:8080` açın
   - Ana sayfada "Eşleşme Başlat" butonuna tıklayın
   - "Eşleşme aranıyor..." mesajını görmelisiniz

2. **İkinci Kullanıcı:**
   - Tarayıcı 2'de `http://localhost:8080` açın
   - Ana sayfada "Eşleşme Başlat" butonuna tıklayın
   - "Eşleşme aranıyor..." mesajını görmelisiniz

3. **Eşleşme:**
   - İki kullanıcı eşleştiğinde, her iki tarayıcıda da otomatik olarak "Görüşme" ekranına geçmeli
   - Room ID ve eşleşilen kullanıcı bilgileri görünmeli

## Sorun Giderme

### Socket.io Bağlantı Hatası
- Backend loglarını kontrol edin: `docker-compose logs backend | findstr Socket`
- Port 9092'nin açık olduğundan emin olun
- Tarayıcı konsolunda (F12) hata mesajlarını kontrol edin

### Eşleşme Olmuyor
- Her iki tarayıcıda da "Eşleşme Başlat" butonuna basıldığından emin olun
- Backend loglarını kontrol edin: `docker-compose logs backend --tail 50`
- Socket.io bağlantısının kurulduğunu kontrol edin (tarayıcı konsolu)

### CORS Hatası
- Backend'te CORS ayarlarının doğru olduğundan emin olun
- `CorsConfig.java` dosyasında `localhost:8080` ve `localhost:9092` izinli olmalı

## Debug İçin

### Backend Logları
```bash
docker-compose logs backend --tail 50 --follow
```

### Frontend Console (Tarayıcı)
- F12 tuşuna basın
- Console sekmesine gidin
- Socket.io bağlantı mesajlarını görebilirsiniz

### Socket.io Test
```bash
# Backend container'ına bağlan
docker exec -it english-app-backend sh

# Socket.io portunu test et
curl http://localhost:9092
```

## Beklenen Davranış

1. ✅ İlk kullanıcı queue'ya katılır
2. ✅ İkinci kullanıcı queue'ya katılır
3. ✅ Backend iki kullanıcıyı eşleştirir
4. ✅ Her iki kullanıcıya "match_found" eventi gönderilir
5. ✅ Her iki kullanıcı "Görüşme" ekranına yönlendirilir
6. ✅ Room ID ve eşleşilen kullanıcı bilgileri gösterilir

