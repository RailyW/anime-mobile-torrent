import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bangumi / bgm.tv 风格图标。
///
/// 这里不直接打包站点 PNG，而是用 Flutter Canvas 重绘一个透明背景的矢量图标。
/// 这样它可以自然跟随导航栏和标题栏的 IconTheme 变色，也不会在不同 DPI 下出现
/// 位图缩放发糊或非透明底色的问题。图形语义来自 bgm.tv 的电视气泡、天线和
/// 表情轮廓，但只保留移动端导航所需的简洁线条。
class BangumiLogoIcon extends StatelessWidget {
  const BangumiLogoIcon({
    this.size = 24,
    this.color,
    this.strokeWidth = 2.1,
    super.key,
  });

  /// 图标边长。
  final double size;

  /// 可选固定颜色。
  ///
  /// 未传入时使用当前 [IconTheme] 颜色，因此放进 `NavigationDestination`、
  /// `IconButton` 或标题栏时会自动继承选中/未选中的颜色。
  final Color? color;

  /// 线条粗细。
  ///
  /// 底部导航选中态可以传入稍粗一点的值，让矢量图标和 Material 图标的视觉重量
  /// 更接近。
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedColor =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: 'Bangumi',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BangumiLogoPainter(
            color: resolvedColor,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

/// Bangumi 图标矢量绘制器。
///
/// 坐标系以 24x24 为基准，再按实际尺寸等比缩放。所有线条都使用圆角端点和圆角
/// 连接，保证在小尺寸导航栏中仍然柔和可读。
class _BangumiLogoPainter extends CustomPainter {
  const _BangumiLogoPainter({required this.color, required this.strokeWidth});

  /// 图标线条颜色。
  final Color color;

  /// 以 24x24 坐标系为基准的线条粗细。
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final scale = side / 24;
    final dx = (size.width - side) / 2;
    final dy = (size.height - side) / 2;

    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawAntenna(canvas, paint);
    _drawBubble(canvas, paint);
    _drawFace(canvas, paint);

    canvas.restore();
  }

  /// 绘制顶部天线。
  ///
  /// 两条斜线落在电视气泡顶部中心，保留 bgm.tv 图标最容易被识别的轮廓特征。
  void _drawAntenna(Canvas canvas, Paint paint) {
    canvas.drawLine(const Offset(12, 7), const Offset(6.5, 1.8), paint);
    canvas.drawLine(const Offset(12, 7), const Offset(17.5, 1.8), paint);
  }

  /// 绘制电视气泡主体。
  ///
  /// 右上、右下和左上使用圆角，底部加入一个向下的小尾巴，表达原图标中的
  /// “电视 + 对话气泡”形态。
  void _drawBubble(Canvas canvas, Paint paint) {
    final bubble = Path()
      ..moveTo(5.3, 7)
      ..lineTo(18.7, 7)
      ..quadraticBezierTo(21, 7, 21, 9.3)
      ..lineTo(21, 15.7)
      ..quadraticBezierTo(21, 18, 18.7, 18)
      ..lineTo(11.2, 18)
      ..lineTo(7.1, 22)
      ..lineTo(8.4, 18)
      ..lineTo(5.3, 18)
      ..quadraticBezierTo(3, 18, 3, 15.7)
      ..lineTo(3, 9.3)
      ..quadraticBezierTo(3, 7, 5.3, 7)
      ..close();

    canvas.drawPath(bubble, paint);
  }

  /// 绘制表情。
  ///
  /// “><”眼睛、倒三角嘴和两侧短横线对应 bgm.tv 图标里的表情符号。线条保持
  /// 简化，避免小尺寸下糊成一团。
  void _drawFace(Canvas canvas, Paint paint) {
    final leftEye = Path()
      ..moveTo(5.6, 11.1)
      ..lineTo(8.8, 12.6)
      ..lineTo(5.6, 14.1);
    final rightEye = Path()
      ..moveTo(18.4, 11.1)
      ..lineTo(15.2, 12.6)
      ..lineTo(18.4, 14.1);
    final mouth = Path()
      ..moveTo(9.7, 12.2)
      ..lineTo(14.3, 12.2)
      ..lineTo(12, 16.3)
      ..close();

    canvas
      ..drawPath(leftEye, paint)
      ..drawPath(rightEye, paint)
      ..drawPath(mouth, paint)
      ..drawLine(const Offset(3.9, 15.5), const Offset(7.2, 15.5), paint)
      ..drawLine(const Offset(3.9, 16.9), const Offset(7.2, 16.9), paint)
      ..drawLine(const Offset(16.8, 15.5), const Offset(20.1, 15.5), paint)
      ..drawLine(const Offset(16.8, 16.9), const Offset(20.1, 16.9), paint);
  }

  @override
  bool shouldRepaint(covariant _BangumiLogoPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}
