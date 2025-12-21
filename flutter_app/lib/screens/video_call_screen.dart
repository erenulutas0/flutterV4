// import 'dart:js' as js; // Web only - disabled for Android
import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class VideoCallScreen extends StatefulWidget {
  final IO.Socket socket;
  final String roomId;
  final String matchedUserId;
  final String? role; // 'caller' or 'callee'

  const VideoCallScreen({
    super.key,
    required this.socket,
    required this.roomId,
    required this.matchedUserId,
    this.role, // Optional, will be determined from match_found event
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  dynamic _webrtcManager; // js.JsObject? yerine dynamic kullan (platform agnostic)
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isRemoteVideoReady = false;
  String _connectionState = 'Connecting...';
  double _remoteVolume = 1.0; // 0.0 - 1.0
  double _localVolume = 1.0; // 0.0 - 1.0
  
  // Android WebRTC için
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream; // Remote stream'i tutmak için
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isLocalRendererInitialized = false;
  bool _isRemoteRendererInitialized = false;
  int _iceRestartAttempts = 0;
  static const int _maxIceRestartAttempts = 3;
  bool _remoteRendererBound = false; // Remote renderer sadece bir kez bağlanacak

  @override
  void initState() {
    super.initState();
    
    // Video call sırasında ekranı açık tut (Android için)
    if (!kIsWeb) {
      WakelockPlus.enable();
      print('🔋 Wakelock enabled - ekran açık tutuluyor');
    }
    
    if (!kIsWeb) {
      // Android'de WebRTC desteği var
      print('📱 Android platformu: WebRTC başlatılıyor');
      print('✅ Eşleşme başarılı! RoomId: ${widget.roomId}, MatchedUserId: ${widget.matchedUserId}');
      _initializeAndroidWebRTC();
      return;
    }
    // Web için role belirleme (Android'de zaten yapılıyor)
    final role = widget.role ?? 'caller';
    print('🔧 Web platform - Role: $role');
    
    // Socket bağlantısını kontrol et
    if (!widget.socket.connected) {
      widget.socket.connect();
      // Bağlantıyı bekle
      widget.socket.onConnect((_) async {
        await _initializeWebRTC();
        _setupSocketListeners(role);
      });
    } else {
      _initializeWebRTC().then((_) {
        _setupSocketListeners(role);
      });
    }
    
    // Socket disconnect listener'ı ekle - Web için
    // Not: Android için disconnect listener'ı _setupSocketListeners içinde ekleniyor
    if (kIsWeb) {
      widget.socket.onDisconnect((_) {
        print('⚠️ Socket disconnected in VideoCallScreen (Web) - attempting reconnect');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bağlantı koptu. Yeniden bağlanılıyor...'),
              duration: Duration(seconds: 2),
            ),
          );
          // Reconnect dene
          widget.socket.connect();
        }
      });
    }
  }

  Future<void> _initializeAndroidWebRTC() async {
    try {
      print('🚀 ========== ANDROID WEBRTC INITIALIZATION STARTED ==========');
      print('🚀 RoomId: ${widget.roomId}');
      print('🚀 MatchedUserId: ${widget.matchedUserId}');
      print('🚀 Role: ${widget.role}');
      print('🚀 Socket connected: ${widget.socket.connected}');
      print('🚀 Socket ID: ${widget.socket.id}');
      
      // İzinleri kontrol et
      print('🔐 ========== REQUESTING PERMISSIONS ==========');
      try {
        await _requestPermissions();
        print('✅ Permissions granted');
      } catch (e) {
        print('❌ Permission error: $e');
        rethrow;
      }
      
      // Renderer'ları başlat
      print('📹 ========== INITIALIZING RENDERERS ==========');
      try {
        print('📹 Initializing local renderer...');
        await _localRenderer.initialize();
        print('✅ Local renderer initialized');
        
        print('📹 Initializing remote renderer...');
        await _remoteRenderer.initialize();
        print('✅ Remote renderer initialized');
        
        if (mounted) {
          setState(() {
            _isLocalRendererInitialized = true;
            _isRemoteRendererInitialized = true;
          });
        }
        print('✅ Renderers initialized and state updated');
      } catch (e) {
        print('❌ Renderer initialization error: $e');
        rethrow;
      }
      
      // STUN ve TURN server'ları
      // Emülatörler arası bağlantı için TURN gerekebilir
      final configuration = {
        'iceServers': [
          // STUN servers
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          // TURN servers for better NAT traversal, especially between emulators
          {
            'urls': 'turn:openrelay.metered.ca:80',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
          {
            'urls': 'turn:openrelay.metered.ca:443',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
          {
            'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
          {
            'urls': 'turn:openrelay.metered.ca:80?transport=tcp',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
          {
            'urls': 'turn:openrelay.metered.ca:3478',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
          {
            'urls': 'turn:openrelay.metered.ca:3478?transport=tcp',
            'username': 'openrelayproject',
            'credential': 'openrelayproject',
          },
        ],
        'iceTransportPolicy': 'all', // Tüm ICE transport'ları dene
        'iceCandidatePoolSize': 20, // Daha fazla ICE candidate
        'bundlePolicy': 'max-bundle', // Bundle all media on single transport
        'rtcpMuxPolicy': 'require', // Require RTCP muxing
      };
      
      // Peer connection oluştur
      print('🔧 Creating peer connection...');
      _peerConnection = await createPeerConnection(configuration);
      print('✅ Peer connection created');
      print('🔧 Initial signaling state: ${_peerConnection!.signalingState}');
      
      // Local stream oluştur (kamera ve mikrofon)
      print('📹 Kamera ve mikrofon erişimi isteniyor...');
      
      // Android için optimize edilmiş video constraints
      // Daha yüksek kalite için ayarlar
      final Map<String, dynamic> constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280, 'min': 640, 'max': 1920},
          'height': {'ideal': 720, 'min': 480, 'max': 1080},
          'frameRate': {'ideal': 30, 'min': 20, 'max': 30},
          'aspectRatio': {'ideal': 16.0 / 9.0},
        },
      };
      
      print('📹 ========== REQUESTING USER MEDIA ==========');
      print('📹 Constraints: $constraints');
      try {
      print('📹 ========== REQUESTING USER MEDIA ==========');
      print('📹 Constraints: $constraints');
      try {
        _localStream = await navigator.mediaDevices.getUserMedia(constraints);
        print('✅ Kamera ve mikrofon erişimi başarılı');
        print('✅ Local stream ID: ${_localStream?.id}');
      } catch (e) {
        print('❌ getUserMedia error: $e');
        rethrow;
      }
        print('✅ Local stream ID: ${_localStream?.id}');
      } catch (e) {
        print('❌ getUserMedia error: $e');
        rethrow;
      }
      
      // Track'leri logla ve video kalitesini optimize et
      final tracks = _localStream!.getTracks();
      print('📹 Local stream tracks: ${tracks.length}');
      tracks.forEach((track) {
        print('  - Track: ${track.kind}, enabled: ${track.enabled}, id: ${track.id}');
        if (track.kind == 'video') {
          final videoTrack = track as MediaStreamTrack;
          final settings = videoTrack.getSettings();
          print('    Video track settings: $settings');
          
          // Video kalitesini artırmak için constraint'leri uygula
          try {
            videoTrack.applyConstraints({
              'width': {'ideal': 1280, 'min': 640},
              'height': {'ideal': 720, 'min': 480},
              'frameRate': {'ideal': 30, 'min': 20},
            });
            print('    ✅ Video constraints applied for better quality');
          } catch (e) {
            print('    ⚠️ Could not apply video constraints: $e');
          }
        }
      });
      
      // Local stream'i peer connection'a ekle
      print('📹 ========== ADDING TRACKS TO PEER CONNECTION ==========');
      tracks.forEach((track) {
        print('📹 Adding ${track.kind} track to peer connection...');
        print('📹 Track ID: ${track.id}');
        print('📹 Track enabled: ${track.enabled}');
        try {
          _peerConnection!.addTrack(track, _localStream!);
          print('✅ Added ${track.kind} track to peer connection successfully');
        } catch (e) {
          print('❌ Error adding ${track.kind} track: $e');
        }
      });
      print('📹 ========== TRACKS ADDED TO PEER CONNECTION ==========');
      
      // Local video renderer'a ekle - MUTLAKA set et
      print('📹 Setting local stream to renderer...');
      print('📹 Local stream: ${_localStream != null}');
      print('📹 Local renderer initialized: $_isLocalRendererInitialized');
      
      if (_localStream == null) {
        print('❌ ERROR: Local stream is null!');
        throw Exception('Local stream is null');
      }
      
      if (!_isLocalRendererInitialized) {
        print('❌ ERROR: Local renderer not initialized!');
        throw Exception('Local renderer not initialized');
      }
      
      // Renderer'a stream'i set et
      _localRenderer.srcObject = _localStream;
      
      // Kontrol et
      await Future.delayed(const Duration(milliseconds: 100));
      print('📹 Local renderer srcObject set: ${_localRenderer.srcObject != null}');
      if (_localRenderer.srcObject != null) {
        print('📹 Local renderer has ${_localRenderer.srcObject!.getTracks().length} tracks');
        _localRenderer.srcObject!.getTracks().forEach((track) {
          print('  - Local renderer track: ${track.kind}, enabled: ${track.enabled}');
        });
        
        // State'i güncelle
        if (mounted) {
          setState(() {
            // Local video hazır
          });
        }
      } else {
        print('❌ WARNING: Local renderer srcObject is null after setting!');
        print('❌ Retrying...');
        await Future.delayed(const Duration(milliseconds: 200));
        _localRenderer.srcObject = _localStream;
        if (_localRenderer.srcObject == null) {
          print('❌ ERROR: Failed to set local renderer srcObject after retry!');
        }
      }
      
      // Remote stream listener - SADECE BİR KEZ RENDERER'A BAĞLA
      print('🎬 ========== REGISTERING onTrack LISTENER ==========');
      print('🎬 Peer connection: ${_peerConnection != null}');
      _peerConnection!.onTrack = (event) {
        print('🎬 ========== onTrack EVENT RECEIVED ==========');
        print('🎬 ⚠️⚠️⚠️ THIS IS CRITICAL - onTrack IS BEING CALLED ⚠️⚠️⚠️');
        print('🎬 Track kind: ${event.track.kind}');
        print('🎬 Streams count: ${event.streams.length}');
        print('🎬 Track ID: ${event.track.id}');
        print('🎬 Track enabled: ${event.track.enabled}');
        print('🎬 Remote renderer already bound: $_remoteRendererBound');
        
        // Renderer zaten bağlandıysa, tekrar set etme (EGL reset'i önlemek için)
        if (_remoteRendererBound && _remoteRenderer.srcObject != null) {
          print('⚠️ Remote renderer already bound, skipping srcObject assignment');
          // Sadece track'leri enable et
          if (event.streams.isNotEmpty) {
            event.streams[0].getTracks().forEach((track) {
              if (!track.enabled) {
                track.enabled = true;
                print('    ✅ Enabled ${track.kind} track: ${track.id}');
              }
            });
          }
          return;
        }
        
        // Stream varsa kullan
        if (event.streams.isEmpty) {
          print('⚠️ No stream in event, waiting for stream...');
          return;
        }
        
        _remoteStream = event.streams[0];
        print('✅ Using stream from event: ${_remoteStream!.id}');
        print('✅ Remote stream tracks: ${_remoteStream!.getTracks().length}');
        
        // Track'leri enable et
        _remoteStream!.getTracks().forEach((track) {
          print('  - Remote track: ${track.kind}, enabled: ${track.enabled}, id: ${track.id}');
          if (!track.enabled) {
            track.enabled = true;
            print('    ✅ Enabled ${track.kind} track');
          }
        });
        
        // Video track varsa renderer'a SADECE BİR KEZ set et
        final videoTracks = _remoteStream!.getVideoTracks();
        if (videoTracks.isNotEmpty && !_remoteRendererBound) {
          print('✅ Found ${videoTracks.length} video track(s) in remote stream');
          print('✅ Setting remote stream to renderer (FIRST TIME ONLY)...');
          
          // Renderer'a SADECE BİR KEZ set et
          _remoteRenderer.srcObject = _remoteStream;
          _remoteRendererBound = true; // Flag'i set et
          
          // Kontrol et
          if (_remoteRenderer.srcObject != null) {
            print('✅ Renderer srcObject set successfully');
            print('✅ Renderer srcObject tracks: ${_remoteRenderer.srcObject!.getTracks().length}');
          } else {
            print('❌ Renderer srcObject is null after setting!');
            _remoteRendererBound = false; // Retry için flag'i reset et
          }
          
          if (mounted) {
            setState(() {
              _isRemoteVideoReady = true;
              _connectionState = 'Bağlandı';
            });
          }
          print('✅ Remote video ready set to true');
        } else if (videoTracks.isEmpty) {
          print('⚠️ No video tracks in remote stream yet (might be audio only)');
        }
        
        print('🎬 ========== onTrack EVENT HANDLED ==========');
      };
      
      // ICE gathering state listener - TURN server'ların çalışıp çalışmadığını kontrol et
      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        print('🧊 ========== ICE GATHERING STATE CHANGED ==========');
        print('🧊 New gathering state: $state');
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          print('✅ ICE gathering complete - all candidates collected');
        } else if (state == RTCIceGatheringState.RTCIceGatheringStateGathering) {
          print('🔄 ICE gathering in progress...');
        } else if (state == RTCIceGatheringState.RTCIceGatheringStateNew) {
          print('🆕 ICE gathering started');
        }
      };
      
      // ICE candidate listener
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        // Null kontrolleri yap
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          final candidateStr = candidate.candidate!;
          final candidateData = {
            'roomId': widget.roomId,
            'candidate': candidateStr,
            'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
            'sdpMid': candidate.sdpMid ?? '',
          };
          print('📤 Sending ICE candidate: ${candidateStr.length > 50 ? candidateStr.substring(0, 50) : candidateStr}...');
          widget.socket.emit('webrtc_ice_candidate', candidateData);
        } else {
          print('⚠️ ICE candidate is null or empty, skipping');
        }
      };
      
      // Connection state listener
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('🔌 Connection state changed: $state');
        if (mounted) {
          setState(() {
            if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
              _connectionState = 'Bağlandı';
            } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnecting) {
              _connectionState = 'Bağlanıyor...';
            } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
              _connectionState = 'Bağlantı kesildi - Yeniden deneniyor...';
            } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
              _connectionState = 'Bağlantı hatası - Yeniden deneniyor...';
            } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
              _connectionState = 'Bağlantı kapandı';
            }
          });
        }
        
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          print('✅ Peer connection connected!');
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          print('⚠️ Peer connection failed - keeping call alive, user can manually end');
          // Otomatik sonlandırma yok - sadece durumu güncelle
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          print('⚠️ Peer connection closed!');
          // Sadece kullanıcı manuel olarak sonlandırdığında veya call_ended event'i geldiğinde kapanmalı
        }
      };
      
      // ICE connection state listener
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('🧊 ========== ICE CONNECTION STATE CHANGED ==========');
        print('🧊 New state: $state');
        print('🧊 Remote stream: ${_remoteStream != null}');
        print('🧊 Remote renderer bound: $_remoteRendererBound');
        if (_remoteStream != null) {
          print('🧊 Remote stream tracks: ${_remoteStream!.getTracks().length}');
          print('🧊 Remote stream video tracks: ${_remoteStream!.getVideoTracks().length}');
        }
        
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          print('✅ ICE connection established!');
          
          // Connection kurulduğunda remote stream'i kontrol et
          // Ama renderer zaten bağlandıysa tekrar set etme (EGL reset'i önlemek için)
          if (_remoteStream != null && _remoteStream!.getVideoTracks().isNotEmpty && !_remoteRendererBound) {
            print('✅ ICE connected: Remote stream has video tracks, setting renderer...');
            _remoteRenderer.srcObject = _remoteStream;
            _remoteRendererBound = true;
            if (mounted) {
              setState(() {
                _isRemoteVideoReady = true;
                _connectionState = 'Bağlandı';
              });
            }
          } else if (_remoteRendererBound) {
            print('✅ ICE connected: Remote renderer already bound, skipping');
            if (mounted) {
              setState(() {
                _connectionState = 'Bağlandı';
              });
            }
          } else {
            print('⚠️ ICE connected but no remote video stream yet');
            print('⚠️ Waiting for onTrack event...');
            print('⚠️ This might indicate that onTrack events are not being received');
            print('⚠️ Check if media tracks are being added to peer connection');
          }
          
          if (mounted) {
            setState(() {
              _connectionState = 'Bağlandı';
            });
          }
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          print('⚠️ ICE connection failed!');
          print('🔄 Attempting ICE restart (attempt ${_iceRestartAttempts + 1}/$_maxIceRestartAttempts)...');
          
          if (mounted) {
            setState(() {
              _connectionState = 'Bağlantı hatası - Yeniden deneniyor...';
            });
          }
          
          // ICE restart mekanizması - socket bağlıysa dene
          if (widget.socket.connected && _iceRestartAttempts < _maxIceRestartAttempts && _peerConnection != null) {
            _iceRestartAttempts++;
            _performIceRestart();
          } else if (!widget.socket.connected) {
            print('⚠️ Socket not connected, cannot perform ICE restart. Waiting for socket reconnect...');
            // Socket bağlantısını bekle - reconnect olduğunda tekrar dene
            _waitForSocketAndRetryIceRestart();
          } else {
            print('⚠️ Max ICE restart attempts reached. Connection failed but keeping call alive.');
            if (mounted) {
              setState(() {
                _connectionState = 'Bağlantı sorunu - Görüşme devam ediyor...';
              });
            }
            // Otomatik sonlandırma yok - görüşmeyi devam ettir
          }
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          print('⚠️ ICE connection disconnected!');
          print('🔄 Attempting ICE restart (attempt ${_iceRestartAttempts + 1}/$_maxIceRestartAttempts)...');
          
          if (mounted) {
            setState(() {
              _connectionState = 'Bağlantı kesildi - Yeniden deneniyor...';
            });
          }
          
          // Disconnected durumunda da ICE restart dene - socket bağlıysa
          if (widget.socket.connected && _iceRestartAttempts < _maxIceRestartAttempts && _peerConnection != null) {
            _iceRestartAttempts++;
            _performIceRestart();
          } else if (!widget.socket.connected) {
            print('⚠️ Socket not connected, cannot perform ICE restart. Waiting for socket reconnect...');
            // Socket bağlantısını bekle
            _waitForSocketAndRetryIceRestart();
          }
        }
      };
      
      // Role'e göre offer veya answer oluştur
      print('🔧 ========== ROLE CHECK ==========');
      print('🔧 Widget role: ${widget.role}');
      print('🔧 Widget role type: ${widget.role?.runtimeType}');
      print('🔧 Widget role is null: ${widget.role == null}');
      print('🔧 Widget role is empty: ${widget.role?.isEmpty ?? true}');
      print('🔧 Socket connected: ${widget.socket.connected}');
      print('🔧 Socket ID: ${widget.socket.id}');
      
      // Role null ise veya boşsa, caller olarak varsay
      String role;
      if (widget.role == null || widget.role!.isEmpty) {
        role = 'caller';
        print('🔧 Role is null or empty, defaulting to caller');
      } else {
        role = widget.role!;
        print('🔧 Using provided role: $role');
      }
      
      print('🔧 Final role to use: $role');
      print('🔧 Role comparison (caller): ${role == 'caller'}');
      print('🔧 Role comparison (callee): ${role == 'callee'}');
      
      // Socket listener'ları role'e göre kur - KRİTİK!
      print('🔧 Setting up socket listeners based on role...');
      _setupSocketListeners(role);
      print('✅ Socket listeners set up');
      print('🔧 Socket connected after setup: ${widget.socket.connected}');
      
      if (role == 'caller') {
        print('📤 ========== CALLER MODE ==========');
        print('📤 Caller: Creating offer...');
        print('📤 Peer connection exists: ${_peerConnection != null}');
        print('📤 Local stream exists: ${_localStream != null}');
        // Kısa bir gecikme ekle (socket listener'ların kurulması için)
        await Future.delayed(const Duration(milliseconds: 1500));
        print('📤 Delay completed, creating offer now...');
        await _createOffer();
        print('📤 Offer creation completed');
      } else {
        print('📥 ========== CALLEE MODE ==========');
        print('📥 Callee: Waiting for offer...');
        print('📥 Socket listeners should receive offer event');
        print('📥 Peer connection exists: ${_peerConnection != null}');
        print('📥 Local stream exists: ${_localStream != null}');
        // Callee için answer bekliyoruz, offer geldiğinde answer oluşturacağız
      }
      
      if (mounted) {
        setState(() {
          _connectionState = 'Bağlanıyor...';
        });
      }
      print('✅ ========== WEBRTC INITIALIZATION COMPLETE ==========');
    } catch (e) {
      print('❌ Android WebRTC initialization error: $e');
      String errorMessage = 'Bağlantı hatası';
      if (e.toString().contains('NotAllowedError') || e.toString().contains('izin')) {
        errorMessage = 'Kamera ve mikrofon izinleri gerekli!\nLütfen uygulama ayarlarından izinleri verin.';
      } else if (e.toString().contains('getUserMedia')) {
        errorMessage = 'Kamera/mikrofon erişilemiyor.\nEmülatör ayarlarını kontrol edin.';
      } else {
        errorMessage = 'Hata: $e';
      }
      
      setState(() {
        _connectionState = errorMessage;
      });
      
      // Kullanıcıya bilgi ver
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Ayarlar',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }
  
  Future<void> _requestPermissions() async {
    print('🔐 İzinler isteniyor...');
    
    // Kamera izni
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Kamera izni verilmedi');
      }
    }
    print('✅ Kamera izni verildi');
    
    // Mikrofon izni
    var microphoneStatus = await Permission.microphone.status;
    if (!microphoneStatus.isGranted) {
      microphoneStatus = await Permission.microphone.request();
      if (!microphoneStatus.isGranted) {
        throw Exception('Mikrofon izni verilmedi');
      }
    }
    print('✅ Mikrofon izni verildi');
  }
  
  Future<void> _createOffer() async {
    try {
      print('📤 ========== CREATING OFFER ==========');
      print('📤 Peer connection: ${_peerConnection != null}');
      
      if (_peerConnection == null) {
        print('❌ ERROR: Peer connection is null!');
        return;
      }
      
      // Signaling state kontrolü
      final currentState = _peerConnection!.signalingState;
      print('📤 Current signaling state before offer: $currentState');
      print('📤 Socket connected: ${widget.socket.connected}');
      print('📤 Socket ID: ${widget.socket.id}');
      print('📤 RoomId: ${widget.roomId}');
      
      if (!widget.socket.connected) {
        print('❌ ERROR: Socket is not connected!');
        print('❌ Attempting to reconnect...');
        widget.socket.connect();
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!widget.socket.connected) {
          print('❌ ERROR: Socket still not connected after reconnect attempt!');
          return;
        }
      }
      
      if (currentState != RTCSignalingState.RTCSignalingStateStable) {
        print('⚠️ Warning: Signaling state is not stable: $currentState');
        print('⚠️ Waiting for stable state...');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      print('📤 Creating offer...');
      final offer = await _peerConnection!.createOffer();
      print('📤 Offer created: ${offer.type}');
      
      // Null kontrolleri
      if (offer.sdp == null || offer.sdp!.isEmpty) {
        print('❌ Offer SDP is null or empty');
        return;
      }
      
      print('📤 Offer SDP length: ${offer.sdp!.length}');
      print('📤 Setting local description (offer)...');
      print('📤 Signaling state BEFORE setLocalDescription: ${_peerConnection!.signalingState}');
      await _peerConnection!.setLocalDescription(offer);
      print('✅ Local description (offer) set successfully');
      final newState = _peerConnection!.signalingState;
      print('📤 New signaling state AFTER setLocalDescription: $newState');
      
      // State'in "have-local-offer" olduğundan emin ol
      if (newState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        print('⚠️ WARNING: Signaling state is not "have-local-offer" after setLocalDescription!');
        print('⚠️ State: $newState');
        print('⚠️ This might cause issues when answer arrives');
      } else {
        print('✅ Signaling state is correct: $newState');
      }
      
      // Backend'in beklediği format: { "roomId": "...", "offer": { "sdp": "...", "type": "offer" } }
      print('📤 ========== EMITTING OFFER TO SOCKET ==========');
      print('📤 Socket connected: ${widget.socket.connected}');
      print('📤 RoomId: ${widget.roomId}');
      
      final offerData = {
        'roomId': widget.roomId,
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      };
      
      print('📤 Emitting webrtc_offer event...');
      widget.socket.emit('webrtc_offer', offerData);
      print('✅ Offer emitted to socket');
      
      // Socket'in emit ettiğini doğrula
      if (!widget.socket.connected) {
        print('❌ WARNING: Socket is not connected after emit!');
      } else {
        print('✅ Socket is still connected after emit');
      }
      
      print('📤 ========== OFFER CREATION COMPLETE ==========');
    } catch (e, stackTrace) {
      print('❌ Error creating offer: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }
  
  Future<void> _performIceRestart() async {
    print('🔄 ========== PERFORMING ICE RESTART ==========');
    try {
      if (_peerConnection == null) {
        print('❌ Peer connection is null, cannot perform ICE restart');
        return;
      }
      
      final role = widget.role ?? 'caller';
      print('🔄 Role: $role');
      print('🔄 Current signaling state: ${_peerConnection!.signalingState}');
      
      // ICE restart için yeni offer/answer oluştur
      if (role == 'caller') {
        print('🔄 Caller: Creating new offer for ICE restart...');
        // ICE restart için yeni offer oluştur (createOffer otomatik olarak ICE restart yapar)
        await _createOffer();
      } else {
        print('🔄 Callee: Waiting for new offer after ICE restart...');
        // Callee için caller'dan yeni offer gelmesi gerekiyor
        // Bu durumda sadece bekle
      }
      
      print('✅ ICE restart initiated');
    } catch (e, stackTrace) {
      print('❌ Error performing ICE restart: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }
  
  Future<void> _createAnswer() async {
    try {
      // Signaling state kontrolü
      final currentState = _peerConnection!.signalingState;
      print('📤 Current signaling state before answer: $currentState');
      
      // Answer oluşturmak için "have-remote-offer" olmalı
      if (currentState != RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        print('⚠️ Warning: Signaling state is not have-remote-offer: $currentState');
        print('⚠️ Continuing anyway, but this might cause issues');
      }
      
      final answer = await _peerConnection!.createAnswer();
      
      // Null kontrolleri
      if (answer.sdp == null || answer.sdp!.isEmpty) {
        print('❌ Answer SDP is null or empty');
        return;
      }
      
      print('📤 Setting local description (answer)...');
      await _peerConnection!.setLocalDescription(answer);
      print('✅ Local description (answer) set successfully');
      print('📤 New signaling state: ${_peerConnection!.signalingState}');
      
      // Backend'in beklediği format: { "roomId": "...", "answer": { "sdp": "...", "type": "answer" } }
      widget.socket.emit('webrtc_answer', {
        'roomId': widget.roomId,
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      });
      print('✅ Answer created and sent');
    } catch (e) {
      print('❌ Error creating answer: $e');
      print('❌ Error details: ${e.toString()}');
    }
  }

  Future<void> _initializeWebRTC() async {
    if (!kIsWeb) {
      print('WebRTC sadece web platformunda destekleniyor');
      return;
    }
    // Web-specific code is now in a separate file to avoid compilation errors on Android
    // For now, Android will show a placeholder message
    setState(() {
      _connectionState = 'WebRTC sadece web platformunda destekleniyor';
    });
    return;
    // Web-only code removed for Android compatibility
    /*
    try {
      // Get WebRTCManager class from JavaScript
      dynamic WebRTCManagerClass;
      if (kIsWeb) {
        WebRTCManagerClass = js.context['WebRTCManager'];
      } else {
        return;
      }
      if (WebRTCManagerClass == null) {
        print('WebRTCManager not found in JavaScript');
        return;
      }

      // Socket.io objesini JavaScript'e geçirmek için global değişkene kaydet
      // Flutter'dan JavaScript'e Socket.io objesi doğrudan geçirilemez
      // Bunun yerine socket'i global window objesine kaydedip JavaScript'ten erişeceğiz
      if (kIsWeb) {
        final socketJs = js.context['socket_io_client'];
        if (socketJs != null) {
          // Socket.io client'ı JavaScript'e geçir
          js.context['currentSocket'] = widget.socket;
        }

        // Socket.io objesini JavaScript'e geçirmek için wrapper oluştur
        // emit metodunu Flutter tarafından çağırmak için bir wrapper kullanıyoruz
        js.context['currentSocket'] = js.JsObject.jsify({
          'emit': js.allowInterop((dynamic event, dynamic data) {
            try {
            // Event adını string'e çevir
            String eventName = '';
            if (event != null) {
              eventName = event.toString();
            } else {
              print('Error: event is null');
              return;
            }
            
            // Data'yı Dart Map'e çevir
            Map<String, dynamic> dataMap = {};
            if (data != null) {
              try {
                // Önce direkt property access dene (daha güvenli)
                if (kIsWeb && data is js.JsObject) {
                  try {
                    // roomId'yi al
                    final roomId = data['roomId'];
                    if (roomId != null) {
                      dataMap['roomId'] = roomId.toString();
                    }
                    
                    // offer'ı al
                    final offer = data['offer'];
                    if (offer != null) {
                      if (kIsWeb && offer is js.JsObject) {
                        try {
                          dataMap['offer'] = {
                            'type': offer['type']?.toString() ?? '',
                            'sdp': offer['sdp']?.toString() ?? '',
                          };
                        } catch (e) {
                          print('Error accessing offer properties: $e');
                        }
                      } else {
                        dataMap['offer'] = offer;
                      }
                    }
                    
                    // answer'ı al
                    final answer = data['answer'];
                    if (answer != null) {
                      if (kIsWeb && answer is js.JsObject) {
                        try {
                          dataMap['answer'] = {
                            'type': answer['type']?.toString() ?? '',
                            'sdp': answer['sdp']?.toString() ?? '',
                          };
                        } catch (e) {
                          print('Error accessing answer properties: $e');
                        }
                      } else {
                        dataMap['answer'] = answer;
                      }
                    }
                    
                    // candidate'ı al
                    final candidate = data['candidate'];
                    if (candidate != null) {
                      if (kIsWeb && candidate is js.JsObject) {
                        try {
                          dataMap['candidate'] = {
                            'candidate': candidate['candidate']?.toString() ?? '',
                            'sdpMLineIndex': candidate['sdpMLineIndex'],
                            'sdpMid': candidate['sdpMid']?.toString(),
                          };
                        } catch (e) {
                          print('Error accessing candidate properties: $e');
                        }
                      } else {
                        dataMap['candidate'] = candidate;
                      }
                    }
                  } catch (e) {
                    print('Direct property access failed: $e');
                    // Fallback: JSON.stringify dene
                    try {
                      final jsonStr = kIsWeb ? js.context.callMethod('JSON.stringify', [data]) : null;
                      if (jsonStr != null && jsonStr.toString().isNotEmpty && jsonStr.toString() != 'null') {
                        final decoded = convert.json.decode(jsonStr.toString());
                        if (decoded is Map) {
                          dataMap = Map<String, dynamic>.from(decoded);
                        }
                      }
                    } catch (jsonError) {
                      print('JSON.stringify also failed: $jsonError');
                    }
                  }
                } else if (data is Map) {
                  dataMap = Map<String, dynamic>.from(data);
                } else {
                  // Try JSON.stringify as last resort
                  try {
                    final jsonStr = kIsWeb ? js.context.callMethod('JSON.stringify', [data]) : null;
                    if (jsonStr != null && jsonStr.toString().isNotEmpty && jsonStr.toString() != 'null') {
                      final decoded = convert.json.decode(jsonStr.toString());
                      if (decoded is Map) {
                        dataMap = Map<String, dynamic>.from(decoded);
                      }
                    }
                  } catch (e) {
                    print('JSON.stringify failed: $e');
                  }
                }
              } catch (e) {
                print('Error converting data to map: $e');
                // Don't send error, just log it
              }
            }
            
            // Flutter socket'inden emit yap
            widget.socket.emit(eventName, dataMap);
            print('Emitted $eventName with data: $dataMap');
          } catch (e, stackTrace) {
            print('Error in socket emit wrapper: $e');
            print('Stack trace: $stackTrace');
            }
          }),
        });
      }

      // Create WebRTCManager instance with role
      if (kIsWeb && WebRTCManagerClass != null) {
        if (kIsWeb) {
          _webrtcManager = js.JsObject(WebRTCManagerClass, [
            widget.roomId,
            widget.role ?? 'callee', // Default to callee if role not provided
          ]);

          // Initialize WebRTC with role (async, but we can't await in Dart-JS interop)
          // The initialize method will handle role-based offer creation
          print('Initializing WebRTC with role: ${widget.role ?? 'callee'}');
          // Initialize returns a Promise, wait for it to complete
          (_webrtcManager as js.JsObject).callMethod('initialize', [widget.role ?? 'callee']);
        }
        // Wait for initialization to complete (getUserMedia takes time)
        await Future.delayed(const Duration(milliseconds: 500));

        // Listen for connection state changes
        // js.context zaten window objesidir, doğrudan callMethod kullanabiliriz
        if (kIsWeb) {
          js.context.callMethod('addEventListener', [
            'webrtc_connection_state',
            js.allowInterop((dynamic event) {
              try {
                if (event is js.JsObject) {
                  final detail = event['detail'];
                  if (mounted) {
                    setState(() {
                      _connectionState = detail?.toString() ?? 'Unknown';
                    });
                  }
                }
              } catch (e) {
                print('Error in connection state handler: $e');
              }
            }),
          ]);

          // Listen for remote video ready
          js.context.callMethod('addEventListener', [
            'webrtc_remote_video_ready',
            js.allowInterop((dynamic event) {
              try {
                print('Remote video ready event received');
                if (mounted) {
                  setState(() {
                    _isRemoteVideoReady = true;
                  });
                }
              } catch (e) {
                print('Error in remote video ready handler: $e');
              }
            }),
          ]);

          // Listen for WebRTC errors
          js.context.callMethod('addEventListener', [
            'webrtc_error',
            js.allowInterop((dynamic event) {
              try {
                String errorMessage = 'Bilinmeyen hata';
                if (event is js.JsObject) {
                  final detail = event['detail'];
                  errorMessage = detail?.toString() ?? 'Bilinmeyen hata';
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                  setState(() {
                    _connectionState = 'Hata: $errorMessage';
                  });
                }
              } catch (e) {
                print('Error in error handler: $e');
              }
            }),
          ]);
        }
      }

      // Room'a katıl
      widget.socket.emit('join_room', {'roomId': widget.roomId});

      setState(() {});
    } catch (e) {
      print('WebRTC initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WebRTC hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {
          _connectionState = 'Hata: $e';
        });
      }
    }
    */
  }

  void _setupSocketListeners(String role) {
      print('🔧 ========== SETTING UP SOCKET LISTENERS ==========');
      print('🔧 Role: $role');
      print('🔧 Platform: ${kIsWeb ? 'Web' : 'Android'}');
      
      if (!kIsWeb && _peerConnection != null) {
        // CALLEE için offer listener - CALLER için YOK!
        if (role == 'callee') {
          print('✅ Socket listener: webrtc_offer registered (CALLEE ONLY)');
          print('🔧 Socket connected when registering listener: ${widget.socket.connected}');
          widget.socket.on('webrtc_offer', (data) async {
        try {
          print('📥 ========== OFFER RECEIVED ==========');
          print('📥 Offer received! Data: ${data.runtimeType}');
          print('📥 Socket connected when receiving offer: ${widget.socket.connected}');
          print('📥 Raw offer data: $data');
          
          // Backend'den gelen format: { "offer": { "sdp": "...", "type": "offer" }, "from": "userId" }
          // Veya direkt: { "sdp": "...", "type": "offer" }
          String? sdp;
          String? type;
          
          if (data is Map) {
            // Önce "offer" key'ini kontrol et (backend formatı)
            if (data['offer'] != null) {
              final offerObj = data['offer'];
              if (offerObj is Map) {
                sdp = offerObj['sdp']?.toString();
                type = offerObj['type']?.toString() ?? 'offer';
              }
            } 
            // Direkt format kontrolü
            else if (data['sdp'] != null) {
              sdp = data['sdp'].toString();
              type = data['type']?.toString() ?? 'offer';
            }
          }
          
          if (sdp != null && sdp.isNotEmpty) {
            // Signaling state kontrolü
            final currentState = _peerConnection!.signalingState;
            print('📥 Current signaling state: $currentState');
            
            // Offer almak için "stable" olmalı (ama çok katı olmayalım)
            if (currentState != RTCSignalingState.RTCSignalingStateStable) {
              print('⚠️ Warning: Signaling state is not stable: $currentState');
              print('⚠️ Continuing anyway - this might be a race condition');
              // return; // Gevşetildi - devam et
            }
            
            print('📥 Receiving offer: ${sdp.substring(0, sdp.length > 50 ? 50 : sdp.length)}...');
            print('📥 Setting remote description (offer)...');
            
            try {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(sdp, type ?? 'offer'),
              );
              print('✅ Remote description (offer) set successfully');
              print('📥 New signaling state: ${_peerConnection!.signalingState}');
              
              print('📥 Creating answer...');
              await _createAnswer();
              print('✅ Answer created and sent');
            } catch (e) {
              print('❌ Error setting remote description (offer): $e');
              print('❌ Current signaling state: ${_peerConnection!.signalingState}');
            }
          } else {
            print('⚠️ Invalid offer data: $data');
            print('⚠️ SDP: $sdp, Type: $type');
          }
        } catch (e) {
          print('❌ Error handling offer: $e');
          print('❌ Error details: ${e.toString()}');
        }
      });
        } else {
          print('⚠️ CALLER MODE: NOT registering webrtc_offer listener');
          print('⚠️ Caller should only SEND offers, not receive them');
        }
      
      // CALLER için answer listener - CALLEE için YOK!
      if (role == 'caller') {
        print('✅ Socket listener: webrtc_answer registered (CALLER ONLY)');
        widget.socket.on('webrtc_answer', (data) async {
        try {
          print('📥 Answer received! Data: ${data.runtimeType}');
          print('📥 Raw answer data: $data');
          
          // Backend'den gelen format: { "answer": { "sdp": "...", "type": "answer" }, "from": "userId" }
          // Veya direkt: { "sdp": "...", "type": "answer" }
          String? sdp;
          String? type;
          
          if (data is Map) {
            // Önce "answer" key'ini kontrol et (backend formatı)
            if (data['answer'] != null) {
              final answerObj = data['answer'];
              if (answerObj is Map) {
                sdp = answerObj['sdp']?.toString();
                type = answerObj['type']?.toString() ?? 'answer';
              }
            } 
            // Direkt format kontrolü
            else if (data['sdp'] != null) {
              sdp = data['sdp'].toString();
              type = data['type']?.toString() ?? 'answer';
            }
          }
          
          if (sdp != null && sdp.isNotEmpty) {
            print('📥 ========== PROCESSING ANSWER ==========');
            print('📥 Receiving answer: ${sdp.substring(0, sdp.length > 50 ? 50 : sdp.length)}...');
            
            // Signaling state kontrolü - KRİTİK!
            final currentState = _peerConnection!.signalingState;
            print('📥 Current signaling state BEFORE answer: $currentState');
            print('📥 Expected state: RTCSignalingStateHaveLocalOffer');
            
            // Answer almak için MUTLAKA "have-local-offer" olmalı
            if (currentState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
              print('❌ ERROR: Wrong signaling state for answer: $currentState');
              print('❌ Expected: have-local-offer, but got: $currentState');
              print('❌ Waiting for offer to be set first...');
              
              // Offer'ın set edilmesini bekle (max 5 saniye)
              int waitCount = 0;
              while (_peerConnection!.signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer && waitCount < 50) {
                await Future.delayed(const Duration(milliseconds: 100));
                final newState = _peerConnection!.signalingState;
                print('📥 Waiting... State: $newState (attempt $waitCount/50)');
                if (newState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
                  print('✅ Signaling state is now correct: $newState');
                  break;
                }
                waitCount++;
              }
              
              // Hala doğru state değilse hata ver
              final finalState = _peerConnection!.signalingState;
              if (finalState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
                print('❌ ERROR: Signaling state is still not correct after waiting!');
                print('❌ Final state: $finalState');
                print('❌ Cannot process answer - aborting');
                return;
              }
            }
            
            print('📥 Setting remote description (answer)...');
            try {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(sdp, type ?? 'answer'),
              );
              print('✅ Remote description (answer) set successfully');
              print('📥 New signaling state: ${_peerConnection!.signalingState}');
              print('✅ Answer processing complete - waiting for onTrack event');
            } catch (e) {
              print('❌ Error setting remote description (answer): $e');
              print('❌ Current signaling state: ${_peerConnection!.signalingState}');
              print('❌ Error details: ${e.toString()}');
            }
          } else {
            print('⚠️ Invalid answer data: $data');
            print('⚠️ SDP: $sdp, Type: $type');
          }
        } catch (e) {
          print('❌ Error handling answer: $e');
          print('❌ Error details: ${e.toString()}');
        }
      });
      } else {
        print('⚠️ CALLEE MODE: NOT registering webrtc_answer listener');
        print('⚠️ Callee should only SEND answers, not receive them');
      }
      
      // ICE candidate alındığında (Her iki role için de)
      print('✅ Socket listener: webrtc_ice_candidate registered (BOTH ROLES)');
      widget.socket.on('webrtc_ice_candidate', (data) async {
        try {
          if (data is Map && data['candidate'] != null && data['candidate'].toString().isNotEmpty) {
            // Null kontrolleri yap
            final candidate = data['candidate'].toString();
            final sdpMid = data['sdpMid']?.toString() ?? '';
            final sdpMLineIndex = data['sdpMLineIndex'] is int 
                ? data['sdpMLineIndex'] 
                : (int.tryParse(data['sdpMLineIndex']?.toString() ?? '0') ?? 0);
            
            print('📥 Receiving ICE candidate: ${candidate.substring(0, candidate.length > 50 ? 50 : candidate.length)}...');
            
            await _peerConnection!.addCandidate(
              RTCIceCandidate(
                candidate,
                sdpMid,
                sdpMLineIndex,
              ),
            );
            print('✅ ICE candidate added successfully');
          } else {
            print('⚠️ Invalid ICE candidate data: $data');
          }
        } catch (e) {
          print('❌ Error handling ICE candidate: $e');
          print('❌ Error details: ${e.toString()}');
          // Crash'i önlemek için hatayı yutuyoruz
        }
      });
    }
    
    if (!kIsWeb) {
      // Android için socket listener'lar yukarıda eklendi
      // call_ended event'ini dinle - diğer kullanıcı görüşmeyi sonlandırdığında
      widget.socket.on('call_ended', (_) {
        print('📞 ========== CALL ENDED BY OTHER USER (Android) ==========');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Diğer kullanıcı görüşmeyi sonlandırdı.'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Kaynakları temizle
          _cleanup();
          
          // Anasayfaya dön
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomeScreen()),
            (route) => false,
          );
        }
        print('📞 =======================================================');
      });
      
      widget.socket.onDisconnect((_) {
        print('⚠️ Socket disconnected during call - attempting aggressive reconnect');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bağlantı koptu. Yeniden bağlanılıyor...'),
              duration: Duration(seconds: 5),
            ),
          );
          // Agresif reconnect - görüşmeyi devam ettir
          _aggressiveReconnect();
        }
      });
      
      // Socket reconnect listener - bağlantı kurulduğunda
      widget.socket.onConnect((_) {
        print('✅ Socket reconnected during call!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bağlantı yeniden kuruldu.'),
              duration: Duration(seconds: 2),
            ),
          );
          // Socket bağlandığında, eğer ICE restart bekleniyorsa tekrar dene
          if (_iceRestartAttempts < _maxIceRestartAttempts && 
              _peerConnection != null &&
              (_peerConnection!.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateFailed ||
               _peerConnection!.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateDisconnected)) {
            print('🔄 Socket reconnected, retrying ICE restart...');
            _iceRestartAttempts = 0; // Counter'ı sıfırla
            _performIceRestart();
          }
        }
      });
      
      // call_ended event'ini dinle - diğer kullanıcı görüşmeyi sonlandırdığında
      widget.socket.on('call_ended', (_) {
        print('📞 ========== CALL ENDED BY OTHER USER ==========');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Diğer kullanıcı görüşmeyi sonlandırdı.'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Kaynakları temizle
          _cleanup();
          
          // Anasayfaya dön
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomeScreen()),
            (route) => false,
          );
        }
        print('📞 ===============================================');
      });
      return;
    }
    // Offer alındığında
    widget.socket.on('webrtc_offer', (data) {
      try {
        if (!kIsWeb || _webrtcManager == null) return;
        // Web-only: WebRTC handling disabled for Android
        print('Offer received (WebRTC disabled on Android)');
        print('Offer received and handled');
      } catch (e) {
        print('Error handling offer: $e');
      }
    });

    // Answer alındığında
    widget.socket.on('webrtc_answer', (data) {
      try {
        if (!kIsWeb || _webrtcManager == null) return;
        // Web-only: WebRTC handling disabled for Android
        print('Answer received (WebRTC disabled on Android)');
        print('Answer received and handled');
      } catch (e) {
        print('Error handling answer: $e');
      }
    });

    // ICE candidate alındığında
    widget.socket.on('webrtc_ice_candidate', (data) {
      try {
        if (!kIsWeb || _webrtcManager == null) return;
        // Web-only: WebRTC handling disabled for Android
        print('ICE candidate received (WebRTC disabled on Android)');
        print('ICE candidate received and handled');
      } catch (e) {
        print('Error handling ICE candidate: $e');
      }
    });

    // call_ended event'ini dinle - diğer kullanıcı görüşmeyi sonlandırdığında (Web)
    widget.socket.on('call_ended', (_) {
      print('📞 ========== CALL ENDED BY OTHER USER (Web) ==========');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diğer kullanıcı görüşmeyi sonlandırdı.'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Kaynakları temizle
        _cleanup();
        
        // Anasayfaya dön
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomeScreen()),
          (route) => false,
        );
      }
      print('📞 ====================================================');
    });

    // Socket disconnect - Bağlantı koptuğunda reconnect dene, otomatik kapanma (Web)
    widget.socket.onDisconnect((_) {
      print('⚠️ Socket disconnected during call (Web) - attempting reconnect');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bağlantı koptu. Yeniden bağlanılıyor...'),
            duration: Duration(seconds: 3),
          ),
        );
        // Reconnect dene - görüşmeyi devam ettir
        widget.socket.connect();
        // Anasayfaya gitme - görüşmeyi devam ettir
        // Backend zaten disconnect olduğunda call_ended gönderecek
      }
    });
  }

  void _toggleVideo() {
    if (kIsWeb) {
      if (_webrtcManager == null) return;
      try {
        final result = (_webrtcManager as dynamic).callMethod('toggleVideo');
        setState(() {
          _isVideoEnabled = result ?? false;
        });
      } catch (e) {
        print('Error toggling video: $e');
      }
    } else {
      // Android için
      if (_localStream != null) {
        final videoTrack = _localStream!.getVideoTracks().first;
        videoTrack.enabled = !_isVideoEnabled;
        setState(() {
          _isVideoEnabled = !_isVideoEnabled;
        });
      }
    }
  }

  void _toggleAudio() {
    if (kIsWeb) {
      if (_webrtcManager == null) return;
      try {
        final result = (_webrtcManager as dynamic).callMethod('toggleAudio');
        setState(() {
          _isAudioEnabled = result ?? false;
        });
      } catch (e) {
        print('Error toggling audio: $e');
      }
    } else {
      // Android için
      if (_localStream != null) {
        final audioTrack = _localStream!.getAudioTracks().first;
        audioTrack.enabled = !_isAudioEnabled;
        setState(() {
          _isAudioEnabled = !_isAudioEnabled;
        });
      }
    }
  }

  void _adjustRemoteVolume(double delta) {
    if (!kIsWeb || _webrtcManager == null) return;
    _remoteVolume = (_remoteVolume + delta).clamp(0.0, 1.0);
    if (kIsWeb) {
      try {
        (_webrtcManager as dynamic).callMethod('setRemoteVolume', [_remoteVolume]);
      } catch (e) {
        print('Error adjusting remote volume: $e');
      }
    }
    setState(() {});
  }

  void _adjustLocalVolume(double delta) {
    if (!kIsWeb || _webrtcManager == null) return;
    _localVolume = (_localVolume + delta).clamp(0.0, 1.0);
    if (kIsWeb) {
      try {
        (_webrtcManager as dynamic).callMethod('setLocalVolume', [_localVolume]);
      } catch (e) {
        print('Error adjusting local volume: $e');
      }
    }
    setState(() {});
  }

  void _endCall() {
    print('📞 ========== ENDING CALL ==========');
    print('📞 RoomId: ${widget.roomId}');
    
    // Backend'e bildir
    if (widget.socket.connected) {
      widget.socket.emit('end_call', {'roomId': widget.roomId});
      print('✅ end_call event sent to backend');
    } else {
      print('⚠️ Socket not connected, cannot send end_call event');
    }
    
    // Kaynakları temizle
    _cleanup();
    
    // Anasayfaya dön
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HomeScreen()),
        (route) => false,
      );
    }
    
    print('📞 ==================================');
  }

  // Helper function to convert JsObject to Map
  Map<String, dynamic> _jsObjectToMap(dynamic jsObj) {
    if (!kIsWeb) {
      if (jsObj is Map) {
        return Map<String, dynamic>.from(jsObj);
      }
      return {'value': jsObj.toString()};
    }
    try {
      final map = <String, dynamic>{};
      if (jsObj == null) return map;
      
      // Android'de JsObject yok, direkt Map döndür
      if (!kIsWeb) {
        if (jsObj is Map) {
          return Map<String, dynamic>.from(jsObj);
        }
        return {'value': jsObj.toString()};
      }
      
      // Web-only code - commented out for Android
      return map;
      
      return map;
    } catch (e) {
      print('Error in _jsObjectToMap: $e');
      return <String, dynamic>{};
    }
  }

  void _emitToSocket(dynamic event, dynamic data) {
    try {
      // Event adını string'e çevir
      String eventName = '';
      if (event != null) {
        eventName = event.toString();
      } else {
        print('Error: event is null');
        return;
      }
      
      // Data'yı Dart Map'e çevir
      Map<String, dynamic> dataMap = {};
      if (data != null) {
        try {
          // Android ve Web uyumlu veri işleme
          if (data is String) {
            // String olarak geldiyse JSON parse et
            try {
              dataMap = convert.json.decode(data);
            } catch (e) {
              dataMap = {'data': data};
            }
          } else if (data is Map) {
            // Veri zaten Map olarak geldiyse direkt kullan (Android/Socket.io davranışı)
            dataMap = Map<String, dynamic>.from(data);
          } else {
            print("Bilinmeyen veri formatı: $data");
            dataMap = {'data': data.toString()};
          }
        } catch (e) {
          print('Error converting data to map using JSON.stringify/parse: $e');
          dataMap = {'rawData': data.toString()};
        }
      }
      
      // Flutter socket'inden emit yap
      if (widget.socket.connected) {
        widget.socket.emit(eventName, dataMap);
        print('Emitted $eventName with data: $dataMap');
      } else {
        print('Cannot emit $eventName: socket not connected');
      }
    } catch (e, stackTrace) {
      print('Error in _emitToSocket: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Agresif socket reconnect - birden fazla deneme
  Future<void> _aggressiveReconnect() async {
    print('🔄 Starting aggressive reconnect...');
    int maxRetries = 5;
    int retryDelay = 2000; // 2 saniye
    
    for (int i = 0; i < maxRetries; i++) {
      if (!mounted) break;
      
      print('🔄 Reconnect attempt ${i + 1}/$maxRetries...');
      
      try {
        if (!widget.socket.connected) {
          widget.socket.connect();
          
          // Bağlantıyı bekle
          await Future.delayed(Duration(milliseconds: retryDelay));
          
          if (widget.socket.connected) {
            print('✅ Socket reconnected successfully!');
            return;
          }
        } else {
          print('✅ Socket already connected!');
          return;
        }
      } catch (e) {
        print('❌ Reconnect attempt ${i + 1} failed: $e');
      }
      
      // Son deneme değilse bekle
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(milliseconds: retryDelay));
      }
    }
    
    print('⚠️ Aggressive reconnect failed after $maxRetries attempts');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı kurulamadı. Görüşme devam ediyor...'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Socket bağlantısını bekle ve ICE restart'ı tekrar dene
  Future<void> _waitForSocketAndRetryIceRestart() async {
    print('⏳ Waiting for socket connection to retry ICE restart...');
    
    // Socket zaten bağlıysa direkt dene
    if (widget.socket.connected) {
      print('✅ Socket already connected, retrying ICE restart...');
      if (_iceRestartAttempts < _maxIceRestartAttempts && _peerConnection != null) {
        _iceRestartAttempts++;
        _performIceRestart();
      }
      return;
    }
    
    // Socket bağlantısını bekle (max 10 saniye)
    int maxWaitTime = 10000; // 10 saniye
    int checkInterval = 500; // 500ms
    int elapsed = 0;
    
    while (elapsed < maxWaitTime && mounted) {
      await Future.delayed(Duration(milliseconds: checkInterval));
      elapsed += checkInterval;
      
      if (widget.socket.connected) {
        print('✅ Socket connected, retrying ICE restart...');
        if (_iceRestartAttempts < _maxIceRestartAttempts && _peerConnection != null) {
          _iceRestartAttempts = 0; // Counter'ı sıfırla
          _performIceRestart();
        }
        return;
      }
    }
    
    print('⚠️ Socket connection timeout, ICE restart will be retried when socket reconnects');
  }
  
  void _cleanup() async {
    print('🧹 WebRTC kaynakları temizleniyor...');
    if (kIsWeb && _webrtcManager != null) {
      try {
        (_webrtcManager as dynamic).callMethod('cleanup');
      } catch (e) {
        print('Error in cleanup: $e');
      }
    } else {
      // Android için cleanup
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          track.stop();
          track.dispose();
        });
        _localStream!.dispose();
        _localStream = null;
      }
      if (_remoteStream != null) {
        _remoteStream!.getTracks().forEach((track) {
          track.stop();
          track.dispose();
        });
        _remoteStream!.dispose();
        _remoteStream = null;
      }
      _remoteRendererBound = false; // Flag'i reset et
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }
      if (_isLocalRendererInitialized) {
        try {
          await _localRenderer.dispose();
          _isLocalRendererInitialized = false;
        } catch (e) {
          print('⚠️ Error disposing local renderer: $e');
          _isLocalRendererInitialized = false;
        }
      }
      if (_isRemoteRendererInitialized) {
        try {
          await _remoteRenderer.dispose();
          _isRemoteRendererInitialized = false;
        } catch (e) {
          print('⚠️ Error disposing remote renderer: $e');
          _isRemoteRendererInitialized = false;
        }
      }
    }
    print('✅ WebRTC kaynakları temizlendi');
  }

  @override
  void dispose() {
    // Wakelock'u kapat - ekran normal moduna dönsün
    if (!kIsWeb) {
      WakelockPlus.disable();
      print('🔋 Wakelock disabled - ekran normal moduna döndü');
    }
    
    _cleanup();
    // Socket'i disconnect etme - matchmaking ekranına dönerse kullanılabilir
    // Sadece end_call event'i gönder
    widget.socket.emit('end_call', {'roomId': widget.roomId});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent yap ki remote video görünsün
      appBar: AppBar(
        title: Text('Görüntülü Görüşme - $_connectionState'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Container(
        color: Colors.transparent, // Transparent yap ki remote video görünsün
        child: Stack(
          clipBehavior: Clip.none, // Kontrollerin görünmesi için
          fit: StackFit.expand, // Tam ekran
          children: [
            // Remote Video Container - Web için
            if (kIsWeb && !_isRemoteVideoReady)
              Positioned.fill(
                child: Container(
                  color: AppTheme.darkBackground,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Bağlantı kuruluyor...',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Remote Video - Android için
            // Renderer initialize edilmişse ve srcObject set edilmişse göster
            if (!kIsWeb && _isRemoteRendererInitialized && _remoteRenderer.srcObject != null)
              Positioned.fill(
                child: RTCVideoView(_remoteRenderer, mirror: false),
              ),
            
            // Local video (Picture-in-Picture) - Android için
            // Daha büyük boyut için kalite artırıldı
            // Renderer initialize edilmişse VE srcObject set edilmişse göster
            if (!kIsWeb && _isLocalRendererInitialized && _localRenderer.srcObject != null)
              Positioned(
                top: 20,
                right: 20,
                width: 160, // 120'den 160'a artırıldı
                height: 213, // 160'tan 213'e artırıldı (16:9 aspect ratio)
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentBlue, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: RTCVideoView(_localRenderer, mirror: true),
                  ),
                ),
              ),
            
            // Loading indicator (Android'de bağlantı kurulmamışsa)
            // Remote video yoksa göster
            if (!kIsWeb && _isRemoteRendererInitialized && _remoteRenderer.srcObject == null)
              Positioned.fill(
                child: Container(
                  color: AppTheme.darkBackground,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _connectionState,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Karşı tarafın görüntüsü bekleniyor...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Local Video (Picture-in-Picture) - JavaScript tarafında gösteriliyor
            // Video element'leri JavaScript tarafından DOM'a ekleniyor
            
            // Controls - Her zaman görünür (en üstte, remote video'nun üzerinde)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 16, // Daha yüksek elevation (görünürlük için)
                color: Colors.transparent, // Material'in arka planını şeffaf yap
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface.withOpacity(0.95), // Daha opak (daha görünür)
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ses kontrolleri
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                          // Gelen ses kontrolü
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Gelen Ses',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _adjustRemoteVolume(-0.1),
                                    icon: const Icon(Icons.volume_down),
                                    color: AppTheme.textPrimary,
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${(_remoteVolume * 100).toInt()}%',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _adjustRemoteVolume(0.1),
                                    icon: const Icon(Icons.volume_up),
                                    color: AppTheme.textPrimary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Giden ses kontrolü
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Giden Ses',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _adjustLocalVolume(-0.1),
                                    icon: const Icon(Icons.volume_down),
                                    color: AppTheme.textPrimary,
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${(_localVolume * 100).toInt()}%',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _adjustLocalVolume(0.1),
                                    icon: const Icon(Icons.volume_up),
                                    color: AppTheme.textPrimary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                        ),
                      const SizedBox(height: 16),
                      // Ana kontroller
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FloatingActionButton(
                            onPressed: _toggleAudio,
                            heroTag: 'micBtn',
                            backgroundColor: _isAudioEnabled ? Colors.green : Colors.red,
                            child: Icon(_isAudioEnabled ? Icons.mic : Icons.mic_off),
                          ),
                          FloatingActionButton(
                            onPressed: _toggleVideo,
                            heroTag: 'camBtn',
                            backgroundColor: _isVideoEnabled ? Colors.blue : Colors.grey,
                            child: Icon(_isVideoEnabled ? Icons.videocam : Icons.videocam_off),
                          ),
                          FloatingActionButton(
                            onPressed: _endCall,
                            heroTag: 'endCallBtn',
                            backgroundColor: Colors.red,
                            child: const Icon(Icons.call_end),
                          ),
                        ],
                      ),
                    ],
                  ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
