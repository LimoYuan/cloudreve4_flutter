import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/constants/storage_keys.dart';
import '../core/utils/file_type_utils.dart';
import '../data/models/file_model.dart';
import '../data/models/share_model.dart';
import 'storage_service.dart';

/// 本地最近活动统计服务。
///
/// 只读写用户本机 SharedPreferences，不主动请求服务器。
/// 概览页的最近分享、最近查看/编辑都从这里读取。
class LocalRecentActivityService {
  LocalRecentActivityService._();

  static final LocalRecentActivityService instance = LocalRecentActivityService._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const int defaultDisplayLimit = 10;
  static const int _maxStoredItems = 120;

  Future<int> getDisplayLimit() async {
    final value = await StorageService.instance.getInt(StorageKeys.recentActivityDisplayLimit);
    return (value ?? defaultDisplayLimit).clamp(1, 50).toInt();
  }

  Future<void> setDisplayLimit(int value) async {
    await StorageService.instance.setInt(
      StorageKeys.recentActivityDisplayLimit,
      value.clamp(1, 50).toInt(),
    );
    _notifyChanged();
  }

  Future<List<LocalRecentFileActivity>> getFileActivities({int? limit}) async {
    final items = await _readList(
      StorageKeys.localRecentFileActivities,
      LocalRecentFileActivity.fromJson,
    );
    final sorted = [...items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final take = limit ?? await getDisplayLimit();
    return sorted.take(take).toList();
  }

  Future<List<LocalRecentShareActivity>> getShareActivities({int? limit}) async {
    final items = await _readList(
      StorageKeys.localRecentShareActivities,
      LocalRecentShareActivity.fromJson,
    );
    final sorted = [...items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final take = limit ?? await getDisplayLimit();
    return sorted.take(take).toList();
  }

  Future<void> recordViewedFile(FileModel file) async {
    await _recordFile(file, LocalRecentFileAction.view);
  }

  Future<void> recordEditedFile(FileModel file, {String? actionLabel}) async {
    await _recordFile(file, LocalRecentFileAction.edit, actionLabel: actionLabel);
  }

  Future<void> recordEditedPath(String uri, {String? name, int? size, String? actionLabel}) async {
    final now = DateTime.now();
    final fileName = (name == null || name.isEmpty) ? _nameFromUri(uri) : name;
    final item = LocalRecentFileActivity(
      id: _safeId(uri),
      name: fileName,
      path: uri,
      size: size,
      typeLabel: _typeLabel(fileName),
      action: LocalRecentFileAction.edit,
      actionLabel: actionLabel ?? '编辑',
      updatedAt: now,
    );
    await _upsertFileActivity(item);
  }

  Future<void> recordSharedFileFromFile(FileModel file, String url) async {
    final item = LocalRecentShareActivity(
      id: url.isNotEmpty ? url : _safeId(file.path),
      name: file.name,
      typeLabel: file.isFolder ? '文件夹' : FileTypeUtils.getFileTypeDescription(file.name),
      visited: 0,
      downloaded: 0,
      isExpired: false,
      url: url,
      updatedAt: DateTime.now(),
    );
    await _upsertShareActivity(item);
  }

  /// 缓存"我的分享"页已经加载过的分享数据。
  /// 这样概览页可以复用本地数据，不再额外请求服务器。
  Future<void> cacheShareList(List<ShareModel> shares) async {
    if (shares.isEmpty) return;
    final existing = await _readList(
      StorageKeys.localRecentShareActivities,
      LocalRecentShareActivity.fromJson,
    );
    final map = <String, LocalRecentShareActivity>{
      for (final item in existing) item.id: item,
    };

    for (final share in shares) {
      final id = share.url.isNotEmpty ? share.url : share.id;
      final old = map[id];
      map[id] = LocalRecentShareActivity(
        id: id,
        name: share.name,
        typeLabel: share.isFolder ? '文件夹' : FileTypeUtils.getFileTypeDescription(share.name),
        visited: share.visited,
        downloaded: share.downloaded ?? 0,
        isExpired: share.expired,
        url: share.url,
        updatedAt: old?.updatedAt ?? share.createdAt,
      );
    }

    final merged = map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _writeList(
      StorageKeys.localRecentShareActivities,
      merged.take(_maxStoredItems).map((e) => e.toJson()).toList(),
    );
    _notifyChanged();
  }

  Future<void> clearAll() async {
    await StorageService.instance.remove(StorageKeys.localRecentFileActivities);
    await StorageService.instance.remove(StorageKeys.localRecentShareActivities);
    _notifyChanged();
  }

  Future<void> _recordFile(
    FileModel file,
    LocalRecentFileAction action, {
    String? actionLabel,
  }) async {
    final item = LocalRecentFileActivity(
      id: _safeId(file.id.isNotEmpty ? file.id : file.path),
      name: file.name,
      path: file.path,
      size: file.size,
      typeLabel: file.isFolder ? '文件夹' : FileTypeUtils.getFileTypeDescription(file.name),
      action: action,
      actionLabel: actionLabel ?? (action == LocalRecentFileAction.view ? '查看' : '编辑'),
      updatedAt: DateTime.now(),
    );
    await _upsertFileActivity(item);
  }

  Future<void> _upsertFileActivity(LocalRecentFileActivity item) async {
    final items = await _readList(
      StorageKeys.localRecentFileActivities,
      LocalRecentFileActivity.fromJson,
    );
    items.removeWhere((old) => old.id == item.id && old.action == item.action);
    items.insert(0, item);
    await _writeList(
      StorageKeys.localRecentFileActivities,
      items.take(_maxStoredItems).map((e) => e.toJson()).toList(),
    );
    _notifyChanged();
  }

  Future<void> _upsertShareActivity(LocalRecentShareActivity item) async {
    final items = await _readList(
      StorageKeys.localRecentShareActivities,
      LocalRecentShareActivity.fromJson,
    );
    items.removeWhere((old) => old.id == item.id);
    items.insert(0, item);
    await _writeList(
      StorageKeys.localRecentShareActivities,
      items.take(_maxStoredItems).map((e) => e.toJson()).toList(),
    );
    _notifyChanged();
  }

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, dynamic> json) decoder,
  ) async {
    final raw = await StorageService.instance.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(decoder)
          .toList();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> data) async {
    await StorageService.instance.setString(key, jsonEncode(data));
  }

