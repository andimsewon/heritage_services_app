// lib/screens/damage_map_preview_screen.dart (⑦)

import 'package:flutter/material.dart';
import 'package:my_cross_app/core/ui/widgets/ambient_background.dart';
import 'package:my_cross_app/core/ui/widgets/yellow_nav_button.dart';
import 'package:my_cross_app/features/dashboard/presentation/home_screen.dart';

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

  void _toggleLayer(String label, bool value) {
    setState(() => _layers[label] = value);
  }

  void _handleExport() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('지도 내보내기(목업)')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppBar(title: const Text('손상지도 미리보기')),
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                final layerPanel = _LayerControlPanel(
                  layers: _layers,
                  onToggle: _toggleLayer,
                  onExport: _handleExport,
                );
                const mapPanel = _MapPreviewPanel();

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 320, child: layerPanel),
                      const SizedBox(width: 20),
                      const Expanded(child: mapPanel),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    layerPanel,
                    const SizedBox(height: 16),
                    const AspectRatio(aspectRatio: 4 / 3, child: mapPanel),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
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

class _LayerControlPanel extends StatelessWidget {
  const _LayerControlPanel({
    required this.layers,
    required this.onToggle,
    required this.onExport,
  });

  final Map<String, bool> layers;
  final void Function(String layer, bool value) onToggle;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '레이어',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...layers.entries.map(
              (entry) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(entry.key),
                value: entry.value,
                onChanged: (value) => onToggle(entry.key, value ?? false),
              ),
            ),
            const Divider(height: 32),
            FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.save_alt),
              label: const Text('내보내기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreviewPanel extends StatelessWidget {
  const _MapPreviewPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F4E79), Color(0xFF2C6FB6)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map,
                size: 80,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 12),
              Text(
                '지도 미리보기(목업) - 차후 GoogleMap/Leaflet/WebGL 연동',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
