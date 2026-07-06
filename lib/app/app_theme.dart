import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Sakura 设计系统的品牌色。
///
/// 选用接近 Bangumi 的樱粉作为种子色，让亮色与暗色主题的中性色都带上
/// 一点暖粉调，从而在白底粉色与黑底粉色两种模式下保持同一种气质。
const _sakuraSeed = Color(0xFFE0507E);

/// 资源交接等“去外部完成”的动作使用的暖橘强调色。
///
/// 它与主粉色形成区分，专门承载“打开 / 分享 / 交给外部客户端”这类跳出动作，
/// 避免页面里所有按钮都是同一种粉色而失去层次。
const _emberAccent = Color(0xFFE8743B);

/// 表示“完成 / 可用 / 已看”等正向状态的柔和青绿色。
const _leafAccent = Color(0xFF3FA796);

/// 亮色模式下的卡片底色：纯白，与略暖的页面底色([_lightScaffold])拉开层次。
const _lightSurface = Color(0xFFFFFFFF);

/// 亮色模式下的页面底色（`--bg`），比纯白略暖，避免纯白显得生硬，也让白卡浮起。
const _lightScaffold = AppColors.bg;

/// 暗色模式下的页面底色，是带暖调的近黑色，衬托粉色不刺眼。
const _darkSurface = Color(0xFF161013);

/// 构建亮色主题。
///
/// 以樱粉种子色生成 Material 3 配色，再覆盖主色、强调色与底色，保证
/// “白底粉色”观感统一。圆角、字体比例等组件风格在 [_composeTheme] 内集中维护。
ThemeData buildLightTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _sakuraSeed,
        brightness: Brightness.light,
      ).copyWith(
        primary: _sakuraSeed,
        secondary: _emberAccent,
        tertiary: _leafAccent,
        surface: _lightSurface,
        // 用中性灰覆盖 sakura 种子派生的“带粉调”容器 / 描边 / 次文字色，
        // 让分段控件容器、卡片描边、分隔线、副文字回到设计稿干净的中性灰。
        surfaceContainerHighest: AppColors.surface2,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.ink2,
        outlineVariant: AppColors.line2,
      );

  return _composeTheme(scheme, scaffoldBackground: _lightScaffold);
}

/// 构建暗色主题。
///
/// 暗色模式沿用同一套语义色，但把主色调亮为浅樱粉，强调色与正向色也相应提亮，
/// 保证“黑底粉色”在夜间既醒目又不过曝。
ThemeData buildDarkTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _sakuraSeed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFFFB1C7),
        secondary: const Color(0xFFF7A06E),
        tertiary: const Color(0xFF7FD1C1),
        surface: _darkSurface,
      );

  return _composeTheme(scheme, scaffoldBackground: _darkSurface);
}

/// 组装亮色与暗色共享的组件风格。
///
/// 这里统一管理圆角、字体比例与各组件外观，让全局视觉只有一个事实来源：
/// 卡片用 16px 圆角加 1px 描边、零阴影；按钮用 12px 圆角；导航栏使用
/// 药丸形指示器并始终显示文字标签，整体偏柔和、亲和的消费级 App 气质。
ThemeData _composeTheme(ColorScheme scheme, {required Color scaffoldBackground}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBackground,
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = _composeTextTheme(base.textTheme, scheme);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// 调整全局字体比例。
///
/// 让大标题更有分量、正文行高更舒展，整体阅读节奏更接近消费级内容 App，
/// 而不是默认 Material 那种偏中性的工具感。
TextTheme _composeTextTheme(TextTheme base, ColorScheme scheme) {
  return base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: scheme.onSurface,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: scheme.onSurface,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
    bodySmall: base.bodySmall?.copyWith(height: 1.4),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );
}
