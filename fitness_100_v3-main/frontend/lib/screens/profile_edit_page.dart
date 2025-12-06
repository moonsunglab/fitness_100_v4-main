import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentInfo();
  }

  void _loadCurrentInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _nicknameController.text = user.userMetadata?['nickname'] ?? "";
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);

    try {
      final newPassword = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      // [수정] 비밀번호 필드 유효성 검사 강화
      if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
        if (newPassword.isEmpty || confirmPassword.isEmpty) {
          throw const AuthException('두 비밀번호 필드를 모두 입력해주세요.');
        }
        if (newPassword != confirmPassword) {
          throw const AuthException('비밀번호가 일치하지 않습니다.');
        }
        if (newPassword.length < 6) {
          throw const AuthException('비밀번호는 6자 이상이어야 합니다.');
        }
      }

      final supabase = Supabase.instance.client;
      final UserAttributes attributes = UserAttributes(
        data: {'nickname': _nicknameController.text.trim()},
        password: newPassword.isNotEmpty ? newPassword : null,
      );

      await supabase.auth.updateUser(attributes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("프로필이 성공적으로 수정되었습니다!")),
        );
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("오류가 발생했습니다."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("프로필 수정"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: "닉네임",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "새 비밀번호 (변경시에만 입력)",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
                helperText: "비밀번호는 6자리 이상 입력해주세요.",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "비밀번호 확인",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF5F5F5),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "저장하기",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
