/// @Describe: 渐进式背景模糊
///
/// @Author: LiWeNHuI
/// @Date: 2026/09/14
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 对应 Figma：Effects -> Background blur -> Progressive（Start / End）。
///
/// 用法与 [BackdropFilter] 一致：直接包裹子组件，真正被模糊的是组件**背后**的场景内容
/// （例如导航栏背后滚动的列表），[child] 本身不被模糊，绘制在模糊层之上。
///
/// 模糊量沿 [begin] 到 [end] 的连线，由 [sigmaStart] 线性过渡到 [sigmaEnd]：
/// - 起点/终点是组件自身区域内的对齐位置，默认自上而下
///   （[Alignment.topCenter] -> [Alignment.bottomCenter]），支持任意方向及对角线；
/// - 传入 [AlignmentDirectional] 时按当前 [Directionality] 解析；
/// - 例如 sigmaStart: 0、sigmaEnd: 20 即起点清晰、终点最模糊。
///
/// sigma 原样写入着色器，单位与背景快照纹理一致（物理像素）；取值范围与 Figma 一致为
/// 0～[maxSigma]（100，含端点），超出会被钳制到区间内。卷积核半径为 3σ、最多 255 个
/// 采样点，因此 sigma 超过约 42 后实际模糊量不再继续增大。
///
/// 仅支持 Impeller：通过 `ui.ImageFilter.shader` 以两遍（水平 / 垂直）可分离高斯卷积
/// 实现，由内部的 [BackdropFilterLayer] 合成。以下情况不做模糊、原样呈现 [child]：
/// - 运行在 Skia 后端（`ui.ImageFilter.isShaderFilterSupported` 为 false）；
/// - 着色器尚未加载完成的首帧（建议在 `runApp()` 前调用 [precache] 预编译）；
/// - [sigmaStart] 与 [sigmaEnd] 均为 0。
///
/// 使用限制：
/// - 组件的全局位置仅在 paint 阶段读取一次。若祖先通过纯合成层位移移动本组件
///   （[AnimatedSlide]、[FractionalTranslation]，或命中图层缓存的 `Transform.translate`），
///   本节点不会重新 paint，移动过程中渐变带会与组件错位，需由调用方主动触发重绘。
/// - 不支持祖先存在旋转/缩放等非平移变换：begin/end 按轴对齐矩形换算，变换后位置不成立。
/// - 渐变定位所用的视口尺寸取自 `MediaQuery.sizeOf`；若祖先覆写了 `MediaQuery.size`，
///   归一化坐标会与真实视口不一致，渐变位置可能偏移。
/// - 组件部分移出屏幕时，渐变会被重新映射到可见区域（边缘被裁断），与 Figma 中
///   “沿组件完整尺寸渐变”的语义略有差异。
class ProgressiveBlur extends StatefulWidget {
  const ProgressiveBlur({
    super.key,
    this.begin = .topCenter,
    this.end = .bottomCenter,
    this.sigmaStart = 0,
    required this.sigmaEnd,
    required this.child,
  });

  /// 渐变起点在本组件区域内的对齐位置，默认为 [Alignment.topCenter]。
  final AlignmentGeometry begin;

  /// 渐变终点在本组件区域内的对齐位置，默认为 [Alignment.bottomCenter]。
  final AlignmentGeometry end;

  /// 渐变起点的高斯模糊 sigma，对应 Figma 的 Start。
  ///
  /// 原样写入着色器，单位与背景快照纹理一致（物理像素）；取值范围为 0～100（含端点），
  /// 与 Figma 限制一致，超出会被钳制。
  final double sigmaStart;

  /// 渐变终点的高斯模糊 sigma，对应 Figma 的 End。
  ///
  /// 原样写入着色器，单位与背景快照纹理一致（物理像素）；取值范围为 0～100（含端点），
  /// 与 Figma 限制一致，超出会被钳制。
  final double sigmaEnd;

  /// 模糊层之上的子组件（通常是半透明渐变填充等）。
  final Widget child;

  /// sigma 的取值上限（含），与 Figma Background blur 的 0～100 限制一致。
  static const double maxSigma = 100;

  /// 着色器资源 Key（需在 pubspec.yaml 的 shaders 中注册）。
  static const String shaderAssetKey = 'packages/progressive_background_blur/lib/shaders/progressive_blur.frag';

