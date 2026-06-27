import 'package:flutter/material.dart';

import '../background/presentation/background_tab.dart';
import '../bangumi/presentation/bangumi_tab.dart';
import '../dmhy/presentation/dmhy_tab.dart';
import '../playback/presentation/playback_tab.dart';
import '../torrent_handoff/presentation/torrent_handoff_tab.dart';

/// APP 首页壳。
///
/// 首页只承担顶层导航职责，不直接访问 Bangumi、DMHY 或 Android 平台能力。
/// 每个底部导航项都对应一个独立 feature，后续可以按模块逐步替换为真实页面。
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.initialTabIndex = 0,
    this.initialDmhyKeyword,
    this.initialDmhyAnimeOnly = true,
    super.key,
  });

  /// 初次打开首页时选中的底部导航项。
  ///
  /// 目前用于 Bangumi 条目详情页跳回首页并直接展示 DMHY 搜索结果。
  final int initialTabIndex;

  /// 初次打开 DMHY 标签页时自动填入并搜索的关键词。
  final String? initialDmhyKeyword;

  /// 初次打开 DMHY 标签页时使用的搜索范围。
  ///
  /// 订阅检查可以从全站范围跳回 DMHY 搜索，因此这里不能固定为动画分类。
  final bool initialDmhyAnimeOnly;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _normalizeTabIndex(widget.initialTabIndex);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialTabIndex != widget.initialTabIndex ||
        oldWidget.initialDmhyKeyword != widget.initialDmhyKeyword ||
        oldWidget.initialDmhyAnimeOnly != widget.initialDmhyAnimeOnly) {
      setState(() {
        _selectedIndex = _normalizeTabIndex(widget.initialTabIndex);
      });
    }
  }

  /// 切换首页模块。
  ///
  /// 使用 IndexedStack 保留各模块页面状态，为搜索框输入、分页位置、
  /// 授权状态和后台服务控制状态预留稳定体验。
  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _HomeTab(
        icon: Icons.account_circle_outlined,
        selectedIcon: Icons.account_circle,
        label: 'Bangumi',
        child: BangumiTab(),
      ),
      _HomeTab(
        icon: Icons.rss_feed_outlined,
        selectedIcon: Icons.rss_feed,
        label: 'DMHY',
        child: DmhyTab(
          initialKeyword: widget.initialDmhyKeyword,
          initialAnimeOnly: widget.initialDmhyAnimeOnly,
        ),
      ),
      const _HomeTab(
        icon: Icons.open_in_new_outlined,
        selectedIcon: Icons.open_in_new,
        label: '种子',
        child: TorrentHandoffTab(),
      ),
      const _HomeTab(
        icon: Icons.play_circle_outline,
        selectedIcon: Icons.play_circle,
        label: '播放',
        child: PlaybackTab(),
      ),
      const _HomeTab(
        icon: Icons.notifications_active_outlined,
        selectedIcon: Icons.notifications_active,
        label: '后台',
        child: BackgroundTab(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anime Mobile Torrent'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: null,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: tabs.map((tab) => tab.child).toList(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: tabs.map((tab) {
          return NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }
}

int _normalizeTabIndex(int value) {
  if (value < 0) {
    return 0;
  }

  if (value > 4) {
    return 4;
  }

  return value;
}

class _HomeTab {
  const _HomeTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget child;
}
