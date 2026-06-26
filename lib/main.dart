import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/anime_mobile_torrent_app.dart';

/// 安卓应用进程入口。
///
/// 这里统一完成 Flutter 绑定初始化，并把 Riverpod 的全局容器挂到根节点。
/// 后续 Bangumi 授权状态、DMHY 搜索状态、种子交接状态和播放入口状态
/// 都会通过 ProviderScope 管理，避免在页面之间传递大块可变对象。
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: AnimeMobileTorrentApp()));
}
