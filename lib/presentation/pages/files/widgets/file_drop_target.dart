import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FileDropTarget extends StatefulWidget {
  final Widget child;
  final String currentPath;
  final void Function(List<XFile> files) onDragDone;

  const FileDropTarget({
    super.key,
    required this.child,
    required this.currentPath,
    required this.onDragDone,
  });

  @override
  State<FileDropTarget> createState() => _FileDropTargetState();
}

class _FileDropTargetState extends State<FileDropTarget> {
  bool _isDraggingOver = false;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return widget.child;
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingOver = true),
      onDragExited: (_) => setState(() => _isDraggingOver = false),
      onDragDone: (details) {
        setState(() => _isDraggingOver = false);
        widget.onDragDone(details.files);
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDraggingOver)
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.upload, size: 28, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '释放文件以上传到当前目录',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.currentPath,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
