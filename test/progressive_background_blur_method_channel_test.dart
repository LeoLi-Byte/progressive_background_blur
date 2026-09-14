import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progressive_background_blur/progressive_background_blur_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelProgressiveBackgroundBlur platform = MethodChannelProgressiveBackgroundBlur();
  const MethodChannel channel = MethodChannel('progressive_background_blur');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall methodCall,
    ) async {
      return '42';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
