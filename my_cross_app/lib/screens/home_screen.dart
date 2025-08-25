// lib/screens/home_screen.dart (② 홈 화면 - ③로 확실히 이동하도록 수정)

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
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // ── 조사·등록 시스템 카드
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.assignment_add, size: 48),
                          const SizedBox(height: 10),
                          const Text(
                            '조사·등록 시스템',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          YellowNavButton(
                            label: '들어가기',
                            onTap: () {
                              // ✅ 라우트 테이블 문제를 우회: 직접 push로 ③ 화면 호출
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AssetSelectScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // ── 관리 시스템 카드(목업)
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.admin_panel_settings, size: 48),
                          const SizedBox(height: 10),
                          const Text(
                            '관리 시스템',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          YellowNavButton(
                            label: '(목업) 들어가기',
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('관리 시스템은 추후 구현')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
