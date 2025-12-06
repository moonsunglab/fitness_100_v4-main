import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/battle_result_page.dart'; 

class PeerBattleTab extends StatefulWidget {
  const PeerBattleTab({super.key});

  @override
  State<PeerBattleTab> createState() => _PeerBattleTabState();
}

class _PeerBattleTabState extends State<PeerBattleTab> {
  String _myNickname = "나";
  int _myScore = 0;
  String _myLoAgeLabel = "";

  String _opponentNickname = "상대 찾는 중...";
  int _opponentScore = 0;
  bool _isOpponentFound = false;
  String _opponentLoAgeLabel = "";
  String _statusMessage = "상대를 찾는 중입니다...";
  int _opponentWins = 0;
  int _opponentLosses = 0;

  bool _isLoading = true;

  final List<String> _tierList = [
    "10대", "20대 초반", "20대 중반", "20대 후반", "30대 초반", "30대 중반",
    "30대 후반", "40대 초반", "40대 중반", "40대 후반", "50대 초반", "50대 중반",
    "50대 후반", "60대 초반", "60대 중반", "60대 후반", "70대 이상",
  ];

  @override
  void initState() {
    super.initState();
    _initializeBattle();
  }

  DateTime _getStartOfWeek() {
    final now = DateTime.now();
    final diff = now.weekday - 1;
    return DateTime(now.year, now.month, now.day - diff);
  }

  Future<int> _getWeeklyMissionCount(String userId) async {
    try {
      final startOfWeek = _getStartOfWeek();
      return await Supabase.instance.client
          .from('mission_logs')
          .count(CountOption.exact)
          .eq('user_id', userId)
          .gte('created_at', startOfWeek.toIso8601String());
    } catch (e) {
      return 0;
    }
  }

  Future<void> _getOpponentBattleRecord(String opponentId) async {
    try {
      final List<dynamic> battleRecords = await Supabase.instance.client
          .from('weekly_battles')
          .select('winner_user_id')
          .or('user_a_id.eq.$opponentId,user_b_id.eq.$opponentId');

      int wins = 0;
      int losses = 0;
      for (var record in battleRecords) {
        final winnerId = record['winner_user_id'];
        if (winnerId == opponentId || winnerId == null) {
          wins++;
        } else {
          losses++;
        }
      }
      setState(() {
        _opponentWins = wins;
        _opponentLosses = losses;
      });
    } catch (e) {
      //
    }
  }

  Future<void> _initializeBattle() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final myNick = user.userMetadata?['nickname'] ?? "나";
      String myLabel = "측정불가";

      final myData = await supabase
          .from('physical_age_assessments')
          .select('lo_age_tier_label')
          .eq('user_id', user.id)
          .order('measured_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (myData != null) {
        myLabel = (myData['lo_age_tier_label'] as String?) ?? "측정불가";
      }

      final myMissionCount = await _getWeeklyMissionCount(user.id);
      setState(() {
        _myNickname = myNick;
        _myLoAgeLabel = myLabel;
        _myScore = myMissionCount;
      });

