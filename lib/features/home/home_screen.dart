import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bangumi/presentation/bangumi_tab.dart';
import '../bangumi/presentation/widgets/bangumi_logo_icon.dart';
import '../dmhy/domain/dmhy_entry_context.dart';
import '../dmhy/presentation/dmhy_tab.dart';
import '../playback/presentation/playback_page.dart';
import '../profile/presentation/profile_tab.dart';
import '../torrent_handoff/presentation/torrent_page.dart';
import '../background/presentation/background_page.dart';

/// “我的”页进入后需要立即打开的子页面。
///
/// 后台通知或跨模块跳转会把用户带到“我的”tab，再根据该值自动推入对应子页面，
/// 让用户从通知直接看到目标功能，而不是停在“我的”首页。
enum HomeProfileDestination {
  /// 不自动打开任何子页面。
  none,

  /// 自动打开后台与订阅页。
  background,

  /// 自动打开本地播放页。
  playback,

  /// 自动打开种子工具页。
  torrent,
}

/// APP 首页壳。
///
/// 首页只承担三段式底部导航：Bangumi、资源、我的。每个 tab 对应一个独立 feature
/// 页面，首页本身不直接调用 Bangumi、DMHY 或 Android 平台能力，只负责在 tab
/// 之间切换，并把深链参数透传给对应模块。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    this.initialTabIndex = 0,
    this.initialDmhyKeyword,
    this.initialDmhyAnimeOnly = true,
    this.initialDmhyEntryContext = DmhyEntryContext.normal,
    this.initialPlaybackEntryContext = PlaybackEntryContext.normal,
    this.initialProfileDestination = HomeProfileDestination.none,
    super.key,
  });

  /// 初次打开首页时选中的底部导航项（0 Bangumi / 1 资源 / 2 我的）。
  final int initialTabIndex;

  /// 初次打开资源 tab 时自动填入并搜索的关键词。
  final String? initialDmhyKeyword;

  /// 初次打开资源 tab 时使用的搜索范围。
  ///
  /// 订阅检查可以从全站范围跳回 DMHY 搜索，因此这里不能固定为动画分类。
  final bool initialDmhyAnimeOnly;

  /// 初次打开资源 tab 时展示的入口语境。
  ///
  /// 首页只透传展示语境，真实搜索、订阅保存和种子交接仍由 DMHY 模块处理。
  final DmhyEntryContext initialDmhyEntryContext;

  /// 自动打开播放页时使用的入口语境。
  ///
  /// 该字段只影响播放页提示文案，不会触发文件扫描或外部 BT 客户端读取。
  final PlaybackEntryContext initialPlaybackEntryContext;

  /// 进入“我的”tab 后需要自动打开的子页面。
  final HomeProfileDestination initialProfileDestination;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _normalizeTabIndex(widget.initialTabIndex);
    _scheduleProfileDestination(widget.initialProfileDestination);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialTabIndex != widget.initialTabIndex ||
        oldWidget.initialDmhyKeyword != widget.initialDmhyKeyword ||
        oldWidget.initialDmhyAnimeOnly != widget.initialDmhyAnimeOnly ||
        oldWidget.initialDmhyEntryContext != widget.initialDmhyEntryContext ||
        oldWidget.initialPlaybackEntryContext !=
            widget.initialPlaybackEntryContext) {
      setState(() {
        _selectedIndex = _normalizeTabIndex(widget.initialTabIndex);
      });
    }

    if (oldWidget.initialProfileDestination !=
        widget.initialProfileDestination) {
      _scheduleProfileDestination(widget.initialProfileDestination);
    }
  }

  /// 切换底部导航 tab。
  ///
  /// 使用 IndexedStack 保留各 tab 页面状态，为搜索输入、分页位置、授权状态等
  /// 预留稳定体验。
  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// 在当前帧结束后，根据深链请求自动打开“我的”页下的子页面。
  ///
  /// 后台通知跳转、DMHY 种子交接“去播放”等场景会带上目标子页面。这里先切到
  /// “我的”tab，再在下一帧用根导航器推入对应页面，避免在 build 周期内触发导航。
  void _scheduleProfileDestination(HomeProfileDestination destination) {
    if (destination == HomeProfileDestination.none) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedIndex = _profileTabIndex;
      });

      final navigator = Navigator.of(context);
      switch (destination) {
        case HomeProfileDestination.background:
          navigator.push(
            MaterialPageRoute<void>(builder: (_) => const BackgroundPage()),
          );
        case HomeProfileDestination.playback:
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => PlaybackPage(
                entryContext: widget.initialPlaybackEntryContext,
              ),
            ),
          );
        case HomeProfileDestination.torrent:
          navigator.push(
            MaterialPageRoute<void>(builder: (_) => const TorrentPage()),
          );
        case HomeProfileDestination.none:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <_HomeTab>[
      const _HomeTab(
        icon: BangumiLogoIcon(),
        selectedIcon: BangumiLogoIcon(emphasis: 1.08),
        label: 'Bangumi',
        child: BangumiTab(),
      ),
      _HomeTab(
        icon: const Icon(Icons.inventory_2_outlined),
        selectedIcon: const Icon(Icons.inventory_2),
        label: '资源',
        child: DmhyTab(
          initialKeyword: widget.initialDmhyKeyword,
          initialAnimeOnly: widget.initialDmhyAnimeOnly,
          initialEntryContext: widget.initialDmhyEntryContext,
        ),
      ),
      const _HomeTab(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: '我的',
        child: ProfileTab(),
      ),
    ];

    return Scaffold(
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
            icon: tab.icon,
            selectedIcon: tab.selectedIcon,
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }
}

/// “我的”tab 在底部导航中的下标。
const int _profileTabIndex = 2;

/// 将外部传入的 tab 下标收敛到合法范围（0 Bangumi / 1 资源 / 2 我的）。
int _normalizeTabIndex(int value) {
  if (value < 0) {
    return 0;
  }

  if (value > _profileTabIndex) {
    return _profileTabIndex;
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

  final Widget icon;
  final Widget selectedIcon;
  final String label;
  final Widget child;
}
