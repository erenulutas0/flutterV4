import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart'; // YENİ: Yerel TTS motoru
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';
import '../utils/backend_config.dart';
import '../services/sync_service.dart';
// import 'dart:html' as html; // Web only - disabled for Android

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts(); // YENİ: Flutter TTS
  
  bool _isLoading = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isInConversation = false;
  String _selectedVoice = 'female';
  String _recognizedText = '';
  bool _speechInitialized = false;
  Timer? _sendTimer;
  
  // IELTS/TOEFL Speaking Test states
  String? _testMode; // null, 'IELTS', or 'TOEFL'
  String? _currentTestPart; // 'part1', 'part2', 'part3' for IELTS, 'task1', 'task2', etc. for TOEFL
  List<String> _currentQuestions = [];
  int _currentQuestionIndex = 0;
  String? _currentQuestion;
  Map<String, dynamic>? _testResults; // Store test evaluation results
  bool _isTestActive = false;
  DateTime? _testStartTime;
  Timer? _testTimer;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initTts();
    // Welcome message (only if not in test mode)
    _messages.add(ChatMessage(
      text: "Hello! I'm Owen, your English conversation tutor. Let's practice English together! How are you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }
  
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    // Ses seçimi (isteğe bağlı, platforma göre değişir)
    // await _flutterTts.setVoice({"name": "en-us-x-tpf-local", "locale": "en-US"});

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
      // Konuşma sonrası otomatik dinlemeye geç (sohbet modundaysa)
      if (_isInConversation && !_isListening && !_isLoading) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _isInConversation && !_isListening) {
             _startListening();
          }
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      print("TTS Error: $msg");
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _initializeSpeech() async {
    print('Initializing speech recognition...');
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (mounted) {
          setState(() {
            _isListening = status == 'listening';
          });
          
          // Auto-restart listening when speech recognition stops
          // (but only if we're still in conversation mode and not speaking)
          if ((status == 'done' || status == 'notListening') && 
              _isInConversation && !_isSpeaking && !_isLoading) {
            print('Speech stopped, restarting in conversation mode...');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && _isInConversation && !_isListening && !_isSpeaking && !_isLoading) {
                _startListening();
              }
            });
          }
        }
      },
      onError: (error) {
        print('Speech recognition error: ${error.errorMsg} - ${error.permanent}');
        
        // Timeout handling
        if (error.errorMsg == 'error_speech_timeout') {
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Focus lost or no sound detected. Please tap Start again.'),
                    backgroundColor: AppTheme.accentOrange,
                    duration: Duration(seconds: 3),
                  ),
                );
            }
             // Do NOT auto-restart immediately on timeout to prevent loops
             setState(() {
               _isInConversation = false;
               _isListening = false;
             });
             return;
        }

        // Retry for other errors
        if (_isInConversation && mounted && !_isSpeaking && !_isLoading) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && _isInConversation && !_isListening && !_isSpeaking && !_isLoading) {
              _startListening();
            }
          });
        }
      },
    );
    
    print('Speech recognition available: $available');
    if (available) {
      setState(() {
        _speechInitialized = true;
      });
    } else {
      print('Speech recognition NOT available!');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device.'),
            backgroundColor: AppTheme.accentRed,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }


  // START CONVERSATION - enters continuous conversation mode
  Future<void> _startConversation() async {
    // Request microphone permission
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice chat'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (!_speechInitialized) {
      await _initializeSpeech();
    }

    setState(() {
      _isInConversation = true;
    });
    
    // Start listening
    await _startListening();
  }
  
  // END CONVERSATION - exits conversation mode
  Future<void> _endConversation() async {
    await _speech.stop();
    setState(() {
      _isInConversation = false;
      _isListening = false;
      _isSpeaking = false;
      _recognizedText = '';
    });
  }

  Future<void> _startListening() async {
    if (!_isInConversation) {
      print('Not in conversation mode, skipping listen');
      return;
    }
    
    // İnternet kontrolü
    if (!await SyncService.hasInternet()) {
      print('No internet, cannot start conversation');
      if (mounted) {
        setState(() {
          _isInConversation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konuşma için internet bağlantısı gereklidir.'),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
      }
      return;
    }
    
    if (!_speechInitialized) {
      print('Speech not initialized, initializing now...');
      await _initializeSpeech();
    }
    
    print('Starting to listen...');
    
    setState(() {
      _recognizedText = '';
      _isListening = true;
    });

    // CONTINUOUS CONVERSATION MODE
    // Auto-send when user stops speaking (using timer-based detection)
    try {
      await _speech.listen(
        onResult: (result) {
          print('Speech result: "${result.recognizedWords}" (final: ${result.finalResult})');
          
          if (mounted && result.recognizedWords.trim().isNotEmpty) {
            setState(() {
              _recognizedText = result.recognizedWords;
              _messageController.text = result.recognizedWords;
            });
            
            // Cancel previous timer
            _sendTimer?.cancel();
            
            // Start new timer - if no new speech for 2 seconds, send the message
            _sendTimer = Timer(const Duration(seconds: 2), () {
              print('Timer fired! Sending message: ${_messageController.text}');
              if (mounted && _isInConversation && !_isLoading && _messageController.text.trim().isNotEmpty) {
                _handleFinalResult(_messageController.text.trim());
              }
            });
          }
          
          // Also handle finalResult if it comes
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            print('Final result received, sending message...');
            _sendTimer?.cancel();
            _handleFinalResult(result.recognizedWords.trim());
          }
        },
        listenFor: const Duration(seconds: 30), 
        pauseFor: const Duration(seconds: 5), // Daha uzun bekleme süresi (dediklerimi yutmaması için)
        localeId: 'en-US',
        listenMode: stt.ListenMode.dictation, // Dictation modu daha doğal cümleler için
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }
  
  void _handleFinalResult(String message) async {
    if (!_isInConversation || _isLoading || message.isEmpty) {
      print('Skipping handleFinalResult: inConversation=$_isInConversation, isLoading=$_isLoading, message=$message');
      return;
    }
    
    print('Handling final result: $message');
    
    _sendTimer?.cancel();
    await _speech.stop();
    
    setState(() {
      _isListening = false;
      _recognizedText = '';
    });
    
    _messageController.clear();
    await _sendMessageFromVoice(message);
    
    // Listening will restart after TTS completes (in completion handler)
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _speak(String text) async {
    // Stop any ongoing speech
    await _flutterTts.stop();

    setState(() {
      _isSpeaking = true;
    });

    String cleanedText = text.trim();
    print('Speaking: $cleanedText');
    
    // Speak using FlutterTts (Native TTS)
    // Ses tonunu seçilen cinsiyete göre ayarla
    if (_selectedVoice == 'female') {
        await _flutterTts.setPitch(1.0); 
    } else {
        await _flutterTts.setPitch(0.7); // Erkek sesi için biraz kalınlaştır
    }
    
    await _flutterTts.speak(cleanedText);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _sendMessageFromVoice(String message) async {
    if (message.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();
    
    await _processMessage(message);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    // Stop listening if active
    if (_isListening) {
      await _stopListening();
    }

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();
    
    await _processMessage(message);
  }

  Future<void> _processMessage(String message) async {
    if (!await SyncService.hasInternet()) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Üzgünüm, şu an internet bağlantısı yok. Çevrimdışı çalışamıyorum. Lütfen internetini kontrol et.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _speak("I cannot work offline. Please check your internet connection.");
      return;
    }
    // Don't process messages in test mode (test has its own flow)
    if (_isTestActive) {
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/chatbot/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final botResponse = data['response'] ?? 'Sorry, I could not generate a response.';
        
        setState(() {
          _messages.add(ChatMessage(
            text: botResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
        
        // Automatically speak the bot's response
        await _speak(botResponse);
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppTheme.purpleGradient,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.chat_bubble, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Owen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'English Tutor',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          // Voice selection dropdown
          PopupMenuButton<String>(
            icon: Icon(
              _selectedVoice == 'female' ? Icons.face : Icons.face_outlined,
              color: AppTheme.textPrimary,
            ),
            onSelected: (value) {
              setState(() {
                _selectedVoice = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'female',
                child: Row(
                  children: [
                    Icon(Icons.face, color: AppTheme.textPrimary),
                    SizedBox(width: 8),
                    Text('Female Voice'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'male',
                child: Row(
                  children: [
                    Icon(Icons.face_outlined, color: AppTheme.textPrimary),
                    SizedBox(width: 8),
                    Text('Male Voice'),
                  ],
                ),
              ),
            ],
          ),
          // Stop speaking button (when speaking)
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: AppTheme.accentRed),
              onPressed: _stopSpeaking,
              tooltip: 'Stop speaking',
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.darkGradient,
          ),
        ),
        child: Column(
          children: [
            // Test Mode Selection (always visible when not in active test)
            if (!_isTestActive)
              _buildTestModeSelector(),
            
            // Test Results (if test completed)
            if (_testResults != null)
              _buildTestResults(),
            
            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    // Loading indicator
                    return _buildLoadingMessage();
                  }
                  return _buildMessage(_messages[index]);
                },
              ),
            ),
            // CONVERSATION MODE INDICATOR (not in test mode)
            if (_isInConversation && !_isTestActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isListening 
                      ? AppTheme.primaryPurple.withOpacity(0.15)
                      : (_isSpeaking 
                          ? Colors.green.withOpacity(0.15)
                          : AppTheme.darkSurfaceVariant),
                  border: Border(
                    top: BorderSide(
                      color: _isListening 
                          ? AppTheme.primaryPurple.withOpacity(0.3)
                          : (_isSpeaking 
                              ? Colors.green.withOpacity(0.3)
                              : Colors.transparent),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Status icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isListening 
                            ? AppTheme.primaryPurple 
                            : (_isSpeaking ? Colors.green : AppTheme.darkSurfaceVariant),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _isListening 
                            ? Icons.mic 
                            : (_isSpeaking ? Icons.volume_up : Icons.hourglass_empty),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isListening 
                                ? 'Listening...'
                                : (_isSpeaking 
                                    ? 'Owen is speaking...'
                                    : (_isLoading ? 'Thinking...' : 'Waiting...')),
                            style: TextStyle(
                              color: _isListening 
                                  ? AppTheme.primaryPurple 
                                  : (_isSpeaking ? Colors.green : AppTheme.textSecondary),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isListening 
                                ? (_recognizedText.isEmpty ? 'Say something...' : _recognizedText)
                                : 'Conversation active',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // Input area with START/END CONVERSATION
            Container(
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                child: _isTestActive
                    ? // TEST MODE - Show test controls
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isListening ? null : _startListeningForTest,
                              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                              label: Text(
                                _isListening ? 'Recording...' : 'Record Answer',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isListening ? AppTheme.accentRed : AppTheme.primaryPurple,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _endTest,
                            icon: const Icon(Icons.stop, color: Colors.white),
                            label: const Text('End Test'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentRed,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _isInConversation
                      ? // IN CONVERSATION MODE - Show End button
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _endConversation,
                                icon: const Icon(Icons.stop_circle, color: Colors.white),
                                label: const Text(
                                  'End Conversation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentRed,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : // NOT IN CONVERSATION - Show Start button and text input
                        Row(
                    children: [
                      // START CONVERSATION BUTTON
                      GestureDetector(
                        onTap: _startConversation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppTheme.purpleGradient,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryPurple.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Start',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Type or tap Start to speak...',
                            hintStyle: const TextStyle(color: AppTheme.textTertiary),
                            filled: true,
                            fillColor: AppTheme.darkSurfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !_isLoading,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppTheme.purpleGradient,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: IconButton(
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                          onPressed: _isLoading ? null : _sendMessage,
                        ),
                      ),
                    ],
                  ), // End of text input Row
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppTheme.purpleGradient,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? AppTheme.primaryPurple
                        : AppTheme.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                // Play button for bot messages
                if (!message.isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      icon: Icon(
                        _isSpeaking ? Icons.volume_up : Icons.volume_down,
                        color: AppTheme.textSecondary,
                        size: 16,
                      ),
                      onPressed: () {
                        if (_isSpeaking) {
                          _stopSpeaking();
                        } else {
                          _speak(message.text);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.darkSurfaceVariant,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.person,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppTheme.purpleGradient,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Owen is typing...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // IELTS/TOEFL Speaking Test Functions
  Widget _buildTestModeSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withOpacity(0.2),
            AppTheme.darkSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryPurple, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.quiz,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speaking Test',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Test your speaking skills',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startTest('IELTS'),
                  icon: const Icon(Icons.school, size: 24),
                  label: const Text(
                    'IELTS Speaking',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startTest('TOEFL'),
                  icon: const Icon(Icons.assignment, size: 24),
                  label: const Text(
                    'TOEFL Speaking',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults() {
    if (_testResults == null) return const SizedBox.shrink();
    
    final overallScore = _testResults!['overallScore'] ?? 0.0;
    final criteria = _testResults!['criteria'] as Map<String, dynamic>? ?? {};
    final feedback = _testResults!['feedback'] ?? '';
    final strengths = (_testResults!['strengths'] as List?) ?? [];
    final improvements = (_testResults!['improvements'] as List?) ?? [];
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGreen, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Test Results',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () {
                  setState(() {
                    _testResults = null;
                    _testMode = null;
                    _isTestActive = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Overall Score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Overall Score: ',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  overallScore.toStringAsFixed(1),
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _testMode == 'IELTS' ? ' / 9.0' : ' / 30',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Criteria Scores
          if (criteria.isNotEmpty) ...[
            const Text(
              'Detailed Scores:',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...criteria.entries.map((entry) {
              final score = entry.value as num;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatCriterionName(entry.key),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      score.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppTheme.accentGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          // Feedback
          if (feedback.isNotEmpty) ...[
            const Text(
              'Feedback:',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              feedback,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Strengths
          if (strengths.isNotEmpty) ...[
            const Text(
              'Strengths:',
              style: TextStyle(
                color: AppTheme.accentGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...strengths.map((strength) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strength.toString(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
          ],
          // Improvements
          if (improvements.isNotEmpty) ...[
            const Text(
              'Areas for Improvement:',
              style: TextStyle(
                color: AppTheme.accentRed,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...improvements.map((improvement) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: AppTheme.accentRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      improvement.toString(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  String _formatCriterionName(String key) {
    final names = {
      'fluency': 'Fluency & Coherence',
      'lexicalResource': 'Lexical Resource',
      'grammar': 'Grammatical Range & Accuracy',
      'pronunciation': 'Pronunciation',
      'delivery': 'Delivery',
      'languageUse': 'Language Use',
      'topicDevelopment': 'Topic Development',
    };
    return names[key] ?? key;
  }

  Future<void> _startTest(String testType) async {
    // Clear previous test results
    setState(() {
      _testMode = testType;
      _isTestActive = true;
      _currentTestPart = testType == 'IELTS' ? 'part1' : 'task1';
      _currentQuestionIndex = 0;
      _currentQuestions = [];
      _currentQuestion = null;
      _testResults = null;
      _messages.clear();
      _testStartTime = DateTime.now();
      _isInConversation = false; // Exit conversation mode if active
    });
    
    // Stop any ongoing speech/listening
    await _speech.stop();
    await _flutterTts.stop();

    // Request microphone permission
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for speaking test'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      setState(() {
        _testMode = null;
        _isTestActive = false;
      });
      return;
    }

    if (!_speechInitialized) {
      await _initializeSpeech();
    }

    // Generate questions for the first part
    await _loadTestQuestions();
  }

  Future<void> _loadTestQuestions() async {
    if (_testMode == null || _currentTestPart == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/chatbot/speaking-test/generate-questions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'testType': _testMode,
          'part': _currentTestPart,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final questions = (data['questions'] as List).map((q) => q.toString()).toList();
        final instructions = data['instructions'] ?? '';
        final timeLimit = data['timeLimit'] ?? 60;

        setState(() {
          _currentQuestions = questions;
          _currentQuestionIndex = 0;
          _isLoading = false;
        });

        // Show instructions
        if (instructions.isNotEmpty) {
          _messages.add(ChatMessage(
            text: instructions,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }

        // Show first question
        if (_currentQuestions.isNotEmpty) {
          _currentQuestion = _currentQuestions[0];
          _messages.add(ChatMessage(
            text: _currentQuestion!,
            isUser: false,
            timestamp: DateTime.now(),
          ));
          await _speak(_currentQuestion!);
          
          // Start listening for answer
          await _startListeningForTest();
        }
      } else {
        throw Exception('Failed to load questions: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading questions: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _startListeningForTest() async {
    if (!_isTestActive || _isLoading) return;

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted && result.recognizedWords.trim().isNotEmpty) {
            setState(() {
              _recognizedText = result.recognizedWords;
              _messageController.text = result.recognizedWords;
            });
          }

          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _handleTestResponse(result.recognizedWords.trim());
          }
        },
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en-US',
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _handleTestResponse(String response) async {
    await _speech.stop();
    
    setState(() {
      _isListening = false;
      _recognizedText = '';
    });

    // Add user response
    _messages.add(ChatMessage(
      text: response,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    _scrollToBottom();

    // Evaluate response
    await _evaluateTestResponse(response);
  }

  Future<void> _evaluateTestResponse(String response) async {
    if (_currentQuestion == null || _testMode == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final evalResponse = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/chatbot/speaking-test/evaluate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'testType': _testMode,
          'question': _currentQuestion,
          'response': response,
        }),
      );

      if (evalResponse.statusCode == 200) {
        final data = json.decode(evalResponse.body);
        
        setState(() {
          _testResults = data;
          _isLoading = false;
        });

        // Show results message
        final overallScore = data['overallScore'] ?? 0.0;
        final scoreText = _testMode == 'IELTS' 
            ? 'Your score: ${overallScore.toStringAsFixed(1)}/9.0'
            : 'Your score: ${overallScore.toStringAsFixed(1)}/30';
        
        _messages.add(ChatMessage(
          text: 'Test completed! $scoreText. Check the results above for detailed feedback.',
          isUser: false,
          timestamp: DateTime.now(),
        ));

        _scrollToBottom();
      } else {
        throw Exception('Failed to evaluate: ${evalResponse.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error evaluating response: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _endTest() async {
    await _speech.stop();
    _testTimer?.cancel();
    
    setState(() {
      _isTestActive = false;
      _isListening = false;
      _isSpeaking = false;
      _recognizedText = '';
    });
  }
}
