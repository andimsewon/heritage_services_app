import 'package:flutter/material.dart';

class ManagementItemsCard extends StatefulWidget {
  const ManagementItemsCard({super.key});

  @override
  State<ManagementItemsCard> createState() => _ManagementItemsCardState();
}

class _ManagementItemsCardState extends State<ManagementItemsCard> {
  final List<ManagementItem> _items = [
    ManagementItem(name: '방충·방부 처리', hasItem: false, count: ''),
    ManagementItem(name: '배수시설 정비', hasItem: false, count: ''),
    ManagementItem(name: '균열 보수', hasItem: false, count: ''),
    ManagementItem(name: '도장 작업', hasItem: false, count: ''),
    ManagementItem(name: '기타', hasItem: false, count: ''),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '관리사항',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 140,
                        child: Text(
                          '관리항목',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: Text(
                          '있음/없음',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '수량',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 항목들
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) _dividerLine(),
                  _buildItemRow(_items[i], i),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 반응형 저장 버튼
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Align(
                alignment: isMobile ? Alignment.center : Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ 관리사항이 저장되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('저장'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2A44),
                    minimumSize: isMobile
                        ? const Size(double.infinity, 44)
                        : const Size(120, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ManagementItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 관리항목명
          SizedBox(
            width: 140,
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 있음/없음 라디오 버튼
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: item.hasItem,
                  onChanged: (value) {
                    setState(() {
                      _items[index] = item.copyWith(hasItem: value);
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  activeColor: const Color(0xFF1E2A44),
                ),
                const Text('있음', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Radio<bool>(
                  value: false,
                  groupValue: item.hasItem,
                  onChanged: (value) {
                    setState(() {
                      _items[index] = item.copyWith(hasItem: value);
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  activeColor: const Color(0xFF1E2A44),
                ),
                const Text('없음', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 수량 입력
          Expanded(
            child: TextFormField(
              initialValue: item.count,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44), width: 1.2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _items[index] = item.copyWith(count: value);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine() {
    return Container(
      height: 1,
      color: const Color(0xFFE5E7EB),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class ManagementItem {
  final String name;
  final bool hasItem;
  final String count;

  ManagementItem({
    required this.name,
    required this.hasItem,
    required this.count,
  });

  ManagementItem copyWith({
    String? name,
    bool? hasItem,
    String? count,
  }) {
    return ManagementItem(
      name: name ?? this.name,
      hasItem: hasItem ?? this.hasItem,
      count: count ?? this.count,
    );
  }
}
