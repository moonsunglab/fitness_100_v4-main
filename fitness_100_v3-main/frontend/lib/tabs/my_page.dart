import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../screens/fitness_test_page.dart';
import '../screens/profile_edit_page.dart';
import '../screens/favorite_facilities_page.dart';
import '../services/physical_age_api.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String _nickname = "";
  String _physicalAgeText = "로딩 중...";

  double _sitUpScore = 0.1;
  double _flexScore = 0.1;
  double _jumpScore = 0.1;
  double _cardioScore = 0.1;

  int _sitUpCount = 0;
  int _flexCount = 0;
  int _jumpCount = 0;
  int _cardioCount = 0;

  int _winCount = 0;
  int _loseCount = 0;
  int _winRate = 0;

  List<PhysicalAgeHistoryRecord> _ageHistory = [];
  bool _isHistoryLoading = true;
  final _physicalAgeApi = PhysicalAgeApi();

  @override
  void initState() {
    super.initState();
    _loadMyData();
  }

  double _calculateMissionScore(int count) {
    const maxCount = 50;
    return (count / maxCount).clamp(0.1, 1.0);
  }

  Future<void> _loadMyData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _nickname = "로그인 필요";
          _physicalAgeText = "로그인 필요";
          _isHistoryLoading = false;
        });
      }
      return;
    }

    final nick = user.userMetadata?['nickname'] ?? "사용자";
    if (mounted) setState(() => _nickname = nick);

    try {
      final battleResponse = await Supabase.instance.client
          .from('weekly_battles')
          .select('winner_user_id')
          .or('user_a_id.eq.${user.id},user_b_id.eq.${user.id}');

      final missionCounts = await Supabase.instance.client
          .rpc('get_user_mission_counts', params: {'p_user_id': user.id});

      final historyRecords = await _physicalAgeApi.fetchHistory(user.id);

      int sitUpCount = 0;
      int flexCount = 0;
      int jumpCount = 0;
      int cardioCount = 0;

      for (var item in missionCounts) {
        final category = item['category'] as String?;
        final count = item['mission_count'] as int? ?? 0;
        if (category == '근지구력') sitUpCount = count;
        if (category == '유연성') flexCount = count;
        if (category == '순발력') jumpCount = count;
        if (category == '심폐지구력') cardioCount = count;
      }

      int wins = 0;
      int losses = 0;
      for (var battle in battleResponse) {
        final winnerId = battle['winner_user_id'];
        if (winnerId == user.id || winnerId == null) {
          wins++;
        } else {
          losses++;
        }
      }
      int totalBattles = wins + losses;
      int calculatedWinRate = totalBattles > 0
          ? ((wins / totalBattles) * 100).round()
          : 0;

      String newAgeText = "측정 기록 없음";
      if (historyRecords.isNotEmpty) {
        historyRecords.sort((a, b) => b.measuredAt.compareTo(a.measuredAt)); 
        newAgeText = historyRecords.last.gradeLabel; 
      }
      
      final sortedHistory = List<PhysicalAgeHistoryRecord>.from(historyRecords);
      sortedHistory.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

      if (mounted) {
        setState(() {
          _physicalAgeText = newAgeText;
          _ageHistory = sortedHistory; 

          _sitUpScore = _calculateMissionScore(sitUpCount);
          _flexScore = _calculateMissionScore(flexCount);
          _jumpScore = _calculateMissionScore(jumpCount);
          _cardioScore = _calculateMissionScore(cardioCount);
          
          _sitUpCount = sitUpCount;
          _flexCount = flexCount;
          _jumpCount = jumpCount;
          _cardioCount = cardioCount;
          
          _winCount = wins;
          _loseCount = losses;
          _winRate = calculatedWinRate;
          
          _isHistoryLoading = false;
        });
      }

    } catch (e) {
      debugPrint("데이터 로딩 에러 발생: $e");
      if (mounted) {
        setState(() {
          _physicalAgeText = "기록 불러오기 실패";
          _isHistoryLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("로그아웃 실패")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int total = _winCount + _loseCount;
    int winFlex = total == 0 ? 1 : _winCount;
    int loseFlex = total == 0 ? 1 : _loseCount;
    bool hasNoBattle = total == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("마이페이지"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadMyData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _nickname.isEmpty ? "..." : _nickname,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(
                      Icons.person,
                      size: 36,
                      color: Colors.lightBlue,
                    ),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileEditPage(),
                        ),
                      );
                      if (result == true) _loadMyData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "신체나이: $_physicalAgeText",
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FavoriteFacilitiesPage()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "마이 이지팟",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "미션 그래프",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBar("근지구력", _sitUpScore, _sitUpCount, Colors.lightBlueAccent),
                  _buildBar("유연성", _flexScore, _flexCount, Colors.lightBlueAccent),
                  _buildBar("순발력", _jumpScore, _jumpCount, Colors.lightBlueAccent),
                  _buildBar("심폐지구력", _cardioScore, _cardioCount, Colors.lightBlueAccent),
                ],
              ),
              const SizedBox(height: 40),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "신체나이 동갑 배틀",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: winFlex,
                            child: Container(
                              decoration: BoxDecoration(
                                color: hasNoBattle
                                    ? Colors.grey[300]
                                    : Colors.lightBlueAccent,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "승 $_winCount",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: loseFlex,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "패 $_loseCount",
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "승률 $_winRate%",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "신체나이 변화 추이",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 15),
              _buildAgeHistoryTable(),
              const SizedBox(height: 40),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FitnessTestPage(),
                          ),
                        );
                        _loadMyData();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        "신체나이 재측정",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "※ 미션 30개 수행 시 활성화",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.grey),
                label: const Text(
                  "로그아웃",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(String label, double pct, int count, Color color) {
    return Column(
      children: [
        Text(
          "$count",
          style: const TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 100 * pct,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // [수정] 백분위 열 제거하고 2열 테이블로 변경
  Widget _buildAgeHistoryTable() {
    if (_isHistoryLoading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ageHistory.isEmpty) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(child: Text("측정 기록이 없습니다.")),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DataTable(
        headingRowHeight: 40,
        dataRowHeight: 50,
        columnSpacing: 40, // 간격 조정
        columns: const [
          DataColumn(label: Expanded(child: Center(child: Text('측정 일자', style: TextStyle(fontWeight: FontWeight.bold))))),
          DataColumn(label: Expanded(child: Center(child: Text('신체나이', style: TextStyle(fontWeight: FontWeight.bold))))),
        ],
        rows: _ageHistory.map((record) {
          return DataRow(cells: [
            DataCell(Center(child: Text(DateFormat('yyyy-MM-dd').format(record.measuredAt)))),
            DataCell(Center(child: Text(record.gradeLabel))), 
          ]);
        }).toList(),
      ),
    );
  }
}
