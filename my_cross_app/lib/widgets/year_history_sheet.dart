import 'package:flutter/material.dart';
import '../screens/detail_sections/detail_sections_strings_ko.dart';

/// Modal sheet for selecting past years
class YearHistorySheet extends StatelessWidget {
  final List<String> availableYears;
  final String currentYear;
  final Function(String) onYearSelected;

  const YearHistorySheet({
    super.key,
    required this.availableYears,
    required this.currentYear,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stringsKo['history']!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '현재 연도: $currentYear',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: availableYears.length,
              itemBuilder: (context, index) {
                final year = availableYears[index];
                final isCurrentYear = year == currentYear;
                
                return ListTile(
                  title: Text(
                    year,
                    style: TextStyle(
                      fontWeight: isCurrentYear ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentYear ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  subtitle: isCurrentYear 
                      ? const Text('현재 연도 (편집 가능)')
                      : Text('과거 이력 (읽기 전용)'),
                  trailing: isCurrentYear 
                      ? const Icon(Icons.edit, color: Colors.blue)
                      : const Icon(Icons.visibility, color: Colors.grey),
                  onTap: () {
                    onYearSelected(year);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}