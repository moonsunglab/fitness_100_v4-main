// lib/pages/facility_map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../services/facility_api.dart';
import '../models/facility.dart';

class FacilityMapPage extends StatefulWidget {
  const FacilityMapPage({super.key});

  @override
  State<FacilityMapPage> createState() => _FacilityMapPageState();
}

class _FacilityMapPageState extends State<FacilityMapPage> {
  final _facilityApi = FacilityApi();

  NaverMapController? _mapController;
  List<NMarker> _facilityMarkers = [];
  NMarker? _userMarker;

  bool _isLoading = false;
  String? _infoMessage;
  String? _errorMessage;

  // 서울시청 근처 (기본 위치)
  final NLatLng _initialPos = const NLatLng(37.5665, 126.9780);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주변 공공체육시설'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _initialPos,
                zoom: 12, // 넓게 보기 위해 줌 레벨 조정
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              // 지도 준비되면 초기 위치 기준으로 조회
              await _refreshMarkers(_initialPos);
            },
          ),

          // 상단 안내 배너
          if (_infoMessage != null || _errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: _errorMessage != null
                    ? Colors.red.withOpacity(0.9)
                    : Colors.black.withOpacity(0.7),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    _errorMessage ?? _infoMessage ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_mapController == null) return;
          final cameraPos = await _mapController!.getCameraPosition();
          await _refreshMarkers(cameraPos.target);
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        icon: const Icon(Icons.refresh),
        label: const Text('이 위치에서 다시 찾기'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _refreshMarkers(NLatLng center) async {
    setState(() {
      _isLoading = true;
      _infoMessage = null;
      _errorMessage = null;
    });

    try {
      // [수정] 데이터 확인을 위해 반경을 10km로 늘림
      const double radiusKm = 10.0;

      final facilities = await _facilityApi.getNearFacilities(
        lat: center.latitude,
        lon: center.longitude,
        radiusKm: radiusKm,
      );

      // 사용자 위치 마커
      final userMarker = NMarker(
        id: 'user_location',
        position: center,
        iconTintColor: Colors.blueAccent,
      );
      userMarker.setCaption(
        const NOverlayCaption(text: '검색 중심'),
      );

      // 시설 마커 생성
      final facilityMarkers = facilities.map((f) {
        final marker = NMarker(
          id: 'facility_${f.id}',
          position: NLatLng(f.lat, f.lon),
          caption: NOverlayCaption(text: f.name),
        );
        
        // [추가] 마커 클릭 시 정보창 띄우기
        marker.setOnTapListener((overlay) {
          _showFacilityInfo(f);
        });
        
        return marker;
      }).toList();

      // 지도에 반영
      if (_mapController != null) {
        await _mapController!.clearOverlays();
        await _mapController!.addOverlay(userMarker);
        if (facilityMarkers.isNotEmpty) {
          await _mapController!.addOverlayAll(facilityMarkers);
        }
      }

      setState(() {
        _userMarker = userMarker;
        _facilityMarkers = facilityMarkers;

        if (facilityMarkers.isEmpty) {
          _infoMessage = '반경 ${radiusKm.toInt()}km 내 시설이 없습니다.\n지도를 이동해 보세요.';
        } else {
          _infoMessage = '시설 ${facilities.length}개를 찾았습니다.';
        }
      });
    } catch (e) {
      debugPrint('시설 조회 실패: $e');
      setState(() {
        _errorMessage = '시설 정보를 불러오지 못했습니다.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // [추가] 시설 정보 바텀시트
  void _showFacilityInfo(Facility facility) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facility.name,
                style: const TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      facility.address.isNotEmpty ? facility.address : "주소 정보 없음",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "추천 미션",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.mission,
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "카테고리: ${facility.categories.join(', ')}",
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("미션 수행 기능은 준비 중입니다.")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("이 곳에서 미션 시작하기"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
