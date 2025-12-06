// lib/screens/fitness_test_page.dart
import 'package:flutter/material.dart';
import '../services/physical_age_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sit_up_test_page.dart';
import 'sit_and_reach_test_page.dart';
import 'jump_power_test_page.dart';
import 'cardio_endurance_test_page.dart';

class FitnessTestPage extends StatefulWidget {
  const FitnessTestPage({super.key});

  @override
  State<FitnessTestPage> createState() => _FitnessTestPageState();
}

class _FitnessTestPageState extends State<FitnessTestPage> {
  double? _sitUpRecord;
  double? _flexibilityRecord;
  double? _jumpRecord;
  double? _heartRateRecord;

  bool _loading = false;
  String? _gradeLabel;
  double? _percentile;
  String? _weakPoint;
  
  final _physicalAgeApi = PhysicalAgeApi();

  final Map<String, dynamic> _testItems = {
    'sit_ups': {
      'name': '윗몸 일으키기 (근지구력)',
      'page': const SitUpTestPage(),
      'unit': '회',
    },
    'flexibility': {
      'name': '앉아서 허리 굽히기 (유연성)',
      'page': const SitAndReachTestPage(),
      'unit': 'cm',
    },
    'jump_power': {
      'name': '제자리 높이뛰기 (순발력)',
      'page': const JumpPowerTestPage(),
      'unit': 'cm',
    },
    'cardio_endurance': {
      'name': '회복 심박수 (심폐지구력)',
      'page': const CardioEnduranceTestPage(),
      'unit': '회/분',
    },
  };

  Future<void> _navigateToTestPage(String key, Widget page) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );

    if (result is int || result is double) {
      final double record = (result as num).toDouble();
      setState(() {
        switch (key) {
          case 'sit_ups':
            _sitUpRecord = record;
            break;
          case 'flexibility':
            _flexibilityRecord = record;
            break;
          case 'jump_power':
            _jumpRecord = record;
            break;
          case 'cardio_endurance':
            _heartRateRecord = record;
            break;
        }
      });
      if (_sitUpRecord != null &&
          _flexibilityRecord != null &&
          _jumpRecord != null &&
          _heartRateRecord != null) {
        _saveData();
      }
    }
  }

  Future<void> _saveData() async {
    if (_sitUpRecord == null ||
        _flexibilityRecord == null ||
        _jumpRecord == null ||
        _heartRateRecord == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("모든 항목을 입력해주세요.")));
      return;
    }

    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다.")),
      );
      setState(() => _loading = false);
      return;
    }

    try {
      String sex = 'Male'; 
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('sex') 
            .eq('id', user.id)
            .maybeSingle();
        
        if (profile != null && profile['sex'] != null) {
          sex = profile['sex'];
        }
      } catch (e) {
        debugPrint("성별 조회 실패, 기본값 사용: $e");
      }

      final result = await _physicalAgeApi.predictPhysicalAge(
        userId: user.id,
        sex: sex,
        sitUps: _sitUpRecord!,
        flexibility: _flexibilityRecord!,
        jumpPower: _jumpRecord!,
        cardioEndurance: _heartRateRecord!,
      );

      setState(() {
        _gradeLabel = result.gradeLabel;
        _percentile = result.percentile;
        _weakPoint = result.weakPoint;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("측정 결과가 저장되었습니다.")),
        );
      }

    } catch (e) {
      debugPrint("측정 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("측정 실패: $e")), 
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _getCurrentRecord(String key) {
    switch (key) {
      case 'sit_ups':
        return _sitUpRecord;
      case 'flexibility':
        return _flexibilityRecord;
      case 'jump_power':
        return _jumpRecord;
      case 'cardio_endurance':
        return _heartRateRecord;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("신체나이 측정"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "측정 항목 (4가지)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._testItems.entries.map((entry) {
              final key = entry.key;
              final data = entry.value;
              final record = _getCurrentRecord(key);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(data['name'] as String),
                  subtitle: Text(
                    record != null
                        ? '기록 완료: ${record.toStringAsFixed(record == record.toInt() ? 0 : 1)}${data['unit']}'
                        : '측정 필요',
                    style: TextStyle(
                      color: record != null ? Colors.lightBlueAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _navigateToTestPage(key, data['page']),
                ),
              );
            }).toList(),
            const SizedBox(height: 30),

            // 결과 표시 영역
            if (_gradeLabel != null)
              Column(
                children: [
                  const Divider(),
                  const Text(
                    "측정 결과",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "나의 신체등급: $_gradeLabel",
                    style: const TextStyle(fontSize: 18, color: Colors.lightBlueAccent),
                  ),
                  // [수정] 백분위 점수 제거
                  // Text(
                  //   "백분위 점수: ${_percentile!.toStringAsFixed(1)}%",
                  //   style: const TextStyle(fontSize: 16, color: Colors.black87),
                  // ),
                  if (_weakPoint != null)
                    Text(
                      "취약영역: $_weakPoint",
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  const SizedBox(height: 20),
                ],
              ),

            const SizedBox(height: 20),
            
            // [수정] 버튼 색상 및 텍스트 변경
            if (_gradeLabel != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 마이페이지로 돌아가기
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.lightBlueAccent, // [수정] 녹색 -> 하늘색
                  foregroundColor: Colors.white,
                ),
                child: const Text("마이페이지로 돌아가기"),
              )
            else
              ElevatedButton(
                onPressed:
                    _loading ||
                        _sitUpRecord == null ||
                        _flexibilityRecord == null ||
                        _jumpRecord == null ||
                        _heartRateRecord == null
                    ? null
                    : _saveData,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.lightBlueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : const Text("신체나이 측정하고 기록 저장하기"),
              ),
          ],
        ),
      ),
    );
  }
}
