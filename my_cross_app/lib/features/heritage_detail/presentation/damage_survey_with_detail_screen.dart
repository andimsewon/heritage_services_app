import 'package:flutter/material.dart';

/// 손상부 조사 + 심화조사 통합 화면 (탭 연동형)
class DamageSurveyWithDetailScreen extends StatefulWidget {
  const DamageSurveyWithDetailScreen({super.key});

  static const route = '/damage-survey-detail';

  @override
  State<DamageSurveyWithDetailScreen> createState() =>
      _DamageSurveyWithDetailScreenState();
}

class _DamageSurveyWithDetailScreenState
    extends State<DamageSurveyWithDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedPart; // 선택된 부재
  String? _selectedDirection; // 방향 (남향, 동향 등)
  String? _selectedPosition; // 위치 (상부, 중부, 하부)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _moveToDetailSurvey() {
    if (_selectedPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠ 조사할 부재를 먼저 선택하세요'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    _tabController.animateTo(1); // 심화조사 탭으로 이동
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '손상부 조사 및 심화조사',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E2A44),
          unselectedLabelColor: const Color(0xFF9CA3AF),
          indicatorColor: const Color(0xFF1E2A44),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '손상부 조사'),
            Tab(text: '심화조사'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // 스와이프로 탭 전환 방지
        children: [
          // ① 손상부 조사 탭
          _buildDamageSurveyTab(),
          // ② 심화조사 탭
          _buildDetailSurveyTab(),
        ],
      ),
    );
  }

  Widget _buildDamageSurveyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 부재 선택
          _buildSectionCard(
            title: '부재 선택',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['기단부', '축부(벽체부)', '지붕부', '기타'].map((part) {
                final isSelected = _selectedPart == part;
                return ChoiceChip(
                  label: Text(part),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1E2A44),
                  backgroundColor: const Color(0xFFF3F4F6),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedPart = part);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // 방향 선택
          _buildSectionCard(
            title: '방향',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['남향', '동향', '서향', '북향'].map((direction) {
                final isSelected = _selectedDirection == direction;
                return ChoiceChip(
                  label: Text(direction),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1E2A44),
                  backgroundColor: const Color(0xFFF3F4F6),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedDirection = direction);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // 위치 선택
          _buildSectionCard(
            title: '부재 내 위치',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['상부', '중부', '하부'].map((position) {
                final isSelected = _selectedPosition == position;
                return ChoiceChip(
                  label: Text(position),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1E2A44),
                  backgroundColor: const Color(0xFFF3F4F6),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedPosition = position);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // 심화조사로 이동 버튼
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: _moveToDetailSurvey,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2A44),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            label: const Text(
              '심화조사로 이동',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSurveyTab() {
    if (_selectedPart == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.info_outline,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 16),
            Text(
              '이전 탭에서 부재를 선택하고\n"심화조사로 이동" 버튼을 클릭하세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 선택된 부재 정보 표시
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2A44).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택된 조사 대상',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2A44),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '부재: $_selectedPart${_selectedDirection != null ? " / 방향: $_selectedDirection" : ""}${_selectedPosition != null ? " / 위치: $_selectedPosition" : ""}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 심화조사 내용 입력
          _buildSectionCard(
            title: '심화조사 내용',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: '심화조사 결과를 자세히 입력하세요...\n\n예: 균열 깊이 측정, 손상 원인 분석, 보수 권장사항 등',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF1E2A44), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 저장 버튼
          ElevatedButton.icon(
            icon: const Icon(Icons.save_outlined, size: 18),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ 심화조사 결과가 저장되었습니다'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            label: const Text(
              '저장 및 완료',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
