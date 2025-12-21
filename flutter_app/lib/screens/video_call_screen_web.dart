// Web-only version - will be imported conditionally
import 'dart:js' as js;
import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'video_call_screen.dart';

// Web-specific WebRTC initialization
Future<dynamic> initializeWebRTCForWeb(
  IO.Socket socket,
  String roomId,
  String? role,
  Function setState,
  BuildContext context,
  bool mounted,
  Function(String) updateConnectionState,
  Function(bool) updateRemoteVideoReady,
) async {
  try {
    // Get WebRTCManager class from JavaScript
    final WebRTCManagerClass = js.context['WebRTCManager'];
    if (WebRTCManagerClass == null) {
      print('WebRTCManager not found in JavaScript');
      return null;
    }

    // Socket.io wrapper
    js.context['currentSocket'] = js.JsObject.jsify({
      'emit': js.allowInterop((dynamic event, dynamic data) {
        try {
          String eventName = event?.toString() ?? '';
          Map<String, dynamic> dataMap = {};
          if (data != null) {
            if (data is js.JsObject) {
              dataMap = _jsObjectToMap(data);
            } else if (data is Map) {
              dataMap = Map<String, dynamic>.from(data);
            }
          }
          socket.emit(eventName, dataMap);
        } catch (e) {
          print('Error in socket emit wrapper: $e');
        }
      }),
    });

    // Create WebRTCManager instance
    final webrtcManager = js.JsObject(WebRTCManagerClass, [roomId, role ?? 'callee']);
    webrtcManager.callMethod('initialize', [role ?? 'callee']);
    await Future.delayed(const Duration(milliseconds: 500));

    // Event listeners
    js.context.callMethod('addEventListener', [
      'webrtc_connection_state',
      js.allowInterop((dynamic event) {
        if (event is js.JsObject && mounted) {
          final detail = event['detail'];
          updateConnectionState(detail?.toString() ?? 'Unknown');
        }
      }),
    ]);

    js.context.callMethod('addEventListener', [
      'webrtc_remote_video_ready',
      js.allowInterop((dynamic event) {
        if (mounted) {
          updateRemoteVideoReady(true);
        }
      }),
    ]);

    js.context.callMethod('addEventListener', [
      'webrtc_error',
      js.allowInterop((dynamic event) {
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
          updateConnectionState('Hata: $errorMessage');
        }
      }),
    ]);

    return webrtcManager;
  } catch (e) {
    print('WebRTC initialization error: $e');
    return null;
  }
}

Map<String, dynamic> _jsObjectToMap(dynamic jsObj) {
  final map = <String, dynamic>{};
  if (jsObj == null || jsObj is! js.JsObject) return map;
  
  try {
    final keys = js.context.callMethod('Object.keys', [jsObj]);
    if (keys == null || keys is! js.JsObject) return map;
    
    final length = keys['length'];
    if (length == null) return map;
    
    final intLength = length is int ? length : (length as num).toInt();
    for (var i = 0; i < intLength; i++) {
      try {
        final key = keys[i];
        if (key == null) continue;
        final value = jsObj[key];
        if (value is js.JsObject) {
          map[key.toString()] = _jsObjectToMap(value);
        } else if (value != null) {
          map[key.toString()] = value;
        }
      } catch (e) {
        continue;
      }
    }
  } catch (e) {
    print('Error getting keys: $e');
  }
  
  return map;
}

// Web-specific methods
dynamic callWebRTCMethod(dynamic manager, String method, [List<dynamic>? args]) {
  if (manager == null) return null;
  try {
    return (manager as js.JsObject).callMethod(method, args ?? []);
  } catch (e) {
    print('Error calling $method: $e');
    return null;
  }
}

dynamic jsifyForWeb(dynamic obj) {
  try {
    return js.JsObject.jsify(obj);
  } catch (e) {
    print('Error jsifying: $e');
    return obj;
  }
}

