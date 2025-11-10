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

  Future<void> _tryLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final ok = _id.text.trim() == _devAdminId && _pw.text == _devAdminPw;

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pushReplacementNamed(context, HomeScreen.route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 실패: ID 또는 PW를 확인하세요. (데모는 관리자 계정만 허용)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFF), Color(0xFFEFF3FB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            child: AutofillGroup(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '국가유산 모니터링',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '조사·등록 시스템에 접속해 현황을 작성하고 관리할 수 있습니다.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _FieldLabel('ID (이메일 형식 권장)', theme: theme),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _id,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                      AutofillHints.email,
                                    ],
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? 'ID를 입력하세요' : null,
                                  ),
                                  const SizedBox(height: 18),
                                  _FieldLabel('PW', theme: theme),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _pw,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [AutofillHints.password],
                                    onFieldSubmitted: (_) => _tryLogin(),
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? 'PW를 입력하세요' : null,
                                    decoration: InputDecoration(
                                      suffixIcon: IconButton(
                                        tooltip: _obscure ? '표시' : '숨기기',
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _loading
                                        ? const Center(
                                            child: SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: CircularProgressIndicator(),
                                            ),
                                          )
                                        : YellowNavButton(
                                            key: const ValueKey('loginButton'),
                                            label: '로그인',
                                            onTap: _tryLogin,
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () => Navigator.pushReplacementNamed(
                                      context,
                                      HomeScreen.route,
                                    ),
                                    icon: const Icon(Icons.door_front_door_outlined),
                                    label: const Text('건너뛰고 둘러보기 (데모)'),
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6FB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '데모 계정',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        SelectableText(
                                          'ID  admin@heritage.local\nPW  admin123!',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {required this.theme});
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
