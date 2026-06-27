/// DMHY 页面入口语境。
///
/// 该模型只描述“用户为什么会来到 DMHY 搜索页”的轻量展示信息，不参与
/// RSS 请求、筛选、种子下载或外部客户端交接。把入口语境放在 domain 层，
/// 是为了让后台通知、首页路由和 DMHY 页面共享同一组查询参数契约。
enum DmhyEntryContext {
  /// 普通入口：用户主动打开 DMHY、从 Bangumi 跳转，或从订阅面板手动搜索。
  normal(queryValue: ''),

  /// 后台订阅自动检查发现新命中后，从持续通知进入 DMHY 搜索页。
  backgroundSubscription(queryValue: 'backgroundSubscription');

  const DmhyEntryContext({required this.queryValue});

  /// 写入首页路由查询参数时使用的稳定值。
  final String queryValue;

  /// 是否需要在 DMHY 页面展示后台订阅命中的来源提示。
  bool get isBackgroundSubscription =>
      this == DmhyEntryContext.backgroundSubscription;

  /// 从首页路由查询参数恢复入口语境。
  ///
  /// 解析时兼容大小写、连字符和下划线，便于后续手动调试深链；未知值一律
  /// 降级为普通入口，避免错误参数影响 DMHY 搜索主流程。
  static DmhyEntryContext fromQuery(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'backgroundsubscription' => DmhyEntryContext.backgroundSubscription,
      'background-subscription' => DmhyEntryContext.backgroundSubscription,
      'background_subscription' => DmhyEntryContext.backgroundSubscription,
      'subscriptionautocheck' => DmhyEntryContext.backgroundSubscription,
      'subscription-auto-check' => DmhyEntryContext.backgroundSubscription,
      'subscription_auto_check' => DmhyEntryContext.backgroundSubscription,
      _ => DmhyEntryContext.normal,
    };
  }
}

/// 首页路由中承载 DMHY 入口语境的查询参数名。
const String dmhyEntryContextQueryParameter = 'dmhySource';

/// 生成指向首页 DMHY 标签页并自动搜索关键词的路由。
///
/// 该函数只拼装轻量路由参数；目标页仍会自己执行 RSS 搜索和用户显式触发的
/// `.torrent` 交接动作。`entryContext` 为普通入口时不写入额外参数，保持从
/// Bangumi 或订阅面板跳转的 URL 简洁。
Uri buildDmhySearchHomeRoute({
  required String keyword,
  required bool animeOnly,
  DmhyEntryContext entryContext = DmhyEntryContext.normal,
}) {
  final queryParameters = <String, String>{
    'tab': 'dmhy',
    'keyword': keyword.trim(),
    'animeOnly': animeOnly.toString(),
  };

  if (entryContext != DmhyEntryContext.normal) {
    queryParameters[dmhyEntryContextQueryParameter] = entryContext.queryValue;
  }

  return Uri(path: '/', queryParameters: queryParameters);
}
