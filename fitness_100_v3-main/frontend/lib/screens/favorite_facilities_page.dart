import 'dart:math' show cos, sqrt, asin; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:location/location.dart';
import '../models/facility.dart';
import 'mission_route_page.dart';

class FavoriteFacilitiesPage extends StatefulWidget {
  const FavoriteFacilitiesPage({super.key});

  @override
  State<FavoriteFacilitiesPage> createState() => _FavoriteFacilitiesPageState();
}

class _FavoriteFacilitiesPageState extends State<FavoriteFacilitiesPage> {
  bool _isLoading = true;
  List<Facility> _favoriteFacilities = [];
  final Location _location = Location();
  
  double _userRadiusKm = 1.2; 

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadUserRadius(); 
  }

  Future<void> _loadUserRadius() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('age')
          .eq('id', user.id)
          .single();

      if (mounted && data['age'] != null) {
        final int age = data['age'];
        setState(() {
          _userRadiusKm = _getRadiusFromAge(age);
        });
      }
    } catch (e) {
      //
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

  // [추가] DB 컬럼(is_cardio 등)을 카테고리 문자열로 변환하는 헬퍼
  String _makeCategoryString(Map<String, dynamic> item) {
    List<String> cats = [];
    if (item['is_cardio'] == 1) cats.add('심폐지구력');
    if (item['is_muscular_endurance'] == 1) cats.add('근지구력');
    if (item['is_flexibility'] == 1) cats.add('유연성');
    if (item['quickness'] == 1) cats.add('순발력');
    if (cats.isEmpty) return '기타';
    return cats.join(', ');
  }

  // [추가] DB 데이터를 Facility.fromJson에 맞는 형태로 변환
  Map<String, dynamic> _convertToApiFormat(Map<String, dynamic> item) {
    final categoryStr = _makeCategoryString(item);
    String mission = '운동';
    
    // detail_equip이 있으면 그것을 미션(운동종목)으로 사용
    if (item['detail_equip'] != null && (item['detail_equip'] as String).isNotEmpty) {
      mission = item['detail_equip'];
    } else {
      // 없으면 카테고리 첫 번째 항목으로 대체
      mission = '${categoryStr.split(',').first} 운동';
    }

    return {
      'id': item['id'],
      'name': item['name'],
      'lat': item['lat'],
      'lon': item['lon'],
      'address': item['address'],
      'mission': mission, // 모델이 기대하는 필드명
      'category': categoryStr, // 모델이 기대하는 필드명
    };
  }

  Future<void> _loadFavorites() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final favResponse = await Supabase.instance.client
          .from('favorite_facilities')
          .select('facility_id')
          .eq('user_id', user.id);

      if (favResponse.isEmpty) {
        if (mounted) setState(() {
          _favoriteFacilities = [];
          _isLoading = false;
        });
        return;
      }

      final List<int> facilityIds =
          (favResponse as List<dynamic>).map((item) => item['facility_id'] as int).toList();

      final orFilter = facilityIds.map((id) => 'id.eq.$id').join(',');
      
      // [수정] 필요한 컬럼 명시적 조회
      final facilitiesResponse = await Supabase.instance.client
          .from('facilities')
          .select('id, name, lat, lon, address, detail_equip, is_cardio, is_muscular_endurance, is_flexibility, quickness')
          .or(orFilter);

      if (mounted) {
        final List<Facility> loadedFacilities = (facilitiesResponse as List<dynamic>)
            .map((item) => Facility.fromJson(_convertToApiFormat(item))) // 변환 후 파싱
            .toList();

        setState(() {
          _favoriteFacilities = loadedFacilities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); 
  }

  Future<void> _handleFacilityTap(Facility facility) async {
    try {
      final locationData = await _location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 정보를 가져올 수 없습니다.')),
          );
        }
        return;
      }

      final double distanceKm = _calculateDistance(
        locationData.latitude!,
        locationData.longitude!,
        facility.lat,
        facility.lon,
      );

      if (distanceKm > _userRadiusKm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('반경내에 시설이 없습니다 시설 주위로 이동해 주세요!'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final bool? start = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("이지팟 시작"),
            content: Text("'${facility.name}'\n이지팟을 시작하시겠습니까?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("취소", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("시작하기", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      if (start == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MissionRoutePage(
              facility: facility,
              startLat: locationData.latitude!,
              startLon: locationData.longitude!,
              isFavorite: true,
            ),
          ),
        );
      }

    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다. 잠시 후 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 즐겨찾는 이지팟'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteFacilities.isEmpty
              ? const Center(
                  child: Text(
                    '즐겨찾는 이지팟이 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _favoriteFacilities.length,
                  itemBuilder: (context, index) {
                    final facility = _favoriteFacilities[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(facility.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (facility.mission.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                                child: Text(facility.mission, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            if (facility.categories.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  children: facility.categories.map((cat) {
                                    return Text(
                                      '#${cat.trim()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => _handleFacilityTap(facility),
                      ),
                    );
                  },
                ),
    );
  }
}
