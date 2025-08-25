// lib/screens/basic_info_screen.dart (④ 기본정보 입력 화면)
// - 국유재 선택(③)에서 넘어온 데이터 일부 자동 채움
// - 기본 필드 입력(명칭/주소/관리인/소유자/조성시기 등)
// - 이전(목록으로) / 다음(상세조사) 버튼

import 'package:flutter/material.dart';
import '../ui/widgets/yellow_nav_button.dart';
import 'detail_survey_screen.dart';

class BasicInfoScreen extends StatefulWidget {
  static const route = '/basic-info';
  const BasicInfoScreen({super.key});

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // ─────────────────────────────────────────────────────────────
  // 입력 필드 컨트롤러
  // ─────────────────────────────────────────────────────────────
  final _heritageName = TextEditingController(); // 국가유산명
  final _address      = TextEditingController(); // 지정/주소
  final _manager      = TextEditingController(); // 관리인
  final _owner        = TextEditingController(); // 소유자
  final _era          = TextEditingController(); // 조성시기(시대)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ③ AssetSelectScreen에서 선택한 값 받기
    final sel = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    if (sel != null) {
      _heritageName.text = sel['name'] ?? '';
      _address.text      = sel['region'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기본정보 입력')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text(
                    '기본정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // ─────────────────────────────────────────────────────
                  // 입력폼: 2열 GridView로 배치
                  // ─────────────────────────────────────────────────────
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    childAspectRatio: 3.5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      TextFormField(
                        controller: _heritageName,
                        decoration: const InputDecoration(labelText: '국가유산명'),
                        validator: (v) =>
                        (v == null || v.isEmpty) ? '국가유산명을 입력하세요' : null,
                      ),
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(labelText: '지정/주소'),
                      ),
                      TextFormField(
                        controller: _manager,
                        decoration: const InputDecoration(labelText: '관리인'),
                      ),
                      TextFormField(
                        controller: _owner,
                        decoration: const InputDecoration(labelText: '소유자'),
                      ),
                      TextFormField(
                        controller: _era,
                        decoration: const InputDecoration(labelText: '조성시기(시대)'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─────────────────────────────────────────────────────
                  // 네비게이션 버튼 (이전 / 다음)
                  // ─────────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('목록으로'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: YellowNavButton(
                          label: '다음(상세조사)',
                          onTap: () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pushNamed(
                                context,
                                DetailSurveyScreen.route,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
