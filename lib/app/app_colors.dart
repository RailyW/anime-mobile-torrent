import 'package:flutter/material.dart';

/// Sakura 设计系统的软色常量。
///
/// 主题层([app_theme.dart])已经把 sakura / ember / leaf 三支语义色绑进了
/// Material 3 的 `ColorScheme`。但设计稿里还大量用到一批**手挑的柔和背景色**
/// (`--sakura-soft`、`--ember-soft`、`--leaf-soft`)、金色评分星(`--gold`)与
/// 深墨底色(`--ink`),这些无法从 seed 算法生成的 `xxxContainer` 精确复现——
/// seed 派生的容器色与设计稿手挑软色存在肉眼可辨的色相偏差,直接复用会让页面
/// 逐渐偏离已批准的稿子。
///
/// 因此这里把设计稿的原始十六进制值集中导出为唯一事实来源,供各页面在需要与
/// 设计稿像素级对齐的地方引用(如封面网格角标、详情页深色 hero、评分金星)。
/// 普通语义色仍应优先走 `Theme.of(context).colorScheme`,只有软色/定值色才来
/// 这里取,避免绕过主题体系。
abstract final class AppColors {
  /// 品牌主粉(`--sakura`)。与主题 primary 同值,方便非 build 上下文取用。
  static const Color sakura = Color(0xFFE0507E);

  /// 主粉的加深版(`--sakura-ink`),用于粉色文字在浅底上的高对比呈现。
  static const Color sakuraInk = Color(0xFFB23360);

  /// 暖橘强调色(`--ember`),承载“打开 / 分享 / 交给外部客户端”这类跳出动作。
  static const Color ember = Color(0xFFE8743B);

  /// 正向状态青绿(`--leaf`),表示“完成 / 可用 / 已看”。
  static const Color leaf = Color(0xFF2F9E8C);

  /// 评分金星色(`--gold`)。
  static const Color gold = Color(0xFFEFA524);

  /// 深墨底色(`--ink`),用于详情页深色沉浸式 hero 的压暗渐变。
  static const Color ink = Color(0xFF1B1418);

  /// 樱粉柔和背景(`--sakura-soft`),用于品牌信息的浅底块。
  static const Color sakuraSoft = Color(0xFFFCE7EF);

  /// 暖橘柔和背景(`--ember-soft`)。
  static const Color emberSoft = Color(0xFFFBEADF);

  /// 青绿柔和背景(`--leaf-soft`),用于“已看”类角标底色。
  static const Color leafSoft = Color(0xFFE0F1EE);

  /// 页面底色(`--bg`),比纯白略暖,衬托白色卡片。
  static const Color bg = Color(0xFFFBFAFB);

  /// 分组浅底(`--surface-2`),用于分段控件容器、输入框底、信息 chip 底。
  ///
  /// 这是一支**中性**浅灰,刻意避开由 sakura 种子派生的 `surfaceContainerHighest`
  /// (带可见粉调),以还原设计稿干净的灰底。
  static const Color surface2 = Color(0xFFF4F2F5);

  /// 次文字(`--ink-2`),用于副标题、chip 文字等二级信息。
  static const Color ink2 = Color(0xFF5C545B);

  /// 三级文字(`--muted`),用于弱化说明、未选中态文字。
  static const Color muted = Color(0xFF958D95);

  /// 发丝分隔线(`--line`)。
  static const Color line = Color(0xFFECE8EE);

  /// 描边线(`--line-2`),用于卡片 / chip / 分段容器的 1px 描边。
  static const Color line2 = Color(0xFFE2DDE4);
}
