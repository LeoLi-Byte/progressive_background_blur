## 0.0.1

* Added the `ProgressiveBlur` widget, matching Figma **Effects → Background blur → Progressive (Start / End)**: blur strength interpolates from `sigmaStart` to `sigmaEnd` along the line from `begin` to `end`, defaulting to top-to-bottom.
* `begin` / `end` accept any `AlignmentGeometry`, including `AlignmentDirectional` (resolved against the current `Directionality`).
* `sigmaStart` / `sigmaEnd` are clamped to 0–100 inclusive (the Figma range, exposed as `ProgressiveBlur.maxSigma`); both being 0 applies no blur.
* Pure-Dart fragment-shader implementation: a two-pass (horizontal / vertical) separable Gaussian convolution, no native code.
* Impeller only, detected at runtime via `ui.ImageFilter.isShaderFilterSupported`; on Skia and before the shader finishes loading, `child` is rendered unchanged.
* Added `ProgressiveBlur.precache()` to precompile the shader before `runApp()`.