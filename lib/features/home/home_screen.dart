import 'package:flutter/material.dart';

import '../bangumi/presentation/bangumi_tab.dart';
import '../dmhy/presentation/dmhy_tab.dart';
import '../playback/presentation/playback_tab.dart';
import '../torrent_handoff/presentation/torrent_handoff_tab.dart';

/// APP 首页壳。
///
/// 首页只承担顶层导航职责，不直接访问 Bangumi、DMHY 或 Android 平台能力。
/// 每个底部导航项都对应一个独立 feature，后续可以按模块逐步替换为真实页面。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _tabs = [
    _HomeTab(
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle,
      label: 'Bangumi',
      child: BangumiTab(),
    ),
    _HomeTab(
      icon: Icons.rss_feed_outlined,
      selectedIcon: Icons.rss_feed,
      label: 'DMHY',
      child: DmhyTab(),
    ),
    _HomeTab(
      icon: Icons.open_in_new_outlined,
      selectedIcon: Icons.open_in_new,
      label: '种子',
      child: TorrentHandoffTab(),
    ),
    _HomeTab(
      icon: Icons.play_circle_outline,
      selectedIcon: Icons.play_circle,
      label: '播放',
      child: PlaybackTab(),
    ),
  ];

  int _selectedIndex = 0;

  /// 切换首页模块。
  ///
  /// 使用 IndexedStack 保留各模块页面状态，为后续搜索框输入、分页位置和
  /// 授权状态展示预留稳定体验。
  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          children: _tabs.map((tab) => tab.child).toList(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: _tabs.map((tab) {
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
