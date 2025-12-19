import 'dart:js' as js;
import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
  js.JsObject? _webrtcManager;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isRemoteVideoReady = false;
  String _connectionState = 'Connecting...';
  double _remoteVolume = 1.0; // 0.0 - 1.0
  double _localVolume = 1.0; // 0.0 - 1.0

  @override
  void initState() {
    super.initState();
    // Socket bağlantısını kontrol et
    if (!widget.socket.connected) {
      widget.socket.connect();
      // Bağlantıyı bekle
      widget.socket.onConnect((_) async {
        await _initializeWebRTC();
        _setupSocketListeners();
      });
    } else {
      _initializeWebRTC().then((_) {
        _setupSocketListeners();
      });
    }
    
    // Socket disconnect listener'ı ekle
    widget.socket.onDisconnect((_) {
      print('Socket disconnected in VideoCallScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bağlantı koptu. Yeniden bağlanılıyor...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _initializeWebRTC() async {
    try {
      // Get WebRTCManager class from JavaScript
      final WebRTCManagerClass = js.context['WebRTCManager'];
      if (WebRTCManagerClass == null) {
        print('WebRTCManager not found in JavaScript');
        return;
      }

      // Socket.io objesini JavaScript'e geçirmek için global değişkene kaydet
      // Flutter'dan JavaScript'e Socket.io objesi doğrudan geçirilemez
      // Bunun yerine socket'i global window objesine kaydedip JavaScript'ten erişeceğiz
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
                if (data is js.JsObject) {
                  try {
                    // roomId'yi al
                    final roomId = data['roomId'];
                    if (roomId != null) {
                      dataMap['roomId'] = roomId.toString();
                    }
                    
                    // offer'ı al
                    final offer = data['offer'];
                    if (offer != null) {
                      if (offer is js.JsObject) {
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
                      if (answer is js.JsObject) {
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
                      if (candidate is js.JsObject) {
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
                      final jsonStr = js.context.callMethod('JSON.stringify', [data]);
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
                    final jsonStr = js.context.callMethod('JSON.stringify', [data]);
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
        })
      });

      // Create WebRTCManager instance with role
      _webrtcManager = js.JsObject(WebRTCManagerClass, [
        widget.roomId,
        widget.role ?? 'callee', // Default to callee if role not provided
      ]);

      // Initialize WebRTC with role (async, but we can't await in Dart-JS interop)
      // The initialize method will handle role-based offer creation
      print('Initializing WebRTC with role: ${widget.role ?? 'callee'}');
      // Initialize returns a Promise, wait for it to complete
      final initPromise = _webrtcManager!.callMethod('initialize', [widget.role ?? 'callee']);
      // Wait for initialization to complete (getUserMedia takes time)
      await Future.delayed(const Duration(milliseconds: 500));

      // Listen for connection state changes
      // js.context zaten window objesidir, doğrudan callMethod kullanabiliriz
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
        })
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
        })
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
        })
      ]);

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
  }

  void _setupSocketListeners() {
    // Offer alındığında
    widget.socket.on('webrtc_offer', (data) {
      try {
        final offerData = (data as Map)['offer'];
        _webrtcManager?.callMethod('handleOffer', [js.JsObject.jsify(offerData)]);
        print('Offer received and handled');
      } catch (e) {
        print('Error handling offer: $e');
      }
    });

    // Answer alındığında
    widget.socket.on('webrtc_answer', (data) {
      try {
        final answerData = (data as Map)['answer'];
        _webrtcManager?.callMethod('handleAnswer', [js.JsObject.jsify(answerData)]);
        print('Answer received and handled');
      } catch (e) {
        print('Error handling answer: $e');
      }
    });

    // ICE candidate alındığında
    widget.socket.on('webrtc_ice_candidate', (data) {
      try {
        final candidateData = (data as Map)['candidate'];
        _webrtcManager?.callMethod('handleIceCandidate', [js.JsObject.jsify(candidateData)]);
        print('ICE candidate received and handled');
      } catch (e) {
        print('Error handling ICE candidate: $e');
      }
    });

    // Call ended - Anasayfaya yönlendir
    widget.socket.on('call_ended', (_) {
      if (mounted) {
        _cleanup();
        // Tüm ekranları temizle ve anasayfaya git
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomeScreen()),
          (route) => false,
        );
      }
    });

    // Socket disconnect - Bağlantı koptuğunda da anasayfaya git
    widget.socket.onDisconnect((_) {
      if (mounted) {
        _cleanup();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  void _toggleVideo() {
    if (_webrtcManager != null) {
      final result = _webrtcManager!.callMethod('toggleVideo');
      setState(() {
        _isVideoEnabled = result ?? false;
      });
    }
  }

  void _toggleAudio() {
    if (_webrtcManager != null) {
      final result = _webrtcManager!.callMethod('toggleAudio');
      setState(() {
        _isAudioEnabled = result ?? false;
      });
    }
  }

  void _adjustRemoteVolume(double delta) {
    if (_webrtcManager != null) {
      _remoteVolume = (_remoteVolume + delta).clamp(0.0, 1.0);
      _webrtcManager!.callMethod('setRemoteVolume', [_remoteVolume]);
      setState(() {});
    }
  }

  void _adjustLocalVolume(double delta) {
    if (_webrtcManager != null) {
      _localVolume = (_localVolume + delta).clamp(0.0, 1.0);
      _webrtcManager!.callMethod('setLocalVolume', [_localVolume]);
      setState(() {});
    }
  }

  void _endCall() {
    widget.socket.emit('end_call', {'roomId': widget.roomId});
    _cleanup();
    Navigator.pop(context);
  }

  // Helper function to convert JsObject to Map
  Map<String, dynamic> _jsObjectToMap(dynamic jsObj) {
    try {
      final map = <String, dynamic>{};
      if (jsObj == null) return map;
      
      // If it's not a JsObject, try to convert it
      js.JsObject? jsObject;
      if (jsObj is js.JsObject) {
        jsObject = jsObj;
      } else {
        // Try to wrap it
        try {
          jsObject = js.JsObject.jsify(jsObj);
        } catch (e) {
          // If it's already a plain object, return it as is
          if (jsObj is Map) {
            return Map<String, dynamic>.from(jsObj);
          }
          return {'value': jsObj.toString()};
        }
      }
      
      if (jsObject == null) return map;
      
      try {
        final keys = js.context.callMethod('Object.keys', [jsObject]);
        if (keys == null || keys is! js.JsObject) return map;
        
        final length = keys['length'];
        if (length == null) return map;
        
        final intLength = length is int ? length : (length as num).toInt();
        for (var i = 0; i < intLength; i++) {
          try {
            final key = keys[i];
            if (key == null) continue;
            
            final value = jsObject[key];
            if (value is js.JsObject) {
              map[key.toString()] = _jsObjectToMap(value);
            } else if (value != null) {
              map[key.toString()] = value;
            }
          } catch (e) {
            // Skip this key
            continue;
          }
        }
      } catch (e) {
        print('Error getting keys: $e');
      }
      
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
          // Use JSON.stringify and parse if possible
          final jsonStr = js.context.callMethod('JSON.stringify', [data]);
          if (jsonStr != null) {
            dataMap = convert.json.decode(jsonStr.toString());
          } else {
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

  void _cleanup() {
    _webrtcManager?.callMethod('cleanup');
  }

  @override
  void dispose() {
    _cleanup();
    // Socket'i disconnect etme - matchmaking ekranına dönerse kullanılabilir
    // Sadece end_call event'i gönder
    widget.socket.emit('end_call', {'roomId': widget.roomId});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text('Görüntülü Görüşme - $_connectionState'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Container(
        color: Colors.transparent, // Transparent yap ki remote video görünsün
        child: Stack(
          children: [
            // Remote Video Container - JavaScript tarafında DOM'a ekleniyor
            // Burada sadece loading indicator gösteriyoruz
            // NOT: Remote video JavaScript tarafında z-index 9999 ile body'ye ekleniyor
            // Flutter Stack z-index 0'da, bu yüzden remote video üstte görünecek
            if (!_isRemoteVideoReady)
              Positioned.fill(
                child: Container(
                  color: Colors.transparent, // Tamamen şeffaf (remote video görünsün)
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Bağlantı kuruluyor...',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Local Video (Picture-in-Picture) - JavaScript tarafında gösteriliyor
            // Video element'leri JavaScript tarafından DOM'a ekleniyor
            
            // Controls - Her zaman görünür (en üstte)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface.withOpacity(0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
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
