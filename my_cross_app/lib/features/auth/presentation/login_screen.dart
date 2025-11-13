// lib/screens/login_screen.dart (① 로그인 화면 - 임시 관리자 계정 포함)
//
// ✅ 임시 관리자 계정
//   ID  : admin@heritage.local
//   PW  : admin123!
// ⚠️ 주의: 데모/개발용. 배포 전 반드시 제거하거나 서버 인증으로 교체하세요.

import 'package:flutter/material.dart';
import 'package:my_cross_app/core/ui/widgets/ambient_background.dart';
import 'package:my_cross_app/core/ui/widgets/yellow_nav_button.dart';
import 'package:my_cross_app/features/dashboard/presentation/home_screen.dart';

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
    final goDemo = () =>
        Navigator.pushReplacementNamed(context, HomeScreen.route);

    Widget buildFormCard() {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.public,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '국가유산 모니터링',
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              '정기 조사·등록 포털',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'BETA',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.key_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '데모 계정만 로그인 가능합니다.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
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
                    onPressed: goDemo,
                    icon: const Icon(Icons.door_front_door_outlined),
                    label: const Text('건너뛰고 둘러보기 (데모)'),
                  ),
                  const SizedBox(height: 24),
                  _LoginSupportList(theme: theme),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('데모 계정', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        SelectableText(
                          'ID  admin@heritage.local\nPW  admin123!',
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
      );
    }

    final heroPanel = _LoginHeroPanel(onPlayDemo: goDemo);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                final padding = EdgeInsets.symmetric(
                  horizontal: isWide ? 48 : 20,
                  vertical: 28,
                );

                return SingleChildScrollView(
                  padding: padding,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 1100 : 520,
                        minHeight: constraints.maxHeight - 56,
                      ),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: heroPanel),
                                const SizedBox(width: 32),
                                Flexible(child: buildFormCard()),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                buildFormCard(),
                                const SizedBox(height: 24),
                                heroPanel,
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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

class _LoginHeroPanel extends StatelessWidget {
  const _LoginHeroPanel({required this.onPlayDemo});
  final VoidCallback onPlayDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const highlights = [
      ('현장 업로드', '모바일에서 촬영한 사진·계측파일 즉시 업로드'),
      ('정기 조사 캘린더', '권역별 일정이 자동으로 동기화됩니다'),
      ('AI 요약', '조사 보고서 초안을 자동으로 제안'),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F4E79), Color(0xFF2C6FB6)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Smart Heritage Suite',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '데모 플레이',
                onPressed: onPlayDemo,
                icon: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '조사·등록,\n한 번에 정리하세요',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '국가유산 조사노트, 사진, 손상 지도까지 현장에서 기록하고\n검토팀과 실시간 공유하세요.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 24),
          ...highlights.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HeroHighlight(label: item.$1, description: item.$2),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHighlight extends StatelessWidget {
  const _HeroHighlight({required this.label, required this.description});
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF8FF7FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginSupportList extends StatelessWidget {
  const _LoginSupportList({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.lock_reset_outlined, '비밀번호 초기화', '계정 담당자에게 연락하여 초기화 요청'),
      (
        Icons.support_agent_outlined,
        '지원 채널',
        'heritage-support@mcst.go.kr 로 문의',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('지원 안내', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.$1, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.$3,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
