/// @Describe: Plugin entry.
///
/// @Author: LiWeNHuI
/// @Date: 2024/7/15

library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

part 'progressive_background_blur_method_channel.dart';

part 'progressive_background_blur_platform_interface.dart';

class ProgressiveBackgroundBlur {
  Future<String?> getPlatformVersion() {
    return ProgressiveBackgroundBlurPlatform.instance.getPlatformVersion();
  }
}
