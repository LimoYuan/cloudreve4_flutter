import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/download_task_model.dart';
import '../data/models/upload_task_model.dart';

part 'task_database.g.dart';

// ============ Upload Tasks 表 ============
@DataClassName('UploadTaskEntry')
class UploadTasks extends Table {
  TextColumn get id => text()();
  TextColumn get filePath => text()();
  TextColumn get fileName => text()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  TextColumn get targetPath => text()();
  TextColumn get sourceUri => text().nullable()();
  BoolColumn get overwrite => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get completedAt => text().nullable()();
  IntColumn get status => integer()();
  IntColumn get uploadedBytes => integer().withDefault(const Constant(0))();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  IntColumn get uploadedChunks => integer().withDefault(const Constant(0))();
  IntColumn get totalChunks => integer().withDefault(const Constant(1))();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get session => text().nullable()();
  IntColumn get speed => integer().withDefault(const Constant(0))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ Download Tasks 表 ============
@DataClassName('DownloadTaskEntry')
class DownloadTasks extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get fileUri => text()();
  TextColumn get downloadUrl => text().nullable()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  TextColumn get savePath => text()();
  TextColumn get backgroundTaskId => text().nullable()();
  IntColumn get status => integer()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get speed => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()();
  TextColumn get completedAt => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [UploadTasks, DownloadTasks])
