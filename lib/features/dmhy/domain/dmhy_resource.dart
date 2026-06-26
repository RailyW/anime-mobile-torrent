/// DMHY RSS 搜索得到的资源条目。
///
/// DMHY 当前没有稳定 JSON API，首期以 RSS item 为数据源。该模型只保存
/// RSS 中可以稳定获得的字段：标题、详情页、发布时间、发布者、分类、
/// magnet 和简介纯文本。`.torrent` 文件链接需要进入详情页后再解析，
/// 不在本模型中提前假设。
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
  });

  final String title;
  final Uri detailUri;
  final Uri magnetUri;
  final DateTime? publishedAt;
  final String author;
  final String categoryName;
  final Uri? categoryUri;
  final String descriptionText;

  /// 详情页来源主机。
  ///
  /// RSS 中常见详情链接是 `share.dmhy.org`。UI 展示主机可以让用户知道
  /// 跳转目标，但不把完整 URL 塞进列表页。
  String get sourceHost => detailUri.host.isEmpty ? 'DMHY' : detailUri.host;

  /// 该条目是否具有可交接给外部 BT 客户端的 magnet。
  bool get hasMagnet => magnetUri.scheme == 'magnet';
}
