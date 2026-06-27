import '../../dmhy/application/dmhy_providers.dart';
import '../../dmhy/data/dmhy_rss_client.dart';
import '../../dmhy/data/dmhy_torrent_client.dart';
import '../data/dmhy_subscription_auto_check_storage.dart';
import '../data/dmhy_subscription_storage.dart';
import '../domain/dmhy_subscription.dart';
import 'dmhy_subscription_providers.dart';

/// DMHY 订阅自动检查结果类型。
enum DmhySubscriptionAutoCheckStatus {
  /// 没有配置订阅关键词，因此没有访问 DMHY。
  noKeywords,

  /// 尚未到达低频检查间隔，因此没有访问 DMHY。
  throttled,

  /// 已完成一次 DMHY RSS 自动检查。
  checked,

  /// 已到达检查窗口，但 RSS 请求、解析或其他步骤失败。
  failed,
}

/// DMHY 订阅自动检查结果。
///
/// 后台服务通过该对象决定通知文本和发回主 isolate 的状态。它只包含聚合
/// 信息，不携带完整 RSS 条目列表。
class DmhySubscriptionAutoCheckOutcome {
  const DmhySubscriptionAutoCheckOutcome({
    required this.status,
    required this.message,
    required this.checkedAt,
    this.keywordCount = 0,
    this.resourceCount = 0,
    this.latestKeyword,
    this.latestAnimeOnly = true,
    this.latestTitle,
    this.nextAllowedAt,
  });

  final DmhySubscriptionAutoCheckStatus status;
  final String message;
  final DateTime checkedAt;
  final int keywordCount;
  final int resourceCount;
  final String? latestKeyword;
  final bool latestAnimeOnly;
  final String? latestTitle;
  final DateTime? nextAllowedAt;

  /// 是否成功完成了 DMHY RSS 检查。
  bool get didCheck => status == DmhySubscriptionAutoCheckStatus.checked;

  /// 是否命中了至少一条 RSS 资源。
  bool get hasMatches => resourceCount > 0;

  /// 是否需要把结果更新到持续通知。
  ///
  /// 未配置关键词和节流都不代表新结果；成功检查和失败检查则应该让用户在
  /// 通知或前台页面看到最新状态。
  bool get shouldUpdateNotification =>
      status == DmhySubscriptionAutoCheckStatus.checked ||
      status == DmhySubscriptionAutoCheckStatus.failed;

  /// 转换为可通过 `FlutterForegroundTask.sendDataToMain` 传递的数据。
  Map<String, Object?> toMessage() {
    return {
      'type': 'dmhySubscriptionAutoCheck',
      'status': status.name,
      'message': message,
      'checkedAt': checkedAt.toIso8601String(),
      'keywordCount': keywordCount,
      'resourceCount': resourceCount,
      'latestKeyword': latestKeyword,
      'latestAnimeOnly': latestAnimeOnly,
      'latestTitle': latestTitle,
      'nextAllowedAt': nextAllowedAt?.toIso8601String(),
    };
  }
}

/// DMHY 订阅自动检查服务。
///
/// 该服务是后台任务和测试都可复用的纯 Dart 编排层：读取订阅关键词、判断
/// 是否到达检查间隔、调用 DMHY RSS、保存最近检查摘要。它不负责通知展示、
/// 不下载 `.torrent`，也不打开 magnet。
class DmhySubscriptionAutoCheckService {
  const DmhySubscriptionAutoCheckService({
    required this.subscriptionRepository,
    required this.autoCheckStorage,
    required this.now,
    this.minInterval = const Duration(hours: 1),
    this.limitPerKeyword = 3,
  });

  final DmhySubscriptionRepository subscriptionRepository;
  final DmhySubscriptionAutoCheckStorage autoCheckStorage;
  final DateTime Function() now;
  final Duration minInterval;
  final int limitPerKeyword;

  /// 创建后台 isolate 使用的默认自动检查服务。
  ///
  /// 这里显式组合真实存储、DMHY RSS 客户端和 Repository，避免后台任务依赖
  /// Riverpod 容器。`DartPluginRegistrant.ensureInitialized()` 会由
  /// `flutter_foreground_task` 在设置 TaskHandler 时调用，SharedPreferences
  /// 和 Dio 因而可以在后台 isolate 中使用。
  factory DmhySubscriptionAutoCheckService.createDefault() {
    final rssClient = DmhyRssClient.createDefault();
    final dmhyRepository = DmhyRssRepository(
      rssClient,
      DmhyTorrentClient(rssClient.dio),
    );

    return DmhySubscriptionAutoCheckService(
      subscriptionRepository: DmhySubscriptionRepository(
        storage: const SharedPreferencesDmhySubscriptionStorage(),
        dmhyRepository: dmhyRepository,
        now: DateTime.now,
      ),
      autoCheckStorage:
          const SharedPreferencesDmhySubscriptionAutoCheckStorage(),
      now: DateTime.now,
    );
  }

