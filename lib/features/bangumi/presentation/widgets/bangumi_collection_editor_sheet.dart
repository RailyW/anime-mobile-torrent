import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_colors.dart';
import '../../application/bangumi_collection_providers.dart';
import '../../domain/bangumi_collection.dart';
import '../../domain/bangumi_subject.dart';

/// 弹出 Bangumi 收藏编辑底部弹层。
///
/// 承接详情页原本的收藏编辑对话框：收藏状态、评分、私密标记和短评的编辑与
/// 保存逻辑保持不变（`saveMySubjectCollection` + 失效单条收藏 Provider +
/// 「Bangumi 收藏已保存」提示）。本次重设计只把 AlertDialog 换成更贴合移动端
/// 操作习惯的圆角底部弹层：
/// - 收藏状态改为设计稿 `.stat-opt` 白底选项行(状态色圆点 + 标签 + 说明 +
///   选中樱墨勾),白色为主、只有选中项染樱粉,不再是整排粉色 ChoiceChip；
/// - 弹层随键盘上移，短评输入不再被遮挡。
Future<void> showBangumiCollectionEditorSheet({
  required BuildContext context,
  required WidgetRef ref,
  required BangumiSubject subject,
  required BangumiSubjectCollection? collection,
}) async {
  var selectedType = collection?.type ?? BangumiCollectionType.wish;
  var selectedRate = collection?.rate ?? 0;
  var isPrivate = collection?.isPrivate ?? false;
  var isSaving = false;
  final commentController = TextEditingController(
    text: collection?.comment ?? '',
  );

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final scheme = theme.colorScheme;

            /// 保存收藏：与旧对话框逐字一致的写入、失效与提示流程。
            Future<void> save() async {
              setSheetState(() {
                isSaving = true;
              });

              try {
                final repository = ref.read(
                  bangumiMyCollectionRepositoryProvider,
                );
                await repository.saveMySubjectCollection(
                  subjectId: subject.id,
                  update: BangumiSubjectCollectionUpdate(
                    type: selectedType,
                    rate: selectedRate,
                    comment: commentController.text,
                    isPrivate: isPrivate,
                  ),
                );
                ref.invalidate(bangumiMySubjectCollectionProvider(subject.id));

                if (!sheetContext.mounted) {
                  return;
                }

                Navigator.of(sheetContext).pop();

                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bangumi 收藏已保存')),
                );
              } catch (error) {
                if (!sheetContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
                setSheetState(() {
                  isSaving = false;
                });
              }
            }

            return Padding(
              // 键盘弹出时抬高内容，保证短评输入框始终可见。
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection == null ? '添加收藏' : '修改收藏',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '收藏状态',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 设计稿 `.status-sheet` 顺序:在看→想看→看过→搁置→抛弃。
                  for (final type in const [
                    BangumiCollectionType.doing,
                    BangumiCollectionType.wish,
                    BangumiCollectionType.done,
                    BangumiCollectionType.onHold,
                    BangumiCollectionType.dropped,
                  ])
                    _StatusOptionRow(
                      type: type,
                      selected: type == selectedType,
                      onTap: isSaving
                          ? null
                          : () {
                              setSheetState(() {
                                selectedType = type;
                              });
                            },
                    ),
                  const SizedBox(height: 16),
                  Text('评分：${selectedRate == 0 ? '不评分' : '$selectedRate 分'}'),
                  Slider(
                    value: selectedRate.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: selectedRate == 0 ? '不评分' : '$selectedRate',
                    onChanged: isSaving
                        ? null
                        : (value) {
                            setSheetState(() {
                              selectedRate = value.round();
                            });
                          },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('仅自己可见'),
                    value: isPrivate,
                    onChanged: isSaving
                        ? null
                        : (value) {
                            setSheetState(() {
                              isPrivate = value;
                            });
                          },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(labelText: '短评'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isSaving ? null : save,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(isSaving ? '保存中…' : '保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  } finally {
    commentController.dispose();
  }
}

/// 收藏状态白底选项行,还原设计稿 `.stat-opt`。
///
/// 白底 + 1px 描边,左侧状态色圆点,主标签配一句说明文案;选中态整行换成樱粉
/// 描边 + 樱粉柔底 + 樱墨标签,并在右侧显示樱墨勾(呼应 `.stat-opt.cur`)。
/// 圆点色与说明文案取自设计稿 `STATUS` / `STATUS_DESC`。
class _StatusOptionRow extends StatelessWidget {
  const _StatusOptionRow({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final BangumiCollectionType type;
  final bool selected;
  final VoidCallback? onTap;

  /// 每种收藏状态的圆点色与一句话说明,对齐设计稿。
  static ({Color dot, String desc}) _styleOf(BangumiCollectionType type) {
    return switch (type) {
      BangumiCollectionType.doing => (dot: AppColors.sakura, desc: '正在追这部番'),
      BangumiCollectionType.wish => (dot: AppColors.muted, desc: '加入想看清单'),
      BangumiCollectionType.done => (dot: AppColors.leaf, desc: '已经全部看完'),
      BangumiCollectionType.onHold => (
        dot: AppColors.gold,
        desc: '先放一放，之后再看',
      ),
      BangumiCollectionType.dropped => (
        dot: Color(0xFFB9A7B0),
        desc: '弃坑，不再追了',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = _styleOf(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.sakuraSoft : scheme.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? AppColors.sakura : AppColors.line2,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: style.dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.sakuraInk : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        style.desc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: selected ? AppColors.sakuraInk : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
