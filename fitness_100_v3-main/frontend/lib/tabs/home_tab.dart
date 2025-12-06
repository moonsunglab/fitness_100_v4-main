import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  final Function(int)? onTabChange;

  const HomeTab({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LoAge"), // [수정] 앱 이름 변경
        centerTitle: true,
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/logo.png', 
                height: 180, // [수정] 높이 증가
              ),
              const SizedBox(height: 60),

              _buildMenuButton(
                title: "이지팟",
                onPressed: () {
                  if (onTabChange != null) onTabChange!(1);
                },
              ),
              const SizedBox(height: 16),

              _buildMenuButton(
                title: "마이페이지",
                onPressed: () {
                  if (onTabChange != null) onTabChange!(2);
                },
              ),
              const SizedBox(height: 16),

              _buildMenuButton(
                title: "신체나이 또래배틀",
                onPressed: () {
                  if (onTabChange != null) onTabChange!(3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
