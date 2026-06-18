import 'package:cloudreve4_flutter/data/models/file_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../providers/file_manager_provider.dart';
import '../../../widgets/thumbnail_image.dart';

class DesktopSummaryPanel extends StatelessWidget {
  final VoidCallback? onRecentMore;
  final VoidCallback? onTransferredMore;
  final void Function(FileModel file) onOpenFile;

  const DesktopSummaryPanel({
    super.key,
    this.onRecentMore,
    this.onTransferredMore,
    required this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = Provider.of<FileManagerProvider>(context);

    final recentFiles = List<FileModel>.from(fileManager.files)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final transferredFiles = List<FileModel>.from(fileManager.transferredFiles)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final displayRecentFiles = recentFiles.take(20).toList();
    final displayTransferredFiles = transferredFiles.take(20).toList();
    final dividerColor = theme.dividerColor.withValues(alpha: 0.28);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1180;
          final gap = compact ? 16.0 : 24.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummarySection(
                  title: '最近文件',
                  files: displayRecentFiles,
                  onMore: onRecentMore,
                  onOpenFile: onOpenFile,
                  emptyText: '暂无最近文件',
                ),
              ),
              SizedBox(width: gap),
              Container(
                width: 1,
                height: 118,
                margin: const EdgeInsets.only(top: 34),
                color: dividerColor,
              ),
              SizedBox(width: gap),
              Expanded(
                child: _SummarySection(
                  title: '转存文件',
                  files: displayTransferredFiles,
                  onMore: onTransferredMore,
                  onOpenFile: onOpenFile,
                  emptyText: '暂无转存文件',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final String title;
  final List<FileModel> files;
  final VoidCallback? onMore;
  final void Function(FileModel file) onOpenFile;
  final String emptyText;

  const _SummarySection({
    required this.title,
    required this.files,
    this.onMore,
    required this.onOpenFile,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            _MoreButtonSlot(onMore: onMore),
          ],
        ),
        const SizedBox(height: 10),
        if (files.isEmpty)
          SizedBox(
            height: 110,
            child: Center(
              child: Text(emptyText, style: TextStyle(color: theme.hintColor)),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: HorizontalScrollListView(
              itemCount: files.length,
              itemBuilder: (context, index) {
                return _SummaryFileCard(
                  file: files[index],
                  colorScheme: colorScheme,
                  onOpenFile: onOpenFile,
                );
              },
            ),
          ),
      ],
    );
  }
}


class _MoreButtonSlot extends StatelessWidget {
  final VoidCallback? onMore;

  const _MoreButtonSlot({this.onMore});

  @override
  Widget build(BuildContext context) {
    // Always reserve the same header space. When onMore is null, keep an
    // invisible placeholder so the file card list below will not move up/down
    // when switching categories.
    return SizedBox(
      width: 104,
      height: 40,
      child: onMore == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onMore,
                icon: const Icon(LucideIcons.arrowRight, size: 18),
                label: const Text('查看更多'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
    );
  }
}

class _SummaryFileCard extends StatelessWidget {
  final FileModel file;
  final ColorScheme colorScheme;
  final void Function(FileModel file) onOpenFile;

  const _SummaryFileCard({
    required this.file,
    required this.colorScheme,
    required this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isThumbnailable = !file.isFolder && FileUtils.isThumbnailableFile(file.name);

    return Tooltip(
      message: '${file.name}\n'
          '${app_date_utils.DateUtils.formatFileSize(file.size)}  |  '
          '${app_date_utils.DateUtils.formatDateTime(file.updatedAt)}',
      preferBelow: true,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            if (file.isFolder) {
              final target = file.path.startsWith('cloudreve://shared_with_me')
                  ? file.path
                  : file.relativePath;
              Provider.of<FileManagerProvider>(context, listen: false).enterFolder(target);
            } else {
              onOpenFile(file);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: isThumbnailable
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ThumbnailImage(
                            file: file,
                            contextHint: Provider.of<FileManagerProvider>(context, listen: false).contextHint,
                            borderRadius: 8,
                          ),
                        )
                      : Center(
                          child: Icon(
                            file.isFolder ? LucideIcons.folder : LucideIcons.file,
                            size: 32,
                            color: colorScheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HorizontalScrollListView extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const HorizontalScrollListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<HorizontalScrollListView> createState() => _HorizontalScrollListViewState();
}

class _HorizontalScrollListViewState extends State<HorizontalScrollListView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _controller.hasClients) {
          final maxExt = _controller.position.maxScrollExtent;
          if (maxExt > 0) {
            _controller.jumpTo(
              (_controller.offset + event.scrollDelta.dy).clamp(0.0, maxExt),
            );
          }
        }
      },
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}
