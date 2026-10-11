import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlowVoiceMobileApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FloatingMicWidget(),
  ));
}

class FlowVoiceMobileApp extends StatelessWidget {
  const FlowVoiceMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowVoice Mobile',
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
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isOverlayActive = false;
  String _statusMessage = 'Groq API 키 입력 시 초고속 Whisper AI 변환이 구동됩니다.\n미입력 시 갤럭시 내장 오프라인 음성인식으로 자동 동작합니다.';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('groq_api_key') ?? '';
    _apiKeyController.text = savedKey;
  }

  Future<void> _saveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', _apiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Groq API 키가 저장되었습니다!')),
      );
    }
  }

  Future<void> _toggleOverlay() async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      final bool? requested = await FlutterOverlayWindow.requestPermission();
      if (requested != true) {
        setState(() {
          _statusMessage = '❌ 다른 앱 위에 그리기 권한을 허용해 주세요.';
        });
        return;
      }
    }

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
      setState(() {
        _isOverlayActive = false;
        _statusMessage = '⚪ 플로팅 마이크가 꺼졌습니다.';
      });
    } else {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'FlowVoice 음성 타자기',
        overlayContent: '터치하여 음성 입력 시작/종료',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.rightBottom,
        height: 140,
        width: 140,
      );
      setState(() {
        _isOverlayActive = true;
        _statusMessage = '🎙️ 화면 구석에 플로팅 마이크가 켜졌습니다! 카톡/메모장에서 누르세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎙️ FlowVoice 모바일 음성 타자기'),
        backgroundColor: const Color(0xFF21252B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔑 Groq Whisper API 키 (선택 사항 / 무료)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF61AFEF)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'gsk_... (없으면 내장 엔진으로 동작)',
                filled: true,
                fillColor: const Color(0xFF282C34),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save, color: Color(0xFF98C379)),
                  onPressed: _saveApiKey,
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOverlayActive ? const Color(0xFFE06C75) : const Color(0xFF98C379),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_isOverlayActive ? Icons.stop : Icons.mic, color: Colors.black, size: 28),
                label: Text(
                  _isOverlayActive ? '플로팅 마이크 끄기' : '화면에 플로팅 마이크 켜기',
                  style: const TextStyle(fontSize: 17, color: Colors.black, fontWeight: FontWeight.bold),
                ),
                onPressed: _toggleOverlay,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF282C34),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3B4048)),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Color(0xFFABB2BF), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FloatingMicWidget extends StatefulWidget {
  const FloatingMicWidget({super.key});

  @override
  State<FloatingMicWidget> createState() => _FloatingMicWidgetState();
}

class _FloatingMicWidgetState extends State<FloatingMicWidget> {
  bool _isRecording = false;
  late stt.SpeechToText _speech;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _handleMicClick() async {
    if (!_isRecording) {
      setState(() => _isRecording = true);
      bool available = await _speech.initialize();
      if (available) {
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              _finishSTT(val.recognizedWords);
            }
          },
          localeId: 'ko_KR',
        );
      }
    } else {
      setState(() => _isRecording = false);
      await _speech.stop();
    }
  }

  Future<void> _finishSTT(String text) async {
    if (text.trim().isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    setState(() => _isRecording = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleMicClick,
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: _isRecording ? const Color(0xFFE06C75) : const Color(0xFF98C379),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.black, size: 32),
      ),
    );
  }
}
