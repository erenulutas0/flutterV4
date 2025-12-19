# 🚀 RunPod GPU Kiralama - Hızlı Başlangıç

## Önemli Bilgiler

### ✅ Fiyat Sabit
- **Saatlik fiyat sabittir** - Hangi modeli kullanırsanız kullanın fiyat değişmez
- RTX 5090'ı $0.69/saat kiralarsanız, istediğiniz kadar ağır model kullanabilirsiniz
- Sadece **VRAM limiti** önemli (modelin sığması gerekir)

### 📊 GPU ve Model Uyumluluğu

| GPU | VRAM | Önerilen Modeller | Saatlik Fiyat |
|-----|------|-------------------|---------------|
| RTX 3070 Ti (sizin) | 8GB | llama2:7b, mistral:7b | - |
| RTX 3090 | 24GB | llama2:7b, 13b, qwen2.5:32b | $0.22 |
| RTX 4090 | 24GB | llama2:7b, 13b, qwen2.5:32b | $0.34 |
| RTX 5090 | 32GB | Tüm modeller (70B hariç) | $0.69 |

## Test İçin Öneri: RTX 3090 ($0.22/saat)

**Neden RTX 3090?**
- ✅ En uygun fiyat (test için ideal)
- ✅ 24GB VRAM (çoğu modeli çalıştırır)
- ✅ 3070 Ti'nizden çok daha hızlı
- ✅ Hız farkını net görebilirsiniz

## Adım Adım Kurulum

### 1. RunPod'a Kayıt
1. https://www.runpod.io/ adresine gidin
2. "Sign Up" ile kayıt olun
3. Billing bilgilerinizi ekleyin (kredi kartı)

### 2. Ollama Pod'u Oluştur

1. **"Pods"** sekmesine gidin
2. **"Deploy"** butonuna tıklayın
3. **"Community Cloud"** seçin
4. Template: **"Ollama"** seçin
5. GPU: **RTX 3090** seçin ($0.22/hr)
6. **"Deploy"** butonuna tıklayın

### 3. Pod Başlatıldıktan Sonra

Pod başladıktan sonra (1-2 dakika):

1. Pod'un yanındaki **"Connect"** butonuna tıklayın
2. **"HTTP Service"** sekmesine gidin
3. **Public Endpoint** URL'ini kopyalayın
   - Örnek: `https://xxxxx-xxxxx-5000.proxy.runpod.net`

### 4. Model Yükleme

**Terminal'den (RunPod web UI):**

```bash
# Pod'a bağlan (RunPod web UI'dan terminal açın)

# Hızlı test için 7B model
ollama pull llama2:7b

# Daha iyi kalite için 13B model
ollama pull llama2:13b

# En iyi kalite için 32B model (24GB VRAM limitinde)
ollama pull qwen2.5:32b
```

**Not:** Model yükleme ilk seferde 5-15 dakika sürebilir (model boyutuna göre).

### 5. Backend Yapılandırması

`docker-compose.yml` dosyasını düzenleyin:

```yaml
# Ollama (RunPod GPU servisi)
LANGCHAIN4J_OLLAMA_CHAT_MODEL_BASE_URL: https://xxxxx-xxxxx-5000.proxy.runpod.net
LANGCHAIN4J_OLLAMA_CHAT_MODEL_MODEL_NAME: llama2:13b  # veya qwen2.5:32b
LANGCHAIN4J_OLLAMA_CHAT_MODEL_TEMPERATURE: 0.2
LANGCHAIN4J_OLLAMA_CHAT_MODEL_TIMEOUT: 300s
LANGCHAIN4J_OLLAMA_CHAT_MODEL_TOP_P: 0.9
```

**Önemli:** 
- URL'de `http://` yerine `https://` kullanın
- Port numarası genellikle `:5000` veya `:11434` olur (RunPod size söyler)

### 6. Backend'i Yeniden Başlat

```bash
docker-compose restart backend
```

### 7. Test Edin

1. Uygulamayı açın: http://localhost:8080
2. Bir kelime için cümle üretin
3. Süreyi ölçün ve karşılaştırın:
   - **Önce (3070 Ti):** ~10-30 saniye
   - **Sonra (RTX 3090):** ~1-3 saniye

## Performans Karşılaştırması

### RTX 3070 Ti (8GB VRAM) - Sizin GPU
- **llama2:7b:** ~10-20 saniye/cümle
- **llama2:13b:** Çalışmaz (VRAM yetersiz)
- **qwen2.5:32b:** Çalışmaz (VRAM yetersiz)

### RTX 3090 (24GB VRAM) - RunPod
- **llama2:7b:** ~0.5-1 saniye/cümle ⚡
- **llama2:13b:** ~1-2 saniye/cümle ⚡
- **qwen2.5:32b:** ~2-4 saniye/cümle ⚡

**Hız artışı: 10-20x daha hızlı!**

## Maliyet Tahmini

### Test Senaryosu (1 saat):
- RTX 3090: **$0.22**
- Farklı modelleri test edebilirsiniz
- İstediğiniz kadar model yükleyebilirsiniz (fiyat değişmez)

### Günlük Kullanım (8 saat/gün):
- RTX 3090: **$1.76/gün** (~$53/ay)
- RTX 4090: **$2.72/gün** (~$82/ay)
- RTX 5090: **$5.52/gün** (~$166/ay)

### 24/7 Kullanım:
- RTX 3090: **~$158/ay**
- RTX 4090: **~$245/ay**
- RTX 5090: **~$497/ay**

## Önemli Notlar

1. **Pod'u Durdurmayı Unutmayın!**
   - Kullanmadığınızda pod'u durdurun (fiyatlandırma durur)
   - RunPod'da "Stop" butonuna tıklayın

2. **Network Volume Kullanın (Opsiyonel)**
   - Model dosyalarını kalıcı hale getirmek için
   - Pod yeniden başlatıldığında modeller kaybolmaz

3. **Idle Timeout**
   - Bazı pod'lar kullanılmadığında otomatik kapanır
   - Ayarlardan kontrol edin

4. **CORS Ayarları**
   - RunPod endpoint'leri genellikle HTTPS kullanır
   - CORS ayarları backend'de zaten yapılmış olmalı

## Sorun Giderme

### Pod'a Bağlanamıyorum
- Pod'un "Running" durumunda olduğundan emin olun
- Public endpoint URL'ini kontrol edin
- Firewall ayarlarını kontrol edin

### Model Yüklenmiyor
- Pod'un yeterli disk alanına sahip olduğundan emin olun
- Daha küçük bir model deneyin (7B → 13B → 32B)

### Backend Bağlanamıyor
- URL'nin doğru olduğundan emin olun (https://)
- Port numarasını kontrol edin
- Backend loglarını kontrol edin: `docker-compose logs backend`

## Sonuç

**Test için RTX 3090 ($0.22/saat) ile başlayın:**
- ✅ Uygun fiyat
- ✅ 24GB VRAM (çoğu modeli çalıştırır)
- ✅ 3070 Ti'nizden 10-20x daha hızlı
- ✅ Fiyat sabit (hangi modeli kullanırsanız kullanın)

**Performans beklentisi:**
- 3070 Ti: 10-30 saniye/cümle
- RTX 3090: 1-3 saniye/cümle
- **10-20x hızlanma!** 🚀


