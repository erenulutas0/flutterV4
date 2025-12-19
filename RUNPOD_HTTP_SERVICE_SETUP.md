# 🔧 RunPod HTTP Service (Port 11434) Kurulumu

## Sorun
Backend'den Ollama'ya bağlanırken 404 hatası alıyorsunuz. Bu, RunPod'da port 11434 için HTTP service'in oluşturulmadığı anlamına gelir.

## Çözüm: RunPod Panelinde HTTP Service Oluşturma

### 1. RunPod Pod Paneline Gidin
- RunPod dashboard'da pod'unuzu açın: `premier_maroon_bass` (ID: `rrna7tjcexmtbd`)
- "Connect" sekmesine tıklayın

### 2. HTTP Service Oluşturun
RunPod panelinde "HTTP services" bölümünde:

1. **"Add HTTP Service"** veya **"Expose Port"** butonuna tıklayın
2. Şu bilgileri girin:
   - **Port:** `11434`
   - **Name:** `Ollama` (veya istediğiniz bir isim)
   - **Protocol:** `HTTP`
3. **"Save"** veya **"Create"** butonuna tıklayın

### 3. Proxy URL'yi Alın
HTTP service oluşturulduktan sonra, RunPod size bir proxy URL verecek. Format genellikle şöyledir:
```
https://rrna7tjcexmtbd-11434.proxy.runpod.net
```

**ÖNEMLİ:** Bu URL'yi kopyalayın, `docker-compose.yml` dosyasında kullanacağız.

### 4. Ollama'nın Çalıştığını Kontrol Edin
RunPod web terminal'inde veya SSH ile pod'a bağlanın ve şu komutları çalıştırın:

```bash
# Ollama'nın çalışıp çalışmadığını kontrol edin
ps aux | grep ollama

# Port 11434'ün dinlendiğini kontrol edin
netstat -tuln | grep 11434
# veya
ss -tuln | grep 11434

# Ollama API'sini test edin (pod içinden)
curl http://localhost:11434/api/tags
```

Eğer Ollama çalışmıyorsa:

```bash
# Önce süreci temizleyin
pkill ollama

# Değişkeni set edin (0.0.0.0 tüm ağlardan erişim için)
export OLLAMA_HOST=0.0.0.0:11434

# Arka planda başlatın
ollama serve &
```

### 5. Model Yüklü mü Kontrol Edin
```bash
# Yüklü modelleri listeleyin
ollama list

# Eğer qwen2.5:32b yoksa, yükleyin
ollama pull qwen2.5:32b
```

### 6. docker-compose.yml'i Güncelleyin
RunPod'dan aldığınız proxy URL'yi `docker-compose.yml` dosyasına ekleyin:

```yaml
# Ollama (RunPod GPU service - RTX 4090)
LANGCHAIN4J_OLLAMA_CHAT_MODEL_BASE_URL: https://rrna7tjcexmtbd-11434.proxy.runpod.net
LANGCHAIN4J_OLLAMA_CHAT_MODEL_MODEL_NAME: qwen2.5:32b
```

### 7. Backend'i Yeniden Başlatın
```bash
docker-compose restart backend
```

### 8. Test Edin
1. Browser'da proxy URL'yi açın: `https://rrna7tjcexmtbd-11434.proxy.runpod.net/api/tags`
2. JSON response görmelisiniz (yüklü modeller listesi)
3. Uygulamada cümle üretmeyi deneyin

## Alternatif: Direct TCP Port (Önerilmez)
Eğer HTTP service oluşturamıyorsanız, RunPod'un direct TCP port'unu kullanabilirsiniz, ama bu güvenlik açısından önerilmez:

1. RunPod panelinde "Direct TCP ports" bölümüne bakın
2. Port 11434 için bir TCP port bulun (örn: `69.145.85.83:XXXXX`)
3. `docker-compose.yml`'de URL'yi güncelleyin:
   ```yaml
   LANGCHAIN4J_OLLAMA_CHAT_MODEL_BASE_URL: http://69.145.85.83:XXXXX
   ```

**Not:** Direct TCP port genellikle SSH için kullanılır ve Ollama için önerilmez. HTTP service kullanmak daha güvenli ve kolaydır.

## Sorun Giderme

### 404 Hatası
- HTTP service'in oluşturulduğundan emin olun
- Proxy URL'nin doğru olduğunu kontrol edin
- Ollama'nın çalıştığını kontrol edin

### Connection Refused
- Ollama'nın `0.0.0.0:11434` üzerinde dinlediğinden emin olun
- `OLLAMA_HOST=0.0.0.0:11434` değişkenini set edin

### Model Not Found
- Model'in yüklü olduğunu kontrol edin: `ollama list`
- Model'i yükleyin: `ollama pull qwen2.5:32b`

