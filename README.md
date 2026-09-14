# progressive_background_blur

[![pub package](https://img.shields.io/pub/v/progressive_background_blur)](https://pub.dev/packages/progressive_background_blur)
[![GitHub license](https://img.shields.io/github/license/LeoLi-Byte/progressive_background_blur?label=协议&style=flat-square)](https://github.com/LeoLi-Byte/progressive_background_blur/blob/main/LICENSE)

Language: [中文](README-ZH.md) | English

> A Flutter widget for **progressive (gradient / feathered) backdrop blur**, matching Figma's
> **Effects → Background blur → Progressive (Start / End)** effect. Pure Dart implementation
> powered by a fragment shader — no native code.

It works just like `BackdropFilter`: the widget blurs the scene content **behind** it (for example,
a scrolling list behind a navigation bar). The blur strength interpolates linearly from
`sigmaStart` to `sigmaEnd` along the line from `begin` to `end`, going top-to-bottom by default.

## Preparing for use

### Version constraints

```yaml
  sdk: ^3.11.0
  flutter: ">=3.41.0"
```

- **Impeller only.** Runtime support is detected through
  [`ui.ImageFilter.isShaderFilterSupported`](https://api.flutter.dev/flutter/dart-ui/ImageFilter/isShaderFilterSupported.html);
  Impeller is enabled by default on iOS / Android / macOS in recent Flutter versions.

> **Graceful degradation**
>
> No blur is applied and `child` is rendered unchanged in any of these cases:
>
> - Running on the Skia backend.
> - The shader hasn't finished loading on the first frame.
> - Both `sigmaStart` and `sigmaEnd` are 0.

### Add the dependency

```yaml
dependencies:
  progressive_background_blur: ^0.0.1
```

```dart
import 'package:progressive_background_blur/progressive_background_blur.dart';
```

## Usage

### Precache the shader (recommended)

Call `ProgressiveBlur.precache()` before `runApp()` to precompile the shader and avoid an
unblurred first frame:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProgressiveBlur.precache();
  runApp(const MyApp());
}
```

> `precache()` is a no-op on unsupported platforms; the widget also loads the shader itself if
> you don't call it.

### Basic usage

The example below creates a 120-pixel-high region at the top fading from crisp to blurred,
matching Figma Start: 0 / End: 20:

```dart
Stack(
  fit: StackFit.expand,
  children: <Widget>[
    // The scene behind: images, a scrolling list, etc.
    ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        return ListTile(title: Text('Item $index'));
      },
    ),

    // The progressive blur layer.
    Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: 120,
      child: ProgressiveBlur(
        sigmaStart: 0,
        sigmaEnd: 20,
        // child is painted above the blur layer, usually holding a translucent
        // overlay, text, etc. For blur only, just pass SizedBox.expand().
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    ),
  ],
)
```

### Custom gradient direction

`begin` / `end` define the alignment positions of the start and end points within the widget's own
bounds. The blur strength only transitions from `sigmaStart` to `sigmaEnd` along the line between
the two points:

```dart
// Left-to-right gradient.
ProgressiveBlur(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  sigmaStart: 0,
  sigmaEnd: 16,
  child: const SizedBox.expand(),
)

// Diagonal gradient.
ProgressiveBlur(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  sigmaStart: 4,
  sigmaEnd: 24,
  child: const SizedBox.expand(),
)

// Use AlignmentDirectional to mirror the gradient automatically in RTL text direction.
ProgressiveBlur(
  begin: AlignmentDirectional.topStart,
  end: AlignmentDirectional.bottomEnd,
  sigmaStart: 0,
  sigmaEnd: 20,
  child: const SizedBox.expand(),
)
```

## Parameters

| Name         | Type                | Default                  | Description                                                                                                                                                                                              |
|--------------|---------------------|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `begin`      | `AlignmentGeometry` | `Alignment.topCenter`    | Alignment of the gradient start point within the widget's bounds.                                                                                                                                        |
| `end`        | `AlignmentGeometry` | `Alignment.bottomCenter` | Alignment of the gradient end point within the widget's bounds.                                                                                                                                          |
| `sigmaStart` | `double`            | `0`                      | Gaussian blur sigma at the start point, corresponding to Figma **Start**. Passed to the shader as-is in backdrop-texture pixels (physical pixels). Clamped to 0–100 (inclusive), matching Figma's range. |
| `sigmaEnd`   | `double`            | required                 | Gaussian blur sigma at the end point, corresponding to Figma **End**. Same rules as `sigmaStart`.                                                                                                        |
| `child`      | `Widget`            | required                 | The child painted above the blur layer.                                                                                                                                                                  |

Static members:

| Name                             | Description                                                                                      |
|----------------------------------|--------------------------------------------------------------------------------------------------|
| `ProgressiveBlur.precache()`     | Precompiles and caches the shader program; recommended to `await` before `runApp()` in `main()`. |
| `ProgressiveBlur.shaderAssetKey` | The shader asset key (`lib/shaders/progressive_blur.frag`).                             |
| `ProgressiveBlur.maxSigma`       | The upper bound for sigma, `100` (inclusive), matching Figma's range.                            |

## How it works

A fragment shader runs a two-pass (horizontal → vertical) separable Gaussian convolution, applied
to `BackdropFilter`'s full-screen backdrop snapshot through
[`ui.ImageFilter.shader`](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html).
Per fragment, sigma is interpolated between `sigmaStart` and `sigmaEnd` by the fragment's position
along the `begin` → `end` line.

## Notes

- **Sigma cap**: inputs are clamped to 0–100 inclusive (`ProgressiveBlur.maxSigma`); due to the
  shader's 255-sample kernel limit, beyond a sigma of approximately 42 the actual blur strength
  stops increasing.
- **Translation-only animations may misalign**: the widget reads its on-screen position only once
  per paint. If it is moved by an outer widget that changes the position without triggering a
  repaint (`AnimatedSlide`, `FractionalTranslation`, or a layer-cached `Transform.translate`), the
  gradient band stays at the old position while the widget moves, so the two become misaligned. The
  app side needs to trigger repaints during such an animation.
- **No rotation / scale in outer widgets**: when an outer widget wrapping this one applies
  rotation, scale, or other non-translation transforms, the start / end point mapping no longer
  holds, so the gradient position can't be guaranteed.
- **Partially off-screen**: when the widget extends beyond the viewport, the gradient is remapped to
  the visible region (clipped at the edges), which differs slightly from Figma's "gradient across
  the widget's full size" semantics.
- **Performance**: every blurred region requires a backdrop snapshot and extra compositing cost, so
  avoid creating many instances frequently inside long lists.

> If you like my project, please click "Star" in the upper right corner of the project. Your
> support is my biggest encouragement! ^_^