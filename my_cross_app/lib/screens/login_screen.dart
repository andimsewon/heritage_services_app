// lib/screens/login_screen.dart (① 로그인 화면 - 임시 관리자 계정 포함)
//
// ✅ 임시 관리자 계정
//   ID  : admin@heritage.local
//   PW  : admin123!
// ⚠️ 주의: 데모/개발용. 배포 전 반드시 제거하거나 서버 인증으로 교체하세요.

import 'package:flutter/material.dart';
import '../ui/widgets/yellow_nav_button.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  static const route = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── 임시 관리자 자격 (필요하면 여기서 바꿔라)
  static const _devAdminId = 'admin@heritage.local';
  static const _devAdminPw = 'admin123!';

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _tryLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    // ── 임시 검증: 하드코드 관리자 자격만 통과
    final ok = _id.text.trim() == _devAdminId && _pw.text == _devAdminPw;

    await Future.delayed(const Duration(milliseconds: 250)); // UX용 살짝 딜레이

    setState(() => _loading = false);

    if (ok) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, HomeScreen.route);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 실패: ID 또는 PW를 확인하세요. (데모는 관리자 계정만 허용)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '국가유산 모니터링\n조사·등록 시스템',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _id,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'ID (이메일 형식 권장)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? 'ID를 입력하세요' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _pw,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'PW',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? '표시' : '숨김',
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                      (v == null || v.isEmpty) ? 'PW를 입력하세요' : null,
                    ),
                    const SizedBox(height: 16),
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : YellowNavButton(
                      label: '로그인',
                      onTap: _tryLogin,
                    ),
                    const SizedBox(height: 6),

                    // (선택) 데모 편의: 건너뛰기 버튼 — 필요 없으면 지워도 됨
                    TextButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        HomeScreen.route,
                      ),
                      icon: const Icon(Icons.door_front_door_outlined),
                      label: const Text('건너뛰고 둘러보기(데모)'),
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const Text(
                      '데모 계정: admin@heritage.local / admin123!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
