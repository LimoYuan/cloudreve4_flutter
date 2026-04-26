import '../config/api_config.dart';
import '../data/models/server_model.dart';
import '../data/models/user_model.dart';
import 'storage_service.dart';
import '../core/utils/app_logger.dart';

/// 服务器服务 - 管理多个服务器配置
class ServerService {
  static ServerService? _instance;
  ServerService._();

  static ServerService get instance {
    _instance ??= ServerService._();
    return _instance!;
  }

  static const String _defaultLabel = 'Cloudreve 官方';
  static const String _defaultBaseUrl = ApiConfig.defaultBaseUrl;

  List<ServerModel> _servers = [];
  ServerModel? _currentServer;

  /// 获取所有服务器
  List<ServerModel> get servers => List.unmodifiable(_servers);

  /// 获取当前选中的服务器
  ServerModel? get currentServer => _currentServer;

  /// 初始化服务器列表
  Future<void> init() async {
    await _loadServers();
  }

  /// 从存储加载服务器列表
  Future<void> _loadServers() async {
    try {
      // 从 StorageService 加载服务器列表
      final loadedServers = await StorageService.instance.servers;

      if (loadedServers.isEmpty) {
        // 如果没有保存的服务器，使用默认服务器
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

      _servers = loadedServers;

      // 加载上次选中的服务器
      final lastSelectedLabel = await StorageService.instance.lastSelectedServerLabel;
      if (lastSelectedLabel != null) {
        _currentServer = _servers.firstWhere(
          (s) => s.label == lastSelectedLabel,
          orElse: () => _servers.first,
        );
      } else if (_servers.isNotEmpty) {
        _currentServer = _servers.first;
      }

      AppLogger.d('加载了 ${_servers.length} 个服务器配置');
      AppLogger.d('当前服务器: ${_currentServer?.label}');
    } catch (e) {
      AppLogger.d('加载服务器列表失败: $e');
      // 加载失败时使用默认服务器
      _servers = [
        ServerModel(
          label: _defaultLabel,
          baseUrl: _defaultBaseUrl,
        ),
      ];
      _currentServer = _servers.first;
    }
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
    // 检查 label 是否已存在
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

    // 如果修改了 label，检查新 label 是否已存在
    if (oldLabel != newServer.label && _servers.any((s) => s.label == newServer.label)) {
      throw Exception('服务器名称已存在');
    }

    _servers[index] = newServer;

    // 如果更新的是当前服务器，更新引用
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

    // 如果删除的是当前服务器，切换到第一个
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

  /// 更新当前服务器的服务登录信息
  Future<void> updateCurrentServerLogin({
    String? email,
    String? password,
    UserModel? user,
    bool? rememberMe,
  }) async {
    if (_currentServer == null) {
      throw Exception('没有选中的服务器');
    }

    _currentServer = _currentServer!.copyWith(
      email: email,
      password: password,
      user: user,
      rememberMe: rememberMe ?? _currentServer!.rememberMe,
    );

    // 更新列表中的引用
    final index = _servers.indexWhere((s) => s.label == _currentServer!.label);
    if (index != -1) {
      _servers[index] = _currentServer!;
    }

    await _saveServers();
  }

  /// 清除当前服务器的服务登录信息
  Future<void> clearCurrentServerLogin() async {
    await updateCurrentServerLogin(
      email: null,
      password: null,
      user: null,
    );
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
