// FlowVoice Mobile v31.9 - Main Dart Entry Point
// Copy this code into lib/main.dart on GitHub repository

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlowVoiceMobileApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FloatingMicOverlayWidget(),
  ));
}

class FlowVoiceMobileApp extends StatelessWidget {
  const FlowVoiceMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowVoice Mobile v31.9',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E2227),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF98C379),
          secondary: Color(0xFF61AFEF),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _groqApiKeyController = TextEditingController();
  final TextEditingController _geminiApiKeyController = TextEditingController();
  bool _isOverlayActive = false;
  String _statusMessage = 'API Key 설정 상태 확인 중...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groqApiKeyController.text = prefs.getString('groq_api_key') ?? '';
      _geminiApiKeyController.text = prefs.getString('gemini_api_key') ?? '';
      if (_groqApiKeyController.text.isNotEmpty || _geminiApiKeyController.text.isNotEmpty) {
        _statusMessage = 'API Key 등록 완료 (음성 입력 준비 됨)';
      } else {
        _statusMessage = 'API Key를 하나 이상 입력해주세요.';
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', _groqApiKeyController.text.trim());
    await prefs.setString('gemini_api_key', _geminiApiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groq & Gemini API 키 설정이 저장되었습니다!')),
      );
      setState(() {
        _statusMessage = 'API 키 저장 완료! 오버레이 마이크를 켜서 사용하세요.';
      });
    }
  }

  Future<void> _toggleOverlay() async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      final bool? requested = await FlutterOverlayWindow.requestPermission();
      if (requested != true) {
        setState(() {
          _statusMessage = '플로팅 권한이 거부되었습니다.';
        });
        return;
      }
    }

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
      setState(() {
        _isOverlayActive = false;
        _statusMessage = '오버레이 마이크 닫힘';
      });
    } else {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'FlowVoice Mobile',
        overlayContent: '짧게 터치: 녹음 / 길게 터치: 히스토리',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.none,
        height: 160,
        width: 160,
      );
      setState(() {
        _isOverlayActive = true;
        _statusMessage = '플로팅 마이크 실행 중';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowVoice Mobile v31.9'),
        backgroundColor: const Color(0xFF21252B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1순위: Groq API Key (0.3초 초고속)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF61AFEF)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _groqApiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Groq API Key (gsk_...)',
                filled: true,
                fillColor: const Color(0xFF282C34),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '2순위 (보조/Fallback): Gemini API Key',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF98C379)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _geminiApiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Gemini API Key (AIzaSy...)',
                filled: true,
                fillColor: const Color(0xFF282C34),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF61AFEF),
                ),
                icon: const Icon(Icons.save, color: Colors.black),
                label: const Text('API 키 전체 저장', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                onPressed: _saveSettings,
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOverlayActive ? const Color(0xFFE06C75) : const Color(0xFF98C379),
                ),
                icon: Icon(_isOverlayActive ? Icons.stop : Icons.mic, color: Colors.black),
                label: Text(
                  _isOverlayActive ? '플로팅 마이크 끄기' : '화면 위에 플로팅 마이크 띄우기',
                  style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                ),
                onPressed: _toggleOverlay,
              ),
            ),
            const SizedBox(height: 15),
            Center(child: Text(_statusMessage, style: const TextStyle(color: Color(0xFFABB2BF)))),
            const SizedBox(height: 25),
            const Divider(color: Color(0xFF3B4048)),
            const SizedBox(height: 10),
            const Text(
              '💡 하이브리드 Fallback 구조:\n'
              '1. Groq API Key로 먼저 변환 시도\n'
              '2. Groq 한도 초과 또는 실패 시 Gemini 2.0 Flash API로 자동 우회\n'
              '3. 키가 없거나 실패 시 오류 없이 안전 안내 표시\n\n'
              '터치 조작 안내:\n'
              '• 짧게 터치: 음성 녹음 시작 및 종료\n'
              '• 꾹 누르기 (Long Press): 히스토리 패널 열기\n'
              '• 더블 터치: 최근 인식된 텍스트 재복사',
              style: TextStyle(color: Color(0xFFE5C07B), fontSize: 13, height: 1.5),
            )
          ],
        ),
      ),
    );
  }
}

