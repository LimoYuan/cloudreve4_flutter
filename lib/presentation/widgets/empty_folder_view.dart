import 'package:flutter/material.dart';

/// 空文件夹状态组件
class EmptyFolderView extends StatelessWidget {
  final String currentPath;

  const EmptyFolderView({
    super.key,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            currentPath == '/' ? '文件夹为空' : '暂无文件',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          if (currentPath == '/') const SizedBox(height: 8),
          if (currentPath == '/')
            Text(
              '点击 + 按钮创建新文件夹',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }
}
