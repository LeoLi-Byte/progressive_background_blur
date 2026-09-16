## 0.0.4

* Removed the redundant outer `ClipRect` wrapper introduced in 0.0.3: the blur node is now returned directly, so one compositing clip layer is saved. No change to the public API or the documented usage limitations.
* Internal cleanup of `ProgressiveBlur`'s build path (fewer intermediate assignments) and doc comments updated to match the current implementation.
* Documented per-platform Impeller availability in the READMEs, following the official Impeller docs: mandatory on iOS; default on Android API 29+ (older devices fall back to OpenGL and degrade gracefully); default since Flutter 3.47 on macOS / Linux / Windows (Flutter 3.41–3.46 still defaults to Skia there and degrades gracefully).

## 0.0.3

* Made `ProgressiveBlur.child` optional (`Widget?`, defaults to `null`). When omitted, the backdrop blur is still applied to the widget's own region (its size is determined by the parent's constraints); only the foreground content is absent, matching `BackdropFilter`'s behavior.
* On the no-blur degradation paths (Skia backend, web, shader still loading, both sigmas 0), a null `child` now renders as a zero-sized placeholder instead of being skipped.
* Fixed the blur bleeding outside the widget's own bounds: the shader-based backdrop filter's output region is conservatively computed by the engine as the full-screen backdrop snapshot, so the blur could spill past the widget and linger as a full-screen smear during route slide/fade-out transitions until the node was destroyed. The widget is now wrapped in a `ClipRect`, so the blur is strictly confined to its own rect and moves, fades, and disposes with its page.

## 0.0.2

* Raised the minimum Flutter version from 3.3.0 to 3.41.0 (the Dart SDK constraint was relaxed from ^3.11.5 to ^3.11.0), as required by the shader-based `ProgressiveBlur` implementation introduced in 0.0.1.
* Declared the supported platforms (Android, iOS, Linux, macOS, Windows) in `pubspec.yaml` via the top-level `platforms:` field.
* Excluded web from the declared platforms, so pub.dev no longer shows a web platform tag. Web builds are unaffected — the widget still renders `child` unchanged there through the `isShaderFilterSupported` graceful-degradation path.

## 0.0.1

* Added the `ProgressiveBlur` widget, matching Figma **Effects → Background blur → Progressive (Start / End)**: blur strength interpolates from `sigmaStart` to `sigmaEnd` along the line from `begin` to `end`, defaulting to top-to-bottom.
* `begin` / `end` accept any `AlignmentGeometry`, including `AlignmentDirectional` (resolved against the current `Directionality`).
* `sigmaStart` / `sigmaEnd` are clamped to 0–100 inclusive (the Figma range, exposed as `ProgressiveBlur.maxSigma`); both being 0 applies no blur.
* Pure-Dart fragment-shader implementation: a two-pass (horizontal / vertical) separable Gaussian convolution, no native code.
* Impeller only, detected at runtime via `ui.ImageFilter.isShaderFilterSupported`; on Skia and before the shader finishes loading, `child` is rendered unchanged.
* Added `ProgressiveBlur.precache()` to precompile the shader before `runApp()`.