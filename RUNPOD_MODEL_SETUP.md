# 📦 RunPod Model Yükleme Rehberi

## Sorun
Backend hatası: `{"error":"model 'llama2:7b' not found"}`

RunPod pod'unuzda model yüklü değil. Model yüklemeniz gerekiyor.

## Adım Adım Model Yükleme

### 1. RunPod Pod'una Bağlanın

RunPod web terminal'inden veya SSH ile pod'a bağlanın.

### 2. Yüklü Modelleri Kontrol Edin

```bash
ollama list
```

Eğer boş liste görüyorsanız, model yüklemeniz gerekiyor.

### 3. Model Yükleyin

RTX 5090 (32GB VRAM) için önerilen modeller:

#### Hızlı Test İçin (7B):
```bash
ollama pull llama2:7b
```
- Boyut: ~4GB
- Yükleme süresi: ~2-3 dakika
- Hız: Çok hızlı (~0.5-1 saniye/cümle)

#### Daha İyi Kalite İçin (13B):
```bash
ollama pull llama2:13b
```
- Boyut: ~7GB
- Yükleme süresi: ~5-7 dakika
- Hız: Hızlı (~1-2 saniye/cümle)

#### En İyi Kalite İçin (32B):
```bash
ollama pull qwen2.5:32b
```
- Boyut: ~18GB
- Yükleme süresi: ~10-15 dakika
- Hız: Orta (~2-4 saniye/cümle)

### 4. Model Yüklemesini Kontrol Edin

```bash
# Yüklü modelleri listeleyin
ollama list

# Model çalışıyor mu test edin
ollama run llama2:7b "Hello, how are you?"
```

### 5. docker-compose.yml'de Model Adını Güncelleyin

Yüklediğiniz modele göre `docker-compose.yml` dosyasını güncelleyin:

```yaml
LANGCHAIN4J_OLLAMA_CHAT_MODEL_MODEL_NAME: llama2:7b  # veya llama2:13b veya qwen2.5:32b
```

### 6. Backend'i Yeniden Başlatın

```bash
docker-compose restart backend
```

## Öneri: Test İçin Başlangıç

1. **Önce `llama2:7b` yükleyin** (en hızlı, test için ideal)
2. Backend'i yeniden başlatın
3. Test edin
4. İsterseniz daha büyük model yükleyin

## Model Yükleme Süresi

- **7B model**: ~2-3 dakika
- **13B model**: ~5-7 dakika
- **32B model**: ~10-15 dakika

Model yükleme sırasında terminal'de ilerleme göreceksiniz.

## Sorun Giderme

### Model yüklenmiyor
- Disk alanını kontrol edin: `df -h`
- İnternet bağlantısını kontrol edin
- Ollama'nın çalıştığını kontrol edin: `ps aux | grep ollama`

### Model yüklü ama backend bulamıyor
- Model adını kontrol edin: `ollama list`
- docker-compose.yml'deki model adını kontrol edin
- Backend'i yeniden başlatın: `docker-compose restart backend`

### Model çok yavaş
- Daha küçük bir model deneyin (32B → 13B → 7B)
- GPU kullanımını kontrol edin: `nvidia-smi`


