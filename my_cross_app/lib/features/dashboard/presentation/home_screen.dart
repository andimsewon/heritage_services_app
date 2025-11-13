import 'package:flutter/material.dart';
import 'package:my_cross_app/core/ui/widgets/ambient_background.dart';
import 'package:my_cross_app/core/ui/widgets/yellow_nav_button.dart';
import 'package:my_cross_app/features/heritage_list/presentation/asset_select_screen.dart';

class HomeScreen extends StatelessWidget {
  static const route = '/home';
  const HomeScreen({super.key});

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 기능은 곧 제공될 예정입니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('국가유산 모니터링'),
        actions: [
          IconButton(
            tooltip: '도움말',
            onPressed: () => _showComingSoon(context, '도움말 센터'),
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: '알림',
            onPressed: () => _showComingSoon(context, '알림함'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 900;
                final contentWidth = isCompact ? constraints.maxWidth : 1100.0;

                final cards = [
                  _HomeMenuCard(
                    icon: Icons.assignment_outlined,
                    title: '조사·등록 시스템',
                    description: '문화유산을 검색하고 조사·등록을 진행합니다.',
                    badge: '바로가기',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AssetSelectScreen(),
                        ),
                      );
                    },
                  ),
                  _HomeMenuCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: '관리 시스템',
                    description: '자산 관리 도구는 현재 준비 중입니다.',
                    badge: '준비 중',
                    disabled: true,
                    onPressed: () => _showComingSoon(context, '관리 시스템'),
                  ),
                ];


                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16 : 24,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroBanner(
                            theme: theme,
                            showComingSoon: () =>
                                _showComingSoon(context, '신규 조사 만들기'),
                          ),
                          const SizedBox(height: 28),
                          const _SectionHeader(
                            title: '시스템 모듈',
                            subtitle: '정식 배포된 서비스부터 차례대로 연결됩니다.',
                          ),
                          const SizedBox(height: 16),
                          if (isCompact)
                            Column(
                              children: [
                                for (int i = 0; i < cards.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 16),
                                  cards[i],
                                ],
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(width: 16),
                                Expanded(child: cards[1]),
                              ],
                            ),
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

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.theme, required this.showComingSoon});
  final ThemeData theme;
  final VoidCallback showComingSoon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F4E79), Color(0xFF2C6FB6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroPill(label: 'Smart Heritage Service'),
              _HeroPill(label: '정기 조사 2024'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '국가유산 조사·등록 허브',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '문화재 현황을 빠르게 검색하고 조사 결과를 체계적으로 정리합니다. 필드 데이터 업로드부터 보고서 발행까지 한 화면에서 진행하세요.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              const _HeroGlyph(),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroGlyph extends StatelessWidget {
  const _HeroGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: 160,
      child: Stack(
        children: const [
          _GlyphCircle(size: 160, opacity: 0.35),
          _GlyphCircle(size: 120, opacity: 0.55),
          _GlyphCircle(size: 80, opacity: 0.85),
          Positioned(
            right: 16,
            bottom: 16,
            child: Icon(Icons.travel_explore, color: Colors.white, size: 42),
          ),
        ],
      ),
    );
  }
}

class _GlyphCircle extends StatelessWidget {
  const _GlyphCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      ),
    );
  }
}

class _HomeMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final VoidCallback onPressed;
  final bool disabled;

  const _HomeMenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    required this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: disabled ? 0.72 : 1,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: colorScheme.primary, size: 26),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: disabled
                          ? const Color(0xFFFFF2E0)
                          : colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: disabled
                            ? const Color(0xFFB45309)
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              YellowNavButton(
                label: disabled ? '(목업) 들어가기' : '들어가기',
                onTap: onPressed,
                isDisabled: disabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
