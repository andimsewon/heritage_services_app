import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cross_app/screens/basic_info_screen.dart';

Map<String, dynamic> _sampleManagementData() => {
      'heritageName': '테스트 문화재',
      'years': {
        '2024': {
          'survey': {
            'structure': '조사 구조 메모',
            'wall': '벽 조사 기록',
            'roof': '지붕 상태 양호',
          },
          'conservation': {
            'structure': {
              'section': '구조부',
              'part': '기단',
              'note': '기단 균열 점검 완료',
              'photoLocation': '좌표 123,456',
            },
            'roof': {
              'section': '지붕부',
              'part': '—',
              'note': '지붕 보수 불필요',
              'photoLocation': '부재',
            },
          },
          'fireSafety': {
            'note': '소방 점검 필요',
            'exists': 'yes',
          },
          'electrical': {
            'note': '전기 점검 완료',
            'exists': 'no',
          },
          'locationPhotos': <Map<String, dynamic>>[],
          'currentPhotos': <Map<String, dynamic>>[],
          'damagePhotos': <Map<String, dynamic>>[],
        },
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HeritageHistoryDialog requires heritageId', () {
    expect(
      () => HeritageHistoryDialog(heritageId: '', heritageName: '무명'),
      throwsAssertionError,
    );
  });

  testWidgets('HeritageHistoryDialog hydrates from management data', (tester) async {
    Future<void> pumpDialog() async {
      final data = _sampleManagementData();
      await tester.pumpWidget(
        MaterialApp(
          home: HeritageHistoryDialog(
            heritageId: 'heritage-1',
            heritageName: '테스트 문화재',
            initialManagementData: data,
            managementDataStream: Stream<Map<String, dynamic>>.value(data),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    await pumpDialog();

    expect(find.text('조사 구조 메모'), findsOneWidget);
    expect(find.text('기단 균열 점검 완료'), findsOneWidget);
    expect(find.text('소방 점검 필요'), findsOneWidget);
    expect(find.text('전기 점검 완료'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpDialog();

    expect(find.text('조사 구조 메모'), findsOneWidget);
    expect(find.text('기단 균열 점검 완료'), findsOneWidget);
  });
}