  /// 着色器程序，应用启动时通过 precache 预加载。
  static ui.FragmentProgram? _program;

  /// 预编译着色器，避免使用首帧卡顿。建议在 `main()` 中 `runApp` 之前调用。
  static Future<void> precache() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    _program ??= await ui.FragmentProgram.fromAsset(shaderAssetKey);
  }

  @override
  State<ProgressiveBlur> createState() => _ProgressiveBlurState();
}

class _ProgressiveBlurState extends State<ProgressiveBlur> {
  @override
  void initState() {
    super.initState();

    if (ProgressiveBlur._program == null && ui.ImageFilter.isShaderFilterSupported) {
      /// 加载失败时静默降级为不模糊，避免未捕获的异步错误。
      ProgressiveBlur.precache()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui.FragmentProgram? program = ProgressiveBlur._program;

    /// Skia 后端不支持着色器背景滤镜，不做模糊处理。
    /// 着色器尚未加载完成的首帧不做模糊，加载完成后下一帧切换。
    if (!ui.ImageFilter.isShaderFilterSupported || program == null) return widget.child;

    /// 与 Figma 一致，sigma 取值钳制在 0～100（含端点）；两端都为 0 时 shader 仅做
    /// identity 采样，但仍有 saveLayer 开销，直接返回子组件。
    final double sigmaStart = widget.sigmaStart.clamp(0.0, ProgressiveBlur.maxSigma);
    final double sigmaEnd = widget.sigmaEnd.clamp(0.0, ProgressiveBlur.maxSigma);
    if (sigmaStart == 0 && sigmaEnd == 0) return widget.child;

    /// AlignmentDirectional 按当前文字方向解析。
    final TextDirection textDirection = Directionality.maybeOf(context) ?? .ltr;

    return _ShaderBackdropBlur(
      program: program,
      begin: widget.begin.resolve(textDirection),
      end: widget.end.resolve(textDirection),
      sigmaStart: sigmaStart,
      sigmaEnd: sigmaEnd,
      viewSize: MediaQuery.sizeOf(context),
      child: widget.child,
    );
  }
}

/// Impeller 后端：通过自定义 RenderObject 推送 BackdropFilterLayer，在 paint 阶段拿到组件的全局位置后再写入着色器 uniform。
class _ShaderBackdropBlur extends SingleChildRenderObjectWidget {
  const _ShaderBackdropBlur({
    required this.program,
    required this.begin,
    required this.end,
    required this.sigmaStart,
    required this.sigmaEnd,
    required this.viewSize,
    required super.child,
  });

  final ui.FragmentProgram program;

  /// 渐变起/止点在本组件区域内的对齐位置（已解析 Directionality）。
  final Alignment begin;
  final Alignment end;

  /// 高斯 sigma，原样透传（与背景快照纹理同单位，即物理像素）。
  final double sigmaStart;
  final double sigmaEnd;

  /// 视口逻辑尺寸（MediaQuery.sizeOf），
  /// 用于把组件全局位置换算成背景纹理中的归一化坐标。
  final Size viewSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderShaderBackdropBlur(
    program: program,
    begin: begin,
    end: end,
    sigmaStart: sigmaStart,
    sigmaEnd: sigmaEnd,
    viewSize: viewSize,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderShaderBackdropBlur renderObject) => renderObject
    ..begin = begin
    ..end = end
    ..sigmaStart = sigmaStart
    ..sigmaEnd = sigmaEnd
    ..viewSize = viewSize;
}

class _RenderShaderBackdropBlur extends RenderProxyBox {
  _RenderShaderBackdropBlur({
    required ui.FragmentProgram program,
    required Alignment begin,
    required Alignment end,
    required double sigmaStart,
    required double sigmaEnd,
    required Size viewSize,
  }) : _begin = begin,
       _end = end,
       _sigmaStart = sigmaStart,
       _sigmaEnd = sigmaEnd,
       _viewSize = viewSize,
       _horizontalShader = program.fragmentShader(),
       _verticalShader = program.fragmentShader();

  /// 水平、垂直两个 pass 各持一个着色器实例（可分离高斯），可长期复用。
  final ui.FragmentShader _horizontalShader;
  final ui.FragmentShader _verticalShader;

