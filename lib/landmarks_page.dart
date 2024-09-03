import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // Google Generative AI 패키지 임포트
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data'; // 추가된 부분: Uint8List, ByteData를 사용하기 위해 필요
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

const apiKey = 'YOUR_API_KEY'; // 여기에 실제 API 키를 입력하세요

class LandmarksPage extends StatefulWidget {
  final String landmarkName; // 랜드마크 이름
  final String description; // 랜드마크 설명

  const LandmarksPage({
    Key? key,
    required this.landmarkName,
    required this.description,
  }) : super(key: key);

  @override
  _LandmarksPageState createState() => _LandmarksPageState();
}

class _LandmarksPageState extends State<LandmarksPage> {
  TextEditingController _textController = TextEditingController();
  bool _isSending = false; // 서버로 요청을 보내는 중인지 확인하는 플래그
  List<String> _messages = []; // 채팅 메시지를 저장할 리스트

  late GenerativeModel model; // Gemini 모델 객체

  GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    initializeModel();
  }

  void initializeModel() {
    model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: apiKey,
    );
  }

  Future<void> _sendMessage(String message) async {
    // 메시지에 랜드마크 이름을 자동으로 추가
    String modifiedMessage = '${widget.landmarkName}에 대한 질문입니다: $message';

    setState(() {
      _isSending = true;
      _messages.add('User: $message'); // 사용자의 원래 메시지를 리스트에 추가
    });

    try {
      final content = [Content.text(modifiedMessage)];
      final response = await model.generateContent(content);

      setState(() {
        _messages.add(
            'Gemini: ${response.text ?? 'No response from Gemini'}'); // Gemini의 응답을 리스트에 추가
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add('Error: Unable to get a response.');
        _isSending = false;
      });
    }

    _textController.clear(); // 텍스트 필드 초기화
  }

  Future<void> _shareMergedImage() async {
    try {
      // 캡처된 이미지를 병합
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final directory = (await getTemporaryDirectory()).path;
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final filePath = '$directory/${widget.landmarkName}_shared.png';
      File imgFile = File(filePath);
      await imgFile.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(imgFile.path)],
        text: 'Check out this landmark: ${widget.landmarkName}',
        subject: widget.landmarkName,
      );
    } catch (e) {
      print('Error sharing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.landmarkName),
        previousPageTitle: 'Back',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.share),
          onPressed: _shareMergedImage,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                key: _globalKey,
                child: GifWithText(landmarkName: widget.landmarkName),
              ),
              SizedBox(height: 16),
              Text(
                widget.landmarkName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                widget.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '자주 묻는 질문',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              // 동적으로 랜드마크 이름에 맞는 질문 생성
              Text('• ${widget.landmarkName} 입장료가 있나요?'),
              Text('• ${widget.landmarkName} 운영시간은 언제인가요?'),
              SizedBox(height: 16),
              Text(
                '대화 기록',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 200, // 채팅 블록의 높이 설정
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Scrollbar(
                    child: ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(_messages[index]),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16), // 간격 추가
              CupertinoTextField(
                controller: _textController,
                placeholder: 'Ask something...',
                onSubmitted: _isSending ? null : (value) => _sendMessage(value),
              ),
              SizedBox(height: 8),
              CupertinoButton.filled(
                onPressed: _isSending
                    ? null
                    : () => _sendMessage(_textController.text),
                child: Text('Send'),
              ),
              SizedBox(height: 20), // 페이지 끝에 약간의 여백 추가
            ],
          ),
        ),
      ),
    );
  }
}

class GifWithText extends StatelessWidget {
  final String landmarkName;

  const GifWithText({required this.landmarkName});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter, // 텍스트를 GIF 하단에 배치
      children: [
        Image.asset(
          'assets/gifs/icon.gif', // GIF 파일 경로
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
        Positioned(
          bottom: -5, // 텍스트를 GIF 하단부에서 4픽셀 위로 조정
          child: Text(
            landmarkName, // 랜드마크 이름을 텍스트로 표시
            style: TextStyle(
              color: Color(0xFF7E59CC), // 텍스트 색상을 #5D3FD3로 설정
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
