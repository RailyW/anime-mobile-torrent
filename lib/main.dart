import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/anime_mobile_torrent_app.dart';

/// 安卓应用进程入口。
///
/// 这里统一完成 Flutter 绑定初始化、前台服务通信端口初始化，并把 Riverpod
/// 的全局容器挂到根节点。后续 Bangumi 授权状态、DMHY 搜索状态、种子
/// 交接状态、播放入口状态和后台常驻状态都会通过 ProviderScope 管理。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  runApp(
    const ProviderScope(
      child: WithForegroundTask(child: AnimeMobileTorrentApp()),
    ),
  );
}
