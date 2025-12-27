# VocabMaster - İngilizce Kelime Öğrenme Uygulaması 🇬🇧🇹🇷

VocabMaster, İngilizce kelime ezberlemeyi, cümle kurmayı ve telaffuz çalışmayı kolaylaştıran kapsamlı bir Flutter uygulamasıdır. Hem online hem de offline çalışabilen yapısı sayesinde her yerde öğrenmeye devam edebilirsiniz.

## 🚀 Özellikler

*   **Offline Mod Desteği:** İnternetiniz olmasa bile kelime ekleyin, çalışın. İnternet geldiğinde otomatik senkronize olur.
*   **Kelime Yönetimi:** Kelime ekleme, düzenleme, silme ve detaylı inceleme.
*   **Cümle Pratiği:** Kelimelerle ilgili cümleler kurun, çevirilerini ekleyin.
*   **Akıllı Sıralama:** En son eklediğiniz veya öğrendiğiniz içerikler her zaman elinizin altında.
*   **Zorluk Seviyeleri:** Kelimeleri ve cümleleri zorluk seviyesine (Kolay, Orta, Zor) göre sınıflandırın.
*   **Güvenli Yapı:** Hassas bilgiler `.env` dosyası üzerinden yönetilir.

## 📂 Proje Yapısı

*   `flutter_app/`: Flutter mobil uygulama kodları.
*   `backend/`: (Varsa) Uygulamanın sunucu tarafı kodları.

## 🛠️ Kurulum

### Gereksinimler

*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0 veya üzeri)
*   Dart SDK

### Uygulamayı Çalıştırma

1.  Repoyu klonlayın:
    ```bash
    git clone https://github.com/erenulutas0/flutterV4.git
    cd flutterV4
    ```

2.  Flutter dizinine gidin:
    ```bash
    cd flutter_app
    ```

3.  Bağımlılıkları yükleyin:
    ```bash
    flutter pub get
    ```

4.  `.env` Dosyasını Oluşturun:
    `flutter_app` dizininde `.env` dosyası oluşturun ve IP adreslerinizi girin:
    ```env
    REAL_DEVICE_IP=192.168.1.X # Bilgisayarınızın IP adresi
    EMULATOR_IP=10.0.2.2
    ```

5.  Uygulamayı başlatın:
    ```bash
    flutter run
    ```

## 📝 Lisans

Bu proje [MIT Lisansı](LICENSE) ile lisanslanmıştır.

---
Geliştirici: Eren Ulutaş
