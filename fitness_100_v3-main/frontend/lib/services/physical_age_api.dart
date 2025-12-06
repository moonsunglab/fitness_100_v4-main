// lib/services/physical_age_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class PhysicalAgeResult {
  final double loAgeValue;      
  final String gradeLabel;      
  final double percentile;      
  final String weakPoint;       
  final int tierIndex;          

  PhysicalAgeResult({
    required this.loAgeValue,
    required this.gradeLabel,
    required this.percentile,
    required this.weakPoint,
    required this.tierIndex,
  });

  factory PhysicalAgeResult.fromJson(Map<String, dynamic> json) {
    return PhysicalAgeResult(
      loAgeValue: (json['lo_age_value'] as num).toDouble(),
      gradeLabel: (json['lo_age_tier_label'] ?? json['grade_label']) as String,
      percentile: (json['percentile'] as num).toDouble(),
      weakPoint: json['weak_point'] as String,
      tierIndex: (json['tier_index'] as num).toInt(),
    );
  }
}

/// 히스토리 한 건
class PhysicalAgeHistoryRecord {
  final int id;
  final String userId;
  final DateTime measuredAt;
  final int gradeIndex;
  final String gradeLabel;
  final double percentile;
  final String? weakPoint;
  final double? avgQuantile;
  final int loAgeValue; 

  PhysicalAgeHistoryRecord({
    required this.id,
    required this.userId,
    required this.measuredAt,
    required this.gradeIndex,
    required this.gradeLabel,
    required this.percentile,
    this.weakPoint,
    this.avgQuantile,
    required this.loAgeValue,
  });

  factory PhysicalAgeHistoryRecord.fromJson(Map<String, dynamic> json) {
    // [수정] UTC 시간을 로컬 시간으로 변환
    DateTime parsedDate = DateTime.parse(json['measured_at'] as String);
    if (parsedDate.isUtc) {
      parsedDate = parsedDate.toLocal();
    }

    return PhysicalAgeHistoryRecord(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      measuredAt: parsedDate, // 로컬 시간 사용
      gradeIndex: (json['grade_index'] as num?)?.toInt() ?? 0,
      gradeLabel: json['grade_label'] as String? ?? '',
      percentile: (json['percentile'] as num?)?.toDouble() ?? 0.0,
      weakPoint: json['weak_point'] as String?,
      avgQuantile: json['avg_quantile'] == null
          ? null
          : (json['avg_quantile'] as num).toDouble(),
      loAgeValue: (json['lo_age_value'] as num?)?.toInt() ?? 0,
    );
  }

  // 그래프용 나이 값 반환 (DB에 숫자가 없으면 라벨 파싱)
  double get graphYValue {
    if (loAgeValue > 0) return loAgeValue.toDouble();
    return _parseAgeFromLabel(gradeLabel);
  }

  // 텍스트 라벨을 숫자로 변환하는 헬퍼 함수
  double _parseAgeFromLabel(String label) {
    if (label.contains("19세") || label.contains("이하")) return 18.0;
    if (label.contains("70대") || label.contains("이상")) return 72.0;

    // "30대 중반" -> 35
    // 숫자 부분 추출
    final RegExp regExp = RegExp(r'(\d+)대');
    final match = regExp.firstMatch(label);
    
    if (match != null) {
      int tens = int.parse(match.group(1)!);
      
      if (label.contains("초반")) return (tens + 2).toDouble();
      if (label.contains("중반")) return (tens + 5).toDouble();
      if (label.contains("후반")) return (tens + 8).toDouble();
      
      return tens.toDouble(); // 기본값
    }
    
    return 0.0; // 파싱 실패 시
  }
}

class PhysicalAgeApi {
  /// 신체나이 예측
  Future<PhysicalAgeResult> predictPhysicalAge({
    String? userId,                 
    required String sex,            
    required double sitUps,         
    required double flexibility,
    required double jumpPower,
    required double cardioEndurance,
  }) async {
    final uri = apiUri('/predict/physical-age');

    final body = jsonEncode({
      'user_id': userId,            
      'sex': sex,
      'sit_ups': sitUps,
      'flexibility': flexibility,
      'jump_power': jumpPower,
      'cardio_endurance': cardioEndurance,
    });

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('신체나이 API 실패: ${res.statusCode} / ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final Map<String, dynamic> data =
        decoded is List ? (decoded.first as Map<String, dynamic>)
                        : (decoded as Map<String, dynamic>);

    return PhysicalAgeResult.fromJson(data);
  }

  /// 신체나이 히스토리 조회
  Future<List<PhysicalAgeHistoryRecord>> fetchHistory(
    String userId, {
    int limit = 20,
  }) async {
    final uri = apiUri('/users/$userId/physical-age/history')
        .replace(queryParameters: {'limit': '$limit'});

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception(
          '신체나이 히스토리 API 실패: ${res.statusCode} / ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> recordsJson = decoded['records'] as List<dynamic>;

    return recordsJson
        .map((e) =>
            PhysicalAgeHistoryRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
