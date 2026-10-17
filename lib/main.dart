// FlowVoice Mobile v49 - Main Dart Entry Point
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
      title: 'FlowVoice Mobile v49',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E2227),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF61AFEF),
          surface: Color(0xFF21252B),
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final TextEditingController _groqController = TextEditingController();
  final TextEditingController _geminiController = TextEditingController();

  List<String> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadSettingsAndHistory();
  }

  Future<void> _loadSettingsAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groqController.text = prefs.getString('groq_api_key') ?? '';
      _geminiController.text = prefs.getString('gemini_api_key') ?? '';
      _historyList = prefs.getStringList('history_list') ?? [];
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', _groqController.text.trim());
    await prefs.setString('gemini_api_key', _geminiController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 키가 성공적으로 저장되었습니다!')),
      );
    }
  }

  Future<void> _toggleOverlay() async {
    final bool isPermissionGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isPermissionGranted) {
      final bool? granted = await FlutterOverlayWindow.requestPermission();
      if (granted != true) return;
    }

    final bool isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.closeOverlay();
    } else {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'FlowVoice Mic',
        overlayContent: 'FlowVoice Floating Mic Overlay',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.none,
        width: 160,
        height: 160,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowVoice Mobile v49'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF21252B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔑 STT API Key 설정',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF61AFEF)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _groqController,
                      decoration: const InputDecoration(
                        labelText: '1순위: Groq API Key (whisper-large-v3-turbo)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _geminiController,
                      decoration: const InputDecoration(
                        labelText: '2순위: Gemini API Key (gemini-2.0-flash)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF98C379),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('설정 저장하기', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF21252B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '🎙️ 플로팅 마이크 버튼',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF98C379)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '다른 앱 화면 위에서도 녹음 및 클립보드 자동 복사가 가능한 오버레이 마이크입니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _toggleOverlay,
                      icon: const Icon(Icons.layers),
                      label: const Text('플로팅 마이크 실행 / 닫기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF61AFEF),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '📜 변환 히스토리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE5C07B)),
            ),
            const SizedBox(height: 8),
            _historyList.isEmpty
                ? const Center(child: Text('변환 기록이 아직 없습니다.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _historyList.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: const Color(0xFF21252B),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(_historyList[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, color: Color(0xFF61AFEF)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _historyList[index]));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('클립보드에 복사되었습니다!')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null && event is Map) {
        if (event['action'] == 'toggle_recording') {
          _handleShortClick();
        }
      }
    });
  }

  Future<void> _handleShortClick() async {
    if (_isProcessing) return;

    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      final String? path = await _audioRecorder.stop();
      if (path != null) {
        await _transcribeAudio(path);
      }

      setState(() {
        _isProcessing = false;
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/flow_recording.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 16000),
          path: path,
        );

        setState(() {
          _isRecording = true;
        });
      }
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
        history.insert(0, '[\$nowStr]\n\$cleanText');
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
