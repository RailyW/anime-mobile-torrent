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
}
