import 'package:flutter/material.dart';

class YearHistoryItem {
  const YearHistoryItem({
    required this.year,
    required this.hasData,
    this.updatedAt,
    this.isCurrentYear = false,
  });

  final String year;
  final bool hasData;
  final DateTime? updatedAt;
  final bool isCurrentYear;

  String get formattedTimestamp {
    if (updatedAt == null) return '기록 없음';
    final dt = updatedAt!.toLocal();
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd $hh:$min';
  }
}

class YearHistorySheet extends StatelessWidget {
  const YearHistorySheet({
    super.key,
    required this.items,
    required this.activeYear,
  });

  final List<YearHistoryItem> items;
  final String activeYear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '기존 이력',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  '연도를 선택하면 해당 조사 내용을 읽기 전용으로 확인합니다.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isActive = item.year == activeYear;
                final badge = item.isCurrentYear ? ' (현재)' : '';
                return ListTile(
                  leading: Icon(
                    item.hasData
                        ? Icons.history
                        : Icons.history_toggle_off,
                    color: item.hasData ? const Color(0xFF2563EB) : Colors.grey,
                  ),
                  title: Text('${item.year}년$badge'),
                  subtitle: Text(
                    item.hasData
                        ? '최종 갱신: ${item.formattedTimestamp}'
                        : '데이터 없음',
                  ),
                  trailing: isActive
                      ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.of(context).pop(item.year),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showYearHistoryPicker({
  required BuildContext context,
  required List<YearHistoryItem> items,
  required String activeYear,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => YearHistorySheet(
      items: items,
      activeYear: activeYear,
    ),
  );
}