  /// 如果达到检查条件，则执行一次 DMHY RSS 自动检查。
  ///
  /// `force` 只用于测试或未来手动调度；后台常驻心跳默认不强制检查，严格遵守
  /// `minInterval`，降低对 DMHY 的请求压力。
  Future<DmhySubscriptionAutoCheckOutcome> runIfDue({
    bool force = false,
  }) async {
    final timestamp = now();
    final keywords = await subscriptionRepository.loadKeywords();
    if (keywords.isEmpty) {
      return DmhySubscriptionAutoCheckOutcome(
        status: DmhySubscriptionAutoCheckStatus.noKeywords,
        message: '未配置 DMHY 订阅关键词',
        checkedAt: timestamp,
      );
    }

    final lastRecord = await autoCheckStorage.loadLastRecord();
    if (!force && lastRecord != null) {
      final nextAllowedAt = lastRecord.checkedAt.add(minInterval);
      if (timestamp.isBefore(nextAllowedAt)) {
        return DmhySubscriptionAutoCheckOutcome(
          status: DmhySubscriptionAutoCheckStatus.throttled,
          message: '尚未到达 DMHY 订阅检查间隔',
          checkedAt: timestamp,
          keywordCount: lastRecord.keywordCount,
          resourceCount: lastRecord.resourceCount,
          latestKeyword: lastRecord.latestKeyword,
          latestAnimeOnly: lastRecord.latestAnimeOnly,
          latestTitle: lastRecord.latestTitle,
          nextAllowedAt: nextAllowedAt,
        );
      }
    }

    final List<DmhySubscriptionCheckResult> results;
    try {
      results = await subscriptionRepository.checkAll(
        keywords,
        limitPerKeyword: limitPerKeyword,
      );
    } catch (error) {
      final message = 'DMHY 订阅检查失败：${_formatAutoCheckError(error)}';
      await autoCheckStorage.saveLastRecord(
        DmhySubscriptionAutoCheckRecord(
          status: DmhySubscriptionAutoCheckRecordStatus.failed,
          checkedAt: timestamp,
          keywordCount: keywords.length,
          resourceCount: 0,
          message: message,
        ),
      );
      return DmhySubscriptionAutoCheckOutcome(
        status: DmhySubscriptionAutoCheckStatus.failed,
        message: message,
        checkedAt: timestamp,
        keywordCount: keywords.length,
      );
    }

    final summary = DmhySubscriptionCheckSummary(results: results);
    final latestMatch = _findLatestMatch(summary);
    final message = summary.hasMatches
        ? 'DMHY 订阅检查发现 ${summary.totalResourceCount} 条资源'
        : 'DMHY 订阅检查完成，暂未发现资源';
    final record = DmhySubscriptionAutoCheckRecord(
      checkedAt: timestamp,
      keywordCount: keywords.length,
      resourceCount: summary.totalResourceCount,
      latestKeyword: latestMatch?.keyword,
      latestAnimeOnly: latestMatch?.animeOnly ?? true,
      latestTitle: latestMatch?.title,
      message: message,
    );
    await autoCheckStorage.saveLastRecord(record);

    return DmhySubscriptionAutoCheckOutcome(
      status: DmhySubscriptionAutoCheckStatus.checked,
      message: message,
      checkedAt: timestamp,
      keywordCount: keywords.length,
      resourceCount: summary.totalResourceCount,
      latestKeyword: latestMatch?.keyword,
      latestAnimeOnly: latestMatch?.animeOnly ?? true,
      latestTitle: latestMatch?.title,
    );
  }

  _LatestSubscriptionMatch? _findLatestMatch(
    DmhySubscriptionCheckSummary summary,
  ) {
    for (final result in summary.results) {
      final latestResource = result.latestResource;
      if (latestResource != null && latestResource.title.trim().isNotEmpty) {
        return _LatestSubscriptionMatch(
          keyword: result.subscription.normalizedKeyword,
          animeOnly: result.subscription.animeOnly,
          title: latestResource.title.trim(),
        );
      }
    }

    return null;
  }
}

/// 自动检查中第一个可展示命中的轻量上下文。
///
/// 后台记录只保存聚合摘要，不保存完整 RSS 列表；但保留命中关键词和标题可以让
/// 前台页面在用户点击时重新走 DMHY 搜索，而不是长期缓存第三方资源条目。
class _LatestSubscriptionMatch {
  const _LatestSubscriptionMatch({
    required this.keyword,
    required this.animeOnly,
    required this.title,
  });

  final String keyword;
  final bool animeOnly;
  final String title;
}

String _formatAutoCheckError(Object error) {
  if (error is DmhySubscriptionException) {
    return error.message;
  }

  return error.toString();
}
