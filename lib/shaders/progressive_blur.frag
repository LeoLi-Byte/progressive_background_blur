#version 460 core
#include <flutter/runtime_effect.glsl>

// 用于 ImageFilter.shader + BackdropFilter：
// 引擎自动写入第一个 vec2 uniform（输入纹理尺寸）并绑定第一个 sampler2D（背景输入）。
// 注意：作为背景滤镜时，背景输入是整屏快照，ImageFilter.compose 第二遍的中间快照同样
// 按整屏覆盖域分配；而 FlutterFragCoord() 取的是几何顶点 position（矩形从 (0,0) 排到
// u_size），并非 gl_FragCoord，所以两遍中它都是相对整屏纹理的像素坐标。组件自身只占
// 屏幕一小块，不能直接用 fragCoord / u_size 当作组件内 0..1 的渐变位置，需由外部传入
// 起止点在整屏纹理中的归一化坐标（u_begin / u_end）。

#define MAX_KERNEL_SIZE 255

uniform vec2 u_size;           // 引擎自动写入：输入纹理尺寸（背景快照，通常为整屏物理像素）
uniform sampler2D u_texture;   // 引擎自动绑定：待模糊的背景

uniform float u_sigma_start;   // 渐变起点 u_begin 处的高斯 sigma，对应 Figma Start；单位为输入纹理像素（物理像素），由调用方原样传入
uniform float u_sigma_end;     // 渐变终点 u_end 处的高斯 sigma，对应 Figma End；单位同上
uniform float u_direction;     // 0 = 横向卷积，1 = 纵向卷积（compose 两次实现可分离高斯）
uniform vec2 u_begin;          // 渐变起点在输入纹理中的归一化坐标（0~1，y 自上而下）
uniform vec2 u_end;            // 渐变终点在输入纹理中的归一化坐标（0~1，y 自上而下）

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;

  // 采样坐标：Impeller 在 OpenGL(ES) 后端下纹理 y 轴反向；
  // 而 FlutterFragCoord 的 y 始终自上而下，不受影响。
  vec2 sample_uv = uv;
#ifdef IMPELLER_TARGET_OPENGLES
  sample_uv.y = 1.0 - uv.y;
#endif

  // 渐变参数 t：片元坐标在 begin->end 连线上的投影比例，仅在两点之间从 0 线性变化到 1。
  // begin/end 重合（区域宽或高塌缩为 0）时分母兜底，防止除零产生 NaN。
  vec2 axis = u_end - u_begin;
  float t = clamp(dot(uv - u_begin, axis) / max(dot(axis, axis), 1e-10), 0.0, 1.0);
  float sigma = mix(u_sigma_start, u_sigma_end, t);
  vec2 dir = u_direction == 0.0 ? vec2(1.0, 0.0) : vec2(0.0, 1.0);

  // 起点无模糊，直接采样输出。
  if (sigma < 1e-5) {
    frag_color = texture(u_texture, sample_uv);
    return;
  }

  // 高斯核半径取 3σ（覆盖 99.7% 权重）。GLSL 的循环上界必须是常量，因此采样数上限
  // 为 MAX_KERNEL_SIZE（半径最多 127，对应 σ≈42.3）；触顶后把有效 σ 一并钳制到
  // 127/3，使更大的输入不会改变权重形状，模糊量在 255 个采样点处饱和。
  int kernel_radius = int(ceil(3.0 * sigma));
  if (kernel_radius > MAX_KERNEL_SIZE / 2) {
    kernel_radius = MAX_KERNEL_SIZE / 2;
    sigma = float(kernel_radius) / 3.0;
  }
  int kernel_size = 2 * kernel_radius + 1;

  vec4 color = vec4(0.0);
  float total_weight = 0.0;
  for (int i = 0; i < MAX_KERNEL_SIZE; i++) {
    if (i >= kernel_size) {
      break;
    }

    int v = i - kernel_radius;
    float weight = exp(-float(v * v) / (2.0 * sigma * sigma));
    total_weight += weight;

    vec2 offset = vec2(float(v)) / u_size;
    color += texture(u_texture, sample_uv + offset * dir) * weight;
  }

  frag_color = color / total_weight;
}
