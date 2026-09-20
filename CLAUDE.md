# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

`progressive_background_blur` exposes a progressive (gradient/feathered) backdrop blur — the Figma **Effects → Background blur → Progressive** (Start/End) effect. Key facts:

- The blur is implemented as a **pure-Dart Flutter package**: `pubspec.yaml` has no `plugin:` section and there is no native code anywhere in the package. Do not reintroduce method-channel/native plumbing for blur features — extend the widget and fragment shader instead.
- The supported platform list (android/ios/linux/macos/windows, **web deliberately excluded**) is declared via the **top-level `platforms:` map in `pubspec.yaml`** — not via a plugin registration. pana reads this field to assign pub.dev platform tags; do not add `web:` to it. Web builds still compile (pure Dart) and the widget then renders `child` unchanged via the `isShaderFilterSupported` degradation path.
- The only consumer-facing API is the `ProgressiveBlur` widget (`lib/widget/progressive_blur.dart`), rendered through the fragment shader `lib/shaders/progressive_blur.frag` registered under `flutter.shaders` in `pubspec.yaml`.
- **Impeller only.** Runtime support is gated on `ui.ImageFilter.isShaderFilterSupported`; on the Skia backend, while the shader is still loading, or when both sigmas are 0, the widget renders `child` unchanged.
- `lib/interface/` still contains the legacy `getPlatformVersion()` method-channel template (`ProgressiveBackgroundBlur` / platform interface / method channel). It is exported from the barrel and covered by `test/`, but it is residue from the plugin template, not the product direction. The example app no longer uses it — `example/lib/main.dart` is a full `ProgressiveBlur` demo with direction presets and Start/End sigma sliders.
- Example host runners exist under `example/{android,ios,linux,macos,windows}`; there are no native plugin dirs at the package root and none are expected.

## Commands

Run from the package root unless noted:

```bash
flutter pub get
flutter analyze                      # strict-casts + strict-inference; warnings treated seriously
flutter test                         # all unit tests in test/
flutter test test/progressive_background_blur_test.dart --plain-name 'getPlatformVersion'  # single test
dart format .                        # page width is 120 (analysis_options.yaml: formatter.page_width)
```

Manual shader/widget verification requires a device or simulator with Impeller (default on iOS/Android/macOS in recent Flutter):

```bash
cd example
flutter run -d <device-id>
flutter test integration_test/plugin_integration_test.dart
```

Fragment shaders are compiled at build time; a shader compile error surfaces as an asset-build failure when building the example, not during `flutter analyze`.

## Architecture

Public entry point is the barrel `lib/progressive_background_blur.dart`, which re-exports `ProgressiveBackgroundBlur` from the interface library and the whole `widget/progressive_blur.dart`.

### Blur rendering pipeline (all in `lib/widget/progressive_blur.dart`)

1. `ProgressiveBlur` (StatefulWidget) — public API: `begin`/`end` (`AlignmentGeometry`, default top→bottom), `sigmaStart`/`sigmaEnd` (passed to the shader unchanged in backdrop-texture/physical pixels; clamped to the Figma range 0–`ProgressiveBlur.maxSigma` (100), inclusive), optional `child`. Holds the static, lazily-loaded `ui.FragmentProgram`; `ProgressiveBlur.precache()` should be called before `runApp()` to precompile it.
2. `build()` resolves `AlignmentDirectional` against `Directionality`, passes sigmas through unchanged (written to the shader as-is in backdrop-texture/physical pixels), and reads the logical view size from `MediaQuery.sizeOf(context)` (so rotation/window resize auto-rebuilds the node; note an ancestor that overrides `MediaQuery.size` will skew the gradient mapping).
3. `_ShaderBackdropBlur` (SingleChildRenderObjectWidget) → `_RenderShaderBackdropBlur` (RenderProxyBox, `alwaysNeedsCompositing`) pushes a `BackdropFilterLayer` in `paint()`. The widget's global position is read once per paint via `localToGlobal` and mapped to normalized coordinates inside the full-screen backdrop snapshot; begin/end alignments are interpolated into that 0..1 space and clamped to the visible region.
4. The filter is one `ui.ImageFilter.compose` of two `ui.ImageFilter.shader` passes (horizontal then vertical) — a separable Gaussian. The two `FragmentShader` instances are constructed once per RenderObject and disposed in `RenderObject.dispose`, but the compose filter is **recreated on every paint, after uniforms are written**: the engine's `_FragmentShaderImageFilter.nativeFilter` is a `late final` whose `as_image_filter()` memcpys (snapshots) the current uniforms on first conversion, so reusing one `ImageFilter` freezes the parameters and property changes never reach the screen.

### Shader uniform contract (Dart ↔ GLSL — edit in lockstep)

In `progressive_blur.frag`, the engine auto-fills/binds the first two declarations: float index 0–1 = `u_size` (vec2, backdrop texture size), and the `u_texture` sampler. Dart (`_configureShader`) must set the rest by exact index:

| Index | Uniform | Meaning |
| --- | --- | --- |
| 2 | `u_sigma_start` | sigma at `u_begin`, physical pixels |
| 3 | `u_sigma_end` | sigma at `u_end`, physical pixels |
| 4 | `u_direction` | 0 = horizontal pass, 1 = vertical pass |
| 5–6 | `u_begin` | gradient start, normalized coords in the backdrop texture |
| 7–8 | `u_end` | gradient end, normalized coords (y top-down, matching `FlutterFragCoord`) |

Other shader facts: kernel radius is `3σ`, hard-capped by `MAX_KERNEL_SIZE` (255); the fragment loop is a fixed upper bound with `break` (GLSL requires constant loop bounds); gradient `t` is the projection onto the begin→end axis; under the OpenGLES Impeller backend the sample y is flipped (`IMPELLER_TARGET_OPENGLES`) while `FlutterFragCoord().y` stays top-down. Documented widget limitations (see the class doc comment) include: pure-compositor translation ancestors (`AnimatedSlide`, `FractionalTranslation`) don't repaint the node, non-translate ancestor transforms are unsupported, and partially off-screen widgets remap the gradient to the visible rect rather than the full Figma semantics.

### Legacy interface library

`lib/interface/progressive_background_blur.dart` is a single `library` with two `part` files (`..._method_channel.dart`, `..._platform_interface.dart`) — the platform interface, method-channel implementation, and app-facing class are not separate importable libraries. Tests import the interface library directly (`package:progressive_background_blur/interface/progressive_background_blur.dart`) and swap a `MockPlatformInterfaceMixin` fake at the platform-interface layer; the method-channel test mocks via `setMockMethodCallHandler`. Follow those patterns if touching the legacy layer.

## Code conventions (from analysis_options.yaml)

- Explicit types everywhere: `always_specify_types` and `type_annotate_public_apis` are on; no `var` / type-omitting `final` for locals, no untyped public signatures.
- `strict-casts` and `strict-inference` are enabled — no implicit `dynamic`; cast nullable to non-nullable explicitly.
- Single quotes, mandatory trailing commas in multi-line collections/arguments, ordered directives (`directives_ordering`), constructors before other members.
- Format with `dart format` at 120 columns, not 80.
- Doc comments for the package's own APIs (including the shader) are written in Chinese; match that language when extending existing documentation.