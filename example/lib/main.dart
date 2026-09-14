import 'package:flutter/material.dart';
import 'package:progressive_background_blur/progressive_background_blur.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 在首帧前预编译着色器，避免第一次进入页面时模糊“闪”一下。
  await ProgressiveBlur.precache();

  runApp(const ProgressiveBlurDemoApp());
}

/// 渐变方向预设，对应 [ProgressiveBlur.begin] / [ProgressiveBlur.end] 两个参数。
enum GradientDirection {
  bottomToTop('下 → 上', Alignment.bottomCenter, Alignment.topCenter),
  topToBottom('上 → 下', Alignment.topCenter, Alignment.bottomCenter),
  leftToRight('左 → 右', Alignment.centerLeft, Alignment.centerRight),
  topLeftToBottomRight('左上 → 右下', Alignment.topLeft, Alignment.bottomRight);

  const GradientDirection(this.label, this.begin, this.end);

  final String label;
  final Alignment begin;
  final Alignment end;
}

class ProgressiveBlurDemoApp extends StatelessWidget {
  const ProgressiveBlurDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progressive Blur Demo',
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  GradientDirection _direction = GradientDirection.bottomToTop;
  double _sigmaStart = 0;
  double _sigmaEnd = 4;

  @override
  Widget build(BuildContext context) {
    Widget child = ListView.builder(
      itemCount: 40,
      itemBuilder: (BuildContext context, int index) {
        final Color color = HSVColor.fromAHSV(1, (index * 23) % 360, 0.7, 0.9).toColor();
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          height: 88,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '背景内容 ${index + 1}',
            style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        );
      },
    );

    child = Stack(
      children: <Widget>[
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ProgressiveBlur(
            begin: _direction.begin,
            end: _direction.end,
            sigmaStart: _sigmaStart,
            sigmaEnd: _sigmaEnd,
            child: Container(
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                /// 模拟 Figma 中常见的半透明叠色，模糊本身由 ProgressiveBlur 完成。
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: const SafeArea(
                bottom: false,
                child: Text(
                  'Progressive Blur\nFigma Effects → Background blur → Progressive',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: child,
      bottomNavigationBar: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                children: GradientDirection.values.map((GradientDirection direction) {
                  return ChoiceChip(
                    label: Text(direction.label),
                    selected: _direction == direction,
                    onSelected: (_) {
                      setState(() => _direction = direction);
                    },
                  );
                }).toList(),
              ),
              _SigmaSlider(
                label: 'Start',
                value: _sigmaStart,
                onChanged: (double value) => setState(() => _sigmaStart = value),
              ),
              _SigmaSlider(
                label: 'End',
                value: _sigmaEnd,
                onChanged: (double value) => setState(() => _sigmaEnd = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SigmaSlider extends StatelessWidget {
  const _SigmaSlider({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 44, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            max: ProgressiveBlur.maxSigma,
            divisions: ProgressiveBlur.maxSigma.toInt(),
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text(value.toStringAsFixed(0))),
      ],
    );
  }
}
