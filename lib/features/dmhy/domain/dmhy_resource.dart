import 'dmhy_resource_metadata.dart';

/// DMHY RSS 搜索得到的资源条目。
///
/// DMHY 当前没有稳定 JSON API，首期以 RSS item 为数据源。该模型只保存
/// RSS 中可以稳定获得的字段：标题、详情页、发布时间、发布者、分类、
/// magnet、简介纯文本，以及从标题/简介中宽容提取出的轻量元数据。
/// `.torrent` 文件链接需要进入详情页后再解析，不在本模型中提前假设。
class DmhyResource {
  const DmhyResource({
    required this.title,
    required this.detailUri,
    required this.magnetUri,
    this.publishedAt,
    this.author = '',
    this.categoryName = '',
    this.categoryUri,
    this.descriptionText = '',
    this.metadata = const DmhyResourceMetadata.empty(),
    this.stats = const DmhyResourceStats.empty(),
  });

  final String title;
  final Uri detailUri;
  final Uri magnetUri;
  final DateTime? publishedAt;
  final String author;
  final String categoryName;
  final Uri? categoryUri;
  final String descriptionText;
  final DmhyResourceMetadata metadata;
  final DmhyResourceStats stats;

  /// 详情页来源主机。
  ///
  /// RSS 中常见详情链接是 `share.dmhy.org`。UI 展示主机可以让用户知道
  /// 跳转目标，但不把完整 URL 塞进列表页。
  String get sourceHost => detailUri.host.isEmpty ? 'DMHY' : detailUri.host;

  /// 该条目是否具有可交接给外部 BT 客户端的 magnet。
  bool get hasMagnet => magnetUri.scheme == 'magnet';

  /// 返回一份附加 HTML 列表统计后的资源对象。
  ///
  /// RSS 是主数据源，HTML 统计只是增强信息；因此这里只替换 `stats` 字段，
  /// 其余字段保持 RSS 解析结果，避免 HTML 页面格式波动污染核心交接数据。
  DmhyResource withStats(DmhyResourceStats stats) {
    return DmhyResource(
      title: title,
      detailUri: detailUri,
      magnetUri: magnetUri,
      publishedAt: publishedAt,
      author: author,
      categoryName: categoryName,
      categoryUri: categoryUri,
      descriptionText: descriptionText,
      metadata: metadata,
      stats: stats,
    );
  }
}

/// DMHY HTML 列表页中可读取的资源统计信息。
///
/// RSS 不提供可靠的视频大小和热度统计；DMHY HTML 搜索列表当前有“大小、
/// 種子、下載、完成”列。该模型只保存这些增强字段，解析不到时保持 null。
class DmhyResourceStats {
  const DmhyResourceStats({
    this.sizeLabel,
    this.seedCount,
    this.downloadCount,
    this.completedCount,
  });

  /// 空统计常量，供 RSS-only 结果和测试替身使用。
  const DmhyResourceStats.empty()
    : sizeLabel = null,
      seedCount = null,
      downloadCount = null,
      completedCount = null;

  /// HTML 列表页“大小”列的展示文本，例如 `1.25 GB`。
  final String? sizeLabel;

  /// HTML 列表页“種子”列的数量。
  final int? seedCount;

  /// HTML 列表页“下載”列的数量。
  final int? downloadCount;

  /// HTML 列表页“完成”列的数量。
  final int? completedCount;

  /// 是否没有任何可展示统计字段。
  bool get isEmpty =>
      sizeLabel == null &&
      seedCount == null &&
      downloadCount == null &&
      completedCount == null;

  /// 是否至少有一个可展示统计字段。
  bool get isNotEmpty => !isEmpty;
}