class TaskDatabase extends _$TaskDatabase {
  TaskDatabase._() : super(_openConnection());
  static final TaskDatabase instance = TaskDatabase._();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_upload_status ON upload_tasks(status)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_upload_updated ON upload_tasks(updated_at DESC)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_download_status ON download_tasks(status)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_download_updated ON download_tasks(updated_at DESC)',
          );
        },
      );

  // ============ Upload DAO ============

  Future<void> upsertUploadTask(UploadTasksCompanion companion) =>
      into(uploadTasks).insertOnConflictUpdate(companion);

  Future<void> deleteUploadTask(String id) =>
      (delete(uploadTasks)..where((t) => t.id.equals(id))).go();

  Future<void> deleteUploadTasksByStatus(List<int> statusIndexes) =>
      (delete(uploadTasks)..where((t) => t.status.isIn(statusIndexes))).go();

  Future<void> deleteAllUploadTasks() => delete(uploadTasks).go();

  Future<void> updateUploadTaskFields(
    String id, {
    int? status,
    int? uploadedBytes,
    double? progress,
    int? uploadedChunks,
    int? totalChunks,
    int? speed,
    String? errorMessage,
    String? completedAt,
    String? session,
    String? updatedAt,
  }) async {
    final companion = UploadTasksCompanion(
      id: Value(id),
      status: status == null ? const Value.absent() : Value(status),
      uploadedBytes: uploadedBytes == null
          ? const Value.absent()
          : Value(uploadedBytes),
      progress: progress == null ? const Value.absent() : Value(progress),
      uploadedChunks:
          uploadedChunks == null ? const Value.absent() : Value(uploadedChunks),
      totalChunks:
          totalChunks == null ? const Value.absent() : Value(totalChunks),
      speed: speed == null ? const Value.absent() : Value(speed),
      errorMessage:
          errorMessage == null ? const Value.absent() : Value(errorMessage),
      completedAt:
          completedAt == null ? const Value.absent() : Value(completedAt),
      session: session == null ? const Value.absent() : Value(session),
      updatedAt: updatedAt == null ? const Value.absent() : Value(updatedAt),
    );
    await (update(uploadTasks)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<List<UploadTaskEntry>> queryActiveUploadTasks() {
    final activeStatuses = [
      UploadStatus.waiting.index,
      UploadStatus.uploading.index,
      UploadStatus.paused.index,
    ];
    return (select(uploadTasks)
          ..where((t) => t.status.isIn(activeStatuses))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<UploadTaskEntry>> queryUploadTasks({
    required List<int> statusIndexes,
    int limit = 20,
    int offset = 0,
  }) {
    return (select(uploadTasks)
          ..where((t) => t.status.isIn(statusIndexes))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Stream<List<UploadTaskEntry>> watchUploadTasks({
    required List<int> statusIndexes,
    int limit = 20,
    int offset = 0,
  }) {
    return (select(uploadTasks)
          ..where((t) => t.status.isIn(statusIndexes))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset))
        .watch();
  }

  Future<int> countUploadTasksByStatus(List<int> statusIndexes) async {
    final count = countAll();
    final query = selectOnly(uploadTasks)
      ..addColumns([count])
      ..where(uploadTasks.status.isIn(statusIndexes));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Stream 监听指定状态任务的总数（用于分页计算总页数）
  Stream<int> watchUploadTasksCount(List<int> statusIndexes) {
    final count = countAll();
    final query = selectOnly(uploadTasks)
      ..addColumns([count])
      ..where(uploadTasks.status.isIn(statusIndexes));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // ============ Download DAO ============

  Future<void> upsertDownloadTask(DownloadTasksCompanion companion) =>
      into(downloadTasks).insertOnConflictUpdate(companion);

  Future<void> deleteDownloadTask(String id) =>
      (delete(downloadTasks)..where((t) => t.id.equals(id))).go();

  Future<void> deleteDownloadTasksByStatus(List<int> statusIndexes) =>
      (delete(downloadTasks)..where((t) => t.status.isIn(statusIndexes))).go();

  Future<void> deleteAllDownloadTasks() => delete(downloadTasks).go();

  Future<void> updateDownloadTaskFields(
    String id, {
    int? status,
    int? downloadedBytes,
    int? fileSize,
    int? speed,
    String? errorMessage,
    String? completedAt,
    String? backgroundTaskId,
    String? downloadUrl,
    String? updatedAt,
  }) async {
    final companion = DownloadTasksCompanion(
      id: Value(id),
      status: status == null ? const Value.absent() : Value(status),
      downloadedBytes: downloadedBytes == null
          ? const Value.absent()
          : Value(downloadedBytes),
      fileSize: fileSize == null ? const Value.absent() : Value(fileSize),
      speed: speed == null ? const Value.absent() : Value(speed),
      errorMessage:
          errorMessage == null ? const Value.absent() : Value(errorMessage),
      completedAt:
          completedAt == null ? const Value.absent() : Value(completedAt),
      backgroundTaskId: backgroundTaskId == null
          ? const Value.absent()
          : Value(backgroundTaskId),
      downloadUrl:
          downloadUrl == null ? const Value.absent() : Value(downloadUrl),
      updatedAt: updatedAt == null ? const Value.absent() : Value(updatedAt),
    );
    await (update(downloadTasks)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  Future<List<DownloadTaskEntry>> queryActiveDownloadTasks() {
    final activeStatuses = [
      DownloadStatus.waiting.index,
      DownloadStatus.downloading.index,
      DownloadStatus.paused.index,
      DownloadStatus.archiving.index,
    ];
    return (select(downloadTasks)
          ..where((t) => t.status.isIn(activeStatuses))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<DownloadTaskEntry>> queryDownloadTasks({
    required List<int> statusIndexes,
    int limit = 20,
    int offset = 0,
  }) {
    return (select(downloadTasks)
          ..where((t) => t.status.isIn(statusIndexes))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Stream<List<DownloadTaskEntry>> watchDownloadTasks({
    required List<int> statusIndexes,
    int limit = 20,
    int offset = 0,
  }) {
    return (select(downloadTasks)
          ..where((t) => t.status.isIn(statusIndexes))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit, offset: offset))
        .watch();
  }

  Future<int> countDownloadTasksByStatus(List<int> statusIndexes) async {
    final count = countAll();
    final query = selectOnly(downloadTasks)
      ..addColumns([count])
      ..where(downloadTasks.status.isIn(statusIndexes));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Stream 监听指定状态下载任务的总数（用于分页计算总页数）
  Stream<int> watchDownloadTasksCount(List<int> statusIndexes) {
    final count = countAll();
    final query = selectOnly(downloadTasks)
      ..addColumns([count])
      ..where(downloadTasks.status.isIn(statusIndexes));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // ============ 迁移辅助 ============

  /// 批量插入上传任务（迁移用，遇到冲突替换）
  Future<void> batchUpsertUploadTasks(
    Iterable<UploadTasksCompanion> companions,
  ) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(uploadTasks, companions.toList());
    });
  }

  /// 批量插入下载任务（迁移用，遇到冲突替换）
  Future<void> batchUpsertDownloadTasks(
    Iterable<DownloadTasksCompanion> companions,
  ) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(downloadTasks, companions.toList());
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // 与项目内其他应用数据（avatar_cache / site_brand_cache / sync_core 等）一致，
    // 使用 applicationSupportDirectory：
    // - Windows: %APPDATA%\cloudreve4_flutter\tasks.sqlite
    // - Linux: ~/.local/share/cloudreve4_flutter/tasks.sqlite
    // - macOS: ~/Library/Application Support/cloudreve4_flutter/tasks.sqlite
    // - Android: /data/data/<pkg>/files/tasks.sqlite
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/tasks.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
