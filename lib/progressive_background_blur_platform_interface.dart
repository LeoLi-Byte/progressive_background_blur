import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'progressive_background_blur_method_channel.dart';

abstract class ProgressiveBackgroundBlurPlatform extends PlatformInterface {
  /// Constructs a ProgressiveBackgroundBlurPlatform.
  ProgressiveBackgroundBlurPlatform() : super(token: _token);

  static final Object _token = Object();

  static ProgressiveBackgroundBlurPlatform _instance = MethodChannelProgressiveBackgroundBlur();

  /// The default instance of [ProgressiveBackgroundBlurPlatform] to use.
  ///
  /// Defaults to [MethodChannelProgressiveBackgroundBlur].
  static ProgressiveBackgroundBlurPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ProgressiveBackgroundBlurPlatform] when
  /// they register themselves.
  static set instance(ProgressiveBackgroundBlurPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
