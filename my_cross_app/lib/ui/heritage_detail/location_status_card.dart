import 'package:flutter/material.dart';

class LocationStatusCard extends StatefulWidget {
  const LocationStatusCard({super.key});

  @override
  State<LocationStatusCard> createState() => _LocationStatusCardState();
}

class _LocationStatusCardState extends State<LocationStatusCard> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

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
            '위치 현황',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '문화유산의 위치 정보를 입력하거나 확인하세요.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          // 주소 입력
          _buildInputField(
            label: '주소',
            controller: _addressController,
            hint: '예: 경기도 여주시 북내면 상교리 산18',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          // 좌표 입력 (가로 배치)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              if (isMobile) {
                return Column(
                  children: [
                    _buildInputField(
                      label: '위도 (Latitude)',
                      controller: _latitudeController,
                      hint: '예: 37.2985',
                      icon: Icons.location_searching,
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      label: '경도 (Longitude)',
                      controller: _longitudeController,
                      hint: '예: 127.6374',
                      icon: Icons.location_searching,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: '위도 (Latitude)',
                      controller: _latitudeController,
                      hint: '예: 37.2985',
                      icon: Icons.location_searching,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                      label: '경도 (Longitude)',
                      controller: _longitudeController,
                      hint: '예: 127.6374',
                      icon: Icons.location_searching,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // 지도 미리보기 영역
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF3F4F6),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 48,
                        color: Color(0xFF9CA3AF),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '지도 미리보기',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: 지도 API 연동 (네이버, 카카오맵 등)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🗺 지도 API 연동 예정'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('지도 열기', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2A44),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
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
                        content: Text('✅ 위치 정보가 저장되었습니다'),
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
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
            isDense: true,
          ),
        ),
      ],
    );
  }
}
