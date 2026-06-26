import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_status_view.dart';

/// Bangumi 功能首页入口。
///
/// 后续 OAuth 登录、token 刷新、条目搜索、收藏同步等能力都应放在
/// `features/bangumi` 模块内，并通过 Repository 向页面暴露稳定接口。
class BangumiTab extends StatelessWidget {
  const BangumiTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureStatusView(
      icon: Icons.account_circle_outlined,
      title: 'Bangumi',
      status: '待授权',
      summary: '登录后同步条目、收藏和进度，作为后续搜索资源的动画信息入口。',
      capabilities: [
        FeatureCapability(
          icon: Icons.login_outlined,
          title: 'OAuth 授权',
          status: '下一步',
        ),
        FeatureCapability(
          icon: Icons.search_outlined,
          title: '动画条目搜索',
          status: '规划中',
        ),
        FeatureCapability(
          icon: Icons.bookmark_border_outlined,
          title: '收藏状态同步',
          status: '规划中',
        ),
      ],
      actions: [
        FeatureAction(icon: Icons.login_outlined, label: '登录', onPressed: null),
        FeatureAction(
          icon: Icons.search_outlined,
          label: '搜索',
          onPressed: null,
        ),
      ],
    );
  }
}
