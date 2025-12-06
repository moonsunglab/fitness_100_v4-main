import 'package:flutter/material.dart';

class JumpPowerTestPage extends StatefulWidget {
  const JumpPowerTestPage({super.key});

  @override
  State<JumpPowerTestPage> createState() => _JumpPowerTestPageState();
}

class _JumpPowerTestPageState extends State<JumpPowerTestPage> {
  final TextEditingController _recordController = TextEditingController();

  @override
  void dispose() {
    _recordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("제자리 높이뛰기 (순발력)"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // [삭제] 아이콘 삭제
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: const [
                  Text(
                    "제자리 점프 높이를 측정합니다.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "※ 측정 방법\n\n1. 벽 옆에 서서 한 팔을 최대한 뻗어\n손끝 위치를 표시합니다.\n\n2. 제자리에서 최대한 점프하며\n손끝으로 벽에 다시 표시합니다.\n\n3. 두 점의 차이(cm)를 측정하여 입력하세요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            const Text(
              "측정 결과 (cm)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _recordController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "0.0",
                suffixText: "cm",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                if (_recordController.text.isEmpty) return;
                double? result = double.tryParse(_recordController.text);
                if (result != null) {
                  Navigator.pop(context, result);
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: Colors.lightBlueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "기록 저장하기",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
