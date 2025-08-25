// lib/screens/detail_survey_screen.dart (⑤ 상세조사 화면)
// - 기록개요 섹션
// - 보존이력 테이블 (+추가 다이얼로그)
// - 첨부(사진/메타/음성) 목업 타일
// - 손상요소 목록 (+신규 등록 다이얼로그)
// - 다음 단계로: 손상 예측/모델 화면으로 이동

import 'package:flutter/material.dart';
import '../ui/widgets/section.dart';
import '../ui/widgets/attach_tile.dart';
import '../ui/widgets/yellow_nav_button.dart';
import 'damage_model_screen.dart';

class DetailSurveyScreen extends StatefulWidget {
  static const route = '/detail-survey';
  const DetailSurveyScreen({super.key});

  @override
  State<DetailSurveyScreen> createState() => _DetailSurveyScreenState();
}

class _DetailSurveyScreenState extends State<DetailSurveyScreen> {
  // ─────────────────────────────────────────────────────────────
  // 기록개요 필드 (간단 텍스트 입력 위젯들)
  // ─────────────────────────────────────────────────────────────
  final _section = TextEditingController(); // 구/부/세부명
  final _period  = TextEditingController(); // 시정/지정일(예시)
  final _writer  = TextEditingController(); // 작성인
  final _note    = TextEditingController(); // 메모/비고

  // 보존이력 (간단 테이블 목업 데이터)
  final List<Map<String, String>> _history = [
    {'date': '2021-05-01', 'desc': '부분 보수(지붕 기와)'},
  ];

  // 손상요소 (목업 리스트 데이터)
  final List<Map<String, dynamic>> _damages = [
    {'type': '균열', 'severity': '중', 'memo': '북측 벽체 수평균열'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상세 조사')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                // ─────────────────────────────────────────────────────────
                // (1) 기록개요 섹션: 간단한 텍스트 필드들을 2열 Grid로 배치
                // ─────────────────────────────────────────────────────────
                Section(
                  title: '기록개요',
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    childAspectRatio: 3.5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      TextField(
                        controller: _section,
                        decoration: const InputDecoration(labelText: '구/부/세부명'),
                      ),
                      TextField(
                        controller: _period,
                        decoration: const InputDecoration(labelText: '시정/지정일(예시)'),
                      ),
                      TextField(
                        controller: _writer,
                        decoration: const InputDecoration(labelText: '작성인'),
                      ),
                      TextField(
                        controller: _note,
                        decoration: const InputDecoration(labelText: '메모/비고'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ─────────────────────────────────────────────────────────
                // (2) 보존이력: 간단 DataTable + "추가" 다이얼로그
                // ─────────────────────────────────────────────────────────
                Section(
                  title: '보존이력',
                  action: OutlinedButton.icon(
                    onPressed: () async {
                      final item = await _showAddHistoryDialog(context);
                      if (item != null) setState(() => _history.add(item));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('추가'),
                  ),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('일자')),
                      DataColumn(label: Text('내용')),
                    ],
                    rows: _history
                        .map((h) => DataRow(
                      cells: [
                        DataCell(Text(h['date']!)),
                        DataCell(Text(h['desc']!)),
                      ],
                    ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // ─────────────────────────────────────────────────────────
                // (3) 첨부: 사진/메타/음성 (현재는 목업 타일)
                // ─────────────────────────────────────────────────────────
                Section(
                  title: '첨부',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      AttachTile(icon: Icons.photo_camera, label: '사진촬영(목업)'),
                      AttachTile(icon: Icons.image_outlined, label: '사진선택'),
                      AttachTile(icon: Icons.info_outline, label: '메타데이터'),
                      AttachTile(icon: Icons.mic_none, label: '음성기록'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ─────────────────────────────────────────────────────────
                // (4) 손상요소: 카드 목록 + 신규 등록(간이 다이얼로그)
                // ─────────────────────────────────────────────────────────
                Section(
                  title: '손상요소',
                  action: FilledButton.icon(
                    onPressed: () async {
                      final item = await _showAddDamageDialog(context);
                      if (item != null) setState(() => _damages.add(item));
                    },
                    icon: const Icon(Icons.add_alert),
                    label: const Text('신규 등록'),
                  ),
                  child: Column(
                    children: [
                      for (final d in _damages)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.report_problem_outlined),
                            title: Text('${d['type']} · 심각도 ${d['severity']}'),
                            subtitle: Text('${d['memo']}'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─────────────────────────────────────────────────────────
                // 이전/다음 네비게이션
                // ─────────────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('기본정보로'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: YellowNavButton(
                        label: '다음(손상 예측/모델)',
                        onTap: () =>
                            Navigator.pushNamed(context, DamageModelScreen.route),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 보존이력 추가 다이얼로그
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, String>?> _showAddHistoryDialog(BuildContext context) async {
    final date = TextEditingController();
    final desc = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('보존이력 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: date,
              decoration:
              const InputDecoration(labelText: '일자 (YYYY-MM-DD)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: '내용'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, {'date': date.text, 'desc': desc.text}),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 손상요소 신규 등록 다이얼로그(간이 버전)
  //  ※ 향후: 위저드 화면으로 승격 예정 (유형/세부/심각도/위치/원인/권고/증빙 등)
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, String>?> _showAddDamageDialog(BuildContext context) async {
    final type = TextEditingController();
    final severity = ValueNotifier<String>('중');
    final memo = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('손상요소 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: type,
              decoration: const InputDecoration(
                labelText: '손상유형(예: 균열/박락/오염)',
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: severity,
              builder: (context, value, _) => DropdownButtonFormField<String>(
                value: value,
                decoration: const InputDecoration(labelText: '심각도'),
                items: const [
                  DropdownMenuItem(value: '경', child: Text('경')),
                  DropdownMenuItem(value: '중', child: Text('중')),
                  DropdownMenuItem(value: '심', child: Text('심')),
                ],
                onChanged: (v) => severity.value = v!,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: memo,
              decoration: const InputDecoration(labelText: '메모'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'type': type.text,
              'severity': severity.value,
              'memo': memo.text,
            }),
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }
}
