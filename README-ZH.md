# progressive_background_blur

[![pub package](https://img.shields.io/pub/v/progressive_background_blur)](https://pub.dev/packages/progressive_background_blur)
[![GitHub license](https://img.shields.io/github/license/LeoLi-Byte/progressive_background_blur?label=协议&style=flat-square)](https://github.com/LeoLi-Byte/progressive_background_blur/blob/main/LICENSE)

Language: 中文 | [English](README.md)

> 实现 **渐进式（渐变 / 羽化）背景模糊** 的 Flutter 组件，对应 Figma
> **Effects → Background blur → Progressive（Start / End）** 效果。纯 Dart + Fragment Shader
> 实现，无任何原生代码。

与 `BackdropFilter` 用法一致：组件模糊的是其**背后**的场景内容（例如导航栏背后正在滚动的列表），
模糊量沿 `begin` 到 `end` 的连线由 `sigmaStart` 线性过渡到 `sigmaEnd`，默认方向自上而下。

## 准备工作

### 版本限制

```yaml
  sdk: ^3.11.0
  flutter: ">=3.41.0"
```

- 仅支持 **Impeller** 渲染后端（近期 Flutter 在 iOS / Android / macOS 上默认启用），运行时通过
  [`ui.ImageFilter.isShaderFilterSupported`](https://api.flutter.dev/flutter/dart-ui/ImageFilter/isShaderFilterSupported.html)
  探测能力。

> **降级策略**
>
> 以下情况不做模糊，原样呈现 `child`：
>
> - 运行在 Skia 后端
> - 着色器加载完成前的首帧
> - `sigmaStart` 与 `sigmaEnd` 均为 0

### 添加依赖

```yaml
dependencies:
  progressive_background_blur: ^0.0.1
```

```dart
import 'package:progressive_background_blur/progressive_background_blur.dart';
```

## 使用方法

### 预编译着色器（建议）

在 `runApp()` 之前调用 `ProgressiveBlur.precache()` 预编译着色器，避免首帧没有模糊：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProgressiveBlur.precache();
  runApp(const MyApp());
}
```

> 不支持的平台上 `precache()` 为空操作；不调用时组件也会自行加载。

### 基础用法

下例在顶部高度 120 的区域实现“由清晰到模糊”，对应 Figma Start: 0 / End: 20：

```dart
Stack(
  fit: StackFit.expand,
  children: <Widget>[
    // 背后的场景内容：图片、滚动列表等
    ListView.builder(
      itemBuilder: (BuildContext context, int index) {
        return ListTile(title: Text('Item $index'));
      },
    ),

    // 渐变模糊层
    Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: 120,
      child: ProgressiveBlur(
        sigmaStart: 0,
        sigmaEnd: 20,
        // child 绘制在模糊层之上，通常放置半透明遮罩、文字等；
        // 只需要纯模糊时传 SizedBox.expand() 即可。
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    ),
  ],
)
```

### 自定义渐变方向

`begin` / `end` 表示渐变起点、终点在组件区域内的对齐位置，模糊量只在两点连线上
由 `sigmaStart` 过渡到 `sigmaEnd`：

```dart
// 自左向右渐变
ProgressiveBlur(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  sigmaStart: 0,
  sigmaEnd: 16,
  child: const SizedBox.expand(),
)

// 沿对角线渐变
ProgressiveBlur(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  sigmaStart: 4,
  sigmaEnd: 24,
  child: const SizedBox.expand(),
)

// 使用 AlignmentDirectional，随文字方向（RTL）自动镜像
ProgressiveBlur(
  begin: AlignmentDirectional.topStart,
  end: AlignmentDirectional.bottomEnd,
  sigmaStart: 0,
  sigmaEnd: 20,
  child: const SizedBox.expand(),
)
```

## 参数说明

| 参数           | 类型                  | 默认值                      | 说明                                                                                |
|--------------|---------------------|--------------------------|-----------------------------------------------------------------------------------|
| `begin`      | `AlignmentGeometry` | `Alignment.topCenter`    | 渐变起点在组件区域内的对齐位置                                                                   |
| `end`        | `AlignmentGeometry` | `Alignment.bottomCenter` | 渐变终点在组件区域内的对齐位置                                                                   |
| `sigmaStart` | `double`            | `0`                      | 起点的高斯模糊 sigma，对应 Figma **Start**；原样写入着色器，单位与背景快照纹理一致（物理像素），取值范围 0～100（含端点），超出会被钳制 |
| `sigmaEnd`   | `double`            | 必填                       | 终点的高斯模糊 sigma，对应 Figma **End**；规则同 `sigmaStart`                                   |
| `child`      | `Widget`            | 必填                       | 绘制在模糊层之上的子组件                                                                      |

静态成员：

| 成员                               | 说明                                                      |
|----------------------------------|---------------------------------------------------------|
| `ProgressiveBlur.precache()`     | 预编译并缓存着色器程序，建议在 `main()` 中 `runApp` 之前 `await`          |
| `ProgressiveBlur.shaderAssetKey` | 着色器资源 Key（`lib/shaders/progressive_blur.frag`） |
| `ProgressiveBlur.maxSigma`       | sigma 取值上限常量，值为 `100`（含），与 Figma 限制一致                   |

## 实现原理

通过片段着色器做两遍（水平 → 垂直）可分离高斯卷积，以
[`ui.ImageFilter.shader`](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html)
组合后作用于 `BackdropFilter` 的整屏背景快照；每个片元的 sigma 按其在 `begin` → `end`
连线上的位置在 `sigmaStart` 与 `sigmaEnd` 间线性插值。

## 注意事项

- **sigma 上限**：入参钳制在 0～100（含端点，`ProgressiveBlur.maxSigma`）；受卷积核
  255 个采样点的上限影响，sigma 超过约 42 后实际模糊量不再增大。
- **纯位移动画可能错位**：组件只在每次绘制时读取一次自己在屏幕上的位置。如果它被
  `AnimatedSlide`、`FractionalTranslation`（或命中图层缓存的 `Transform.translate`）这类
  “只改变位置、不触发重新绘制”的外层组件带着移动，移动过程中模糊渐变带会停在旧位置、与组件
  本身错位，需要业务侧在动画过程中主动触发重绘。
- **外层不要做旋转 / 缩放**：当包裹本组件的外层组件存在旋转、缩放等变换时，渐变起点 / 终点的
  位置换算不再成立，渐变位置无法保证正确。
- **部分移出屏幕**：组件部分超出视口时，渐变会被重新映射到可见区域（边缘被裁断），与 Figma
  中“沿组件完整尺寸渐变”的语义略有差异。
- **性能**：每个模糊区域都会产生背景快照与额外的合成开销，避免在长列表中大量、频繁创建。

> 如果您喜欢这个项目，欢迎点击项目右上角的 "Star"，您的支持是对我最大的鼓励！ ^_^