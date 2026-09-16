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

- 仅支持 **Impeller** 渲染后端，运行时通过
  [`ui.ImageFilter.isShaderFilterSupported`](https://api.flutter.dev/flutter/dart-ui/ImageFilter/isShaderFilterSupported.html)
  探测能力。各平台支持情况（详见 [Impeller 官方文档](https://docs.flutter.dev/perf/impeller)）：
  - **iOS**：Impeller 是唯一支持的渲染引擎，无 Skia 回退，始终可用；
  - **Android**：API 29+ 默认启用 Impeller；更低系统版本或不支持 Vulkan 的设备会回退到
    OpenGL 渲染器，此时 `isShaderFilterSupported` 为 `false`，按下述降级策略原样呈现 `child`；
  - **macOS / Linux / Windows**：自 Flutter 3.47 起默认启用 Impeller；3.41～3.46 版本
    这些平台仍默认 Skia，同样按降级策略处理；
  - 各平台调试时可用 `flutter run --no-enable-impeller` 关闭 Impeller 验证降级表现。
- **不支持 Web**：Web 上组件不产生模糊，按下述降级策略原样呈现 `child`（`child` 为空时退化为零尺寸占位）。

> **降级策略**
>
> 以下情况不做模糊：有 `child` 时原样呈现；`child` 为空时组件不占空间，与无孩子的 `RenderProxyBox` 行为一致：
>
> - 运行在 Skia 后端或 Web（`isShaderFilterSupported` 为 `false`）
> - 着色器加载完成前的首帧
> - `sigmaStart` 与 `sigmaEnd` 均为 0

### 添加依赖

```yaml
dependencies:
  progressive_background_blur: ^0.0.4
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

下面的示例与 `example/lib/main.dart` 一致：背后是彩色卡片组成的滚动列表，顶部悬浮一条渐变
模糊层——下沿清晰、越靠近顶部越模糊（`begin` 在下方、sigma 为 0，`end` 在顶部、sigma 最大），
模糊层之上再叠加 6% 半透明白色与标题文字：

```dart
Stack(
  children: <Widget>[
    // 背后的场景内容：彩色卡片滚动列表
    ListView.builder(
      itemCount: 40,
      itemBuilder: (BuildContext context, int index) {
        final Color color = HSVColor.fromAHSV(1, (index * 23) % 360, 0.7, 0.9).toColor();
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          height: 88,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('背景内容 ${index + 1}'),
        );
      },
    ),

    // 顶部渐变模糊层（高度由 child 内容撑开）
    Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ProgressiveBlur(
        // 下沿清晰、顶部最模糊：模糊量沿 begin → end 由 0 过渡到 4
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        sigmaStart: 0,
        sigmaEnd: 4,
        // child 绘制在模糊层之上，通常放置半透明遮罩、文字等，可为空。
        // 本例 Positioned 的高度依赖 child 撑开，因此仍需传入尺寸型 child；
        // 不提供 child 的纯模糊用法见下文“不提供 child 的纯模糊用法”。
        child: Container(
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // 模拟 Figma 中常见的半透明叠色，模糊本身由 ProgressiveBlur 完成
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: const SafeArea(
            bottom: false,
            child: Text('Progressive Blur'),
          ),
        ),
      ),
    ),
  ],
)
```

> 完整可运行示例见 `example/lib/main.dart`：示例 App 底部提供了方向选择
>（下 → 上 / 上 → 下 / 左 → 右 / 左上 → 右下）与 Start、End 两个 sigma 滑块，
> 可以实时切换渐变方向并调节两端的模糊强度。

### 自定义渐变方向

`begin` / `end` 表示渐变起点、终点在组件区域内的对齐位置，模糊量只在两点连线上
由 `sigmaStart` 过渡到 `sigmaEnd`。示例 App 内置了 4 个方向预设，可直接照用：

```dart
// 下 → 上（示例 App 的默认方向）
ProgressiveBlur(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  sigmaStart: 0,
  sigmaEnd: 4,
  child: const SizedBox.expand(),
)

// 上 → 下（组件默认方向，begin / end 省略时即此方向）
ProgressiveBlur(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  sigmaStart: 0,
  sigmaEnd: 16,
  child: const SizedBox.expand(),
)

// 左 → 右
ProgressiveBlur(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  sigmaStart: 0,
  sigmaEnd: 16,
  child: const SizedBox.expand(),
)

// 左上 → 右下（沿对角线渐变）
ProgressiveBlur(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  sigmaStart: 4,
  sigmaEnd: 24,
  child: const SizedBox.expand(),
)
```

也可以使用 `AlignmentDirectional`，渐变方向会随文字方向（RTL）自动镜像：

```dart
ProgressiveBlur(
  begin: AlignmentDirectional.topStart,
  end: AlignmentDirectional.bottomEnd,
  sigmaStart: 0,
  sigmaEnd: 20,
  child: const SizedBox.expand(),
)
```

### 不提供 child 的纯模糊用法

`child` 可空：省略时只绘制背景模糊、不绘制前景内容，但组件仍需从父级获得尺寸——
宽松约束下无 child 的组件尺寸为 0，因此请用 `Positioned.fill`、`SizedBox` 等能提供紧约束的
父级撑开区域：

```dart
Positioned.fill(
  child: ProgressiveBlur(
    sigmaStart: 0,
    sigmaEnd: 20,
  ),
)
```

## 参数说明

| 参数           | 类型                  | 默认值                      | 说明                                                                                |
|--------------|---------------------|--------------------------|-----------------------------------------------------------------------------------|
| `begin`      | `AlignmentGeometry` | `Alignment.topCenter`    | 渐变起点在组件区域内的对齐位置                                                                   |
| `end`        | `AlignmentGeometry` | `Alignment.bottomCenter` | 渐变终点在组件区域内的对齐位置                                                                   |
| `sigmaStart` | `double`            | `0`                      | 起点的高斯模糊 sigma，对应 Figma **Start**；原样写入着色器，单位与背景快照纹理一致（物理像素），取值范围 0～100（含端点），超出会被钳制 |
| `sigmaEnd`   | `double`            | 必填                       | 终点的高斯模糊 sigma，对应 Figma **End**；规则同 `sigmaStart`                                   |
| `child`      | `Widget?`           | `null`                   | 绘制在模糊层之上的子组件，可空；为空时仍会对组件自身区域应用模糊（区域大小由父级约束决定），仅不绘制前景内容                            |

静态成员：

| 成员                               | 说明                                             |
|----------------------------------|------------------------------------------------|
| `ProgressiveBlur.precache()`     | 预编译并缓存着色器程序，建议在 `main()` 中 `runApp` 之前 `await` |
| `ProgressiveBlur.shaderAssetKey` | 着色器资源 Key（`lib/shaders/progressive_blur.frag`） |
| `ProgressiveBlur.maxSigma`       | sigma 取值上限常量，值为 `100`（含），与 Figma 限制一致          |

## 实现原理

通过片段着色器做两遍（水平 → 垂直）可分离高斯卷积，以
[`ui.ImageFilter.shader`](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html)
组合后作用于 `BackdropFilter` 的整屏背景快照；每个片元的 sigma 按其在 `begin` → `end`
连线上的位置在 `sigmaStart` 与 `sigmaEnd` 间线性插值。

模糊由组件自身的 RenderObject 应用：每次绘制时先解析渐变在屏幕上的位置并写入着色器
uniform，再推送覆盖组件自身区域的 `BackdropFilterLayer`，模糊随所属页面一起平移、
淡出与销毁（例如路由过渡动画期间）。

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