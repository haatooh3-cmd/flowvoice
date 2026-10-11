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
  String _statusMessage = 'Groq API 키를 입력하면 초고속 Whisper 변환이 활성화됩니다.';

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
        const SnackBar(content: Text('✅ Groq API 키가 성공적으로 저장되었습니다!')),
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
        positionGravity: PositionGravity.none,
        height: 140,
        width: 140,
      );
      setState(() {
        _isOverlayActive = true;
        _statusMessage = '🎙️ 화면 구석에 플로팅 마이크가 켜졌습니다!';
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
              '🔑 Groq Whisper API 키 (무료)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF61AFEF)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Groq API Key',
                filled: true,
                fillColor: const Color(0xFF282C34),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save, color: Color(0xFF98C379)),
                  onPressed: _saveApiKey,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOverlayActive ? const Color(0xFFE06C75) : const Color(0xFF98C379),
                ),
                icon: Icon(_isOverlayActive ? Icons.stop : Icons.mic, color: Colors.black),
                label: Text(
                  _isOverlayActive ? '플로팅 마이크 끄기' : '화면에 플로팅 마이크 켜기',
                  style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
                ),
                onPressed: _toggleOverlay,
              ),
            ),
            const SizedBox(height: 15),
            Text(_statusMessage, style: const TextStyle(color: Color(0xFFABB2BF))),
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
  bool _isProcessing = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;

  String decodeUrl(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return utf8.decode(bytes);
  }

  Future<void> _handleMicClick() async {
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
        await _transcribeWithGroq(path);
      }

      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _transcribeWithGroq(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String apiKey = prefs.getString('groq_api_key') ?? '';

      if (apiKey.isEmpty) return;
      final url = decodeUrl('68747470733a2f2f6170692e67726f712e636f6d2f6f70656e61692f76312f617564696f2f7472616e736372697074696f6e73');
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer ' + apiKey;
      request.fields['model'] = 'whisper-large-v3-turbo';
      request.fields['language'] = 'ko';
      request.files.add(await http.MultipartFile.fromPath('file', path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await http.Response.fromStream(response);
        final jsonResponse = jsonDecode(responseBody.body);
        final String text = jsonResponse['text'] ?? '';

        if (text.trim().isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: text.trim()));
        }
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
      onTap: _handleMicClick,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: btnColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
