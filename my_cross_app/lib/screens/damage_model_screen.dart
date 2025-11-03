// lib/screens/damage_model_screen.dart (⑥ 손상 예측 / 적용모델 / 작동관리 방안)
// - FilterChip 에러 수정: onSelected 콜백 추가, const 제거
// - 선택 상태를 State로 보관(_rule/_tflite/_llm)

import 'package:flutter/material.dart';
import '../ui/widgets/section.dart';
import '../ui/widgets/yellow_nav_button.dart';
import '../widgets/responsive_page.dart';
import 'damage_map_preview_screen.dart';

class DamageModelScreen extends StatefulWidget {
  static const route = '/damage-model';
  const DamageModelScreen({super.key});

  @override
  State<DamageModelScreen> createState() => _DamageModelScreenState();
}

class _DamageModelScreenState extends State<DamageModelScreen> {
  // 예측 등급
  String _pred = 'A';

  // 적용모델 선택 상태(다중 선택 허용)
  bool _rule = true;
  bool _tflite = false;
  bool _llm = false;

  // 작동관리 방안 입력
  final _management = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('손상 예측 / 적용모델 / 작동관리 방안')),
      body: ResponsivePage(
        maxWidth: 900.0,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                // ────────────────────────────────────────────────
                // (1) 손상 예측: 예상 손상등급 (A~F 선택)
                // ────────────────────────────────────────────────
                Section(
                  title: '손상 예측',
                  child: Row(
                    children: [
                      const Text('예상 손상등급:'),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _pred,
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('A')),
                          DropdownMenuItem(value: 'B', child: Text('B')),
                          DropdownMenuItem(value: 'C', child: Text('C')),
                          DropdownMenuItem(value: 'D', child: Text('D')),
                          DropdownMenuItem(value: 'E', child: Text('E')),
                          DropdownMenuItem(value: 'F', child: Text('F')),
                        ],
                        onChanged: (v) => setState(() => _pred = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ────────────────────────────────────────────────
                // (2) 적용모델: FilterChip (다중선택)
                //   - const 제거 + onSelected 콜백 필수
                // ────────────────────────────────────────────────
                Section(
                  title: '적용모델',
                  child: Wrap(
                    spacing: 12,
                    children: [
                      FilterChip(
                        label: const Text('규칙기반'),
                        selected: _rule,
                        onSelected: (v) => setState(() => _rule = v),
                      ),
                      FilterChip(
                        label: const Text('이미지분류(TFLite)'),
                        selected: _tflite,
                        onSelected: (v) => setState(() => _tflite = v),
                      ),
                      FilterChip(
                        label: const Text('LLM 요약/권고'),
                        selected: _llm,
                        onSelected: (v) => setState(() => _llm = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ────────────────────────────────────────────────
                // (3) 작동관리 방안 입력
                // ────────────────────────────────────────────────
                Section(
                  title: '작동관리 방안',
                  child: TextField(
                    controller: _management,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: '예: 7일 내 정밀점검, 차수막 임시 보강 등',
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ────────────────────────────────────────────────
                // (4) 이전 / 다음 네비게이션
                // ────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('상세조사로'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: YellowNavButton(
                        label: '다음(손상지도 미리보기)',
                        onTap: () => Navigator.pushNamed(
                          context,
                          DamageMapPreviewScreen.route,
                        ),
                      ),
                    ),
                  ],
                )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _management.dispose();
    super.dispose();
  }
}
