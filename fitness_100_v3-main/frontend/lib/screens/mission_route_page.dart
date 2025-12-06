import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/facility.dart';
import '../config/api_config.dart';

class MissionRoutePage extends StatefulWidget {
  final Facility facility;
  final double startLat;
  final double startLon;
  final bool isFavorite;

  const MissionRoutePage({
    super.key,
    required this.facility,
    required this.startLat,
    required this.startLon,
    required this.isFavorite,
  });

  @override
  State<MissionRoutePage> createState() => _MissionRoutePageState();
}

// [수정] 애니메이션 관련 Mixin 제거
class _MissionRoutePageState extends State<MissionRoutePage> {
  NaverMapController? _mapController;
  bool _mapReady = false;

  String _step = 'not_started';
  bool _saving = false;

  late bool _isFavoriteCurrent;

  @override
  void initState() {
    super.initState();
    _isFavoriteCurrent = widget.isFavorite;
  }

  // [삭제] 애니메이션 관련 dispose 로직 제거

  Future<void> _logMission(String status) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      final uri = apiUri('/mission/complete');
      final body = jsonEncode({
        'user_id': user.id,
        'facility_id': widget.facility.id,
        'status': status,
        'is_favorite': _isFavoriteCurrent,
      });

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (resp.statusCode != 200) {
        throw Exception('status=${resp.statusCode}, body=${resp.body}');
      }

      if (mounted) {
        setState(() {
          if (status == 'started') _step = 'started';
          if (status == 'arrived') _step = 'arrived';
          if (status == 'completed') _step = 'completed';
        });
      }
    } catch (e) {
      debugPrint("미션 상태 저장 실패: $e");
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _addFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _isFavoriteCurrent) return;

    try {
      final uri = apiUri('/favorites/toggle');
      final body = jsonEncode({
        'user_id': user.id,
        'facility_id': widget.facility.id,
        'is_favorite': true,
      });

      await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
      _isFavoriteCurrent = true;
    } catch (e) {
      debugPrint("즐겨찾기 추가 실패: $e");
    }
  }

  Future<void> _showCompletionDialog() async {
    final bool? addToFavorites = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('미션 완료!'),
          content: const Text('운동을 완료하였습니다!\n이 장소를 즐겨찾기에 등록할까요?'),
          actions: <Widget>[
            TextButton(
              child: const Text('안하기'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('등록하기'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (addToFavorites == true) {
      await _addFavorite();
    }

    await _logMission('completed');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onMainButtonPressed() async {
    if (_saving) return;

    if (_step == 'not_started') {
      await _logMission('started');
    } else if (_step == 'started') {
      await _logMission('arrived');
    } else if (_step == 'arrived') {
      await _showCompletionDialog();
    }
  }

  Color _chipBg(String step) {
    if (_step == 'completed') return Colors.lightBlueAccent;
    if (step == 'started' && (_step == 'started' || _step == 'arrived')) return Colors.lightBlueAccent;
    if (step == 'arrived' && _step == 'arrived') return Colors.lightBlueAccent;
    if (step == 'completed' && _step == 'completed') return Colors.lightBlueAccent;
    return Colors.grey.shade300;
  }

  Color _chipText(String step) {
    return _chipBg(step) == Colors.lightBlueAccent ? Colors.white : Colors.black87;
  }

  Widget _stepChip(String step, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Chip(
          label: Center(child: Text(label)),
          backgroundColor: _chipBg(step),
          labelStyle: TextStyle(color: _chipText(step), fontSize: 13),
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }

  // [수정] 원래의 텍스트 안내 문구로 복원
  Widget _buildStatusMessage() {
    String message = '';
    if (_step == 'started') {
      message = '목표 시설로 이동하세요!';
    } else if (_step == 'arrived') {
      message = '자신에게 맞는 운동을 시작해주세요!';
    }

    if (message.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.facility;

    return Scaffold(
      appBar: AppBar(
        title: const Text('미션팟 안내'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 260,
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(target: NLatLng(f.lat, f.lon), zoom: 16),
                locationButtonEnable: false,
              ),
              onMapReady: (controller) async {
                _mapController = controller;
                _mapReady = true;

                final marker = NMarker(id: 'mission_facility_${f.id}', position: NLatLng(f.lat, f.lon));
                await controller.addOverlay(marker);
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(f.mission, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  if (f.categories.isNotEmpty)
                    Text(
                      '#${f.categories.join(' #')}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                  const Text('오늘 미션 진행 상태', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stepChip('started', '시작'),
                      _stepChip('arrived', '도착'),
                      _stepChip('completed', '완료'),
                    ],
                  ),
                  const Spacer(),
                  _buildStatusMessage(),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _onMainButtonPressed,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.lightBlueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _step == 'completed' ? '미션 완료됨' : _step == 'arrived' ? '미션 완료' : _step == 'started' ? '이지팟 도착' : '미션 시작',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