  /// 水平 + 垂直两遍组合后的背景滤镜，每次 paint 都重新创建。
  ///
  /// 注意不能复用同一个滤镜：引擎侧 `ui.ImageFilter.shader` 对应的
  /// `_FragmentShaderImageFilter.nativeFilter` 是 `late final`，首次使用时
  /// 会把当时的 uniform 拷贝成一份快照（引擎 `as_image_filter()` 中 memcpy），
  /// 之后再对 FragmentShader 调用 setFloat 不会反映到已创建的滤镜上。
  /// 因此必须在写完 uniform 之后重新构造滤镜，参数变化才能生效。
  ui.ImageFilter? _filter;

  Alignment _begin;

  Alignment get begin => _begin;

  set begin(Alignment value) {
    if (value == _begin) return;
    _begin = value;
    markNeedsPaint();
  }

  Alignment _end;

  Alignment get end => _end;

  set end(Alignment value) {
    if (value == _end) return;
    _end = value;
    markNeedsPaint();
  }

  /// 起止 sigma，原样透传（与背景快照纹理同单位，即物理像素）。
  double _sigmaStart;

  double get sigmaStart => _sigmaStart;

  set sigmaStart(double value) {
    if (value == _sigmaStart) return;
    _sigmaStart = value;
    markNeedsPaint();
  }

  double _sigmaEnd;

  double get sigmaEnd => _sigmaEnd;

  set sigmaEnd(double value) {
    if (value == _sigmaEnd) return;
    _sigmaEnd = value;
    markNeedsPaint();
  }

  Size _viewSize;

  Size get viewSize => _viewSize;

  set viewSize(Size value) {
    if (value == _viewSize) return;
    _viewSize = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  /// 写入除引擎自动填充（索引 0/1 的 vec2 与 sampler）以外的全部 uniform。
  ///
  /// 索引 2/3 为起止 sigma（物理像素），4 为方向，
  /// 5/6、7/8 分别为渐变起、止点在整屏背景纹理中的归一化坐标。
  void _configureShader(ui.FragmentShader shader, double direction, Offset beginPoint, Offset endPoint) => shader
    ..setFloat(2, _sigmaStart)
    ..setFloat(3, _sigmaEnd)
    ..setFloat(4, direction)
    ..setFloat(5, beginPoint.dx)
    ..setFloat(6, beginPoint.dy)
    ..setFloat(7, endPoint.dx)
    ..setFloat(8, endPoint.dy);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }

    final Offset globalTopLeft = localToGlobal(Offset.zero);
    final double left = (globalTopLeft.dx / _viewSize.width).clamp(0, 1);
    final double top = (globalTopLeft.dy / _viewSize.height).clamp(0, 1);
    final double right = ((globalTopLeft.dx + size.width) / _viewSize.width).clamp(0, 1);
    final double bottom = ((globalTopLeft.dy + size.height) / _viewSize.height).clamp(0, 1);

    /// Alignment（-1..1）映射到本区域内的归一化纹理坐标，y 自上而下，与 FlutterFragCoord 的方向一致。
    Offset alignmentToPoint(Alignment alignment) {
      return Offset(left + (alignment.x + 1) / 2 * (right - left), top + (alignment.y + 1) / 2 * (bottom - top));
    }

    final Offset beginPoint = alignmentToPoint(_begin);
    final Offset endPoint = alignmentToPoint(_end);

    _configureShader(_horizontalShader, 0, beginPoint, endPoint);
    _configureShader(_verticalShader, 1, beginPoint, endPoint);

    /// 必须在 uniform 写入之后再创建滤镜：引擎首次使用滤镜时会快照 uniform，
    /// 复用旧滤镜会导致 sigma / 渐变方向变化后画面不更新。
    _filter = ui.ImageFilter.compose(
      inner: ui.ImageFilter.shader(_horizontalShader),
      outer: ui.ImageFilter.shader(_verticalShader),
    );

    assert(needsCompositing);
    layer ??= BackdropFilterLayer();
    layer!
      ..filter = _filter
      ..blendMode = .srcOver;
    context.pushLayer(layer!, super.paint, offset);
  }

  @override
  void dispose() {
    _horizontalShader.dispose();
    _verticalShader.dispose();
    super.dispose();
  }
}
