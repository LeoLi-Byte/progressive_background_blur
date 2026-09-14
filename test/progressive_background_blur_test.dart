import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:progressive_background_blur/interface/progressive_background_blur.dart';

class MockProgressiveBackgroundBlurPlatform
    with MockPlatformInterfaceMixin
    implements ProgressiveBackgroundBlurPlatform {
  @override
  Future<String?> getPlatformVersion() => Future<String>.value('42');
}

void main() {
  final ProgressiveBackgroundBlurPlatform initialPlatform = ProgressiveBackgroundBlurPlatform.instance;

  test('$MethodChannelProgressiveBackgroundBlur is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelProgressiveBackgroundBlur>());
  });

  test('getPlatformVersion', () async {
    final ProgressiveBackgroundBlur progressiveBackgroundBlurPlugin = ProgressiveBackgroundBlur();
    final MockProgressiveBackgroundBlurPlatform fakePlatform = MockProgressiveBackgroundBlurPlatform();
    ProgressiveBackgroundBlurPlatform.instance = fakePlatform;

    expect(await progressiveBackgroundBlurPlugin.getPlatformVersion(), '42');
  });
}
