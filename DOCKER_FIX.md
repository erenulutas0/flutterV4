# Docker Desktop Düzeltme Rehberi

## Hızlı Çözüm

1. **Docker Desktop'ı Kapat**
   - Sistem tepsisindeki Docker ikonuna sağ tıklayın
   - "Quit Docker Desktop" seçin

2. **Görev Yöneticisi'nden Kontrol**
   - Ctrl + Shift + Esc ile Görev Yöneticisi'ni açın
   - "com.docker.service", "Docker Desktop" gibi process'leri sonlandırın

3. **Docker Desktop'ı Yeniden Başlat**
   - Docker Desktop'ı tekrar açın
   - Başlatılmasını bekleyin (1-2 dakika)

4. **Test Et**
   ```powershell
   docker version
   docker ps
   ```

## Alternatif: WSL2'yi Yeniden Başlat

Eğer hala çalışmazsa:

```powershell
# WSL2'yi yeniden başlat
wsl --shutdown

# Docker Desktop'ı tekrar başlat
```

## Hala Çalışmazsa

Docker Desktop'ı tamamen kaldırıp yeniden yükleyin:
1. Settings → Apps → Docker Desktop → Uninstall
2. Docker Desktop'ı tekrar indirip yükleyin



