import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:geolocator/geolocator.dart';
import 'landmarks_page.dart'; // landmarks_page.dart 파일을 임포트합니다.
import 'package:intl/intl.dart';

class SeoulListPage extends StatefulWidget {
  @override
  _SeoulListPageState createState() => _SeoulListPageState();
}

class _SeoulListPageState extends State<SeoulListPage> {
  List<Map<String, dynamic>> landmarksData = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadCSV();
    _getCurrentLocation(); // 위치 권한을 요청하고 위치를 가져오는 함수 호출
    _listenToLocationChanges(); // 위치 변경을 감지하는 스트림 시작
  }

  Future<void> _loadCSV() async {
    final rawData = await rootBundle.loadString('assets/seoul_db.csv');
    List<List<dynamic>> listData =
        const CsvToListConverter().convert(rawData, eol: '\n');

    // 모든 칼럼을 읽어와서 landmarksData 리스트에 저장
    landmarksData = listData.skip(1).map((data) {
      return {
        'id': data[0].toString(),
        'name': data[1].toString(), // '랜드마크' 칼럼
        'category': data[2].toString(),
        'description': data[3].toString(),
        'name_en': data[4].toString(),
        'category_en': data[5].toString(),
        'description_en': data[6].toString(),
        'gps': data[7].toString(),
        'address': data[8].toString(),
        'latitude': _parseLatLng(data[7].toString())[0],
        'longitude': _parseLatLng(data[7].toString())[1],
      };
    }).toList();

    setState(() {}); // 상태를 갱신하여 UI를 업데이트
  }

  List<double> _parseLatLng(String gpsString) {
    // GPS 문자열에서 위도와 경도를 추출하는 함수
    final cleanedString = gpsString.replaceAll(RegExp(r'[^\d.,-]'), '');
    final parts = cleanedString.split(',');

    double latitude = double.parse(parts[0].trim());
    double longitude = double.parse(parts[1].trim());

    return [latitude, longitude];
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스가 활성화되었는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 위치 서비스가 활성화되지 않은 경우
      print('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 위치 권한이 거부된 경우
        print('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // 위치 권한이 영구적으로 거부된 경우
      print(
          'Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    // 권한이 허용된 경우 현재 위치 가져오기
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _sortLandmarksByDistance();
      setState(() {}); // 상태를 갱신하여 UI를 업데이트
    } catch (e) {
      // 위치를 가져오지 못했을 때의 에러 처리
      print('Error getting location: $e');
    }
  }

  void _listenToLocationChanges() {
    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _currentPosition = position;
      _sortLandmarksByDistance();
      setState(() {});
    });
  }

  void _sortLandmarksByDistance() {
    if (_currentPosition == null) return;

    landmarksData.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(_currentPosition!.latitude,
          _currentPosition!.longitude, a['latitude'], a['longitude']);
      double distanceB = Geolocator.distanceBetween(_currentPosition!.latitude,
          _currentPosition!.longitude, b['latitude'], b['longitude']);
      return distanceA.compareTo(distanceB);
    });
  }

  String _calculateDistance(double lat, double lon) {
    if (_currentPosition == null) return '';
    double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude, lat, lon);
    return NumberFormat('#,###', 'en_US').format(distance.round()) + 'm'; // 미터 단위로 반올림 & 콤마
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Seoul Landmarks'),
        previousPageTitle: 'Back',
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          // SingleChildScrollView로 추가
          child: ListView.builder(
            physics: NeverScrollableScrollPhysics(), // ListView의 자체 스크롤 비활성화
            shrinkWrap: true, // ListView가 자신의 크기에 맞게 조정
            itemCount: landmarksData.length,
            itemBuilder: (context, index) {
              final landmark = landmarksData[index];
              final distance = _calculateDistance(
                  landmark['latitude'], landmark['longitude']);
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => LandmarksPage(
                        landmarkName: landmark['name_en']!,
                        description: landmark['description_en']!,
                      ),
                    ),
                  );
                },
                child: _buildCupertinoListTile(landmark['name_en']!, distance),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCupertinoListTile(String name, String distance) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                distance,
                style: CupertinoTheme.of(context).textTheme.textStyle,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        Container(
          height: 1.0,
          color: CupertinoColors.separator,
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
        ),
      ],
    );
  }
}
