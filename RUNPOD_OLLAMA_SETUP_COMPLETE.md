# 🚀 RunPod'da Ollama Kurulumu ve Başlatma (Tam Rehber)

## 1. Ollama'yı İndirme ve Kurma

RunPod terminal'inde (web terminal veya SSH) şu komutları çalıştırın:

```bash
# Ollama'yı indir ve kur
curl -fsSL https://ollama.com/install.sh | sh
```

Bu komut:
- Ollama'yı otomatik olarak indirir
- Sisteminize kurar
- `ollama` komutunu PATH'e ekler

**Kurulum tamamlandıktan sonra**, Ollama'nın kurulduğunu kontrol edin:

```bash
ollama --version
```

## 2. Model İndirme

```bash
# qwen2.5:32b modelini indir (yaklaşık 19 GB, 5-15 dakika sürebilir)
ollama pull qwen2.5:32b
```

**Not:** Model indirme sırasında terminal'de ilerleme göreceksiniz. İndirme tamamlanana kadar bekleyin.

Model indirildikten sonra kontrol edin:

```bash
# Yüklü modelleri listele
ollama list
```

`qwen2.5:32b` modelini görmelisiniz.

## 3. Ollama'yı Başlatma (Port 11434'te)

RunPod'da Ollama'yı tüm ağlardan erişilebilir yapmak için:

```bash
# Önce varsa eski Ollama process'lerini durdur
pkill ollama

# Ollama'nın tüm ağlardan erişilebilir olması için environment variable set et
export OLLAMA_HOST=0.0.0.0:11434

# Ollama'yı arka planda başlat
nohup ollama serve > /tmp/ollama.log 2>&1 &
```

**Alternatif (daha detaylı log için):**

```bash
pkill ollama
export OLLAMA_HOST=0.0.0.0:11434
ollama serve &
```

## 4. Ollama'nın Çalıştığını Kontrol Etme

```bash
# Ollama process'inin çalıştığını kontrol et
ps aux | grep ollama

# Port 11434'ün dinlendiğini kontrol et (0.0.0.0:11434 veya *:11434 olmalı)
ss -tuln | grep 11434
# veya
netstat -tuln | grep 11434

# Ollama API'sini test et (pod içinden)
curl http://localhost:11434/api/tags
```

**Beklenen çıktı:**
- `ps aux | grep ollama`: `ollama serve` process'i görünmeli
- `ss -tuln | grep 11434`: `tcp LISTEN 0 4096 *:11434` veya `tcp LISTEN 0 4096 0.0.0.0:11434` görünmeli
- `curl http://localhost:11434/api/tags`: JSON formatında model listesi dönmeli

## 5. RunPod HTTP Service Kontrolü

RunPod panelinde "Connect" sekmesine gidin ve kontrol edin:

- **HTTP services** bölümünde "Port 11434 → HTTP Service" görünmeli
- Durum "Ready" (yeşil) olmalı

Eğer görünmüyorsa:
1. RunPod panelinde "Details" sekmesine gidin
2. "Expose HTTP Ports" bölümünde `11434` olduğundan emin olun
3. Pod'u yeniden başlatın (Stop → Start)

## 6. Proxy URL Testi

Browser'da şu URL'yi açın (pod ID'nizi kullanın):

```
https://[pod-id]-11434.proxy.runpod.net/api/tags
```

**Beklenen sonuç:**
- JSON formatında model listesi görmelisiniz
- Eğer 404 hatası alırsanız, RunPod HTTP service'i düzgün çalışmıyor olabilir

## 7. Pod Yeniden Başlatıldığında

RunPod pod'u yeniden başlatıldığında, Ollama'yı tekrar başlatmanız gerekir:

```bash
# Ollama'yı başlat
export OLLAMA_HOST=0.0.0.0:11434
nohup ollama serve > /tmp/ollama.log 2>&1 &
```

**Otomatik başlatma için:** Pod'un startup script'ine ekleyebilirsiniz (RunPod template'inde "Start Command" bölümüne):

```bash
export OLLAMA_HOST=0.0.0.0:11434 && ollama serve
```

## Sorun Giderme

### Ollama başlamıyor
- Disk alanını kontrol edin: `df -h`
- Logları kontrol edin: `cat /tmp/ollama.log`
- Port'un kullanılmadığını kontrol edin: `lsof -i :11434`

### Model yüklenmiyor
- İnternet bağlantısını kontrol edin
- Disk alanını kontrol edin (en az 25 GB boş alan gerekir)
- Daha küçük bir model deneyin: `ollama pull llama2:7b`

### Port 11434 dinlenmiyor
- `OLLAMA_HOST=0.0.0.0:11434` değişkeninin set edildiğinden emin olun
- Ollama'yı yeniden başlatın: `pkill ollama && export OLLAMA_HOST=0.0.0.0:11434 && ollama serve &`

### Proxy URL çalışmıyor
- RunPod panelinde HTTP service'in "Ready" durumunda olduğunu kontrol edin
- Pod ID'sinin doğru olduğunu kontrol edin
- Pod'u yeniden başlatmayı deneyin

## Özet Komutlar (Hızlı Başlangıç)

```bash
# 1. Ollama'yı kur
curl -fsSL https://ollama.com/install.sh | sh

# 2. Model'i indir
ollama pull qwen2.5:32b

# 3. Ollama'yı başlat
pkill ollama
export OLLAMA_HOST=0.0.0.0:11434
nohup ollama serve > /tmp/ollama.log 2>&1 &

# 4. Kontrol et
ollama list
curl http://localhost:11434/api/tags
```

## Backend Yapılandırması

Pod ID'nizi aldıktan sonra, `docker-compose.yml` dosyasında şu şekilde güncelleyin:

```yaml
LANGCHAIN4J_OLLAMA_CHAT_MODEL_BASE_URL: https://[pod-id]-11434.proxy.runpod.net
LANGCHAIN4J_OLLAMA_CHAT_MODEL_MODEL_NAME: qwen2.5:32b
```

Sonra backend'i yeniden başlatın:

```bash
docker-compose restart backend
```