  String _safeId(String value) => value.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : value;

  String _nameFromUri(String uri) {
    final cleaned = uri.split('?').first;
    final parts = cleaned.split('/')..removeWhere((part) => part.isEmpty);
    return parts.isEmpty ? uri : parts.last;
  }

  String _typeLabel(String name) => FileTypeUtils.getFileTypeDescription(name);

  void _notifyChanged() {
    revision.value++;
  }
}

enum LocalRecentFileAction { view, edit }

class LocalRecentFileActivity {
  final String id;
  final String name;
  final String path;
  final int? size;
  final String typeLabel;
  final LocalRecentFileAction action;
  final String actionLabel;
  final DateTime updatedAt;

  const LocalRecentFileActivity({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.typeLabel,
    required this.action,
    required this.actionLabel,
    required this.updatedAt,
  });

  factory LocalRecentFileActivity.fromJson(Map<String, dynamic> json) {
    return LocalRecentFileActivity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt(),
      typeLabel: json['typeLabel']?.toString() ?? '文件',
      action: json['action'] == 'edit' ? LocalRecentFileAction.edit : LocalRecentFileAction.view,
      actionLabel: json['actionLabel']?.toString() ?? (json['action'] == 'edit' ? '编辑' : '查看'),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'size': size,
        'typeLabel': typeLabel,
        'action': action == LocalRecentFileAction.edit ? 'edit' : 'view',
        'actionLabel': actionLabel,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class LocalRecentShareActivity {
  final String id;
  final String name;
  final String typeLabel;
  final int visited;
  final int downloaded;
  final bool isExpired;
  final String url;
  final DateTime updatedAt;

  const LocalRecentShareActivity({
    required this.id,
    required this.name,
    required this.typeLabel,
    required this.visited,
    required this.downloaded,
    required this.isExpired,
    required this.url,
    required this.updatedAt,
  });

  factory LocalRecentShareActivity.fromJson(Map<String, dynamic> json) {
    return LocalRecentShareActivity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      typeLabel: json['typeLabel']?.toString() ?? '文件',
      visited: (json['visited'] as num?)?.toInt() ?? 0,
      downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
      isExpired: json['isExpired'] == true,
      url: json['url']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'typeLabel': typeLabel,
        'visited': visited,
        'downloaded': downloaded,
        'isExpired': isExpired,
        'url': url,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
