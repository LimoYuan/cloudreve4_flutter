import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/sort_options.dart';
import '../../../providers/file_manager_provider.dart';
import '../../../widgets/file_operation_dialogs.dart';
import '../../../widgets/search_dialog.dart';
import '../../../widgets/upload_dialog.dart';

class DesktopActionButtons extends StatelessWidget {
  final FileManagerProvider fileManager;
  final bool hasSelection;
  final VoidCallback? onShowCreateTextFile;
  final bool showFileMutations;

  const DesktopActionButtons({
    super.key,
    required this.fileManager,
    this.hasSelection = false,
    this.onShowCreateTextFile,
    this.showFileMutations = true,
  });

  @override
  Widget build(BuildContext context) {
    if (hasSelection) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.search, size: 19),
          onPressed: () => SearchDialog.show(context),
          tooltip: '搜索',
          visualDensity: VisualDensity.compact,
        ),
        _buildSortMenu(fileManager),
        Consumer<FileManagerProvider>(
          builder: (context, fm, _) {
            final icon = fm.viewType == FileViewType.list
                ? Icons.grid_view
                : Icons.view_list;
            return IconButton(
              icon: Icon(icon, size: 19),
              onPressed: () {
                fm.setViewType(
                  fm.viewType == FileViewType.list
                      ? FileViewType.grid
                      : FileViewType.list,
                );
              },
              tooltip: fm.viewType == FileViewType.list ? '网格视图' : '列表视图',
              visualDensity: VisualDensity.compact,
            );
          },
        ),
        IconButton(
          icon: Icon(fileManager.isLoading ? Icons.hourglass_empty : Icons.refresh, size: 19),
          onPressed: () => fileManager.refreshFiles(),
          tooltip: '刷新',
          visualDensity: VisualDensity.compact,
        ),
        if (showFileMutations) ...[
            IconButton(
              icon: const Icon(LucideIcons.upload, size: 19),
              onPressed: () => showUploadDialog(context),
              tooltip: '上传文件 / 文件夹',
              visualDensity: VisualDensity.compact,
            ),
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.folderPlus, size: 19),
              tooltip: '新建',
              padding: const EdgeInsets.all(8),
              position: PopupMenuPosition.under,
              onSelected: (value) {
                if (value == 'folder') {
                  FileOperationDialogs.showCreateDialog(context, fileManager);
                } else if (value == 'file') {
                  onShowCreateTextFile?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'folder', child: Row(children: [Icon(LucideIcons.folderPlus, size: 18), SizedBox(width: 10), Text('新建文件夹')])),
                const PopupMenuItem(value: 'file', child: Row(children: [Icon(Icons.note_add_outlined, size: 18), SizedBox(width: 10), Text('新建文件')])),
              ],
            ),
          ],
      ],
    );
  }

  Widget _buildSortMenu(FileManagerProvider fileManager) {
    final allOptions = [
      for (final field in SortField.values)
        for (final dir in SortDirection.values) SortOption(field, dir),
    ];

    return PopupMenuButton<SortOption>(
      icon: const Icon(LucideIcons.arrowUpDown, size: 19),
      tooltip: '排序',
      position: PopupMenuPosition.under,
      padding: const EdgeInsets.all(8),
      onSelected: (option) => fileManager.setSortOption(option),
      itemBuilder: (context) => allOptions.map((option) {
        final isSelected = fileManager.sortOption == option;
        return PopupMenuItem<SortOption>(
          value: option,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                )
              else
                const SizedBox(width: 24),
              Text(option.menuLabel),
            ],
          ),
        );
      }).toList(),
    );
  }
}
