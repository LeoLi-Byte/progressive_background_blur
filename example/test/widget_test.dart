// ProgressiveBlur 示例的冒烟测试：验证页面结构以及参数控制项存在。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progressive_background_blur/progressive_background_blur.dart';

import 'package:progressive_background_blur_example/main.dart';

void main() {
  testWidgets('Demo shows blur panel and parameter controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(ProgressiveBlur), findsOneWidget);
    expect(find.text('End'), findsOneWidget);

    // 拖动 End 滑条应能正常更新参数并重建。
    final Offset sliderCenter = tester.getCenter(find.byType(Slider).last);
    await tester.tapAt(Offset(sliderCenter.dx + 100, sliderCenter.dy));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressiveBlur), findsOneWidget);
  });
}
