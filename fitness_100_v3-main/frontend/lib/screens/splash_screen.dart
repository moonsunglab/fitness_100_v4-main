import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFBF8), // 로고 배경색과 유사하게
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _opacity,
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png', 
                    width: 250, // [수정] 너비 증가
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "로에이지로\n길에서 쉽게, 신체나이 낮추기",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text("시작하기"),
            ),
          ],
        ),
      ),
    );
  }
}
