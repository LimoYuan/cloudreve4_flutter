import '../config/api_config.dart';
import '../data/models/server_model.dart';
import '../data/models/user_model.dart';
import 'storage_service.dart';
import '../core/utils/app_logger.dart';

/// 服务器服务 - 管理多个服务器配置
///
/// 现在的规则：
/// - 一个 ServerModel 表示一个站点；
/// - 同一个站点下的多个账号保存在 ServerModel.accounts；
/// - 不再为了添加账号而新增“管理服务器”条目。
class ServerService {
  static ServerService? _instance;
  ServerService._();

  static ServerService get instance {
    _instance ??= ServerService._();
    return _instance!;
  }

  static const String _defaultLabel = 'Cloudreve 官方';
  static const String _defaultBaseUrl = ApiConfig.defaultBaseUrl;
  static const Object _unset = Object();

  List<ServerModel> _servers = [];
  ServerModel? _currentServer;

  /// 获取所有服务器
  List<ServerModel> get servers => List.unmodifiable(_servers);

  /// 获取当前选中的服务器
  ServerModel? get currentServer => _currentServer;

  /// 当前站点保存的账号
  List<UserModel> get currentAccounts =>
      List.unmodifiable(_currentServer?.accounts ?? const []);

  /// 初始化服务器列表
  Future<void> init() async {
    await _loadServers();
  }

  /// 从存储加载服务器列表
  Future<void> _loadServers() async {
    try {
      final loadedServers = await StorageService.instance.servers;

      if (loadedServers.isEmpty) {
        _servers = [
          ServerModel(
            label: _defaultLabel,
            baseUrl: _defaultBaseUrl,
          ),
        ];
        await _saveServers();
        _currentServer = _servers.first;
        return;
      }

      final lastSelectedLabel = await StorageService.instance.lastSelectedServerLabel;
      final selectedRaw = lastSelectedLabel == null
          ? null
          : loadedServers.where((s) => s.label == lastSelectedLabel).cast<ServerModel?>().firstOrNull;

      _servers = _mergeSameBaseUrlServers(loadedServers, selectedRaw: selectedRaw);

      if (selectedRaw != null) {
        final index = _servers.indexWhere(
          (s) => _normalizeBaseUrl(s.baseUrl) == _normalizeBaseUrl(selectedRaw.baseUrl),
        );
        if (index != -1) {
          _currentServer = _servers[index];
          await _saveLastSelected();
        }
      }

      _currentServer ??= _servers.first;

      await _saveServers();

      AppLogger.d('加载了 ${_servers.length} 个服务器配置');
      AppLogger.d('当前服务器: ${_currentServer?.label}');
    } catch (e) {
      AppLogger.d('加载服务器列表失败: $e');
      _servers = [
        ServerModel(
          label: _defaultLabel,
          baseUrl: _defaultBaseUrl,
        ),
      ];
      _currentServer = _servers.first;
    }
  }

  List<ServerModel> _mergeSameBaseUrlServers(
    List<ServerModel> source, {
    ServerModel? selectedRaw,
  }) {
    final result = <ServerModel>[];
    final byBaseUrl = <String, int>{};

    for (final server in source) {
      final key = _normalizeBaseUrl(server.baseUrl);
      final accounts = _accountsFromServer(server);

      final existingIndex = byBaseUrl[key];
      if (existingIndex == null) {
        byBaseUrl[key] = result.length;
        result.add(
          server.copyWith(
            accounts: accounts,
          ),
        );
        continue;
      }

      final existing = result[existingIndex];
      final mergedAccounts = <UserModel>[...existing.accounts];
      for (final account in accounts) {
        _upsertAccount(mergedAccounts, account);
      }

      var mergedUser = existing.user;
      var mergedEmail = existing.email;
      var mergedPassword = existing.password;
      var mergedRememberMe = existing.rememberMe;

      if (selectedRaw != null && server.label == selectedRaw.label) {
        mergedUser = server.user ?? existing.user;
        mergedEmail = server.email ?? existing.email;
        mergedPassword = server.password ?? existing.password;
        mergedRememberMe = server.rememberMe;
      }

      result[existingIndex] = existing.copyWith(
        user: mergedUser,
        email: mergedEmail,
        password: mergedPassword,
        rememberMe: mergedRememberMe,
        accounts: mergedAccounts,
      );
    }

    return result;
  }

  List<UserModel> _accountsFromServer(ServerModel server) {
    final accounts = <UserModel>[...server.accounts];
    final user = server.user;
    if (user != null) {
      _upsertAccount(accounts, user);
    }
    return accounts;
  }

  String _normalizeBaseUrl(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url.toLowerCase();
  }

  /// 保存服务器列表到存储
  Future<void> _saveServers() async {
    try {
      await StorageService.instance.setServers(_servers);
      AppLogger.d('已保存 ${_servers.length} 个服务器配置');
    } catch (e) {
      AppLogger.d('保存服务器列表失败: $e');
    }
  }

  /// 保存上次选中的服务器
  Future<void> _saveLastSelected() async {
    if (_currentServer != null) {
      await StorageService.instance.setLastSelectedServerLabel(_currentServer!.label);
    }
  }

  /// 添加服务器
  Future<void> addServer(ServerModel server) async {
    if (_servers.any((s) => s.label == server.label)) {
      throw Exception('服务器名称已存在');
    }

    _servers.add(server);
    await _saveServers();
  }

