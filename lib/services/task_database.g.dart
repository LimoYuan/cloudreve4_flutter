// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_database.dart';

// ignore_for_file: type=lint
class $UploadTasksTable extends UploadTasks
    with TableInfo<$UploadTasksTable, UploadTaskEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UploadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetPathMeta = const VerificationMeta(
    'targetPath',
  );
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
    'target_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUriMeta = const VerificationMeta(
    'sourceUri',
  );
  @override
  late final GeneratedColumn<String> sourceUri = GeneratedColumn<String>(
    'source_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overwriteMeta = const VerificationMeta(
    'overwrite',
  );
  @override
  late final GeneratedColumn<bool> overwrite = GeneratedColumn<bool>(
    'overwrite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("overwrite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uploadedBytesMeta = const VerificationMeta(
    'uploadedBytes',
  );
  @override
  late final GeneratedColumn<int> uploadedBytes = GeneratedColumn<int>(
    'uploaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _uploadedChunksMeta = const VerificationMeta(
    'uploadedChunks',
  );
  @override
  late final GeneratedColumn<int> uploadedChunks = GeneratedColumn<int>(
    'uploaded_chunks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalChunksMeta = const VerificationMeta(
    'totalChunks',
  );
  @override
  late final GeneratedColumn<int> totalChunks = GeneratedColumn<int>(
    'total_chunks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionMeta = const VerificationMeta(
    'session',
  );
  @override
  late final GeneratedColumn<String> session = GeneratedColumn<String>(
    'session',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<int> speed = GeneratedColumn<int>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filePath,
    fileName,
    fileSize,
    targetPath,
    sourceUri,
    overwrite,
    createdAt,
    completedAt,
    status,
    uploadedBytes,
    progress,
    uploadedChunks,
    totalChunks,
    errorMessage,
    session,
    speed,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upload_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<UploadTaskEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('target_path')) {
      context.handle(
        _targetPathMeta,
        targetPath.isAcceptableOrUnknown(data['target_path']!, _targetPathMeta),
      );
    } else if (isInserting) {
      context.missing(_targetPathMeta);
    }
    if (data.containsKey('source_uri')) {
      context.handle(
        _sourceUriMeta,
        sourceUri.isAcceptableOrUnknown(data['source_uri']!, _sourceUriMeta),
      );
    }
    if (data.containsKey('overwrite')) {
      context.handle(
        _overwriteMeta,
        overwrite.isAcceptableOrUnknown(data['overwrite']!, _overwriteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('uploaded_bytes')) {
      context.handle(
        _uploadedBytesMeta,
        uploadedBytes.isAcceptableOrUnknown(
          data['uploaded_bytes']!,
          _uploadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('uploaded_chunks')) {
      context.handle(
        _uploadedChunksMeta,
        uploadedChunks.isAcceptableOrUnknown(
          data['uploaded_chunks']!,
          _uploadedChunksMeta,
        ),
      );
    }
    if (data.containsKey('total_chunks')) {
      context.handle(
        _totalChunksMeta,
        totalChunks.isAcceptableOrUnknown(
          data['total_chunks']!,
          _totalChunksMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('session')) {
      context.handle(
        _sessionMeta,
        session.isAcceptableOrUnknown(data['session']!, _sessionMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UploadTaskEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UploadTaskEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      targetPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_path'],
      )!,
      sourceUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_uri'],
      ),
      overwrite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}overwrite'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      uploadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uploaded_bytes'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      uploadedChunks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uploaded_chunks'],
      )!,
      totalChunks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chunks'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      session: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session'],
      ),
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}speed'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UploadTasksTable createAlias(String alias) {
    return $UploadTasksTable(attachedDatabase, alias);
  }
}

