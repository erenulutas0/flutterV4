# Android SDK Platform 31 İndirme Sorunu Çözümü

## Sorun
Gradle, Android SDK Platform 31'i indirmeye çalışırken ZIP hatası veriyor:
```
java.util.zip.ZipException: invalid stored block lengths
```

## Çözüm 1: Android Studio SDK Manager (Önerilen)

1. **Android Studio'yu açın**
2. **Tools → SDK Manager** (veya **File → Settings → Appearance & Behavior → System Settings → Android SDK**)
3. **SDK Platforms** sekmesine gidin
4. **Android 12.0 (S) - API Level 31** seçeneğini işaretleyin
5. **Apply** butonuna tıklayın
6. İndirme tamamlandıktan sonra tekrar deneyin

## Çözüm 2: Komut Satırından İndirme

```powershell
# SDK Manager yolunu bulun
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"

# SDK Manager'ı çalıştırın
cd "$sdkPath\cmdline-tools\latest\bin"
.\sdkmanager.bat "platforms;android-31"
```

## Çözüm 3: Cache Temizleme

```powershell
# Android SDK cache'ini temizle
Remove-Item -Path "$env:LOCALAPPDATA\Android\Sdk\.temp" -Recurse -Force -ErrorAction SilentlyContinue

# Gradle cache'ini temizle
Remove-Item -Path "$env:USERPROFILE\.gradle\caches" -Recurse -Force -ErrorAction SilentlyContinue

# Flutter clean
cd C:\flutter-project-main\flutter_app
flutter clean
```

## Çözüm 4: İnternet Bağlantısı

Eğer hala sorun devam ederse:
- VPN kullanıyorsanız kapatın
- Proxy ayarlarını kontrol edin
- İnternet bağlantınızı kontrol edin

## Not

`flutter_webrtc` paketi Android SDK Platform 31 gerektirir. Bu yüzden Platform 31'in kurulu olması zorunludur.


