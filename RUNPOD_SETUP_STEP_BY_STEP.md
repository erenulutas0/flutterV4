# 🚀 RunPod Ollama Kurulumu - Adım Adım Rehber

## Pod Ayarları (Tamamlandı ✅)
- **HTTP Ports**: `8888,11434`
- **TCP Ports**: `22,11435`
- **Container Disk**: 200 GB
- **Volume Disk**: 200 GB

## Adım 1: Pod ID'yi Alın
1. RunPod panelinde pod'unuzu açın
2. "Connect" sekmesine gidin
3. Pod ID'yi kopyalayın (örn: `xxxxx-xxxxx-xxxxx`)
4. **Pod ID'yi not edin, bana göndereceksiniz!**

## Adım 2: RunPod Terminal'inde Ollama'yı Kurun
RunPod web terminal'inde (veya SSH ile) şu komutları çalıştırın:

```bash
# Ollama'yı kur
curl -fsSL https://ollama.com/install.sh | sh
```

Kurulum tamamlandıktan sonra kontrol edin:
```bash
ollama --version
```

## Adım 3: Model'i İndirin
```bash
# qwen2.5:32b modelini indir (5-15 dakika sürebilir)
ollama pull qwen2.5:32b
```

Model indirildikten sonra kontrol edin:
```bash
ollama list
```

`qwen2.5:32b` modelini görmelisiniz.

## Adım 4: Ollama'yı Port 11435'te Başlatın
**ÖNEMLİ:** TCP port 11435 kullanacağız, bu yüzden Ollama'yı bu port'ta başlatmalıyız:

```bash
# Eski process'leri durdur
pkill ollama

# Ollama'yı port 11435'te başlat (TCP port için)
export OLLAMA_HOST=0.0.0.0:11435

# Arka planda başlat
nohup ollama serve > /tmp/ollama.log 2>&1 &
```

## Adım 5: Ollama'nın Çalıştığını Kontrol Edin
```bash
# Ollama process'inin çalıştığını kontrol et
ps aux | grep ollama

# Port 11435'in dinlendiğini kontrol et (*:11435 veya 0.0.0.0:11435 olmalı)
ss -tuln | grep 11435

# Ollama API'sini test et (pod içinden)
curl http://localhost:11435/api/tags
```

**Beklenen çıktı:**
- `ps aux | grep ollama`: `ollama serve` process'i görünmeli
- `ss -tuln | grep 11435`: `tcp LISTEN 0 4096 *:11435` görünmeli
- `curl http://localhost:11435/api/tags`: JSON formatında model listesi dönmeli

## Adım 6: Direct TCP Port Bilgisini Alın
RunPod panelinde:
1. "Connect" sekmesine gidin
2. "Direct TCP ports" bölümüne bakın
3. Port 11435 için bir entry görmelisiniz (örn: `213.192.2.74:40111 -> :11435`)
4. **Public IP ve Port'u not edin** (örn: `213.192.2.74:40111`)

## Adım 7: Backend Yapılandırması
Pod ID ve Direct TCP port bilgisini aldıktan sonra bana gönderin, ben backend'i güncelleyeceğim.

**Gerekli bilgiler:**
- Pod ID (örn: `xxxxx-xxxxx-xxxxx`)
- Direct TCP Port (örn: `213.192.2.74:40111`)

## Adım 8: Test
Backend güncellendikten sonra uygulamada cümle üretmeyi deneyin.

---

## Sorun Giderme

### Ollama başlamıyor
```bash
# Logları kontrol et
cat /tmp/ollama.log

# Port'un kullanılmadığını kontrol et
lsof -i :11435
```

### Model yüklenmiyor
- İnternet bağlantısını kontrol edin
- Disk alanını kontrol edin: `df -h`
- Daha küçük bir model deneyin: `ollama pull llama2:7b`

### Port 11435 dinlenmiyor
- `OLLAMA_HOST=0.0.0.0:11435` değişkeninin set edildiğinden emin olun
- Ollama'yı yeniden başlatın:
```bash
pkill ollama
export OLLAMA_HOST=0.0.0.0:11435
nohup ollama serve > /tmp/ollama.log 2>&1 &
```

---

## Hızlı Komutlar (Kopyala-Yapıştır)

```bash
# 1. Ollama'yı kur
curl -fsSL https://ollama.com/install.sh | sh

# 2. Model'i indir
ollama pull qwen2.5:32b

# 3. Ollama'yı port 11435'te başlat
pkill ollama
export OLLAMA_HOST=0.0.0.0:11435
nohup ollama serve > /tmp/ollama.log 2>&1 &

# 4. Kontrol et
ollama list
ss -tuln | grep 11435
curl http://localhost:11435/api/tags
```

