# 🔧 RunPod Ollama "Bad Gateway" Hatası Çözümü

## Sorun
RunPod endpoint'ine bağlanırken "Bad gateway" (502) hatası alıyorsunuz. Bu, Ollama servisinin pod'da çalışmadığı anlamına gelir.

## Çözüm Adımları

### 1. RunPod Pod'unda Ollama'yı Başlatın

RunPod web terminal'inden veya SSH ile pod'a bağlanın ve şu komutları çalıştırın:

```bash
# Önce süreci temizleyin
pkill ollama

# Değişkeni set edin (0.0.0.0 tüm ağlardan erişim için)
export OLLAMA_HOST=0.0.0.0:11434

# Arka planda başlatın
ollama serve &
```

### 2. Ollama'nın Çalıştığını Kontrol Edin

```bash
# Ollama'nın çalışıp çalışmadığını kontrol edin
ps aux | grep ollama

# Port 11434'ün dinlendiğini kontrol edin
netstat -tuln | grep 11434
# veya
ss -tuln | grep 11434
```

### 3. Model Yüklü mü Kontrol Edin

```bash
# Yüklü modelleri listeleyin
ollama list

# Eğer model yoksa, yükleyin
ollama pull llama2:7b
# veya
ollama pull llama2:13b
# veya
ollama pull qwen2.5:32b
```

### 4. Ollama'yı Test Edin

```bash
# Ollama API'sini test edin
curl http://localhost:11434/api/tags

# Model çalışıyor mu test edin
curl http://localhost:11434/api/generate -d '{
  "model": "llama2:7b",
  "prompt": "Hello",
  "stream": false
}'
```

### 5. Backend'i Yeniden Başlatın

Local bilgisayarınızda:

```bash
docker-compose restart backend
```

### 6. Backend Loglarını Kontrol Edin

```bash
docker-compose logs backend --tail 50
```

## Alternatif: RunPod Template Kullanın

Eğer manuel başlatma sorun çıkarıyorsa, RunPod'da "Ollama" template'ini kullanarak yeni bir pod oluşturun:

1. RunPod'da "Deploy" butonuna tıklayın
2. Template: "Ollama" seçin
3. GPU: RTX 3090 veya RTX 5090 seçin
4. "Deploy" butonuna tıklayın

Bu template otomatik olarak Ollama'yı başlatır ve doğru şekilde yapılandırır.

## Önemli Notlar

1. **OLLAMA_HOST Değişkeni**: `0.0.0.0:11434` olarak ayarlanmalı (sadece `0.0.0.0` değil, port da belirtilmeli)

2. **HTTPS vs HTTP**: RunPod proxy HTTPS kullanır, ama Ollama HTTP üzerinden çalışır. RunPod proxy otomatik olarak HTTPS'yi HTTP'ye çevirir.

3. **Model Yükleme**: İlk model yükleme 5-15 dakika sürebilir (model boyutuna göre).

4. **Pod Yeniden Başlatma**: Pod yeniden başlatıldığında Ollama'yı tekrar başlatmanız gerekebilir. Bunu otomatikleştirmek için pod'un startup script'ine ekleyebilirsiniz.

## Sorun Giderme

### Ollama başlamıyor
- Pod'un yeterli RAM'e sahip olduğundan emin olun
- Disk alanını kontrol edin: `df -h`
- Logları kontrol edin: `journalctl -u ollama` (eğer systemd kullanıyorsa)

### Model yüklenmiyor
- Disk alanını kontrol edin
- Daha küçük bir model deneyin (7B → 13B → 32B)
- İnternet bağlantısını kontrol edin

### Backend bağlanamıyor
- RunPod endpoint URL'ini kontrol edin
- Ollama'nın çalıştığını kontrol edin
- Backend loglarını kontrol edin: `docker-compose logs backend`


