import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../data/models/server_model.dart';
import '../../../../services/server_service.dart';
import '../../../widgets/toast_helper.dart';

class ServerSelectorSheet extends StatelessWidget {
  const ServerSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final servers = ServerService.instance.servers;
    final currentServer = ServerService.instance.currentServer;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('选择服务器', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RadioGroup<String>(
              groupValue: currentServer?.label,
              onChanged: (value) async {
                if (value == null) return;
                await ServerService.instance.selectServer(value);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: servers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final server = servers[index];
                  final isSelected = currentServer?.label == server.label;
                  return ServerListItem(
                    server: server,
                    isSelected: isSelected,
                    onTap: () async {
                      await ServerService.instance.selectServer(server.label);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServerListItem extends StatelessWidget {
  final ServerModel server;
  final bool isSelected;
  final VoidCallback onTap;

  const ServerListItem({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Radio<String>(
        value: server.label,
      ),
      title: Text(
        server.label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        server.baseUrl,
        style: TextStyle(fontSize: 12, color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      tileColor:
          isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      onTap: onTap,
    );
  }
}

class ServerManagementSheet extends StatefulWidget {
  const ServerManagementSheet({super.key});

  @override
  State<ServerManagementSheet> createState() => _ServerManagementSheetState();
}

class _ServerManagementSheetState extends State<ServerManagementSheet> {
  @override
  Widget build(BuildContext context) {
    final servers = ServerService.instance.servers;
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('管理服务器', style: theme.textTheme.titleLarge),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: servers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final server = servers[index];
                return ServerManagementItem(
                  server: server,
                  onEdit: () => _showEditServerDialog(context, server),
                  onDelete: () => _showDeleteConfirmDialog(context, server),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddServerDialog(context),
              icon: const Icon(LucideIcons.plus),
              label: const Text('添加服务器'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddServerDialog(BuildContext context) async {
    final labelController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加服务器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: '服务器名称',
                hintText: '例如: 我的服务器',
                prefixIcon: Icon(LucideIcons.tag),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://example.com/api/v4',
                prefixIcon: Icon(LucideIcons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (labelController.text.trim().isEmpty ||
                  urlController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.addServer(
          ServerModel(
            label: labelController.text.trim(),
            baseUrl: urlController.text.trim(),
          ),
        );
        setState(() {});
        if (context.mounted) ToastHelper.success('服务器已添加');
      } catch (e) {
        if (context.mounted) ToastHelper.failure('添加失败: $e');
      }
    }
  }

  Future<void> _showEditServerDialog(
    BuildContext context,
    ServerModel server,
  ) async {
    final labelController = TextEditingController(text: server.label);
    final urlController = TextEditingController(text: server.baseUrl);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑服务器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: '服务器名称',
                prefixIcon: Icon(LucideIcons.tag),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                prefixIcon: Icon(LucideIcons.link),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (labelController.text.trim().isEmpty ||
                  urlController.text.trim().isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.updateServer(
          server.label,
          server.copyWith(
            label: labelController.text.trim(),
            baseUrl: urlController.text.trim(),
          ),
        );
        setState(() {});
        if (context.mounted) ToastHelper.success('服务器已更新');
      } catch (e) {
        if (context.mounted) ToastHelper.failure('更新失败: $e');
      }
    }
  }

  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    ServerModel server,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定要删除服务器 "${server.label}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ServerService.instance.deleteServer(server.label);
        setState(() {});
        if (context.mounted) ToastHelper.success('服务器已删除');
      } catch (e) {
        if (context.mounted) ToastHelper.failure('删除失败: $e');
      }
    }
  }
}

class ServerManagementItem extends StatelessWidget {
  final ServerModel server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ServerManagementItem({
    super.key,
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(
        server.label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        server.baseUrl,
        style: TextStyle(fontSize: 12, color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              LucideIcons.pencil,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: onEdit,
            tooltip: '编辑',
          ),
          IconButton(
            icon: Icon(
              LucideIcons.trash2,
              size: 20,
              color: theme.colorScheme.error,
            ),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ],
      ),
    );
  }
}
