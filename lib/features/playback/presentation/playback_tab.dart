import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_status_view.dart';

/// 本地播放首页入口。
///
/// 因为 BT 视频下载由外部客户端负责，首期播放模块只能处理用户显式选择的
/// 本地视频 URI。后续如果恢复内置下载器，再扩展为自动识别已下载视频列表。
class PlaybackTab extends StatelessWidget {
  const PlaybackTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureStatusView(
      icon: Icons.play_circle_outline,
      title: '播放',
      status: '手动选择',
      summary: '外部客户端下载完成后，由用户选择本地视频，再调用系统或第三方播放器。',
      capabilities: [
        FeatureCapability(
          icon: Icons.video_file_outlined,
          title: '选择本地视频',
          status: '规划中',
        ),
        FeatureCapability(
          icon: Icons.smart_display_outlined,
          title: '调起系统播放器',
          status: '规划中',
        ),
        FeatureCapability(
          icon: Icons.folder_open_outlined,
          title: '公共目录导出',
          status: '后续',
        ),
      ],
      actions: [
        FeatureAction(
          icon: Icons.video_file_outlined,
          label: '选择',
          onPressed: null,
        ),
        FeatureAction(
          icon: Icons.play_arrow_outlined,
          label: '播放',
          onPressed: null,
        ),
      ],
    );
  }
}
