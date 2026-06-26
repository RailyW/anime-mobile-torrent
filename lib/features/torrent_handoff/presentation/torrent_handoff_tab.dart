import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_status_view.dart';

/// Torrent 种子交接首页入口。
///
/// 首期边界非常明确：APP 只负责 magnet、`.torrent` 文件和外部 BT 客户端
/// 之间的交接，不实现 BT 协议，也不下载种子指向的视频文件。
class TorrentHandoffTab extends StatelessWidget {
  const TorrentHandoffTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureStatusView(
      icon: Icons.open_in_new_outlined,
      title: '种子交接',
      status: 'MVP',
      summary: 'DMHY 结果中已可把 magnet 或 .torrent 文件交给手机里的 BT 客户端，视频下载由外部客户端完成。',
      capabilities: [
        FeatureCapability(
          icon: Icons.link_outlined,
          title: '打开 magnet',
          status: 'DMHY 已接入',
        ),
        FeatureCapability(
          icon: Icons.file_download_outlined,
          title: '下载 .torrent',
          status: 'DMHY 已接入',
        ),
        FeatureCapability(
          icon: Icons.ios_share_outlined,
          title: '分享给 BT 客户端',
          status: '分享面板',
        ),
        FeatureCapability(
          icon: Icons.phone_android_outlined,
          title: '种子文件直开',
          status: '后续',
        ),
      ],
      actions: [
        FeatureAction(icon: Icons.copy_outlined, label: '复制', onPressed: null),
        FeatureAction(
          icon: Icons.open_in_new_outlined,
          label: '打开',
          onPressed: null,
        ),
      ],
    );
  }
}
