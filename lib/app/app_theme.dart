import 'package:flutter/material.dart';

const _brandTeal = Color(0xFF246B73);
const _warmAccent = Color(0xFFC45A3A);
const _quietGreen = Color(0xFF4E7B45);
const _paperSurface = Color(0xFFFAFAF7);

/// 构建亮色主题。
///
/// 主色用于导航与关键按钮，暖色用于资源交接动作，绿色用于完成或可用状态。
/// 这样可以避免首屏被单一蓝紫色调淹没，也为后续下载/交接状态预留明确语义。
ThemeData buildLightTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _brandTeal,
        brightness: Brightness.light,
      ).copyWith(
        primary: _brandTeal,
        secondary: _warmAccent,
        tertiary: _quietGreen,
        surface: _paperSurface,
      );

  return _buildBaseTheme(scheme);
}

/// 构建暗色主题。
///
/// 暗色主题保留同一套语义颜色，方便系统夜间模式下仍能区分 Bangumi、
/// DMHY、种子交接和播放入口的状态。
ThemeData buildDarkTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _brandTeal,
        brightness: Brightness.dark,
      ).copyWith(
        secondary: const Color(0xFFE08A68),
        tertiary: const Color(0xFF88B77C),
      );

  return _buildBaseTheme(scheme);
}

/// 组装亮色和暗色共享的 Material 组件风格。
///
/// 所有圆角控制在较克制的 8px 左右，适合工具型应用长期浏览和重复操作。
ThemeData _buildBaseTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
