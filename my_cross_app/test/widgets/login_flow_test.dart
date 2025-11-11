import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cross_app/app/app.dart';
import 'package:my_cross_app/features/dashboard/presentation/home_screen.dart';

void main() {
  testWidgets('admin credentials navigate to home', (tester) async {
    await tester.pumpWidget(const HeritageApp());

    final idField = find.byType(TextFormField).at(0);
    final pwField = find.byType(TextFormField).at(1);

    await tester.enterText(idField, 'admin@heritage.local');
    await tester.enterText(pwField, 'admin123!');

    await tester.tap(find.text('로그인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('skip button navigates to home', (tester) async {
    await tester.pumpWidget(const HeritageApp());

    await tester.tap(find.text('건너뛰고 둘러보기 (데모)'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
