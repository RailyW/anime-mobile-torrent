# lib 模块说明

`lib` 是 Flutter/Dart 主工程目录，承载安卓 APP 的跨平台 UI、业务状态和功能模块编排。

## 当前包含文件

- `main.dart`：应用进程入口，初始化 Flutter 绑定并挂载 Riverpod `ProviderScope`。
- `app/`：应用级路由、主题和根组件。
- `features/`：按业务能力拆分的功能模块。
- `shared/`：跨功能模块复用的展示组件和后续公共工具。

## 设计边界

1. `lib` 目录不直接保存平台私有实现细节；Android Intent、FileProvider 和播放器调起逻辑优先放在 `android/` 原生侧或平台桥接层。
2. Bangumi、DMHY、种子交接和播放能力必须保持模块边界清晰，避免把外部 API、页面状态和平台通道揉在首页。
3. 新增功能时应同步更新对应子目录 README，记录模块职责、文件清单和边界变化。
