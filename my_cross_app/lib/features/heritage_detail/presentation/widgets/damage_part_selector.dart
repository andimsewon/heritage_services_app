// lib/screens/damage_part_selector.dart
// 도면 기반 부재 선택 화면

import 'package:flutter/material.dart';

class DamagePartSelector extends StatefulWidget {
  const DamagePartSelector({super.key});

  @override
  State<DamagePartSelector> createState() => _DamagePartSelectorState();
}

class _DamagePartSelectorState extends State<DamagePartSelector> {
  // 부재 데이터 (실제로는 DB나 JSON에서 불러올 수 있음)
  final List<Map<String, dynamic>> parts = [
    {'id': 1, 'name': '기둥', 'x': 100.0, 'y': 450.0, 'direction': '남향'},
    {'id': 2, 'name': '기둥', 'x': 180.0, 'y': 450.0, 'direction': '남향'},
    {'id': 3, 'name': '기둥', 'x': 260.0, 'y': 450.0, 'direction': '남향'},
    {'id': 11, 'name': '기둥', 'x': 320.0, 'y': 250.0, 'direction': '서향'},
    {'id': 17, 'name': '기둥', 'x': 100.0, 'y': 80.0, 'direction': '북향'},
    {'id': 22, 'name': '기둥', 'x': 500.0, 'y': 80.0, 'direction': '북향'},
  ];

  Map<String, dynamic>? selectedPart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('손상부 조사 - 부재 선택'),
        backgroundColor: Colors.orange[700],
      ),
      body: Column(
        children: [
          // ───────────────── 도면 뷰어 ─────────────────
          Expanded(
            flex: 3,
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
                            height: 600,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.architecture, size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  '도면 이미지를 assets/plan_sample.png에 추가하세요',
                                  style: TextStyle(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
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
                              width: isSelected ? 40 : 30,
                              height: isSelected ? 40 : 30,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.orange[600] : Colors.blue[600],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSelected
                                        ? Colors.orange
                                        : Colors.blue).withOpacity(0.5),
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

          // ───────────────── 선택된 부재 정보 ─────────────────
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: selectedPart == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            '도면에서 부재를 선택하세요',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '선택된 부재',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('부재명', selectedPart!['name'] as String),
                          const SizedBox(height: 8),
                          _buildInfoRow('부재번호', '${selectedPart!['id']}'),
                          const SizedBox(height: 8),
                          _buildInfoRow('향', selectedPart!['direction'] as String),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => selectedPart = null);
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('취소'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context, selectedPart);
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('확인'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[700],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
