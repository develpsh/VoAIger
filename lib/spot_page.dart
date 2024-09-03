import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'landmark_details_page.dart';

class SpotPage extends StatefulWidget {
  final double currentLatitude;
  final double currentLongitude;
  final List<String> selectedCategories;

  const SpotPage({
    super.key,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.selectedCategories,
  });

  @override
  _SpotPageState createState() => _SpotPageState();
}

class _SpotPageState extends State<SpotPage> {
  List<Map<String, dynamic>> landmarksData = [];
  Map<String, dynamic>? closestLandmark;
  List<Map<String, dynamic>> closestLandmarks = [];
  final GlobalKey _globalKey = GlobalKey();
  late GenerativeModel model;

  final List<String> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadCSV();
    initializeModel();
  }

  void initializeModel() {
    model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: 'your-api-key',
    );
  }

  Future<void> _loadCSV() async {
    final rawData = await rootBundle.loadString('assets/seoul_db2.csv');
    List<List<dynamic>> listData =
        const CsvToListConverter().convert(rawData, eol: '\n');

    landmarksData = listData.skip(1).map((data) {
      return {
        'id': data[0].toString(),
        'name': data[1].toString(),
        'category': data[2].toString(),
        'description': data[3].toString(),
        'latitude': _parseLatLng(data[7].toString())[0],
        'longitude': _parseLatLng(data[7].toString())[1],
        'image': data[9].toString(),
      };
    }).toList();

    _sortLandmarksByDistance();
    setState(() {});
  }

  List<double> _parseLatLng(String gpsString) {
    final cleanedString = gpsString.replaceAll(RegExp(r'[^\d.,-]'), '');
    final parts = cleanedString.split(',');

    double latitude = double.parse(parts[0].trim());
    double longitude = double.parse(parts[1].trim());

    return [latitude, longitude];
  }

  void _sortLandmarksByDistance() {
    landmarksData.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(widget.currentLatitude,
          widget.currentLongitude, a['latitude'], a['longitude']);
      double distanceB = Geolocator.distanceBetween(widget.currentLatitude,
          widget.currentLongitude, b['latitude'], b['longitude']);
      return distanceA.compareTo(distanceB);
    });

    closestLandmark = landmarksData.isNotEmpty ? landmarksData.first : null;
    closestLandmarks =
        landmarksData.length > 1 ? landmarksData.sublist(1, 4) : [];
  }

  String _calculateDistance(double lat, double lon) {
    double distance = Geolocator.distanceBetween(
        widget.currentLatitude, widget.currentLongitude, lat, lon);
    return '${(distance / 10).round() * 10}m'; // 10미터 단위로 반올림
  }

  Future<void> _shareMergedImage() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final directory = (await getTemporaryDirectory()).path;
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final filePath = '$directory/${closestLandmark!['name']}_shared.png';
      File imgFile = File(filePath);
      await imgFile.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(imgFile.path)],
        text: 'Check out this landmark: ${closestLandmark!['name']}',
        subject: closestLandmark!['name'],
      );
    } catch (e) {
      print('Error sharing image: $e');
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('Error sharing image'),
            actions: <CupertinoDialogAction>[
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  String cleanUrl(String url) {
    return url.trim().replaceAll(RegExp(r'[\r\n]+'), '');
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl =
        closestLandmark != null ? cleanUrl(closestLandmark!['image']) : '';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(closestLandmark?['name'] ?? 'No Landmark'),
        previousPageTitle: 'Back',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _shareMergedImage,
          child: const Icon(
              CupertinoIcons.share), // 이미지를 공유할 때 _shareMergedImage 호출
        ),
      ),
      child: SafeArea(
        child: closestLandmark == null
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RepaintBoundary(
                      key: _globalKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              image: DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            closestLandmark!['name'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            closestLandmark!['description'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '자주 묻는 질문',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('• ${closestLandmark!['name']} 입장료는 얼마인가요?'),
                    Text('• ${closestLandmark!['name']} 운영시간은 언제인가요?'),
                    const SizedBox(height: 16),
                    const Text(
                      '채팅 기록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: CupertinoColors.systemGrey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CupertinoScrollbar(
                          child: ListView.builder(
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: Text(_messages[index]),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      controller: _textController,
                      placeholder: 'Ask something...',
                      onSubmitted:
                          _isSending ? null : (value) => _sendMessage(value),
                    ),
                    const SizedBox(height: 8),
                    CupertinoButton.filled(
                      onPressed: _isSending
                          ? null
                          : () => _sendMessage(_textController.text),
                      child: const Text('Send'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '가까운 랜드마크',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Column(
                      children: closestLandmarks.map((landmark) {
                        final distance = _calculateDistance(
                            landmark['latitude'], landmark['longitude']);
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => LandmarkDetailsPage(
                                  landmarkName: landmark['name'],
                                  description: landmark['description'],
                                  imageUrl: cleanUrl(landmark['image']),
                                  landmarksData: landmarksData,
                                  currentPosition: Position(
                                    latitude: widget.currentLatitude,
                                    longitude: widget.currentLongitude,
                                    altitude: 0.0,
                                    heading: 0.0,
                                    speed: 0.0,
                                    speedAccuracy: 0.0,
                                    timestamp: DateTime.now(),
                                    accuracy: 0.0,
                                    altitudeAccuracy: 0.0,
                                    headingAccuracy: 0.0,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    landmark['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: CupertinoColors.black,
                                    ),
                                  ),
                                ),
                                Text(
                                  distance,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _sendMessage(String message) async {
    String modifiedMessage = '${closestLandmark!['name']}에 대한 질문입니다: $message';

    setState(() {
      _isSending = true;
      _messages.add('User: $message');
    });

    try {
      final content = [Content.text(modifiedMessage)];
      final response = await model.generateContent(content);

      setState(() {
        _messages.add('Gemini: ${response.text ?? 'No response from Gemini'}');
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add('Error: Unable to get a response.');
        _isSending = false;
      });
    }

    _textController.clear();
  }
}
