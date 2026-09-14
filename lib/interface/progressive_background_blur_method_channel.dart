part of 'progressive_background_blur.dart';

/// An implementation of [ProgressiveBackgroundBlurPlatform] that uses method channels.
class MethodChannelProgressiveBackgroundBlur extends ProgressiveBackgroundBlurPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('progressive_background_blur');

  @override
  Future<String?> getPlatformVersion() async {
    final String? version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