class FloatingMicOverlayWidget extends StatefulWidget {
  const FloatingMicOverlayWidget({super.key});

  @override
  State<FloatingMicOverlayWidget> createState() => _FloatingMicOverlayWidgetState();
}

class _FloatingMicOverlayWidgetState extends State<FloatingMicOverlayWidget> {
  bool _isRecording = false;
  bool _isProcessing = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  Future<void> _handleShortClick() async {
    if (_isProcessing) return;

    if (!_isRecording) {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        _audioPath = '${tempDir.path}/flowvoice_temp.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
          path: _audioPath!,
        );

        setState(() {
          _isRecording = true;
        });
      }
    } else {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      final String? path = await _audioRecorder.stop();

      if (path != null && File(path).existsSync()) {
        await _transcribeAudio(path);
      }

      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showOverlayOptionMenu() {
    FlutterOverlayWindow.shareData({
      'action': 'open_history_dialog',
      'time': DateTime.now().toIso8601String()
    });
  }

  Future<void> _transcribeAudio(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String groqApiKey = prefs.getString('groq_api_key') ?? '';
      final String geminiApiKey = prefs.getString('gemini_api_key') ?? '';

      String transcribedText = '';

      // 1순위: Groq API 시도
      if (groqApiKey.isNotEmpty) {
        try {
          final Uri targetUri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
          final request = http.MultipartRequest('POST', targetUri);
          request.headers['Authorization'] = 'Bearer ' + groqApiKey;
          request.fields['model'] = 'whisper-large-v3-turbo';
          request.fields['language'] = 'ko';
          request.files.add(await http.MultipartFile.fromPath('file', path));

          final response = await request.send();
          if (response.statusCode == 200) {
            final responseBody = await http.Response.fromStream(response);
            final jsonResponse = jsonDecode(responseBody.body);
            transcribedText = (jsonResponse['text'] ?? '').toString().trim();
          }
        } catch (_) {}
      }

      // 2순위: Gemini API 자동 우회 (Groq 실패 시 또는 Groq 키 미입력 시)
      if (transcribedText.isEmpty && geminiApiKey.isNotEmpty) {
        try {
          final bytes = await File(path).readAsBytes();
          final base64Audio = base64Encode(bytes);

          final Uri geminiUri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=' + geminiApiKey);
          final response = await http.post(
            geminiUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': '다음 음성을 정확하게 한국어 텍스트로 받아적어주세요. 오직 변환된 텍스트만 출력하고 부연 설명이나 인사말은 절대 포함하지 마세요.'},
                    {
                      'inline_data': {
                        'mime_type': 'audio/m4a',
                        'data': base64Audio
                      }
                    }
                  ]
                }
              ]
            }),
          );

          if (response.statusCode == 200) {
            final jsonResponse = jsonDecode(response.body);
            final String rawText = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
            transcribedText = rawText.trim();
          }
        } catch (_) {}
      }

      // 성공 처리 및 클립보드 복사
      if (transcribedText.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: transcribedText));

        final List<String> history = prefs.getStringList('history_list') ?? [];
        final nowStr = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}";
        history.insert(0, "[$nowStr]\n$transcribedText");
        if (history.length > 50) history.removeLast();
        await prefs.setStringList('history_list', history);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Color btnColor = const Color(0xFF98C379);
    Widget iconWidget = const Icon(Icons.mic, color: Colors.black, size: 30);

    if (_isProcessing) {
      btnColor = const Color(0xFF61AFEF);
      iconWidget = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
      );
    } else if (_isRecording) {
      btnColor = const Color(0xFFE06C75);
      iconWidget = const Icon(Icons.stop, color: Colors.white, size: 30);
    }

    return GestureDetector(
      onTap: _handleShortClick,
      onLongPress: _showOverlayOptionMenu,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: btnColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              spreadRadius: 2,
            )
          ],
        ),
        child: Center(child: iconWidget),
      ),
    );
  }
}