class UploadTaskEntry extends DataClass implements Insertable<UploadTaskEntry> {
  final String id;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String targetPath;
  final String? sourceUri;
  final bool overwrite;
  final String createdAt;
  final String? completedAt;
  final int status;
  final int uploadedBytes;
  final double progress;
  final int uploadedChunks;
  final int totalChunks;
  final String? errorMessage;
  final String? session;
  final int speed;
  final String updatedAt;
  const UploadTaskEntry({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.targetPath,
    this.sourceUri,
    required this.overwrite,
    required this.createdAt,
    this.completedAt,
    required this.status,
    required this.uploadedBytes,
    required this.progress,
    required this.uploadedChunks,
    required this.totalChunks,
    this.errorMessage,
    this.session,
    required this.speed,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['file_path'] = Variable<String>(filePath);
    map['file_name'] = Variable<String>(fileName);
    map['file_size'] = Variable<int>(fileSize);
    map['target_path'] = Variable<String>(targetPath);
    if (!nullToAbsent || sourceUri != null) {
      map['source_uri'] = Variable<String>(sourceUri);
    }
    map['overwrite'] = Variable<bool>(overwrite);
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    map['status'] = Variable<int>(status);
    map['uploaded_bytes'] = Variable<int>(uploadedBytes);
    map['progress'] = Variable<double>(progress);
    map['uploaded_chunks'] = Variable<int>(uploadedChunks);
    map['total_chunks'] = Variable<int>(totalChunks);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || session != null) {
      map['session'] = Variable<String>(session);
    }
    map['speed'] = Variable<int>(speed);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  UploadTasksCompanion toCompanion(bool nullToAbsent) {
    return UploadTasksCompanion(
      id: Value(id),
      filePath: Value(filePath),
      fileName: Value(fileName),
      fileSize: Value(fileSize),
      targetPath: Value(targetPath),
      sourceUri: sourceUri == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUri),
      overwrite: Value(overwrite),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      status: Value(status),
      uploadedBytes: Value(uploadedBytes),
      progress: Value(progress),
      uploadedChunks: Value(uploadedChunks),
      totalChunks: Value(totalChunks),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      session: session == null && nullToAbsent
          ? const Value.absent()
          : Value(session),
      speed: Value(speed),
      updatedAt: Value(updatedAt),
    );
  }

