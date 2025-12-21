import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'video_call_screen.dart';
import '../theme/app_theme.dart';
import '../utils/backend_config.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  IO.Socket? socket;
  bool isSearching = false;
  String? roomId;
  String? matchedUserId;
  int queueSize = 0;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Socket'i başlat ama henüz queue'ya girme
    _connectSocket();
  }

  void _connectSocket() {
    // Async işlemi başlat
    _initializeAndConnect();
  }
  
  Future<void> _initializeAndConnect() async {
    // Backend URL'i BackendConfig'den al (async tespit için)
    String socketUrl;
    try {
      socketUrl = await BackendConfig.getSocketUrl();
      print('🔌 Backend bilgisi: ${BackendConfig.debugInfo}');
      print('🔌 Socket URL: $socketUrl');
    } catch (e) {
      // Hata durumunda varsayılan olarak gerçek cihaz IP'si kullan
      socketUrl = 'http://192.168.1.102:9092';
      print('⚠️ Emülatör tespiti hatası, varsayılan IP kullanılıyor: $socketUrl');
    }
    
    socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionAttempts': 5,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Socket connected to: $socketUrl');
      if (!_isInitialized) {
        _isInitialized = true;
      }
      if (mounted) {
        setState(() {
          // Bağlantı başarılı
        });
      }
    });

    socket!.onDisconnect((_) {
      print('Socket disconnected - attempting reconnect');
      if (mounted) {
        setState(() {
          isSearching = false;
        });
      }
    });

    socket!.onError((error) {
      print('Socket error: $error');
    });

    socket!.on('queue_status', (data) {
      print('📊 Queue status received: $data');
      if (mounted) {
        setState(() {
          queueSize = data['queueSize'] ?? 0;
        });
        print('📊 Queue size: $queueSize');
      }
    });

    socket!.on('match_found', (data) {
      print('🎯 MATCH_FOUND EVENT RECEIVED!');
      print('📦 Event data: $data');
      print('📦 Event data type: ${data.runtimeType}');
      
      if (!mounted) {
        print('⚠️ Widget disposed, ignoring match_found event');
        return;
      }
      
      setState(() {
        isSearching = false;
        if (data is Map) {
          roomId = data['roomId']?.toString();
          matchedUserId = data['matchedUserId']?.toString();
          print('✅ RoomId: $roomId, MatchedUserId: $matchedUserId');
        } else {
          print('❌ Data is not a Map!');
        }
      });

      // Role'i al (caller veya callee)
      // Debug: Tüm data'yı yazdır
      print('Match found! Full data: $data');
      print('Match found! Data type: ${data.runtimeType}');
      
      String? role;
      if (data is Map) {
        role = data['role']?.toString();
        print('Match found! Role from Map: $role');
      } else {
        // Eğer data Map değilse, dynamic olarak erişmeyi dene
        try {
          role = (data as dynamic)['role']?.toString();
          print('Match found! Role from dynamic: $role');
        } catch (e) {
          print('Error getting role: $e');
        }
      }
      
      // Eğer role hala null ise, fallback: roomId'ye göre belirle
      // RoomId formatı: room_timestamp1_timestamp2
      // Daha küçük timestamp'e sahip olan caller olsun
      if (role == null || role.isEmpty) {
        if (roomId != null) {
          final parts = roomId!.split('_');
          if (parts.length >= 3) {
            final timestamp1 = int.tryParse(parts[1]) ?? 0;
            final timestamp2 = int.tryParse(parts[2]) ?? 0;
            // Mevcut userId'yi al (socket'ten veya local'den)
            // Basit fallback: matchedUserId ile karşılaştır
            // Eğer matchedUserId daha küçükse, o caller olsun
            final currentUserId = DateTime.now().millisecondsSinceEpoch.toString();
            if (matchedUserId != null) {
              final matchedTimestamp = int.tryParse(matchedUserId!) ?? 0;
              final currentTimestamp = int.tryParse(currentUserId) ?? 0;
              // Daha küçük timestamp caller olsun
              role = (matchedTimestamp < currentTimestamp) ? 'callee' : 'caller';
              print('Match found! Role fallback: $role (matchedTimestamp: $matchedTimestamp, currentTimestamp: $currentTimestamp)');
            } else {
              role = 'caller'; // Default
              print('Match found! Role fallback: $role (default caller - no matchedUserId)');
            }
          } else {
            role = 'caller'; // Default
            print('Match found! Role fallback: $role (default caller - invalid roomId format)');
          }
        } else {
          role = 'caller'; // Default
          print('Match found! Role fallback: $role (default caller - no roomId)');
        }
      }
      
      print('Match found! Final Role: $role, RoomId: $roomId, MatchedUserId: $matchedUserId');

      // Room'a katıl
      socket!.emit('join_room', {'roomId': roomId});

      // Video call ekranına geç (socket bağlantısını koru)
      if (mounted && roomId != null && matchedUserId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              socket: socket!,
              roomId: roomId!,
              matchedUserId: matchedUserId!,
              role: role, // Role'i geçir
            ),
          ),
        );
      } else {
        print('⚠️ Cannot navigate: widget not mounted or missing data');
      }
    });

    socket!.onDisconnect((_) {
      print('Socket disconnected');
      if (mounted && isSearching) {
        setState(() {
          isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı koptu. Lütfen tekrar deneyin.')),
        );
      }
    });
  }

  void _startMatchmaking() {
    if (socket == null || !socket!.connected) {
      _connectSocket();
      // Socket bağlanana kadar bekle
      Future.delayed(const Duration(milliseconds: 500), () {
        if (socket != null && socket!.connected) {
          _joinQueue();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bağlantı kurulamadı. Lütfen tekrar deneyin.')),
            );
          }
        }
      });
    } else {
      _joinQueue();
    }
  }

  void _joinQueue() {
    if (socket != null && socket!.connected) {
      String userId = DateTime.now().millisecondsSinceEpoch.toString();
      print('🚀 Joining queue with userId: $userId');
      print('🔌 Socket connected: ${socket!.connected}');
      socket!.emit('join_queue', {'userId': userId});
      if (mounted) {
        setState(() {
          isSearching = true;
        });
      }
      print('✅ join_queue event emitted');
    } else {
      print('❌ Cannot join queue: socket is null or not connected');
      print('Socket: $socket, Connected: ${socket?.connected}');
    }
  }

  void _cancelSearch() {
    socket?.emit('leave_queue');
    if (mounted) {
      setState(() {
        isSearching = false;
        queueSize = 0;
      });
    }
  }

  @override
  void dispose() {
    // Socket'i dispose etme - video call ekranında kullanılacak
    // Sadece queue'dan çık
    if (isSearching) {
      socket?.emit('leave_queue');
    }
    // Socket'i disconnect etme, video call ekranında kullanılacak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Eşleşme'),
        backgroundColor: AppTheme.darkBackground,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSearching) ...[
              // Arama animasyonu
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Eşleşme aranıyor...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (queueSize > 0)
                Text(
                  'Kuyrukta $queueSize kişi bekliyor',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _cancelSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('İptal'),
              ),
            ] else ...[
              Icon(
                Icons.search,
                size: 80,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 32),
              Text(
                'Eşleşme başlat',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _startMatchmaking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                ),
                child: const Text(
                  'Eşleşmeyi Başlat',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

