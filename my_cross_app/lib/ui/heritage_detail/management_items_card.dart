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
          // 있음/없음 선택
          SizedBox(
            width: 160,
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _items[index] = item.copyWith(hasItem: true);
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.hasItem == true
                                ? const Color(0xFF1E2A44)
                                : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                          color: item.hasItem == true
                              ? const Color(0xFF1E2A44)
                              : Colors.white,
                        ),
                        child: item.hasItem == true
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '있음',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _items[index] = item.copyWith(hasItem: false);
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.hasItem == false
                                ? const Color(0xFF1E2A44)
                                : const Color(0xFFD1D5DB),
                            width: 2,
                          ),
                          color: item.hasItem == false
                              ? const Color(0xFF1E2A44)
                              : Colors.white,
                        ),
                        child: item.hasItem == false
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '없음',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
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
