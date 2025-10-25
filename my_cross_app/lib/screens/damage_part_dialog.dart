// lib/screens/damage_part_dialog.dart
// 손상부 조사 - 도면 기반 부재 선택 모달

import 'package:flutter/material.dart';

class DamagePartDialog extends StatefulWidget {
  const DamagePartDialog({super.key});

  @override
  State<DamagePartDialog> createState() => _DamagePartDialogState();
}

class _DamagePartDialogState extends State<DamagePartDialog> {
  // 22개 부재 데이터 (실제 도면 좌표 기준)
  // TODO: 실제 도면 이미지 업로드 후 좌표 조정 필요
  final List<Map<String, dynamic>> parts = [
    // 남쪽 기둥 (하단)
    {'id': 1, 'name': '기둥', 'x': 100.0, 'y': 450.0, 'direction': '남향', 'position': '좌측'},
    {'id': 2, 'name': '기둥', 'x': 180.0, 'y': 450.0, 'direction': '남향', 'position': '중앙좌'},
    {'id': 3, 'name': '기둥', 'x': 260.0, 'y': 450.0, 'direction': '남향', 'position': '중앙'},
    {'id': 4, 'name': '기둥', 'x': 340.0, 'y': 450.0, 'direction': '남향', 'position': '중앙우'},
    {'id': 5, 'name': '기둥', 'x': 420.0, 'y': 450.0, 'direction': '남향', 'position': '우측'},

    // 서쪽 기둥 (좌측)
    {'id': 6, 'name': '기둥', 'x': 100.0, 'y': 370.0, 'direction': '서향', 'position': '상단'},
    {'id': 7, 'name': '기둥', 'x': 100.0, 'y': 290.0, 'direction': '서향', 'position': '중앙'},
    {'id': 8, 'name': '기둥', 'x': 100.0, 'y': 210.0, 'direction': '서향', 'position': '하단'},

    // 중앙 부재
    {'id': 9, 'name': '보', 'x': 260.0, 'y': 300.0, 'direction': '중앙', 'position': '횡'},
    {'id': 10, 'name': '보', 'x': 260.0, 'y': 220.0, 'direction': '중앙', 'position': '종'},
    {'id': 11, 'name': '기둥', 'x': 320.0, 'y': 250.0, 'direction': '서향', 'position': '중앙'},

    // 동쪽 기둥 (우측)
    {'id': 12, 'name': '기둥', 'x': 500.0, 'y': 370.0, 'direction': '동향', 'position': '상단'},
    {'id': 13, 'name': '기둥', 'x': 500.0, 'y': 290.0, 'direction': '동향', 'position': '중앙'},
    {'id': 14, 'name': '기둥', 'x': 500.0, 'y': 210.0, 'direction': '동향', 'position': '하단'},

    // 북쪽 기둥 (상단)
    {'id': 15, 'name': '기둥', 'x': 100.0, 'y': 80.0, 'direction': '북향', 'position': '좌측'},
    {'id': 16, 'name': '기둥', 'x': 180.0, 'y': 80.0, 'direction': '북향', 'position': '중앙좌'},
    {'id': 17, 'name': '기둥', 'x': 260.0, 'y': 80.0, 'direction': '북향', 'position': '중앙'},
    {'id': 18, 'name': '기둥', 'x': 340.0, 'y': 80.0, 'direction': '북향', 'position': '중앙우'},
    {'id': 19, 'name': '기둥', 'x': 420.0, 'y': 80.0, 'direction': '북향', 'position': '우측'},

    // 지붕 부재
    {'id': 20, 'name': '추녀', 'x': 80.0, 'y': 50.0, 'direction': '북서', 'position': '좌측'},
    {'id': 21, 'name': '추녀', 'x': 520.0, 'y': 50.0, 'direction': '북동', 'position': '우측'},
    {'id': 22, 'name': '기둥', 'x': 500.0, 'y': 80.0, 'direction': '북향', 'position': '우측'},
  ];

  Map<String, dynamic>? selectedPart;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 800,
          maxHeight: 700,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xff003B7A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.architecture, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    '손상부 조사 - 부재 선택',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 도면 영역
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  boundaryMargin: const EdgeInsets.all(20),
                  child: Center(
                    child: Stack(
                      children: [
                        // 도면 이미지
                        Image.asset(
                          'assets/plan_sample.png',
                          errorBuilder: (context, error, stackTrace) {
                            // 이미지가 없을 경우 대체 UI
                            return Container(
                              width: 600,
                              height: 550,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.architecture,
                                      size: 80,
                                      color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    '도면 이미지를 assets/plan_sample.png에 추가하세요',
                                    style: TextStyle(color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '현재는 기본 좌표로 마커가 표시됩니다',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // 부재 마커
                        ...parts.map((part) {
                          final isSelected = selectedPart?['id'] == part['id'];
                          return Positioned(
                            left: part['x'] as double,
                            top: part['y'] as double,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedPart = part;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isSelected ? 40 : 32,
                                height: isSelected ? 40 : 32,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xff003B7A)
                                      : Colors.blue[400],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.5),
                                      blurRadius: isSelected ? 12 : 6,
                                      spreadRadius: isSelected ? 2 : 1,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${part['id']}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSelected ? 16 : 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 2),

            // 선택 정보 및 버튼
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedPart != null) ...[
                    const Text(
                      '선택된 부재',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('부재명', selectedPart!['name'] as String),
                          const SizedBox(height: 6),
                          _buildInfoRow('부재번호', '${selectedPart!['id']}번'),
                          const SizedBox(height: 6),
                          _buildInfoRow('향', selectedPart!['direction'] as String),
                          const SizedBox(height: 6),
                          _buildInfoRow('부재 내 위치', selectedPart!['position'] as String),
                        ],
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.touch_app,
                              size: 40,
                              color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            '도면에서 부재 번호를 선택하세요',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: selectedPart == null
                            ? null
                            : () => Navigator.pop(context, selectedPart),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('다음'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff003B7A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