      if (myLabel != "측정불가") {
        var opponentCandidates = await supabase
            .from('physical_age_assessments')
            .select('user_id, lo_age_tier_label')
            .neq('user_id', user.id)
            .eq('lo_age_tier_label', myLabel)
            .limit(50);

        if ((opponentCandidates as List).isEmpty) {
          final tierIndex = _tierList.indexOf(myLabel);
          if (tierIndex != -1) {
            List<String> adjacentTiers = [];
            if (tierIndex > 0) adjacentTiers.add(_tierList[tierIndex - 1]);
            if (tierIndex < _tierList.length - 1) adjacentTiers.add(_tierList[tierIndex + 1]);

            if (adjacentTiers.isNotEmpty) {
              final orCondition = adjacentTiers.map((t) => 'lo_age_tier_label.eq.$t').join(',');
              opponentCandidates = await supabase
                  .from('physical_age_assessments')
                  .select('user_id, lo_age_tier_label')
                  .neq('user_id', user.id)
                  .or(orCondition)
                  .limit(50);
            }
          }
        }

        if ((opponentCandidates as List).isEmpty) {
          opponentCandidates = await supabase
              .from('physical_age_assessments')
              .select('user_id, lo_age_tier_label')
              .neq('user_id', user.id)
              .limit(50);
        }

        if ((opponentCandidates as List).isNotEmpty) {
          final random = Random();
          final selectedOpponent = opponentCandidates[random.nextInt(opponentCandidates.length)];
          final String opId = selectedOpponent['user_id'];
          final String opLabel = selectedOpponent['lo_age_tier_label'] ?? "등급없음";

          final opMissionCount = await _getWeeklyMissionCount(opId);
          await _getOpponentBattleRecord(opId);

          final profileData = await supabase.from('profiles').select('nickname').eq('id', opId).maybeSingle();
          final opNick = profileData?['nickname'] ?? "라이벌";

          if (mounted) {
            setState(() {
              _opponentNickname = opNick;
              _opponentScore = opMissionCount;
              _opponentLoAgeLabel = opLabel;
              _isOpponentFound = true;
              _statusMessage = "매칭 성공!";
            });
          }
        } else {
           if (mounted) {
            final random = Random();
            setState(() {
              _opponentNickname = "훈련용 봇";
              _opponentLoAgeLabel = _myLoAgeLabel;
              _opponentScore = random.nextInt(10) + 5;
              _opponentWins = random.nextInt(20);
              _opponentLosses = random.nextInt(10);
              _isOpponentFound = true;
              _statusMessage = "훈련용 봇과 매칭되었습니다!";
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _opponentNickname = "정보 없음";
            _statusMessage = "먼저 신체나이를 측정해주세요.";
            _isOpponentFound = false;
          });
        }
      }
    } catch (e) {
      //
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

 @override
  Widget build(BuildContext context) {
    final double totalScore = (_myScore + _opponentScore).toDouble();
    final int winRate = totalScore == 0
        ? 50
        : ((_myScore / totalScore) * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text("신체나이 또래 배틀"),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              setState(() => _isLoading = true);
              _initializeBattle();
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "🎯 신체나이 [$_myLoAgeLabel] 매치",
                      style: const TextStyle(
                        color: Colors.lightBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildProfileAvatar(Colors.blue),
                            const SizedBox(height: 8),
                            Text(_myNickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            Text(_myLoAgeLabel, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: [
                            const Text("VS", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.redAccent)),
                            if (_isOpponentFound)
                              const Text("Rival Found!", style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _buildProfileAvatar(Colors.red),
                            const SizedBox(height: 8),
                            Text(_opponentNickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                            if (_isOpponentFound)
                              Text(_opponentLoAgeLabel, style: const TextStyle(color: Colors.grey, fontSize: 12))
                            else
                              Text(_statusMessage, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const Text("상대방 배틀 전적", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("$_opponentWins", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const Text(" 승 / ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("$_opponentLosses", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                            const Text(" 패", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text("주간 미션 성공 (회)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 20),
                  // [수정] 점수 표시 부분을 Expanded로 감싸서 중앙 정렬
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text("$_myScore", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const Text("My Missions", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          children: [
                            Text("$_opponentScore", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.red)),
                            const Text("Rival", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // [수정] '현재 승률 (점유율)' -> '현재 승률'로 변경
                  const Text("현재 승률", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("$winRate%", style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w900)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: winRate / 100,
                        minHeight: 15,
                        backgroundColor: Colors.red.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (totalScore == 0)
                    const Text("아직 양쪽 모두 미션 기록이 없습니다.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        final dummyBattleData = {
                          'id': '00000000-0000-0000-0000-000000000000',
                          'user_a_id': Supabase.instance.client.auth.currentUser?.id ?? 'me',
                          'user_b_id': 'opponent-id',
                          'user_a_missions': 5, 
                          'user_b_missions': 3,
                        };
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BattleResultPage(battleData: dummyBattleData)),
                        );
                      },
                      // [수정] [개발용] 텍스트 제거
                      child: const Text("결과 페이지 미리보기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileAvatar(MaterialColor color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(Icons.person, size: 50, color: color),
    );
  }
}
