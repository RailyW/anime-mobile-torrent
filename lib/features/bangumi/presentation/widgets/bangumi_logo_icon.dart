import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bangumi / bgm.tv 风格图标。
///
/// 组件内部渲染 Bangumi iOS 官方仓库中的 `bangumiFaviconFullSize.svg`，也就是
/// bgm.tv 电视气泡、天线和表情图标的完整矢量轮廓。相比 PNG，它没有灰色底色；
/// 相比手写 Canvas 近似图形，放大后也能和官方粉色区域保持一致。
class BangumiLogoIcon extends StatelessWidget {
  const BangumiLogoIcon({
    this.size = 24,
    this.color,
    this.emphasis = 1,
    super.key,
  });

  /// 官方 Bangumi favicon 矢量资源路径。
  static const String assetName =
      'assets/branding/bangumi_favicon_full_size.svg';

  /// 图标边长。
  final double size;

  /// 可选固定颜色。
  ///
  /// 未传入时保留官方 SVG 的粉色渐变和白色底面，确保放大后和原始图标区域一致。
  /// 只有当调用方明确需要单色 Material 图标语义时，才传入该字段进行染色。
  final Color? color;

  /// 视觉强调程度。
  ///
  /// 旧版手绘图标通过 `strokeWidth` 区分选中态。官方 SVG 是填充图形，不再有线宽
  /// 概念；这里保留一个轻量尺寸倍率，底部导航选中态可以略微放大，和 Material
  /// `NavigationBar` 的选中胶囊视觉重量更接近。
  final double emphasis;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Bangumi',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Transform.scale(
            scale: emphasis,
            child: SvgPicture.asset(
              assetName,
              width: size,
              height: size,
              colorFilter: color == null
                  ? null
                  : ColorFilter.mode(color!, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
