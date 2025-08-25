// lib/screens/damage_map_preview_screen.dart (⑦)

import 'package:flutter/material.dart';
import '../ui/widgets/yellow_nav_button.dart';
import 'home_screen.dart';

class DamageMapPreviewScreen extends StatefulWidget {
  static const route = '/damage-map-preview';
  const DamageMapPreviewScreen({super.key});

  @override
  State<DamageMapPreviewScreen> createState() => _DamageMapPreviewScreenState();
}

class _DamageMapPreviewScreenState extends State<DamageMapPreviewScreen> {
  final Map<String, bool> _layers = {
    '균열': true,
    '박락': false,
    '오염': true,
    '침수흔': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('손상지도 미리보기')),
      body: Row(
        children: [
          // 좌측: 레이어 체크리스트
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('레이어', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final e in _layers.entries)
                  CheckboxListTile(
                    value: e.value,
                    title: Text(e.key),
                    onChanged: (v) =>
                        setState(() => _layers[e.key] = v ?? false),
                  ),
                const Divider(),
                FilledButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('지도 내보내기(목업)')),
                  ),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('내보내기'),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 0),

          // 우측: 지도 영역(현재는 목업)
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, size: 80, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('지도 미리보기(목업) - 차후 GoogleMap/Leaflet/WebGL 연동'),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('손상 예측으로'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: YellowNavButton(
                label: '완료(홈으로)',
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  HomeScreen.route,
                      (route) => false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
