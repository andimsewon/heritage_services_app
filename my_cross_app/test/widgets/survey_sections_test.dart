import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/detail_sections/section11_investigation.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/detail_sections/section12_conservation.dart';
import 'package:my_cross_app/features/heritage_detail/presentation/widgets/detail_sections/section13_management.dart';
import 'package:my_cross_app/models/survey_models.dart';

void main() {
  group('Survey Sections Widget Tests', () {
    testWidgets('Section11Investigation renders Korean headers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Section11Investigation(
                data: Section11Data.empty(),
                onChanged: (data) {},
              ),
            ),
          ),
        ),
      );

      // Check if Korean section headers are present
      expect(find.text('1.1 조사결과'), findsOneWidget);
      expect(find.text('기단부'), findsOneWidget);
      expect(find.text('축부(벽체부)'), findsOneWidget);
      expect(find.text('지붕부'), findsOneWidget);
      expect(find.text('채색(단청, 벽화)'), findsOneWidget);
      expect(find.text('충해'), findsOneWidget);
      expect(find.text('기타'), findsOneWidget);
      expect(find.text('특기사항'), findsOneWidget);
      expect(find.text('조사자 종합의견'), findsOneWidget);
      expect(find.text('등급분류'), findsOneWidget);
    });

    testWidgets('Section11Investigation toggles read-only mode', (WidgetTester tester) async {
      bool onChangedCalled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Section11Investigation(
                data: Section11Data.empty(),
                enabled: false, // Read-only mode
                onChanged: (data) {
                  onChangedCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      // Try to interact with a text field
      await tester.enterText(find.byType(TextFormField).first, 'test');
      await tester.pump();

      // onChanged should not be called in read-only mode
      expect(onChangedCalled, false);
    });

    testWidgets('Section12Conservation renders Korean headers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Section12Conservation(
                rows: [],
                onChanged: (rows) {},
              ),
            ),
          ),
        ),
      );

      // Check if Korean section headers are present
      expect(find.text('1.2 보존사항(목조)'), findsOneWidget);
      expect(find.text('구분'), findsOneWidget);
      expect(find.text('부재'), findsOneWidget);
      expect(find.text('조사내용(현상)'), findsOneWidget);
      expect(find.text('사진/위치'), findsOneWidget);
    });

    testWidgets('Section13Management renders Korean headers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Section13Management(
                data: Section13Data.empty(),
                onChanged: (data) {},
              ),
            ),
          ),
        ),
      );

      // Check if Korean section headers are present
      expect(find.text('1.3 관리사항'), findsOneWidget);
      expect(find.text('소방 및 안전관리'), findsOneWidget);
      expect(find.text('전기시설'), findsOneWidget);
      expect(find.text('가스시설'), findsOneWidget);
      expect(find.text('안전경비인력'), findsOneWidget);
      expect(find.text('돌봄사업'), findsOneWidget);
      expect(find.text('안내 및 전시시설'), findsOneWidget);
      expect(find.text('주변 및 부대시설'), findsOneWidget);
      expect(find.text('원래기능/활용상태/사용빈도'), findsOneWidget);
    });

    testWidgets('Section13Management toggles read-only mode', (WidgetTester tester) async {
      bool onChangedCalled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Section13Management(
                data: Section13Data.empty(),
                enabled: false, // Read-only mode
                onChanged: (data) {
                  onChangedCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      // Try to interact with a switch
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      // onChanged should not be called in read-only mode
      expect(onChangedCalled, false);
    });
  });
}
