import 'package:flutter/material.dart';

import '../ui/widgets/yellow_nav_button.dart';
import 'asset_select_screen.dart';

class HomeScreen extends StatelessWidget {
  static const route = '/home';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 620;
                final menuCards = [
                  _HomeMenuCard(
                    icon: Icons.assignment_add,
                    title: '조사·등록 시스템',
                    description: '문화유산을 검색하고 조사·등록을 진행합니다.',
                    buttonLabel: '들어가기',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AssetSelectScreen(),
                        ),
                      );
                    },
                  ),
                  _HomeMenuCard(
                    icon: Icons.admin_panel_settings,
                    title: '관리 시스템',
                    description: '자산 관리 도구는 현재 준비 중입니다.',
                    buttonLabel: '(목업) 들어가기',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('관리 시스템은 추후 구현 예정입니다.'),
                        ),
                      );
                    },
                  ),
                ];

                if (isNarrow) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      menuCards.first,
                      const SizedBox(height: 16),
                      menuCards.last,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: menuCards.first),
                    const SizedBox(width: 20),
                    Expanded(child: menuCards.last),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _HomeMenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            YellowNavButton(label: buttonLabel, onTap: onPressed),
          ],
        ),
      ),
    );
  }
}
