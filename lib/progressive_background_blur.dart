
import 'progressive_background_blur_platform_interface.dart';

class ProgressiveBackgroundBlur {
  Future<String?> getPlatformVersion() {
    return ProgressiveBackgroundBlurPlatform.instance.getPlatformVersion();
  }
}
