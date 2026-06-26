import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_status_view.dart';

/// DMHY 资源搜索首页入口。
///
/// 该模块首期会优先接入 RSS 搜索，再按用户点击解析详情页中的 `.torrent`
/// 链接。模块只负责资源发现和种子文件来源，不直接触碰 BT 视频内容下载。
class DmhyTab extends StatelessWidget {
  const DmhyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureStatusView(
      icon: Icons.rss_feed_outlined,
      title: 'DMHY',
      status: '待接入',
      summary: '使用 RSS 搜索动画资源，用户选择后再进入 magnet 或种子文件交接。',
      capabilities: [
        FeatureCapability(
          icon: Icons.manage_search_outlined,
          title: '关键词 RSS 搜索',
          status: '下一步',
        ),
        FeatureCapability(
          icon: Icons.description_outlined,
          title: '详情页种子解析',
          status: '规划中',
        ),
        FeatureCapability(
          icon: Icons.filter_alt_outlined,
          title: '分类与字幕组过滤',
          status: '规划中',
        ),
      ],
      actions: [
        FeatureAction(
          icon: Icons.search_outlined,
          label: '搜索',
          onPressed: null,
        ),
        FeatureAction(
          icon: Icons.rss_feed_outlined,
          label: 'RSS',
          onPressed: null,
        ),
      ],
    );
  }
}
