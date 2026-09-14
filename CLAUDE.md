# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

`progressive_background_blur` is a Flutter **federated plugin** intended to expose a progressive (gradient/feathered) background blur — a layered frosted-glass effect. It is currently an unscaffolded work-in-progress:

- The Dart side is still the default `flutter create --template=plugin` template. The only API is `getPlatformVersion()`; no blur API or widget exists yet.
- `pubspec.yaml` declares native implementations for android/ios/linux/macos/windows, but the native plugin directories (`android/`, `ios/`, `macos/`, `linux/`, `windows/` at the package root) do **not** exist. Native builds of `example/` will fail until they are regenerated (`flutter create --platforms=android,ios,linux,macos,windows --org org.leoli.plugin.backgroundblur.progressive .`) or implemented.
- `example/` is the template host app; it only displays the platform version.

## Commands

Run from the package root unless noted:

```bash
flutter pub get
flutter analyze                      # strict-casts + strict-inference, treat warnings as errors
flutter test                         # all unit tests in test/
flutter test test/progressive_background_blur_test.dart --plain-name 'getPlatformVersion'  # single test
dart format .                        # page width is 120 (configured in analysis_options.yaml)
```

Example app and integration tests (require a device/emulator; currently blocked by missing native code):

```bash
cd example
flutter pub get
flutter run -d <device-id>
flutter test integration_test/plugin_integration_test.dart
```

## Architecture

Standard Flutter federated-plugin layering, three files in `lib/` (call flows downward):

1. `progressive_background_blur.dart` — app-facing API class `ProgressiveBackgroundBlur`; this is what consumers import.
2. `progressive_background_blur_platform_interface.dart` — `ProgressiveBackgroundBlurPlatform extends PlatformInterface`, a token-verified singleton (`PlatformInterface.verifyToken`). Platform/federated implementations replace `ProgressiveBackgroundBlurPlatform.instance`; the default is the method-channel implementation.
3. `progressive_background_blur_method_channel.dart` — `MethodChannelProgressiveBackgroundBlur` over the channel named `progressive_background_blur`.

Tests mirror these layers: `test/progressive_background_blur_test.dart` swaps in a `MockPlatformInterfaceMixin` fake at the platform-interface layer; `test/progressive_background_blur_method_channel_test.dart` mocks the method channel via `setMockMethodCallHandler`. Follow the same pattern for new APIs.

When adding plugin functionality, a method must be added in lockstep across: app-facing class → abstract platform interface → method-channel implementation → native side. The registered native classes (per `pubspec.yaml`) are `ProgressiveBackgroundBlurPlugin` on Android/iOS/macOS/Linux and `ProgressiveBackgroundBlurPluginCApi` on Windows; Android package is `org.leoli.plugin.backgroundblur.progressive.progressive_background_blur`.

## Code conventions (from analysis_options.yaml)

- Explicit types everywhere: `always_specify_types` and `type_annotate_public_apis` are on; do not use `var`/`final`-type-omission for locals or untyped public signatures.
- `strict-casts` and `strict-inference` are enabled — no implicit `dynamic`, cast nullable to non-nullable explicitly.
- Single quotes, mandatory trailing commas in multi-line collections/arguments, ordered directives (`directives_ordering`), constructors before other members.
- Format with `dart format` (120-column page width), not 80.