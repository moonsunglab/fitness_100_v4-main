// lib/tabs/map_mission_view.dart
import 'dart:async';
import 'dart:math' show cos, sqrt, asin;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:location/location.dart';

import '../models/facility.dart';
import '../screens/mission_route_page.dart';
import '../services/facility_api.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class MapMissionView extends StatefulWidget {
  const MapMissionView({super.key});

  @override
  State<MapMissionView> createState() => _MapMissionViewState();
}

class _MapMissionViewState extends State<MapMissionView> {
  NaverMapController? _naverMapController;
  bool _mapReady = false;

  bool _loading = true;
  static const NLatLng _defaultCenter = NLatLng(37.5665, 126.9780);
  NLatLng? _userCenter;
  
  double _radiusKm = 1.2; 
  int _userAge = 35; 

  final Location _location = Location();
  final Completer<NaverMapController> _mapControllerCompleter = Completer();
  
  final _facilityApi = FacilityApi();

  List<Facility> _facilities = [];
  Facility? _selected;
  final Set<int> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _updateUserLocation();
    await _loadAndSetRadius();
    // [수정] 로딩 순서 변경 및 정렬 적용
    // 즐겨찾기를 먼저 불러와야 시설 로드 시 바로 정렬 가능
    await _loadUserFavorites(); 
    await _loadFacilities();
  }

  Future<void> _loadAndSetRadius() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _radiusKm = _getRadiusFromAge(_userAge));
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('age')
          .eq('id', user.id)
          .single();

      if (mounted && data['age'] != null) {
        setState(() {
          _userAge = data['age'];
          _radiusKm = _getRadiusFromAge(_userAge);
        });
      } else {
        setState(() => _radiusKm = _getRadiusFromAge(_userAge));
      }
    } catch (e) {
      if (mounted) setState(() => _radiusKm = _getRadiusFromAge(_userAge));
    }
  }

  double _getRadiusFromAge(int age) {
    if (age <= 19) return 2.5;
    if (age <= 29) return 1.25;
    if (age <= 39) return 1.2;
    if (age <= 49) return 1.15;
    if (age <= 59) return 1.1;
    if (age <= 69) return 1.0;
    return 0.875;
  }

  String _getAgeGradeString(int age) {
    if (age < 20) return "19세 이하";
    if (age >= 70) return "70대 이상";
    
    int tens = (age ~/ 10) * 10;
    int units = age % 10;
    
    String suffix;
    if (units <= 3) {
      suffix = "초반";
    } else if (units <= 6) {
      suffix = "중반";
    } else {
      suffix = "후반";
    }
    
    return "$tens대 $suffix";
  }

  NLatLng get _mapCenter => _userCenter ?? _defaultCenter;

  Future<void> _updateUserLocation() async {
    try {
      bool serviceEnabled;
      PermissionStatus permissionGranted;

      serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _userCenter = NLatLng(locationData.latitude!, locationData.longitude!);
        });

        if (_mapControllerCompleter.isCompleted) {
           final mapController = await _mapControllerCompleter.future;
           try {
             final cameraUpdate = NCameraUpdate.withParams(
               target: _userCenter!,
               zoom: 14,
             );
             await mapController.updateCamera(cameraUpdate);
             mapController.setLocationTrackingMode(NLocationTrackingMode.follow);
           } catch (e) {
             debugPrint("카메라 이동 오류: $e");
           }
        }
      }
    } catch (e) {
      debugPrint("위치 업데이트 오류: $e");
    }
  }

  Future<void> _goToMyLocation() async {
    await _updateUserLocation();
    if (_userCenter != null) {
      await _loadFacilities();
    }
  }

  // [추가] 시설 목록 정렬 함수 (즐겨찾기 우선)
  void _sortFacilities() {
    _facilities.sort((a, b) {
      final isFavA = _favoriteIds.contains(a.id);
      final isFavB = _favoriteIds.contains(b.id);
      
      // 즐겨찾기 여부가 다르면 즐겨찾기 된 것이 위로(-1)
      if (isFavA && !isFavB) return -1;
      if (!isFavA && isFavB) return 1;
      
      // 즐겨찾기 여부가 같으면 기존 순서 유지 (혹은 이름순 등 추가 가능)
      return 0;
    });
  }

  Future<void> _loadFacilities() async {
    setState(() => _loading = true);

    try {
      final center = _mapCenter;
      
      final nearbyFacilities = await _facilityApi.getNearFacilities(
        lat: center.latitude,
        lon: center.longitude,
        radiusKm: _radiusKm, 
      );

      if (!mounted) return;

      setState(() {
        _facilities = nearbyFacilities;
        _sortFacilities(); // [추가] 로드 후 정렬
      });

      await _renderOverlays();
    } catch (e) {
      debugPrint('[MAP] 시설 로딩 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시설 정보를 불러오지 못했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUserFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('favorite_facilities')
          .select('facility_id')
          .eq('user_id', user.id);

      final ids = data.map((item) => item['facility_id'] as int).toSet();

      if (!mounted) return;
      setState(() {
        _favoriteIds..clear()..addAll(ids);
        _sortFacilities(); // [추가] 즐겨찾기 로드 후에도 정렬 (혹시 시설 로드가 더 빨랐을 경우 대비)
      });
    } catch (e) {
      debugPrint('[MAP] 즐겨찾기 조회 예외: $e');
    }
  }

  Future<void> _toggleFavorite(Facility f) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    final isCurrentlyFavorite = _favoriteIds.contains(f.id);
    final newFavoriteState = !isCurrentlyFavorite;

    setState(() {
      if (newFavoriteState) {
        _favoriteIds.add(f.id);
      } else {
        _favoriteIds.remove(f.id);
      }
      _sortFacilities(); // [추가] 상태 변경 즉시 리스트 재정렬
    });

    try {
      if (newFavoriteState) {
        await Supabase.instance.client.from('favorite_facilities').insert({
          'user_id': user.id,
          'facility_id': f.id,
        });
      } else {
        await Supabase.instance.client.from('favorite_facilities').delete().match({
          'user_id': user.id,
          'facility_id': f.id,
        });
      }
    } catch (e) {
      debugPrint("[Favorite Toggle] Error: $e");
      // 에러 발생 시 원복 및 재정렬
      if (mounted) {
        setState(() {
          if (isCurrentlyFavorite) {
            _favoriteIds.add(f.id);
          } else {
            _favoriteIds.remove(f.id);
          }
          _sortFacilities();
        });
      }
    }
  }

  Future<void> _renderOverlays() async {
    if (!_mapReady || _naverMapController == null) return;

    final overlays = <NAddableOverlay<NOverlay<void>>>{};

    final circle = NCircleOverlay(
      id: 'radius_circle',
      center: _mapCenter,
      radius: _radiusKm * 1000,
      color: const Color.fromARGB(80, 64, 196, 255),
      outlineColor: const Color.fromARGB(180, 64, 196, 255),
      outlineWidth: 2,
    );
    overlays.add(circle);

    for (final f in _facilities) {
      final marker = NMarker(
        id: 'facility_${f.id}',
        position: NLatLng(f.lat, f.lon),
        caption: NOverlayCaption(text: f.name),
      );

      marker.setOnTapListener((overlay) async {
        if (!mounted) return;
        _openMissionPage(f); 
      });

      overlays.add(marker);
    }

    await _naverMapController!.clearOverlays();
    await _naverMapController!.addOverlayAll(overlays);
  }

  Future<void> _focusFacility(Facility f) async {
    if (!_mapReady || _naverMapController == null) return;
    setState(() => _selected = f);
    final cameraUpdate = NCameraUpdate.withParams(target: NLatLng(f.lat, f.lon), zoom: 15);
    await _naverMapController!.updateCamera(cameraUpdate);
  }

  void _openMissionPage(Facility f) async {
    final start = _userCenter ?? _mapCenter;
    final isFav = _favoriteIds.contains(f.id);

    // [수정] 페이지 갔다오면 즐겨찾기 상태 등 바뀔 수 있으므로 다시 로드
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MissionRoutePage(
          facility: f,
          startLat: start.latitude,
          startLon: start.longitude,
          isFavorite: isFav,
        ),
      ),
    );
    
    if (mounted) {
      await _loadUserFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120.0),
        child: FloatingActionButton(
          onPressed: _goToMyLocation,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          child: const Icon(Icons.my_location),
        ),
      ),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _defaultCenter,
                zoom: 14,
              ),
              locationButtonEnable: true, 
              consumeSymbolTapEvents: false,
            ),
            onMapReady: (controller) async {
              _naverMapController = controller;
              _mapReady = true;
              if (!_mapControllerCompleter.isCompleted) {
                _mapControllerCompleter.complete(controller);
              }

              if (_userCenter != null) {
                final cameraUpdate = NCameraUpdate.withParams(
                  target: _userCenter!,
                  zoom: 14,
                );
                await controller.updateCamera(cameraUpdate);
                controller.setLocationTrackingMode(NLocationTrackingMode.follow);
              }
              
              await _renderOverlays();
            },
          ),
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar, color: Colors.lightBlueAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "추천 반경: ${_radiusKm.toStringAsFixed(3).replaceAll('.000', '')} km",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "내 연령대(${_getAgeGradeString(_userAge)})에 따라 자동 설정됩니다.",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.18,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              if (_facilities.isEmpty) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: const Center(
                    child: Text('반경 내 이지팟 미션이 없습니다.'),
                  ),
                );
              }
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '이지팟 목록',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _facilities.length,
                        itemBuilder: (context, index) {
                          final f = _facilities[index];
                          final isFav = _favoriteIds.contains(f.id);

                          return ListTile(
                            onTap: () => _openMissionPage(f),
                            title: Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (f.mission.isNotEmpty)
                                  Text(
                                    f.mission,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                if (f.categories.isNotEmpty)
                                  Wrap(
                                    spacing: 6.0,
                                    runSpacing: 4.0,
                                    children: f.categories.map((cat) {
                                      return Text(
                                        '#${cat.trim()}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    }).toList(),
                                  )
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isFav
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: isFav
                                        ? Colors.amber
                                        : Colors.grey,
                                  ),
                                  onPressed: () => _toggleFavorite(f),
                                ),
                                TextButton(
                                  onPressed: () => _openMissionPage(f),
                                  child: const Text('미션 시작'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
