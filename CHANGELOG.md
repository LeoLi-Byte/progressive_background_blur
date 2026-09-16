## 0.0.3

* Made `ProgressiveBlur.child` optional (`Widget?`, defaults to `null`). When omitted, the backdrop blur is still applied to the widget's own region (its size is determined by the parent's constraints); only the foreground content is absent, matching `BackdropFilter`'s behavior.
* On the no-blur degradation paths (Skia backend, web, shader still loading, both sigmas 0), a null `child` now renders as a zero-sized placeholder instead of being skipped.
* Fixed the blur bleeding outside the widget's own bounds: the shader-based backdrop filter's output region is conservatively computed by the engine as the full-screen backdrop snapshot, so the blur could spill past the widget and linger as a full-screen smear during route slide/fade-out transitions until the node was destroyed. The widget is now wrapped in a `ClipRect`, so the blur is strictly confined to its own rect and moves, fades, and disposes with its page.

## 0.0.2

* Declared the supported platforms (Android, iOS, Linux, macOS, Windows) in `pubspec.yaml` via the top-level `platforms:` field.
* Excluded web from the declared platforms, so pub.dev no longer shows a web platform tag. Web builds are unaffected — the widget still renders `child` unchanged there through the `isShaderFilterSupported` graceful-degradation path.

## 0.0.1

* Added the `ProgressiveBlur` widget, matching Figma **Effects → Background blur → Progressive (Start / End)**: blur strength interpolates from `sigmaStart` to `sigmaEnd` along the line from `begin` to `end`, defaulting to top-to-bottom.
* `begin` / `end` accept any `AlignmentGeometry`, including `AlignmentDirectional` (resolved against the current `Directionality`).
* `sigmaStart` / `sigmaEnd` are clamped to 0–100 inclusive (the Figma range, exposed as `ProgressiveBlur.maxSigma`); both being 0 applies no blur.
* Pure-Dart fragment-shader implementation: a two-pass (horizontal / vertical) separable Gaussian convolution, no native code.
* Impeller only, detected at runtime via `ui.ImageFilter.isShaderFilterSupported`; on Skia and before the shader finishes loading, `child` is rendered unchanged.
* Added `ProgressiveBlur.precache()` to precompile the shader before `runApp()`.