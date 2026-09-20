import 'package:flutter/material.dart';
import 'package:progressive_background_blur/progressive_background_blur.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 在首帧前预编译着色器，避免第一次进入页面时模糊“闪”一下。
  await ProgressiveBlur.precache();

  runApp(const MyApp());
}

/// 新的示例入口：底部悬浮渐变模糊工具栏场景。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Progressive Blur Demo',
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const BottomBlurPage(),
    );
  }
}

/// 演示 [ProgressiveBlur] 叠加在列表底部、作为悬浮工具栏背景的用法。
class BottomBlurPage extends StatefulWidget {
  const BottomBlurPage({super.key});

  @override
  State<BottomBlurPage> createState() => _BottomBlurPageState();
}

class _BottomBlurPageState extends State<BottomBlurPage> {
  double _sigmaEnd = 16;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('底部渐变模糊')),
      body: Stack(
        children: <Widget>[
          ListView.builder(
            itemCount: 40,
            itemBuilder: (BuildContext context, int index) {
              final Color color = HSVColor.fromAHSV(1, (index * 31) % 360, 0.6, 0.85).toColor();
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                height: 88,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '列表项 ${index + 1}',
                  style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _SigmaSlider(
                  label: 'End',
                  value: _sigmaEnd,
                  onChanged: (double value) => setState(() => _sigmaEnd = value),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ProgressiveBlur(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        sigmaStart: 0,
        sigmaEnd: _sigmaEnd,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: .3)],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                IconButton(icon: const Icon(Icons.home), onPressed: () {}),
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                IconButton(icon: const Icon(Icons.favorite), onPressed: () {}),
                IconButton(icon: const Icon(Icons.person), onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
      extendBody: true,
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