  /// 更新服务器
  Future<void> updateServer(String oldLabel, ServerModel newServer) async {
    final index = _servers.indexWhere((s) => s.label == oldLabel);
    if (index == -1) {
      throw Exception('服务器不存在');
    }

    if (oldLabel != newServer.label && _servers.any((s) => s.label == newServer.label)) {
      throw Exception('服务器名称已存在');
    }

    _servers[index] = newServer;

    if (_currentServer?.label == oldLabel) {
      _currentServer = newServer;
    }

    await _saveServers();
    await _saveLastSelected();
  }

  /// 删除服务器
  Future<void> deleteServer(String label) async {
    if (_servers.length == 1) {
      throw Exception('至少保留一个服务器配置');
    }

    _servers.removeWhere((s) => s.label == label);

    if (_currentServer?.label == label) {
      _currentServer = _servers.first;
    }

    await _saveServers();
    await _saveLastSelected();
  }

  /// 选择服务器
  Future<void> selectServer(String label) async {
    final server = _servers.firstWhere((s) => s.label == label);
    _currentServer = server;
    await _saveLastSelected();
    AppLogger.d('已选择服务器: ${server.label}');
  }

  /// 更新当前服务器的登录信息。
  ///
  /// user 传入 UserModel 时，会写入 currentServer.user，并加入 accounts。
  /// user 传入 null 时，会清除 currentServer.user。
  Future<void> updateCurrentServerLogin({
    String? email,
    String? password,
    Object? user = _unset,
    bool? rememberMe,
  }) async {
    if (_currentServer == null) {
      throw Exception('没有选中的服务器');
    }

    final accounts = <UserModel>[..._currentServer!.accounts];
    Object? nextUser = user;

    if (user is UserModel) {
      _upsertAccount(accounts, user);
      nextUser = user;
    } else if (identical(user, _unset)) {
      nextUser = _currentServer!.user;
    }

    _currentServer = _currentServer!.copyWith(
      email: email,
      password: password,
      user: nextUser,
      rememberMe: rememberMe ?? _currentServer!.rememberMe,
      accounts: accounts,
    );

    final index = _servers.indexWhere((s) => s.label == _currentServer!.label);
    if (index != -1) {
      _servers[index] = _currentServer!;
    }

    await _saveServers();
  }

  /// 清除当前服务器的登录信息。
  Future<void> clearCurrentServerLogin({bool removeCurrentAccount = true}) async {
    if (_currentServer == null) return;

    var accounts = <UserModel>[..._currentServer!.accounts];
    final currentUser = _currentServer!.user;

    if (removeCurrentAccount && currentUser != null) {
      accounts = accounts
          .where((account) => !_isSameAccount(account, currentUser))
          .toList();
    }

    _currentServer = _currentServer!.copyWith(
      email: null,
      password: null,
      user: null,
      accounts: accounts,
    );

    final index = _servers.indexWhere((s) => s.label == _currentServer!.label);
    if (index != -1) {
      _servers[index] = _currentServer!;
    }

    await _saveServers();
  }

  /// 添加同站点新账号前的准备动作。
  ///
  /// 现在不再清空当前登录状态。只有登录新账号成功后才会覆盖 currentServer.user；
  /// 如果用户从登录页返回，原账号仍保持登录。
  Future<void> prepareAddAccountForCurrentServer() async {
    await _saveServers();
  }

  /// 切换当前站点下的账号。
  Future<void> switchCurrentServerAccount(String accountKey) async {
    if (_currentServer == null) {
      throw Exception('没有选中的服务器');
    }

    final account = _currentServer!.accounts.firstWhere(
      (user) => user.id == accountKey || user.email == accountKey,
      orElse: () => throw Exception('账号不存在'),
    );

    _currentServer = _currentServer!.copyWith(
      user: account,
      email: account.email,
      password: null,
    );

    final index = _servers.indexWhere((s) => s.label == _currentServer!.label);
    if (index != -1) {
      _servers[index] = _currentServer!;
    }

    await _saveServers();
    await _saveLastSelected();
  }

  void _upsertAccount(List<UserModel> accounts, UserModel user) {
    final index = accounts.indexWhere((item) => _isSameAccount(item, user));
    if (index == -1) {
      accounts.add(user);
    } else {
      accounts[index] = user;
    }
  }

  bool _isSameAccount(UserModel a, UserModel b) {
    return a.id == b.id || (a.email != null && a.email == b.email);
  }

  /// 删除当前站点下保存的指定账号。
  ///
  /// 如果删除的是当前正在使用的账号，会同时清空 currentServer.user。
  /// 不会删除服务器配置本身。
  Future<void> removeCurrentServerAccount(String accountKey) async {
    if (_currentServer == null) {
      throw Exception('没有选中的服务器');
    }

    final currentUser = _currentServer!.user;
    final accounts = _currentServer!.accounts
        .where((account) => account.id != accountKey && account.email != accountKey)
        .toList();

    final removeCurrent = currentUser != null &&
        (currentUser.id == accountKey || currentUser.email == accountKey);

    _currentServer = _currentServer!.copyWith(
      user: removeCurrent ? null : _currentServer!.user,
      email: removeCurrent ? null : _currentServer!.email,
      password: removeCurrent ? null : _currentServer!.password,
      accounts: accounts,
    );

    final index = _servers.indexWhere((s) => s.label == _currentServer!.label);
    if (index != -1) {
      _servers[index] = _currentServer!;
    }

    await _saveServers();
  }

  /// 重置为默认服务器列表
  Future<void> resetToDefault() async {
    _servers = [
      ServerModel(
        label: _defaultLabel,
        baseUrl: _defaultBaseUrl,
      ),
    ];
    _currentServer = _servers.first;
    await _saveServers();
    await _saveLastSelected();
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
