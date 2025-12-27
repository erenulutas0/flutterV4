import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Backend URL yapılandırması
/// Emülatör için 10.0.2.2, gerçek cihaz için bilgisayarın IP'si kullanılır
class BackendConfig {
  // Bilgisayarınızın IP adresi (gerçek cihazlar için)
  // Eğer farklı bir IP kullanıyorsanız, burayı güncelleyin
  static String get _realDeviceIp => dotenv.env['REAL_DEVICE_IP'] ?? '192.168.1.102';
  
  // Emülatör için özel IP
  static String get _emulatorIp => dotenv.env['EMULATOR_IP'] ?? '10.0.2.2';
  
  // Cache için
  static bool? _cachedIsEmulator;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  /// Emülatörde mi çalışıyoruz? (device_info_plus ile güvenilir tespit)
  static Future<bool> _checkIsEmulator() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;
    
    try {
      print('🔍 ========== EMULATOR DETECTION ==========');
      final androidInfo = await _deviceInfo.androidInfo;
      
      final model = androidInfo.model;
      final manufacturer = androidInfo.manufacturer;
      final brand = androidInfo.brand;
      final device = androidInfo.device;
      final product = androidInfo.product;
      final hardware = androidInfo.hardware;
      final fingerprint = androidInfo.fingerprint;
      
      print('📱 Model: $model');
      print('📱 Manufacturer: $manufacturer');
      print('📱 Brand: $brand');
      print('📱 Device: $device');
      print('📱 Product: $product');
      print('📱 Hardware: $hardware');
      print('📱 Fingerprint: $fingerprint');
      
      // Emülatör tespiti için çoklu kontrol
      final modelLower = model.toLowerCase();
      final manufacturerLower = manufacturer.toLowerCase();
      final brandLower = brand.toLowerCase();
      final deviceLower = device.toLowerCase();
      final productLower = product.toLowerCase();
      final hardwareLower = hardware.toLowerCase();
      final fingerprintLower = fingerprint.toLowerCase();
      
      bool isEmulator = false;
      
      // 1. Model kontrolü
      if (modelLower.contains('sdk') || 
          modelLower.contains('emulator') ||
          modelLower.contains('generic')) {
        isEmulator = true;
        print('✅ Emülatör tespit edildi (Model kontrolü)');
      }
      
      // 2. Manufacturer kontrolü
      if (manufacturerLower.contains('unknown') ||
          manufacturerLower.contains('generic')) {
        isEmulator = true;
        print('✅ Emülatör tespit edildi (Manufacturer kontrolü)');
      }
      
      // 3. Brand kontrolü
      if (brandLower.contains('generic') ||
          brandLower.contains('unknown')) {
        isEmulator = true;
        print('✅ Emülatör tespit edildi (Brand kontrolü)');
      }
      
      // 4. Device kontrolü
      if (deviceLower.contains('generic') ||
          deviceLower.contains('emulator')) {
        isEmulator = true;
        print('✅ Emülatör tespit edildi (Device kontrolü)');
      }
      
      // 5. Product kontrolü
      if (productLower.contains('sdk') ||
          productLower.contains('emulator') ||
          productLower.contains('generic')) {
        isEmulator = true;
        print('✅ Emülatör tespit edildi (Product kontrolü)');
      }
      
      // 6. Hardware kontrolü (en güvenilir)
      if (hardwareLower.contains('goldfish') ||
          hardwareLower.contains('ranchu') ||
          hardwareLower.contains('vbox86')) {
        isEmulator = true;
        print('✅ Emülatör tespit edildi (Hardware kontrolü)');
      }
      
      // 7. Fingerprint kontrolü
      if (fingerprintLower.contains('generic') ||
          fingerprintLower.contains('sdk') ||
          fingerprintLower.contains('test-keys')) {
        isEmulator = true;
        print('✅ Emülatör tespit edildi (Fingerprint kontrolü)');
      }
      
      // Gerçek cihaz tespiti (Samsung, Xiaomi, vb.) - öncelikli
      if (manufacturerLower.contains('samsung') ||
          manufacturerLower.contains('xiaomi') ||
          manufacturerLower.contains('huawei') ||
          manufacturerLower.contains('oneplus') ||
          manufacturerLower.contains('oppo') ||
          manufacturerLower.contains('vivo') ||
          manufacturerLower.contains('realme') ||
          manufacturerLower.contains('motorola') ||
          manufacturerLower.contains('lg') ||
          manufacturerLower.contains('sony') ||
          (manufacturerLower.contains('google') && !modelLower.contains('sdk'))) {
        isEmulator = false;
        print('✅ Gerçek cihaz tespit edildi (Manufacturer: $manufacturer)');
      }
      
      print('🎯 Sonuç: ${isEmulator ? "EMÜLATÖR" : "GERÇEK CİHAZ"}');
      print('🔍 ========================================');
      
      return isEmulator;
    } catch (e) {
      print('❌ Emülatör tespiti hatası: $e');
      // Hata durumunda varsayılan olarak gerçek cihaz kabul et (telefon için)
      return false;
    }
  }
  
  /// Emülatörde mi çalışıyoruz? (sync getter - cache kullanır)
  static bool get _isEmulator {
    if (_cachedIsEmulator != null) {
      return _cachedIsEmulator!;
    }
    
    // İlk çağrıda async kontrol yap, sonra cache kullan
    // Bu geçici olarak false döner, async kontrol tamamlanınca güncellenir
    _checkIsEmulator().then((isEmulator) {
      _cachedIsEmulator = isEmulator;
    });
    
    // İlk çağrıda varsayılan olarak gerçek cihaz kabul et
    // (Telefon için güvenli varsayım)
    return false;
  }
  
  /// Backend base URL'ini döndürür (async - emülatör tespiti için)
  static Future<String> getBaseUrl() async {
    if (kIsWeb) {
      return 'http://localhost:8082';
    }
    
    final isEmulator = await _checkIsEmulator();
    _cachedIsEmulator = isEmulator;
    
    if (isEmulator) {
      return 'http://$_emulatorIp:8082';
    } else {
      return 'http://$_realDeviceIp:8082';
    }
  }
  
  /// Backend base URL'ini döndürür (sync - cache kullanır)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8082';
    }
    
    // Cache varsa kullan, yoksa gerçek cihaz varsay (telefon için güvenli)
    if (_cachedIsEmulator == true) {
      return 'http://$_emulatorIp:8082';
    } else {
      return 'http://$_realDeviceIp:8082';
    }
  }
  
  /// API base URL'ini döndürür
  static String get apiBaseUrl {
    return '${baseUrl}/api';
  }
  
  /// Socket.io URL'ini döndürür (async - emülatör tespiti için)
  static Future<String> getSocketUrl() async {
    if (kIsWeb) {
      return 'http://localhost:9092';
    }
    
    final isEmulator = await _checkIsEmulator();
    _cachedIsEmulator = isEmulator;
    
    if (isEmulator) {
      return 'http://$_emulatorIp:9092';
    } else {
      return 'http://$_realDeviceIp:9092';
    }
  }
  
  /// Socket.io URL'ini döndürür (sync - cache kullanır)
  static String get socketUrl {
    if (kIsWeb) {
      return 'http://localhost:9092';
    }
    
    // Cache varsa kullan, yoksa gerçek cihaz varsay (telefon için güvenli)
    if (_cachedIsEmulator == true) {
      return 'http://$_emulatorIp:9092';
    } else {
      return 'http://$_realDeviceIp:9092';
    }
  }
  
  /// Debug: Hangi IP kullanıldığını göster
  static String get debugInfo {
    if (kIsWeb) {
      return 'Web platform - localhost';
    }
    
    final ip = (_cachedIsEmulator == true) ? _emulatorIp : _realDeviceIp;
    final deviceType = (_cachedIsEmulator == true) ? 'Emülatör' : 'Gerçek Cihaz';
    return '$deviceType - IP: $ip';
  }
  
  /// Emülatör tespitini başlat (uygulama başlangıcında çağrılmalı)
  static Future<void> initialize() async {
    if (!kIsWeb && Platform.isAndroid) {
      _cachedIsEmulator = await _checkIsEmulator();
    }
  }
}

