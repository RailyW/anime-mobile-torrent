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
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        _BangumiCollectionEditorSheet(subject: subject, collection: collection),
  );
}

/// Bangumi 收藏编辑底部弹层主体。
///
/// 这里使用独立的 [ConsumerStatefulWidget]，而不是在
/// [showBangumiCollectionEditorSheet] 里用函数局部变量 + [StatefulBuilder]。
/// 这样短评输入框的 [TextEditingController]、保存中状态和 modal route 的子树
/// 生命周期完全绑定；用户拖拽关闭抽屉时，输入框会先随弹层子树正常卸载，最后才
/// 释放 controller，避免外层 future 完成和子树依赖清理交错触发 Flutter 的
/// `_dependents.isEmpty` 框架断言。
class _BangumiCollectionEditorSheet extends ConsumerStatefulWidget {
  const _BangumiCollectionEditorSheet({
    required this.subject,
    required this.collection,
  });

  final BangumiSubject subject;
  final BangumiSubjectCollection? collection;

  @override
  ConsumerState<_BangumiCollectionEditorSheet> createState() =>
      _BangumiCollectionEditorSheetState();
}

class _BangumiCollectionEditorSheetState
    extends ConsumerState<_BangumiCollectionEditorSheet> {
  late BangumiCollectionType _selectedType;
  late int _selectedRate;
  late bool _isPrivate;
  late final TextEditingController _commentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final collection = widget.collection;
    _selectedType = collection?.type ?? BangumiCollectionType.wish;
    _selectedRate = collection?.rate ?? 0;
    _isPrivate = collection?.isPrivate ?? false;
    _commentController = TextEditingController(text: collection?.comment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// 保存收藏：沿用原有写入、失效 Provider 与成功提示流程。
  ///
  /// 保存前先记录当前 [ScaffoldMessengerState]，因为保存成功后会立即关闭
  /// modal route；关闭后不再从已卸载的弹层 context 查找 inherited widget。
  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final repository = ref.read(bangumiMyCollectionRepositoryProvider);
      await repository.saveMySubjectCollection(
        subjectId: widget.subject.id,
        update: BangumiSubjectCollectionUpdate(
          type: _selectedType,
          rate: _selectedRate,
          comment: _commentController.text,
          isPrivate: _isPrivate,
        ),
      );
      ref.invalidate(bangumiMySubjectCollectionProvider(widget.subject.id));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      messenger?.showSnackBar(const SnackBar(content: Text('Bangumi 收藏已保存')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger?.showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collection = widget.collection;
    final subject = widget.subject;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.viewInsets.bottom -
        24;
    // 收藏状态、评分、私密开关和短评输入在小屏或键盘弹出时会超过一屏；这里给
    // modal 内容一个可见区域上限，并让内部滚动承接溢出，避免关闭动画期间出现
    // RenderFlex overflow 或依赖树异常卸载。
    final maxSheetHeight = availableHeight < 240 ? 240.0 : availableHeight;

    return Padding(
      // 键盘弹出时抬高整张弹层，保证短评输入框和保存按钮不会被输入法遮挡。
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                    selected: type == _selectedType,
                    onTap: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _selectedType = type;
                            });
                          },
                  ),
                const SizedBox(height: 16),
                Text('评分：${_selectedRate == 0 ? '不评分' : '$_selectedRate 分'}'),
                Slider(
                  value: _selectedRate.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: _selectedRate == 0 ? '不评分' : '$_selectedRate',
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedRate = value.round();
                          });
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('仅自己可见'),
                  value: _isPrivate,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _isPrivate = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(labelText: '短评'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_isSaving ? '保存中…' : '保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      BangumiCollectionType.onHold => (dot: AppColors.gold, desc: '先放一放，之后再看'),
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