  factory UploadTaskEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UploadTaskEntry(
      id: serializer.fromJson<String>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      targetPath: serializer.fromJson<String>(json['targetPath']),
      sourceUri: serializer.fromJson<String?>(json['sourceUri']),
      overwrite: serializer.fromJson<bool>(json['overwrite']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      status: serializer.fromJson<int>(json['status']),
      uploadedBytes: serializer.fromJson<int>(json['uploadedBytes']),
      progress: serializer.fromJson<double>(json['progress']),
      uploadedChunks: serializer.fromJson<int>(json['uploadedChunks']),
      totalChunks: serializer.fromJson<int>(json['totalChunks']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      session: serializer.fromJson<String?>(json['session']),
      speed: serializer.fromJson<int>(json['speed']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'filePath': serializer.toJson<String>(filePath),
      'fileName': serializer.toJson<String>(fileName),
      'fileSize': serializer.toJson<int>(fileSize),
      'targetPath': serializer.toJson<String>(targetPath),
      'sourceUri': serializer.toJson<String?>(sourceUri),
      'overwrite': serializer.toJson<bool>(overwrite),
      'createdAt': serializer.toJson<String>(createdAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'status': serializer.toJson<int>(status),
      'uploadedBytes': serializer.toJson<int>(uploadedBytes),
      'progress': serializer.toJson<double>(progress),
      'uploadedChunks': serializer.toJson<int>(uploadedChunks),
      'totalChunks': serializer.toJson<int>(totalChunks),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'session': serializer.toJson<String?>(session),
      'speed': serializer.toJson<int>(speed),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  UploadTaskEntry copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? targetPath,
    Value<String?> sourceUri = const Value.absent(),
    bool? overwrite,
    String? createdAt,
    Value<String?> completedAt = const Value.absent(),
    int? status,
    int? uploadedBytes,
    double? progress,
    int? uploadedChunks,
    int? totalChunks,
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> session = const Value.absent(),
    int? speed,
    String? updatedAt,
  }) => UploadTaskEntry(
    id: id ?? this.id,
    filePath: filePath ?? this.filePath,
    fileName: fileName ?? this.fileName,
    fileSize: fileSize ?? this.fileSize,
    targetPath: targetPath ?? this.targetPath,
    sourceUri: sourceUri.present ? sourceUri.value : this.sourceUri,
    overwrite: overwrite ?? this.overwrite,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    status: status ?? this.status,
    uploadedBytes: uploadedBytes ?? this.uploadedBytes,
    progress: progress ?? this.progress,
    uploadedChunks: uploadedChunks ?? this.uploadedChunks,
    totalChunks: totalChunks ?? this.totalChunks,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    session: session.present ? session.value : this.session,
    speed: speed ?? this.speed,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UploadTaskEntry copyWithCompanion(UploadTasksCompanion data) {
    return UploadTaskEntry(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      targetPath: data.targetPath.present
          ? data.targetPath.value
          : this.targetPath,
      sourceUri: data.sourceUri.present ? data.sourceUri.value : this.sourceUri,
      overwrite: data.overwrite.present ? data.overwrite.value : this.overwrite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      status: data.status.present ? data.status.value : this.status,
      uploadedBytes: data.uploadedBytes.present
          ? data.uploadedBytes.value
          : this.uploadedBytes,
      progress: data.progress.present ? data.progress.value : this.progress,
      uploadedChunks: data.uploadedChunks.present
          ? data.uploadedChunks.value
          : this.uploadedChunks,
      totalChunks: data.totalChunks.present
          ? data.totalChunks.value
          : this.totalChunks,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      session: data.session.present ? data.session.value : this.session,
      speed: data.speed.present ? data.speed.value : this.speed,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UploadTaskEntry(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('targetPath: $targetPath, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('overwrite: $overwrite, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('status: $status, ')
          ..write('uploadedBytes: $uploadedBytes, ')
          ..write('progress: $progress, ')
          ..write('uploadedChunks: $uploadedChunks, ')
          ..write('totalChunks: $totalChunks, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('session: $session, ')
          ..write('speed: $speed, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filePath,
    fileName,
    fileSize,
    targetPath,
    sourceUri,
    overwrite,
    createdAt,
    completedAt,
    status,
    uploadedBytes,
    progress,
    uploadedChunks,
    totalChunks,
    errorMessage,
    session,
    speed,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UploadTaskEntry &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.fileName == this.fileName &&
          other.fileSize == this.fileSize &&
          other.targetPath == this.targetPath &&
          other.sourceUri == this.sourceUri &&
          other.overwrite == this.overwrite &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.status == this.status &&
          other.uploadedBytes == this.uploadedBytes &&
          other.progress == this.progress &&
          other.uploadedChunks == this.uploadedChunks &&
          other.totalChunks == this.totalChunks &&
          other.errorMessage == this.errorMessage &&
          other.session == this.session &&
          other.speed == this.speed &&
          other.updatedAt == this.updatedAt);
}

class UploadTasksCompanion extends UpdateCompanion<UploadTaskEntry> {
  final Value<String> id;
  final Value<String> filePath;
  final Value<String> fileName;
  final Value<int> fileSize;
  final Value<String> targetPath;
  final Value<String?> sourceUri;
  final Value<bool> overwrite;
  final Value<String> createdAt;
  final Value<String?> completedAt;
  final Value<int> status;
  final Value<int> uploadedBytes;
  final Value<double> progress;
  final Value<int> uploadedChunks;
  final Value<int> totalChunks;
  final Value<String?> errorMessage;
  final Value<String?> session;
  final Value<int> speed;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const UploadTasksCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.sourceUri = const Value.absent(),
    this.overwrite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.uploadedBytes = const Value.absent(),
    this.progress = const Value.absent(),
    this.uploadedChunks = const Value.absent(),
    this.totalChunks = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.session = const Value.absent(),
    this.speed = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UploadTasksCompanion.insert({
    required String id,
    required String filePath,
    required String fileName,
    this.fileSize = const Value.absent(),
    required String targetPath,
    this.sourceUri = const Value.absent(),
    this.overwrite = const Value.absent(),
    required String createdAt,
    this.completedAt = const Value.absent(),
    required int status,
    this.uploadedBytes = const Value.absent(),
    this.progress = const Value.absent(),
    this.uploadedChunks = const Value.absent(),
    this.totalChunks = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.session = const Value.absent(),
    this.speed = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       filePath = Value(filePath),
       fileName = Value(fileName),
       targetPath = Value(targetPath),
       createdAt = Value(createdAt),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<UploadTaskEntry> custom({
    Expression<String>? id,
    Expression<String>? filePath,
    Expression<String>? fileName,
    Expression<int>? fileSize,
    Expression<String>? targetPath,
    Expression<String>? sourceUri,
    Expression<bool>? overwrite,
    Expression<String>? createdAt,
    Expression<String>? completedAt,
    Expression<int>? status,
    Expression<int>? uploadedBytes,
    Expression<double>? progress,
    Expression<int>? uploadedChunks,
    Expression<int>? totalChunks,
    Expression<String>? errorMessage,
    Expression<String>? session,
    Expression<int>? speed,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (targetPath != null) 'target_path': targetPath,
      if (sourceUri != null) 'source_uri': sourceUri,
      if (overwrite != null) 'overwrite': overwrite,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (status != null) 'status': status,
      if (uploadedBytes != null) 'uploaded_bytes': uploadedBytes,
      if (progress != null) 'progress': progress,
      if (uploadedChunks != null) 'uploaded_chunks': uploadedChunks,
      if (totalChunks != null) 'total_chunks': totalChunks,
      if (errorMessage != null) 'error_message': errorMessage,
      if (session != null) 'session': session,
      if (speed != null) 'speed': speed,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UploadTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? filePath,
    Value<String>? fileName,
    Value<int>? fileSize,
    Value<String>? targetPath,
    Value<String?>? sourceUri,
    Value<bool>? overwrite,
    Value<String>? createdAt,
    Value<String?>? completedAt,
    Value<int>? status,
    Value<int>? uploadedBytes,
    Value<double>? progress,
    Value<int>? uploadedChunks,
    Value<int>? totalChunks,
    Value<String?>? errorMessage,
    Value<String?>? session,
    Value<int>? speed,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return UploadTasksCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      targetPath: targetPath ?? this.targetPath,
      sourceUri: sourceUri ?? this.sourceUri,
      overwrite: overwrite ?? this.overwrite,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      progress: progress ?? this.progress,
      uploadedChunks: uploadedChunks ?? this.uploadedChunks,
      totalChunks: totalChunks ?? this.totalChunks,
      errorMessage: errorMessage ?? this.errorMessage,
      session: session ?? this.session,
      speed: speed ?? this.speed,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (sourceUri.present) {
      map['source_uri'] = Variable<String>(sourceUri.value);
    }
    if (overwrite.present) {
      map['overwrite'] = Variable<bool>(overwrite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (uploadedBytes.present) {
      map['uploaded_bytes'] = Variable<int>(uploadedBytes.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (uploadedChunks.present) {
      map['uploaded_chunks'] = Variable<int>(uploadedChunks.value);
    }
    if (totalChunks.present) {
      map['total_chunks'] = Variable<int>(totalChunks.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (session.present) {
      map['session'] = Variable<String>(session.value);
    }
    if (speed.present) {
      map['speed'] = Variable<int>(speed.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UploadTasksCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('targetPath: $targetPath, ')
          ..write('sourceUri: $sourceUri, ')
          ..write('overwrite: $overwrite, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('status: $status, ')
          ..write('uploadedBytes: $uploadedBytes, ')
          ..write('progress: $progress, ')
          ..write('uploadedChunks: $uploadedChunks, ')
          ..write('totalChunks: $totalChunks, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('session: $session, ')
          ..write('speed: $speed, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DownloadTaskEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileUriMeta = const VerificationMeta(
    'fileUri',
  );
  @override
  late final GeneratedColumn<String> fileUri = GeneratedColumn<String>(
    'file_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadUrlMeta = const VerificationMeta(
    'downloadUrl',
  );
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
    'download_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _savePathMeta = const VerificationMeta(
    'savePath',
  );
  @override
  late final GeneratedColumn<String> savePath = GeneratedColumn<String>(
    'save_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backgroundTaskIdMeta = const VerificationMeta(
    'backgroundTaskId',
  );
  @override
  late final GeneratedColumn<String> backgroundTaskId = GeneratedColumn<String>(
    'background_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<int> speed = GeneratedColumn<int>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileName,
    fileUri,
    downloadUrl,
    fileSize,
    savePath,
    backgroundTaskId,
    status,
    downloadedBytes,
    speed,
    createdAt,
    completedAt,
    errorMessage,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTaskEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_uri')) {
      context.handle(
        _fileUriMeta,
        fileUri.isAcceptableOrUnknown(data['file_uri']!, _fileUriMeta),
      );
    } else if (isInserting) {
      context.missing(_fileUriMeta);
    }
    if (data.containsKey('download_url')) {
      context.handle(
        _downloadUrlMeta,
        downloadUrl.isAcceptableOrUnknown(
          data['download_url']!,
          _downloadUrlMeta,
        ),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('save_path')) {
      context.handle(
        _savePathMeta,
        savePath.isAcceptableOrUnknown(data['save_path']!, _savePathMeta),
      );
    } else if (isInserting) {
      context.missing(_savePathMeta);
    }
    if (data.containsKey('background_task_id')) {
      context.handle(
        _backgroundTaskIdMeta,
        backgroundTaskId.isAcceptableOrUnknown(
          data['background_task_id']!,
          _backgroundTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadTaskEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTaskEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      fileUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_uri'],
      )!,
      downloadUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_url'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      savePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}save_path'],
      )!,
      backgroundTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_task_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}speed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completed_at'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }
}

class DownloadTaskEntry extends DataClass
    implements Insertable<DownloadTaskEntry> {
  final String id;
  final String fileName;
  final String fileUri;
  final String? downloadUrl;
  final int fileSize;
  final String savePath;
  final String? backgroundTaskId;
  final int status;
  final int downloadedBytes;
  final int speed;
  final String createdAt;
  final String? completedAt;
  final String? errorMessage;
  final String updatedAt;
  const DownloadTaskEntry({
    required this.id,
    required this.fileName,
    required this.fileUri,
    this.downloadUrl,
    required this.fileSize,
    required this.savePath,
    this.backgroundTaskId,
    required this.status,
    required this.downloadedBytes,
    required this.speed,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['file_name'] = Variable<String>(fileName);
    map['file_uri'] = Variable<String>(fileUri);
    if (!nullToAbsent || downloadUrl != null) {
      map['download_url'] = Variable<String>(downloadUrl);
    }
    map['file_size'] = Variable<int>(fileSize);
    map['save_path'] = Variable<String>(savePath);
    if (!nullToAbsent || backgroundTaskId != null) {
      map['background_task_id'] = Variable<String>(backgroundTaskId);
    }
    map['status'] = Variable<int>(status);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['speed'] = Variable<int>(speed);
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      id: Value(id),
      fileName: Value(fileName),
      fileUri: Value(fileUri),
      downloadUrl: downloadUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadUrl),
      fileSize: Value(fileSize),
      savePath: Value(savePath),
      backgroundTaskId: backgroundTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundTaskId),
      status: Value(status),
      downloadedBytes: Value(downloadedBytes),
      speed: Value(speed),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadTaskEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTaskEntry(
      id: serializer.fromJson<String>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      fileUri: serializer.fromJson<String>(json['fileUri']),
      downloadUrl: serializer.fromJson<String?>(json['downloadUrl']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      savePath: serializer.fromJson<String>(json['savePath']),
      backgroundTaskId: serializer.fromJson<String?>(json['backgroundTaskId']),
      status: serializer.fromJson<int>(json['status']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      speed: serializer.fromJson<int>(json['speed']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fileName': serializer.toJson<String>(fileName),
      'fileUri': serializer.toJson<String>(fileUri),
      'downloadUrl': serializer.toJson<String?>(downloadUrl),
      'fileSize': serializer.toJson<int>(fileSize),
      'savePath': serializer.toJson<String>(savePath),
      'backgroundTaskId': serializer.toJson<String?>(backgroundTaskId),
      'status': serializer.toJson<int>(status),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'speed': serializer.toJson<int>(speed),
      'createdAt': serializer.toJson<String>(createdAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  DownloadTaskEntry copyWith({
    String? id,
    String? fileName,
    String? fileUri,
    Value<String?> downloadUrl = const Value.absent(),
    int? fileSize,
    String? savePath,
    Value<String?> backgroundTaskId = const Value.absent(),
    int? status,
    int? downloadedBytes,
    int? speed,
    String? createdAt,
    Value<String?> completedAt = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    String? updatedAt,
  }) => DownloadTaskEntry(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    fileUri: fileUri ?? this.fileUri,
    downloadUrl: downloadUrl.present ? downloadUrl.value : this.downloadUrl,
    fileSize: fileSize ?? this.fileSize,
    savePath: savePath ?? this.savePath,
    backgroundTaskId: backgroundTaskId.present
        ? backgroundTaskId.value
        : this.backgroundTaskId,
    status: status ?? this.status,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    speed: speed ?? this.speed,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadTaskEntry copyWithCompanion(DownloadTasksCompanion data) {
    return DownloadTaskEntry(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileUri: data.fileUri.present ? data.fileUri.value : this.fileUri,
      downloadUrl: data.downloadUrl.present
          ? data.downloadUrl.value
          : this.downloadUrl,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      savePath: data.savePath.present ? data.savePath.value : this.savePath,
      backgroundTaskId: data.backgroundTaskId.present
          ? data.backgroundTaskId.value
          : this.backgroundTaskId,
      status: data.status.present ? data.status.value : this.status,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      speed: data.speed.present ? data.speed.value : this.speed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskEntry(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('fileUri: $fileUri, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('fileSize: $fileSize, ')
          ..write('savePath: $savePath, ')
          ..write('backgroundTaskId: $backgroundTaskId, ')
          ..write('status: $status, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('speed: $speed, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileName,
    fileUri,
    downloadUrl,
    fileSize,
    savePath,
    backgroundTaskId,
    status,
    downloadedBytes,
    speed,
    createdAt,
    completedAt,
    errorMessage,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTaskEntry &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.fileUri == this.fileUri &&
          other.downloadUrl == this.downloadUrl &&
          other.fileSize == this.fileSize &&
          other.savePath == this.savePath &&
          other.backgroundTaskId == this.backgroundTaskId &&
          other.status == this.status &&
          other.downloadedBytes == this.downloadedBytes &&
          other.speed == this.speed &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.errorMessage == this.errorMessage &&
          other.updatedAt == this.updatedAt);
}

class DownloadTasksCompanion extends UpdateCompanion<DownloadTaskEntry> {
  final Value<String> id;
  final Value<String> fileName;
  final Value<String> fileUri;
  final Value<String?> downloadUrl;
  final Value<int> fileSize;
  final Value<String> savePath;
  final Value<String?> backgroundTaskId;
  final Value<int> status;
  final Value<int> downloadedBytes;
  final Value<int> speed;
  final Value<String> createdAt;
  final Value<String?> completedAt;
  final Value<String?> errorMessage;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const DownloadTasksCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileUri = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.savePath = const Value.absent(),
    this.backgroundTaskId = const Value.absent(),
    this.status = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.speed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    required String id,
    required String fileName,
    required String fileUri,
    this.downloadUrl = const Value.absent(),
    this.fileSize = const Value.absent(),
    required String savePath,
    this.backgroundTaskId = const Value.absent(),
    required int status,
    this.downloadedBytes = const Value.absent(),
    this.speed = const Value.absent(),
    required String createdAt,
    this.completedAt = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fileName = Value(fileName),
       fileUri = Value(fileUri),
       savePath = Value(savePath),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadTaskEntry> custom({
    Expression<String>? id,
    Expression<String>? fileName,
    Expression<String>? fileUri,
    Expression<String>? downloadUrl,
    Expression<int>? fileSize,
    Expression<String>? savePath,
    Expression<String>? backgroundTaskId,
    Expression<int>? status,
    Expression<int>? downloadedBytes,
    Expression<int>? speed,
    Expression<String>? createdAt,
    Expression<String>? completedAt,
    Expression<String>? errorMessage,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (fileUri != null) 'file_uri': fileUri,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (fileSize != null) 'file_size': fileSize,
      if (savePath != null) 'save_path': savePath,
      if (backgroundTaskId != null) 'background_task_id': backgroundTaskId,
      if (status != null) 'status': status,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (speed != null) 'speed': speed,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (errorMessage != null) 'error_message': errorMessage,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? fileName,
    Value<String>? fileUri,
    Value<String?>? downloadUrl,
    Value<int>? fileSize,
    Value<String>? savePath,
    Value<String?>? backgroundTaskId,
    Value<int>? status,
    Value<int>? downloadedBytes,
    Value<int>? speed,
    Value<String>? createdAt,
    Value<String?>? completedAt,
    Value<String?>? errorMessage,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return DownloadTasksCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileUri: fileUri ?? this.fileUri,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      savePath: savePath ?? this.savePath,
      backgroundTaskId: backgroundTaskId ?? this.backgroundTaskId,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speed: speed ?? this.speed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileUri.present) {
      map['file_uri'] = Variable<String>(fileUri.value);
    }
    if (downloadUrl.present) {
      map['download_url'] = Variable<String>(downloadUrl.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (savePath.present) {
      map['save_path'] = Variable<String>(savePath.value);
    }
    if (backgroundTaskId.present) {
      map['background_task_id'] = Variable<String>(backgroundTaskId.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (speed.present) {
      map['speed'] = Variable<int>(speed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('fileUri: $fileUri, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('fileSize: $fileSize, ')
          ..write('savePath: $savePath, ')
          ..write('backgroundTaskId: $backgroundTaskId, ')
          ..write('status: $status, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('speed: $speed, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TaskDatabase extends GeneratedDatabase {
  _$TaskDatabase(QueryExecutor e) : super(e);
  $TaskDatabaseManager get managers => $TaskDatabaseManager(this);
  late final $UploadTasksTable uploadTasks = $UploadTasksTable(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    uploadTasks,
    downloadTasks,
  ];
}

typedef $$UploadTasksTableCreateCompanionBuilder =
    UploadTasksCompanion Function({
      required String id,
      required String filePath,
      required String fileName,
      Value<int> fileSize,
      required String targetPath,
      Value<String?> sourceUri,
      Value<bool> overwrite,
      required String createdAt,
      Value<String?> completedAt,
      required int status,
      Value<int> uploadedBytes,
      Value<double> progress,
      Value<int> uploadedChunks,
      Value<int> totalChunks,
      Value<String?> errorMessage,
      Value<String?> session,
      Value<int> speed,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$UploadTasksTableUpdateCompanionBuilder =
    UploadTasksCompanion Function({
      Value<String> id,
      Value<String> filePath,
      Value<String> fileName,
      Value<int> fileSize,
      Value<String> targetPath,
      Value<String?> sourceUri,
      Value<bool> overwrite,
      Value<String> createdAt,
      Value<String?> completedAt,
      Value<int> status,
      Value<int> uploadedBytes,
      Value<double> progress,
      Value<int> uploadedChunks,
      Value<int> totalChunks,
      Value<String?> errorMessage,
      Value<String?> session,
      Value<int> speed,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$UploadTasksTableFilterComposer
    extends Composer<_$TaskDatabase, $UploadTasksTable> {
  $$UploadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get overwrite => $composableBuilder(
    column: $table.overwrite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadedBytes => $composableBuilder(
    column: $table.uploadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadedChunks => $composableBuilder(
    column: $table.uploadedChunks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get session => $composableBuilder(
    column: $table.session,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UploadTasksTableOrderingComposer
    extends Composer<_$TaskDatabase, $UploadTasksTable> {
  $$UploadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUri => $composableBuilder(
    column: $table.sourceUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get overwrite => $composableBuilder(
    column: $table.overwrite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadedBytes => $composableBuilder(
    column: $table.uploadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadedChunks => $composableBuilder(
    column: $table.uploadedChunks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get session => $composableBuilder(
    column: $table.session,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UploadTasksTableAnnotationComposer
    extends Composer<_$TaskDatabase, $UploadTasksTable> {
  $$UploadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUri =>
      $composableBuilder(column: $table.sourceUri, builder: (column) => column);

  GeneratedColumn<bool> get overwrite =>
      $composableBuilder(column: $table.overwrite, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get uploadedBytes => $composableBuilder(
    column: $table.uploadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get uploadedChunks => $composableBuilder(
    column: $table.uploadedChunks,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalChunks => $composableBuilder(
    column: $table.totalChunks,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get session =>
      $composableBuilder(column: $table.session, builder: (column) => column);

  GeneratedColumn<int> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UploadTasksTableTableManager
    extends
        RootTableManager<
          _$TaskDatabase,
          $UploadTasksTable,
          UploadTaskEntry,
          $$UploadTasksTableFilterComposer,
          $$UploadTasksTableOrderingComposer,
          $$UploadTasksTableAnnotationComposer,
          $$UploadTasksTableCreateCompanionBuilder,
          $$UploadTasksTableUpdateCompanionBuilder,
          (
            UploadTaskEntry,
            BaseReferences<_$TaskDatabase, $UploadTasksTable, UploadTaskEntry>,
          ),
          UploadTaskEntry,
          PrefetchHooks Function()
        > {
  $$UploadTasksTableTableManager(_$TaskDatabase db, $UploadTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UploadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UploadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UploadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String> targetPath = const Value.absent(),
                Value<String?> sourceUri = const Value.absent(),
                Value<bool> overwrite = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> uploadedBytes = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> uploadedChunks = const Value.absent(),
                Value<int> totalChunks = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> session = const Value.absent(),
                Value<int> speed = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UploadTasksCompanion(
                id: id,
                filePath: filePath,
                fileName: fileName,
                fileSize: fileSize,
                targetPath: targetPath,
                sourceUri: sourceUri,
                overwrite: overwrite,
                createdAt: createdAt,
                completedAt: completedAt,
                status: status,
                uploadedBytes: uploadedBytes,
                progress: progress,
                uploadedChunks: uploadedChunks,
                totalChunks: totalChunks,
                errorMessage: errorMessage,
                session: session,
                speed: speed,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String filePath,
                required String fileName,
                Value<int> fileSize = const Value.absent(),
                required String targetPath,
                Value<String?> sourceUri = const Value.absent(),
                Value<bool> overwrite = const Value.absent(),
                required String createdAt,
                Value<String?> completedAt = const Value.absent(),
                required int status,
                Value<int> uploadedBytes = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> uploadedChunks = const Value.absent(),
                Value<int> totalChunks = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> session = const Value.absent(),
                Value<int> speed = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UploadTasksCompanion.insert(
                id: id,
                filePath: filePath,
                fileName: fileName,
                fileSize: fileSize,
                targetPath: targetPath,
                sourceUri: sourceUri,
                overwrite: overwrite,
                createdAt: createdAt,
                completedAt: completedAt,
                status: status,
                uploadedBytes: uploadedBytes,
                progress: progress,
                uploadedChunks: uploadedChunks,
                totalChunks: totalChunks,
                errorMessage: errorMessage,
                session: session,
                speed: speed,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UploadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$TaskDatabase,
      $UploadTasksTable,
      UploadTaskEntry,
      $$UploadTasksTableFilterComposer,
      $$UploadTasksTableOrderingComposer,
      $$UploadTasksTableAnnotationComposer,
      $$UploadTasksTableCreateCompanionBuilder,
      $$UploadTasksTableUpdateCompanionBuilder,
      (
        UploadTaskEntry,
        BaseReferences<_$TaskDatabase, $UploadTasksTable, UploadTaskEntry>,
      ),
      UploadTaskEntry,
      PrefetchHooks Function()
    >;
typedef $$DownloadTasksTableCreateCompanionBuilder =
    DownloadTasksCompanion Function({
      required String id,
      required String fileName,
      required String fileUri,
      Value<String?> downloadUrl,
      Value<int> fileSize,
      required String savePath,
      Value<String?> backgroundTaskId,
      required int status,
      Value<int> downloadedBytes,
      Value<int> speed,
      required String createdAt,
      Value<String?> completedAt,
      Value<String?> errorMessage,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$DownloadTasksTableUpdateCompanionBuilder =
    DownloadTasksCompanion Function({
      Value<String> id,
      Value<String> fileName,
      Value<String> fileUri,
      Value<String?> downloadUrl,
      Value<int> fileSize,
      Value<String> savePath,
      Value<String?> backgroundTaskId,
      Value<int> status,
      Value<int> downloadedBytes,
      Value<int> speed,
      Value<String> createdAt,
      Value<String?> completedAt,
      Value<String?> errorMessage,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$DownloadTasksTableFilterComposer
    extends Composer<_$TaskDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileUri => $composableBuilder(
    column: $table.fileUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get savePath => $composableBuilder(
    column: $table.savePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundTaskId => $composableBuilder(
    column: $table.backgroundTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadTasksTableOrderingComposer
    extends Composer<_$TaskDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileUri => $composableBuilder(
    column: $table.fileUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get savePath => $composableBuilder(
    column: $table.savePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundTaskId => $composableBuilder(
    column: $table.backgroundTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadTasksTableAnnotationComposer
    extends Composer<_$TaskDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get fileUri =>
      $composableBuilder(column: $table.fileUri, builder: (column) => column);

  GeneratedColumn<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get savePath =>
      $composableBuilder(column: $table.savePath, builder: (column) => column);

  GeneratedColumn<String> get backgroundTaskId => $composableBuilder(
    column: $table.backgroundTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DownloadTasksTableTableManager
    extends
        RootTableManager<
          _$TaskDatabase,
          $DownloadTasksTable,
          DownloadTaskEntry,
          $$DownloadTasksTableFilterComposer,
          $$DownloadTasksTableOrderingComposer,
          $$DownloadTasksTableAnnotationComposer,
          $$DownloadTasksTableCreateCompanionBuilder,
          $$DownloadTasksTableUpdateCompanionBuilder,
          (
            DownloadTaskEntry,
            BaseReferences<
              _$TaskDatabase,
              $DownloadTasksTable,
              DownloadTaskEntry
            >,
          ),
          DownloadTaskEntry,
          PrefetchHooks Function()
        > {
  $$DownloadTasksTableTableManager(_$TaskDatabase db, $DownloadTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> fileUri = const Value.absent(),
                Value<String?> downloadUrl = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String> savePath = const Value.absent(),
                Value<String?> backgroundTaskId = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int> speed = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> completedAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion(
                id: id,
                fileName: fileName,
                fileUri: fileUri,
                downloadUrl: downloadUrl,
                fileSize: fileSize,
                savePath: savePath,
                backgroundTaskId: backgroundTaskId,
                status: status,
                downloadedBytes: downloadedBytes,
                speed: speed,
                createdAt: createdAt,
                completedAt: completedAt,
                errorMessage: errorMessage,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fileName,
                required String fileUri,
                Value<String?> downloadUrl = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                required String savePath,
                Value<String?> backgroundTaskId = const Value.absent(),
                required int status,
                Value<int> downloadedBytes = const Value.absent(),
                Value<int> speed = const Value.absent(),
                required String createdAt,
                Value<String?> completedAt = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion.insert(
                id: id,
                fileName: fileName,
                fileUri: fileUri,
                downloadUrl: downloadUrl,
                fileSize: fileSize,
                savePath: savePath,
                backgroundTaskId: backgroundTaskId,
                status: status,
                downloadedBytes: downloadedBytes,
                speed: speed,
                createdAt: createdAt,
                completedAt: completedAt,
                errorMessage: errorMessage,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$TaskDatabase,
      $DownloadTasksTable,
      DownloadTaskEntry,
      $$DownloadTasksTableFilterComposer,
      $$DownloadTasksTableOrderingComposer,
      $$DownloadTasksTableAnnotationComposer,
      $$DownloadTasksTableCreateCompanionBuilder,
      $$DownloadTasksTableUpdateCompanionBuilder,
      (
        DownloadTaskEntry,
        BaseReferences<_$TaskDatabase, $DownloadTasksTable, DownloadTaskEntry>,
      ),
      DownloadTaskEntry,
      PrefetchHooks Function()
    >;

class $TaskDatabaseManager {
  final _$TaskDatabase _db;
  $TaskDatabaseManager(this._db);
  $$UploadTasksTableTableManager get uploadTasks =>
      $$UploadTasksTableTableManager(_db, _db.uploadTasks);
  $$DownloadTasksTableTableManager get downloadTasks =>
      $$DownloadTasksTableTableManager(_db, _db.downloadTasks);
}
