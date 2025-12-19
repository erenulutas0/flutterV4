# 🚀 GPU Kiralama ile Hızlandırma Rehberi

## Neden GPU Kiralama?

CPU'da çalışan LLM modelleri çok yavaştır. GPU ile:
- **10-100x daha hızlı** yanıt süreleri
- Daha büyük modeller kullanabilme (32B, 70B)
- Daha iyi kalite ve tutarlılık

## Seçenekler ve Karşılaştırma

### 1. RunPod (Önerilen) ⭐
**Avantajlar:**
- Ollama'yı hazır template ile çalıştırma
- GPU'lu pod'larda otomatik kurulum
- Kolay API endpoint yapılandırması
- İyi dokümantasyon

**Fiyat:** ~$0.20-0.50/saat (RTX 3090/4090)

**Kurulum:**
1. https://www.runpod.io/ adresine kaydolun
2. "Templates" → "Ollama" template'ini seçin
3. GPU seçin (RTX 3090 veya 4090 önerilir)
4. Pod'u başlatın
5. API endpoint'i alın (örn: `https://xxxxx-xxxxx.runpod.net`)

### 2. io.net
**Avantajlar:**
- Decentralized GPU network
- Esnek fiyatlandırma
- API endpoint sağlar

**Fiyat:** Değişken (genellikle uygun)

**Kurulum:**
1. https://cloud.io.net/ adresine kaydolun
2. GPU instance oluşturun
3. Ollama'yı kurun ve çalıştırın
4. Public endpoint oluşturun

### 3. Vast.ai
**Avantajlar:**
- En ucuz seçenek
- Çok sayıda GPU seçeneği

**Dezavantajlar:**
- Manuel kurulum gerekir
- Daha az stabil olabilir

**Fiyat:** ~$0.10-0.30/saat

### 4. Together.ai (En Kolay - API Servisi)
**Avantajlar:**
- Hiç kurulum gerekmez
- Direkt API kullanımı
- Çok hızlı ve güvenilir

**Dezavantajlar:**
- Ollama yerine kendi API'lerini kullanır
- Kod değişikliği gerekir
- Biraz daha pahalı olabilir

**Fiyat:** Pay-as-you-go (~$0.0001-0.001 per 1K tokens)

## RunPod ile Entegrasyon (Örnek)

### Adım 1: RunPod'da Ollama Pod'u Oluştur

1. RunPod'a giriş yapın
2. "Pods" → "Deploy" → "Community Cloud"
3. Template: "Ollama" seçin
4. GPU: RTX 3090 veya 4090 seçin
5. "Deploy" butonuna tıklayın

### Adım 2: Model Yükleme

Pod başladıktan sonra, terminal'de:

```bash
# Pod'a bağlan
# RunPod web UI'dan terminal'e erişin

# Model yükle (7B model hızlı, 13B daha iyi kalite)
ollama pull llama2:13b

# Veya daha büyük model (daha yavaş ama çok daha iyi)
ollama pull qwen2.5:32b
```

### Adım 3: API Endpoint'i Al

RunPod pod'unuzun public endpoint'ini alın:
- Örnek: `https://xxxxx-xxxxx-5000.proxy.runpod.net`

### Adım 4: Backend Yapılandırması

`docker-compose.yml` dosyasını güncelleyin:

```yaml
# Ollama (GPU kiralama servisi)
LANGCHAIN4J_OLLAMA_CHAT_MODEL_BASE_URL: https://xxxxx-xxxxx-5000.proxy.runpod.net
LANGCHAIN4J_OLLAMA_CHAT_MODEL_MODEL_NAME: llama2:13b  # veya qwen2.5:32b
```

### Adım 5: Backend'i Yeniden Başlat

```bash
docker-compose restart backend
```

## Together.ai ile Entegrasyon (Alternatif)

Eğer Together.ai kullanmak isterseniz, LangChain4j yerine direkt HTTP client kullanmanız gerekir.

### Avantajlar:
- Hiç sunucu yönetimi yok
- Çok hızlı (managed infrastructure)
- Kolay ölçeklenebilir

### Kod Değişikliği Gerekir:
- `ChatbotService` interface'ini değiştirmeniz gerekir
- Together.ai API'sini kullanacak şekilde güncelleme

## Maliyet Tahmini

### RunPod (RTX 3090):
- Saatlik: ~$0.30
- Aylık (8 saat/gün): ~$72
- Aylık (24/7): ~$216

### io.net:
- Değişken, genellikle RunPod'dan biraz daha ucuz

### Vast.ai:
- Saatlik: ~$0.15-0.25
- Aylık (8 saat/gün): ~$36-60

### Together.ai:
- Pay-as-you-go
- 1M token ~$0.50-2.00 (modele göre)
- Kullanım bazlı, boşta maliyet yok

## Öneri

**Başlangıç için:** RunPod (kolay kurulum, iyi dokümantasyon)
**Uzun vadeli:** Together.ai (yönetim yok, ölçeklenebilir)
**Bütçe odaklı:** Vast.ai (en ucuz, manuel kurulum)

## Test Etme

GPU'lu servisi kullanmaya başladıktan sonra:

1. Backend loglarını kontrol edin:
```bash
docker-compose logs backend -f
```

2. Cümle üretim süresini ölçün (öncesi vs sonrası)

3. Model kalitesini değerlendirin

## Notlar

- GPU servisleri genellikle **idle timeout**'a sahiptir (kullanılmadığında kapanır)
- RunPod'da "Network Volume" kullanarak model dosyalarını kalıcı hale getirebilirsiniz
- API endpoint'leri genellikle HTTPS gerektirir (CORS ayarlarına dikkat)


