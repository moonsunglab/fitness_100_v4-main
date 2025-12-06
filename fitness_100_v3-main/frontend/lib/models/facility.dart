class Facility {
  final int id;
  final String name;
  final double lat;
  final double lon;
  final String address;
  final String mission;
  final List<String> categories;

  Facility({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.address,
    required this.mission,
    required this.categories,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    // [수정] 백엔드 API 응답(FacilityOut)에 맞춰 파싱 로직 변경
    // 백엔드는 'category' 필드에 콤마로 구분된 문자열을 줍니다. (예: "근지구력, 유연성")
    
    List<String> parsedCategories = [];
    if (json['category'] != null) {
      final catStr = json['category'] as String;
      if (catStr.isNotEmpty) {
        parsedCategories = catStr.split(',').map((e) => e.trim()).toList();
      }
    }

    // 카테고리가 비어있으면 기본값
    if (parsedCategories.isEmpty) {
      parsedCategories.add('기타');
    }

    return Facility(
      id: json['id'] as int,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      address: json['address'] as String? ?? '',
      // 백엔드에서 'mission' 필드를 직접 줍니다. ('detail_equip'이 아님)
      mission: json['mission'] as String? ?? '운동', 
      categories: parsedCategories,
    );
  }
}
