// FlowVoice Mobile v42 - Main Dart Entry Point
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
      title: 'FlowVoice Mobile v42',
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
  final TextEditingController _groqKeyController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();
  bool _isOverlayActive = false;
  String _statusMessage = 'Groq & Gemini API Key 설정 대기 중';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groqKeyController.text = prefs.getString('groq_api_key') ?? '';
      _geminiKeyController.text = prefs.getString('gemini_api_key') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', _groqKeyController.text.trim());
    await prefs.setString('gemini_api_key', _geminiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groq 및 Gemini API 키가 성공적으로 저장되었습니다!')),
      );
    }
  }

  Future<void> _toggleOverlay() async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      final bool? requested = await FlutterOverlayWindow.requestPermission();
      if (requested != true) {
        setState(() {
          _statusMessage = '플로팅 마이크 권한이 거부되었습니다.';
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
        overlayTitle: 'FlowVoice Mobile v42',
        overlayContent: '짧게 터치: 녹음 / 꾹 누르기: 히스토리 / 더블터치: 재복사',
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
        title: const Text('FlowVoice Mobile v42'),
        backgroundColor: const Color(0xFF21252B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1순위: Groq API Key (0.3초 초고속 변환)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF61AFEF)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _groqKeyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Groq API Key (gsk_...) 입력',
                filled: true,
                fillColor: const Color(0xFF282C34),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '2순위 보조: Gemini API Key (Groq 한도 초과 시 자동 우회)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFE5C07B)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _geminiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Gemini API Key (AIzaSy...) 입력',
                filled: true,
                fillColor: const Color(0xFF282C34),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF61AFEF),
                ),
                icon: const Icon(Icons.save, color: Colors.black),
                label: const Text('API 키 저장하기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              '📱 플로팅 마이크 사용법:\n'
              '• 짧게 1회 터치: 음성 녹음 시작 및 완료\n'
              '• 0.5초 꾹 누르기 (Long Press): 히스토리 패널 열기\n'
              '• 더블 터치 (Double Tap): 최근 인식된 텍스트 다시 복사\n\n'
              '🛡️ 2중 Fallback 안전장치:\n'
              'Groq API 사용 중 일일 한도 초과 시 Gemini API로 자동 우회하여 음성 타자가 중단되지 않습니다.',
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

  @override  State<FloatingMicOverlayWidget> createState() => _FloatingMicOverlayWidgetState();
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

  Future<void> _reCopyLastText() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('history_list') ?? [];
    if (history.isNotEmpty) {
      final firstRecord = history.first;
      final parts = firstRecord.split('\n');
      final textToCopy = parts.length > 1 ? parts.sublist(1).join('\n') : firstRecord;
      await Clipboard.setData(ClipboardData(text: textToCopy));
    }
  }

  Future<void> _transcribeAudio(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String groqKey = prefs.getString('groq_api_key') ?? '';
      final String geminiKey = prefs.getString('gemini_api_key') ?? '';

      String? resultText;

      // 1순위: Groq API 시도
      if (groqKey.isNotEmpty) {
        try {
          resultText = await _callGroqApi(path, groqKey);
        } catch (_) {
          resultText = null;
        }
      }

      // 2순위: Groq 실패 또는 키 미설정 시 Gemini API 우회
      if ((resultText == null || resultText.trim().isEmpty) && geminiKey.isNotEmpty) {
        try {
          resultText = await _callGeminiApi(path, geminiKey);
        } catch (_) {
          resultText = null;
        }
      }

      if (resultText != null && resultText.trim().isNotEmpty) {
        final cleanText = resultText.trim();
        await Clipboard.setData(ClipboardData(text: cleanText));

        final List<String> history = prefs.getStringList('history_list') ?? [];
        final nowStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
        history.insert(0, '[$nowStr]\n$cleanText');
        if (history.length > 50) history.removeLast();
        await prefs.setStringList('history_list', history);
      }
    } catch (_) {}
  }

  Future<String?> _callGroqApi(String path, String apiKey) async {
    final Uri targetUri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', targetUri);
    request.headers['Authorization'] = 'Bearer ' + apiKey;
    request.fields['model'] = 'whisper-large-v3-turbo';
    request.fields['language'] = 'ko';
    request.files.add(await http.MultipartFile.fromPath('file', path));

    final response = await request.send().timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final responseBody = await http.Response.fromStream(response);
      final jsonResponse = jsonDecode(responseBody.body);
      return jsonResponse['text'] as String?;
    }
    return null;
  }

  Future<String?> _callGeminiApi(String path, String apiKey) async {
    final File audioFile = File(path);
    final List<int> bytes = await audioFile.readAsBytes();
    final String base64Audio = base64Encode(bytes);

    final Uri geminiUri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=' + apiKey);
    final payload = {
      'contents': [
        {
          'parts': [
            {'text': 'Transcribe the following audio accurately into Korean text without commentary.'},
            {
              'inline_data': {
                'mime_type': 'audio/m4a',
                'data': base64Audio
              }
            }
          ]
        }
      ]
    };

    final response = await http.post(
      geminiUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      final candidates = jsonResponse['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final firstCandidate = candidates[0] as Map<String, dynamic>?;
        final content = firstCandidate?['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final firstPart = parts[0] as Map<String, dynamic>?;
          return firstPart?['text'] as String?;
        }
      }
    }
    return null;
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
      onDoubleTap: _reCopyLastText,
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
