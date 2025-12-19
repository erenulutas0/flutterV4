import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../theme/app_theme.dart';

// Web için basitleştirilmiş video call ekranı
// Video call özelliği sonra eklenecek
class VideoCallScreen extends StatefulWidget {
  final IO.Socket socket;
  final String roomId;
  final String matchedUserId;

  const VideoCallScreen({
    super.key,
    required this.socket,
    required this.roomId,
    required this.matchedUserId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  @override
  void initState() {
    super.initState();
    // Room'a katıl
    widget.socket.emit('join_room', {'roomId': widget.roomId});
  }

  void _endCall() {
    widget.socket.emit('end_call', {'roomId': widget.roomId});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Görüşme'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_call,
              size: 100,
              color: AppTheme.accentBlue,
            ),
            const SizedBox(height: 32),
            Text(
              'Eşleşme Bulundu! 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Room ID: ${widget.roomId}',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Eşleşilen Kullanıcı: ${widget.matchedUserId}',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Video call özelliği yakında eklenecek',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _endCall,
              icon: const Icon(Icons.call_end),
              label: const Text('Görüşmeyi Sonlandır'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

