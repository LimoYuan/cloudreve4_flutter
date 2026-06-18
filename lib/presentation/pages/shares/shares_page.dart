import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models/share_model.dart';
import '../../../services/share_service.dart';
import '../../../core/utils/file_type_utils.dart';
import '../../widgets/toast_helper.dart';
import '../../widgets/share/share_dialog.dart';

class SharesPage extends StatefulWidget {
  const SharesPage({super.key});

  @override
  State<SharesPage> createState() => _SharesPageState();
}

class _SharesPageState extends State<SharesPage> {
  List<ShareModel> _shares = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _nextPageToken;
  late ScrollController _scrollController;
  static const _sharesPageListSize = 20;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadShares();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreShares();
    }
  }

  Future<bool> _loadShares({bool isLoadMore = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ShareService().listShares(
        pageSize: _sharesPageListSize,
        nextPageToken: isLoadMore ? _nextPageToken : null,
      );

      final List<dynamic> sharesData =
          response['shares'] as List<dynamic>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
      final newShares = sharesData
          .map((s) => ShareModel.fromJson(s as Map<String, dynamic>))
          .toList();

      setState(() {
        _isLoading = false;
        if (isLoadMore) {
          _shares.addAll(newShares);
        } else {
          _shares = newShares;
        }
        _nextPageToken = pagination['next_token'] as String?;
        _hasMore = _nextPageToken != null;
      });
      return true;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      return false;
    }
  }

  Future<void> _loadMoreShares() async {
    if (!_hasMore || _isLoading) return;
    await _loadShares(isLoadMore: true);
  }

  Future<void> _refreshShares() async {
    final success = await _loadShares(isLoadMore: false);
    if (mounted) {
      if (success) {
        ToastHelper.success('刷新成功');
      } else {
        ToastHelper.failure('刷新失败');
      }
    }
  }

  Future<void> _deleteShare(ShareModel share) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除分享'),
        content: Text('确定删除分享 "${share.name}" 吗？'),
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

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ShareService().deleteShare(id: share.id);
        setState(() => _shares.remove(share));
        if (mounted) ToastHelper.success('删除成功');
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ToastHelper.failure('删除失败: $e');
      }
    }
  }


  int _decodeSharePermissionMask(String? encoded) {
    const values = <String, int>{
      'AQ==': 1,
      'Ag==': 2,
      'Aw==': 3,
      'BA==': 4,
      'BQ==': 5,
      'Bg==': 6,
      'Bw==': 7,
      'CA==': 8,
      'CQ==': 9,
      'Cg==': 10,
      'Cw==': 11,
      'DA==': 12,
      'DQ==': 13,
      'Dg==': 14,
      'Dw==': 15,
    };
    return (values[encoded] ?? SharePermissionMask.read) | SharePermissionMask.read;
  }

  List<SharePermissionEntry> _initialSharePermissionEntries(ShareModel share) {
    final setting = share.permissionSetting;
    final entries = <SharePermissionEntry>[];

    SharePermissionEntry regular({
      required String id,
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required String? encoded,
      required bool removable,
    }) {
      return SharePermissionEntry.regular(
        id: id,
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        mask: _decodeSharePermissionMask(encoded),
        removable: removable,
      );
    }

    SharePermissionEntry builtin({
      required String id,
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required String? encoded,
    }) {
      final entry = SharePermissionEntry.builtin(
        id: id,
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
      );
      entry.mask = _decodeSharePermissionMask(encoded);
      return entry;
    }

    if (setting == null) {
      entries.add(regular(
        id: 'anonymous',
        title: '匿名访客',
        subtitle: '无需登录即可访问',
        icon: Icons.account_circle,
        color: Colors.grey,
        encoded: 'BQ==',
        removable: true,
      ));
      entries.add(regular(
        id: 'everyone',
        title: '其他所有人',
        subtitle: '已登录用户',
        icon: Icons.public,
        color: Theme.of(context).colorScheme.primary,
        encoded: 'AQ==',
        removable: false,
      ));
      return entries;
    }

    if (setting.anonymous != null) {
      entries.add(regular(
        id: 'anonymous',
        title: '匿名访客',
        subtitle: '无需登录即可访问',
        icon: Icons.account_circle,
        color: Colors.grey,
        encoded: setting.anonymous,
        removable: true,
      ));
    }
    if (setting.everyone != null) {
      entries.add(regular(
        id: 'everyone',
        title: '其他所有人',
        subtitle: '已登录用户',
        icon: Icons.public,
        color: Theme.of(context).colorScheme.primary,
        encoded: setting.everyone,
        removable: false,
      ));
    }
    if (setting.sameGroup != null) {
      entries.add(builtin(
        id: 'same_group',
        title: '和我同一用户组',
        subtitle: '当前用户组内成员',
        icon: Icons.group_add,
        color: Colors.green,
        encoded: setting.sameGroup,
      ));
    }
    if (setting.other != null) {
      entries.add(builtin(
        id: 'other_group',
        title: '其他用户组',
        subtitle: '其他已登录用户组',
        icon: Icons.groups,
        color: Colors.orange,
        encoded: setting.other,
      ));
    }

    setting.groupExplicit?.forEach((id, encoded) {
      entries.add(SharePermissionEntry(
        id: id,
        title: '用户组 $id',
        subtitle: '用户组',
        icon: Icons.group,
        color: Colors.deepPurple,
        kind: SharePermissionKind.group,
        mask: _decodeSharePermissionMask(encoded),
        removable: true,
      ));
    });

    setting.userExplicit?.forEach((id, encoded) {
      entries.add(SharePermissionEntry(
        id: id,
        title: '用户 $id',
        subtitle: '用户',
        icon: Icons.person,
        color: Colors.blue,
        kind: SharePermissionKind.user,
        mask: _decodeSharePermissionMask(encoded),
        removable: true,
      ));
    });

    if (entries.isEmpty) {
      entries.add(regular(
        id: 'everyone',
        title: '其他所有人',
        subtitle: '已登录用户',
        icon: Icons.public,
        color: Theme.of(context).colorScheme.primary,
        encoded: 'AQ==',
        removable: false,
      ));
    }

    return entries;
  }

  Future<void> _editShare(ShareModel share) async {
    final parts = share.url.split('/');
    final shareId = share.id.isNotEmpty
        ? share.id
        : (parts.length >= 5 ? parts[4] : '');
    if (shareId.isEmpty) {
      if (mounted) ToastHelper.error('分享链接格式错误');
      return;
    }

    int? currentExpireDays;
    if (share.expires != null) {
      final diff = share.expires!.difference(DateTime.now());
      currentExpireDays = diff.inSeconds <= 0
          ? 1
          : (diff.inSeconds / 86400).ceil();
    }

    final passwordController = TextEditingController(text: share.password ?? '');
    final expireDaysController = TextEditingController(
      text: currentExpireDays?.toString() ?? '',
    );
    final downloadsController = TextEditingController();
    final priceController = TextEditingController(
      text: share.price != null && share.price! > 0 ? share.price.toString() : '',
    );
    final permissionSearchController = TextEditingController();

    var passwordProtected = share.isPrivate ?? share.passwordProtected ?? false;
    var timeoutExpire = share.expires != null;
    var downloadExpire = false;
    var paidDownload = share.price != null && share.price! > 0;
    var shareView = share.shareView ?? true;
    var showReadme = share.showReadme ?? share.isFolder;
    var permissionSearchOpen = false;
    var permissionSearching = false;
    String? permissionSearchError;
    var permissionSearchEntries = <SharePermissionEntry>[];
    List<SharePrincipal>? cachedGroups;

    final permissionEntries = _initialSharePermissionEntries(share);

    int? parsePositiveInt(TextEditingController controller) {
      final raw = controller.text.trim();
      if (raw.isEmpty) return null;
      final value = int.tryParse(raw);
      if (value == null || value <= 0) return null;
      return value;
    }

    Map<String, dynamic> buildPermissions() {
      final permissions = <String, dynamic>{};
      final userExplicit = <String, String>{};
      final groupExplicit = <String, String>{};

      for (final entry in permissionEntries) {
        final encoded = entry.encodedPermission;
        switch (entry.kind) {
          case SharePermissionKind.anonymous:
            permissions['anonymous'] = encoded;
            break;
          case SharePermissionKind.everyone:
            permissions['everyone'] = encoded;
            break;
          case SharePermissionKind.sameGroup:
            permissions['same_group'] = encoded;
            break;
          case SharePermissionKind.otherGroup:
            permissions['other_group'] = encoded;
            break;
          case SharePermissionKind.user:
            userExplicit[entry.id] = encoded;
            break;
          case SharePermissionKind.group:
            groupExplicit[entry.id] = encoded;
            break;
        }
      }

      if (userExplicit.isNotEmpty) permissions['user_explicit'] = userExplicit;
      if (groupExplicit.isNotEmpty) permissions['group_explicit'] = groupExplicit;
      return permissions;
    }

    List<SharePermissionEntry> builtInPermissionEntries() {
      return <SharePermissionEntry>[
        SharePermissionEntry.builtin(
          id: 'same_group',
          title: '和我同一用户组',
          subtitle: '当前用户组内成员',
          icon: Icons.group_add,
          color: Colors.green,
        ),
        SharePermissionEntry.builtin(
          id: 'other_group',
          title: '其他用户组',
          subtitle: '其他已登录用户组',
          icon: Icons.groups,
          color: Colors.orange,
        ),
      ];
    }

    bool permissionAlreadyAdded(SharePermissionEntry candidate) {
      return permissionEntries.any(
        (entry) => entry.kind == candidate.kind && entry.id == candidate.id,
      );
    }

    Future<void> refreshPermissionSearch(StateSetter update) async {
      final keyword = permissionSearchController.text.trim().toLowerCase();
      update(() {
        permissionSearching = true;
        permissionSearchOpen = true;
        permissionSearchError = null;
      });

      try {
        final service = ShareService();
        final usersFuture = keyword.isEmpty
            ? Future<List<SharePrincipal>>.value(const [])
            : service.searchUsers(keyword);

        cachedGroups ??= await service.listGroups();
        final users = await usersFuture;
        final groups = cachedGroups ?? const <SharePrincipal>[];

        final builtIns = builtInPermissionEntries()
            .where((item) => keyword.isEmpty || item.title.toLowerCase().contains(keyword))
            .where((item) => !permissionAlreadyAdded(item))
            .toList();
        final groupEntries = groups
            .where((group) => keyword.isEmpty || group.name.toLowerCase().contains(keyword))
            .map(SharePermissionEntry.principal)
            .where((item) => !permissionAlreadyAdded(item))
            .toList();
        final userEntries = users
            .map(SharePermissionEntry.principal)
            .where((item) => !permissionAlreadyAdded(item))
            .toList();

        update(() {
          permissionSearchEntries = <SharePermissionEntry>[
            ...builtIns,
            ...groupEntries,
            ...userEntries,
          ];
          permissionSearchError = permissionSearchEntries.isEmpty
              ? (keyword.isEmpty ? '没有可添加的用户组/用户' : '没有找到用户或用户组')
              : null;
          permissionSearching = false;
        });
      } catch (e) {
        update(() {
          permissionSearchEntries = const [];
          permissionSearchError = '加载用户组/用户失败: $e';
          permissionSearching = false;
        });
      }
    }

    void addPermissionEntry(SharePermissionEntry candidate, StateSetter update) {
      if (permissionAlreadyAdded(candidate)) {
        ToastHelper.info('已添加过 ${candidate.title}');
        return;
      }
      update(() {
        permissionEntries.add(candidate.copyForEntry());
        permissionSearchController.clear();
        permissionSearchEntries = const [];
        permissionSearchOpen = false;
        permissionSearchError = null;
      });
      FocusManager.instance.primaryFocus?.unfocus();
    }

    Widget buildPermissionMaskSelector(SharePermissionEntry entry, StateSetter update) {
      final theme = Theme.of(context);
      return DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: entry.mask | SharePermissionMask.read,
          borderRadius: BorderRadius.circular(12),
          isDense: true,
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem(value: 1, child: Text('查看')),
            DropdownMenuItem(value: 3, child: Text('查看、创建')),
            DropdownMenuItem(value: 5, child: Text('查看、修改')),
            DropdownMenuItem(value: 9, child: Text('查看、删除')),
            DropdownMenuItem(value: 15, child: Text('完全权限')),
          ],
          onChanged: (value) {
            if (value == null) return;
            update(() => entry.mask = value | SharePermissionMask.read);
          },
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget buildPermissionRow(SharePermissionEntry entry, StateSetter update) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: entry.color.withValues(alpha: isDark ? 0.24 : 0.15),
              child: Icon(entry.icon, color: entry.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            buildPermissionMaskSelector(entry, update),
            if (entry.removable)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => update(() => permissionEntries.remove(entry)),
                tooltip: '移除',
              ),
          ],
        ),
      );
    }

    Widget buildPermissionSection(StateSetter update) {
      final theme = Theme.of(context);
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: const Icon(Icons.groups_outlined),
        title: const Text('访问权限 / 用户组', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('和旧 Windows 分享权限面板保持一致'),
        initiallyExpanded: true,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: permissionSearchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索用户或用户组...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: permissionSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(permissionSearchOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                      onPressed: () {
                        if (permissionSearchOpen) {
                          update(() {
                            permissionSearchOpen = false;
                            permissionSearchEntries = const [];
                            permissionSearchError = null;
                          });
                        } else {
                          refreshPermissionSearch(update);
                        }
                      },
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onTap: () => refreshPermissionSearch(update),
            onChanged: (_) => refreshPermissionSearch(update),
            onSubmitted: (_) => refreshPermissionSearch(update),
          ),
          if (permissionSearchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  permissionSearchError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ),
            ),
          if (permissionSearchOpen && permissionSearchEntries.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 10),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: permissionSearchEntries.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
                itemBuilder: (_, index) {
                  final item = permissionSearchEntries[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: item.color.withValues(alpha: 0.15),
                      child: Icon(item.icon, color: item.color),
                    ),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.searchSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => addPermissionEntry(item, update),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          ...permissionEntries.map((entry) => buildPermissionRow(entry, update)),
        ],
      );
    }

    Widget buildOptionSwitch({
      required IconData icon,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
      String? subtitle,
      Widget? child,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(icon),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: subtitle == null ? null : Text(subtitle),
            value: value,
            onChanged: onChanged,
          ),
          if (value && child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 0, 12),
              child: child,
            ),
        ],
      );
    }

    Widget buildCompactField({
      required TextEditingController controller,
      required String hint,
      String? suffix,
      bool obscure = false,
    }) {
      return TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: suffix == null ? TextInputType.text : TextInputType.number,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          suffixText: suffix,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      );
    }

    final edited = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          final screenWidth = MediaQuery.sizeOf(dialogContext).width;
          final dialogWidth = screenWidth >= 720 ? 680.0 : screenWidth - 32.0;

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            title: Row(
              children: [
                const Expanded(child: Text('编辑分享')),
                IconButton(
                  icon: const Icon(LucideIcons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: share.url));
                    ToastHelper.success('分享链接已复制');
                  },
                  tooltip: '复制分享链接',
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: '文件名',
                        prefixIcon: const Icon(LucideIcons.fileText),
                        suffixIcon: IconButton(
                          icon: const Icon(LucideIcons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: share.name));
                            ToastHelper.success('文件名已复制');
                          },
                          tooltip: '复制文件名',
                        ),
                      ),
                      controller: TextEditingController(text: share.name),
                      readOnly: true,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      decoration: InputDecoration(
                        labelText: '分享链接',
                        prefixIcon: const Icon(LucideIcons.link),
                        suffixIcon: IconButton(
                          icon: const Icon(LucideIcons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: share.url));
                            ToastHelper.success('分享链接已复制');
                          },
                          tooltip: '复制分享链接',
                        ),
                      ),
                      controller: TextEditingController(text: share.url),
                      readOnly: true,
                    ),
                    const SizedBox(height: 18),
                    buildPermissionSection(update),
                    const SizedBox(height: 16),
                    buildOptionSwitch(
                      icon: LucideIcons.lock,
                      title: '使用密码保护链接',
                      subtitle: '和旧 Windows 分享权限面板保持一致',
                      value: passwordProtected,
                      onChanged: (value) => update(() => passwordProtected = value),
                      child: buildCompactField(
                        controller: passwordController,
                        hint: '分享密码，留空则由服务端保留/生成',
                      ),
                    ),
                    buildOptionSwitch(
                      icon: LucideIcons.timer,
                      title: '超时自动过期',
                      value: timeoutExpire,
                      onChanged: (value) => update(() => timeoutExpire = value),
                      child: buildCompactField(
                        controller: expireDaysController,
                        hint: '有效期',
                        suffix: '天',
                      ),
                    ),
                    buildOptionSwitch(
                      icon: LucideIcons.download,
                      title: '下载后自动过期',
                      value: downloadExpire,
                      onChanged: (value) => update(() => downloadExpire = value),
                      child: buildCompactField(
                        controller: downloadsController,
                        hint: '下载次数',
                        suffix: '次',
                      ),
                    ),
                    buildOptionSwitch(
                      icon: Icons.account_balance_wallet_outlined,
                      title: '付费下载',
                      value: paidDownload,
                      onChanged: (value) => update(() => paidDownload = value),
                      child: buildCompactField(
                        controller: priceController,
                        hint: '价格',
                        suffix: '积分',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(LucideIcons.eye),
                      title: const Text('启用分享视图', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('允许使用分享页面预览文件'),
                      value: shareView,
                      onChanged: (value) => update(() => shareView = value),
                    ),
                    if (share.isFolder)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(LucideIcons.bookOpen),
                        title: const Text('显示 README', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('文件夹分享中展示说明文件'),
                        value: showReadme,
                        onChanged: (value) => update(() => showReadme = value),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (timeoutExpire && parsePositiveInt(expireDaysController) == null) {
                    ToastHelper.failure('请输入有效的过期天数');
                    return;
                  }
                  if (downloadExpire && parsePositiveInt(downloadsController) == null) {
                    ToastHelper.failure('请输入有效的下载次数');
                    return;
                  }
                  if (paidDownload && parsePositiveInt(priceController) == null) {
                    ToastHelper.failure('请输入有效的付费金额');
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (edited == true) {
      final expireDays = timeoutExpire ? parsePositiveInt(expireDaysController) : null;
      final downloads = downloadExpire ? parsePositiveInt(downloadsController) : null;
      final price = paidDownload ? parsePositiveInt(priceController) : null;
      final expireSeconds = expireDays == null ? null : expireDays * 24 * 60 * 60;

      setState(() => _isLoading = true);

      try {
        final shareInfo = await ShareService().getShareInfo(
          id: shareId,
          password: share.password,
          ownerExtended: true,
        );
        final sourceUri = shareInfo.sourceUri ?? share.sourceUri;
        if (sourceUri == null) {
          setState(() => _isLoading = false);
          if (mounted) ToastHelper.error('无法获取文件信息');
          return;
        }

        final uri = sourceUri.endsWith('/${share.name}')
            ? sourceUri
            : '$sourceUri/${share.name}';
        final newUrl = await ShareService().editShare(
          id: shareId,
          uri: uri,
          permissions: buildPermissions(),
          isPrivate: passwordProtected,
          password: passwordProtected && passwordController.text.trim().isNotEmpty
              ? passwordController.text.trim()
              : null,
          shareView: shareView,
          downloads: downloads,
          expire: expireSeconds,
          price: price,
          showReadme: share.isFolder ? showReadme : null,
        );

        setState(() => _isLoading = false);
        if (mounted) await _loadShares();
        if (mounted) {
          ToastHelper.success('修改成功');
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('分享链接'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(newUrl, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('复制到剪贴板'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: newUrl));
                      Navigator.of(dialogContext).pop();
                      ToastHelper.success('已复制到剪贴板');
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ToastHelper.failure('修改失败: $e');
      }
    }

    passwordController.dispose();
    expireDaysController.dispose();
    downloadsController.dispose();
    priceController.dispose();
    permissionSearchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的分享'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _refreshShares,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索分享内容...',
            prefixIcon: const Icon(LucideIcons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onChanged: (value) {
            _searchQuery = value.toLowerCase();
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    final filteredShares = _searchQuery.isEmpty
        ? _shares
        : _shares
            .where((s) =>
                s.name.toLowerCase().contains(_searchQuery) ||
                s.url.toLowerCase().contains(_searchQuery))
            .toList();

    if (_isLoading && _shares.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadShares(isLoadMore: false),
      child: _errorMessage != null
          ? _buildErrorState()
          : filteredShares.isEmpty
              ? (_searchQuery.isEmpty ? _buildEmptyState() : _buildNoSearchResult())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 800;
                    return isDesktop
                        ? _buildDesktopLayout(filteredShares)
                        : _buildMobileLayout(filteredShares);
                  },
                ),
    );
  }

  // ─── 桌面端布局 ───

  Widget _buildDesktopLayout(List<ShareModel> shares) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('文件名', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('类型', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('浏览/下载', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('创建时间', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: shares.map((share) {
            return DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Row(
                      children: [
                        Icon(_getShareIcon(share), size: 18, color: _getIconColor(share, colorScheme)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(share.name, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(share.isFolder ? '文件夹' : '文件')),
                DataCell(Text('${share.visited} / ${share.downloaded ?? 0}')),
                DataCell(_buildStatusBadge(share)),
                DataCell(Text(_formatDate(share.createdAt), style: const TextStyle(fontSize: 12))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: LucideIcons.pencil,
                        tooltip: '编辑',
                        onPressed: () => _editShare(share),
                      ),
                      _buildActionButton(
                        icon: LucideIcons.copy,
                        tooltip: '复制链接',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: share.url));
                          if (mounted) ToastHelper.success('链接已复制');
                        },
                      ),
                      _buildActionButton(
                        icon: LucideIcons.trash2,
                        tooltip: '删除',
                        color: colorScheme.error,
                        onPressed: () => _deleteShare(share),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
      ),
    );
  }

  // ─── 移动端布局 ───

  Widget _buildMobileLayout(List<ShareModel> shares) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: shares.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= shares.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final share = shares[index];
        final iconColor = _getIconColor(share, theme.colorScheme);
        return InkWell(
          onTap: () => _editShare(share),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getShareIcon(share), size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        share.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildStatusBadge(share),
                          const SizedBox(width: 8),
                          Text(
                            '浏览 ${share.visited} · 下载 ${share.downloaded ?? 0}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical, size: 18),
                  onPressed: () => _showMobileActionMenu(share),
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 状态徽章 ───

  Widget _buildStatusBadge(ShareModel share) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpired = share.expired;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isExpired
            ? colorScheme.error.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isExpired ? '已过期' : '正常',
        style: TextStyle(
          color: isExpired ? colorScheme.error : Colors.green,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── 桌面端操作按钮 ───

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(4),
        minimumSize: const Size(32, 32),
      ),
    );
  }

  // ─── 图标与颜色 ───

  IconData _getShareIcon(ShareModel share) {
    if (share.isFolder) return LucideIcons.folder;
    final name = share.name;
    if (FileTypeUtils.isImage(name)) return LucideIcons.image;
    if (FileTypeUtils.isPdf(name)) return LucideIcons.fileText;
    if (FileTypeUtils.isVideo(name)) return LucideIcons.video;
    if (FileTypeUtils.isAudio(name)) return LucideIcons.music;
    if (FileTypeUtils.isMarkdown(name)) return LucideIcons.fileText;
    if (FileTypeUtils.isTextCode(name)) return LucideIcons.code;
    return LucideIcons.file;
  }

  Color _getIconColor(ShareModel share, ColorScheme colorScheme) {
    if (share.isFolder) return Colors.amber.shade700;
    final name = share.name;
    if (FileTypeUtils.isImage(name)) return Colors.purple.shade600;
    if (FileTypeUtils.isPdf(name)) return Colors.red.shade600;
    if (FileTypeUtils.isVideo(name)) return Colors.orange.shade600;
    if (FileTypeUtils.isAudio(name)) return Colors.blue.shade600;
    if (FileTypeUtils.isMarkdown(name)) return Colors.teal.shade600;
    if (FileTypeUtils.isTextCode(name)) return Colors.cyan.shade700;
    return colorScheme.onSurfaceVariant;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return '今天';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ─── 移动端菜单 ───

  void _showMobileActionMenu(ShareModel share) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: const Text('修改分享设置'),
              onTap: () {
                Navigator.pop(context);
                _editShare(share);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.copy),
              title: const Text('复制链接'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: share.url));
                if (mounted) ToastHelper.success('链接已复制');
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: colorScheme.error),
              title: Text('取消分享', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteShare(share);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── 空状态 / 错误状态 ───

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.share2, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text('还没有分享过文件', style: TextStyle(color: theme.hintColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoSearchResult() {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.searchX, size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text('没有找到 "$_searchQuery"', style: TextStyle(color: theme.hintColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.alertCircle, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('加载失败', style: TextStyle(color: theme.hintColor)),
                const SizedBox(height: 8),
                Text(_errorMessage ?? '未知错误',
                    style: TextStyle(fontSize: 12, color: theme.hintColor)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('重试'),
                  onPressed: _refreshShares,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
