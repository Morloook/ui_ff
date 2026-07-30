import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_logger.dart';
import '../models/binary_installation.dart';
import '../models/capability.dart';

class CapabilityRepository {
  CapabilityRepository({
    Future<Directory> Function()? supportDirectoryProvider,
    this.databaseFactory,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectoryProvider;
  final DatabaseFactory? databaseFactory;
  Database? _database;
  bool _ftsAvailable = false;

  Future<void> initialize({
    required Duration openTimeout,
    required bool useWorkerIsolate,
  }) async {
    if (_database != null) return;
    sqfliteFfiInit();
    final support = await _supportDirectoryProvider();
    final databasePath = p.join(support.path, 'ffmpeg_ui_catalog.sqlite');
    final factory =
        databaseFactory ??
        (useWorkerIsolate ? databaseFactoryFfi : databaseFactoryFfiNoIsolate);
    AppLogger.info(
      'SQLite',
      'Otwieranie bazy katalogu; '
          'workerIsolate=$useWorkerIsolate, '
          'timeout=${openTimeout.inSeconds}s.',
    );
    final opening = factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA journal_mode = WAL');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE snapshots (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              fingerprint TEXT NOT NULL UNIQUE,
              binary_path TEXT NOT NULL,
              version TEXT NOT NULL,
              configuration TEXT NOT NULL,
              probe_path TEXT NOT NULL,
              probe_version TEXT NOT NULL,
              probe_configuration TEXT NOT NULL,
              created_at TEXT NOT NULL,
              complete INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE components (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              snapshot_id INTEGER NOT NULL,
              kind TEXT NOT NULL,
              name TEXT NOT NULL,
              description TEXT NOT NULL,
              flags TEXT NOT NULL,
              media_type TEXT NOT NULL,
              help_target TEXT NOT NULL,
              raw_line TEXT NOT NULL,
              raw_help TEXT NOT NULL DEFAULT '',
              details_loaded INTEGER NOT NULL DEFAULT 0,
              UNIQUE(snapshot_id, kind, name, flags),
              FOREIGN KEY(snapshot_id) REFERENCES snapshots(id)
                ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE options (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              component_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              value_type TEXT NOT NULL,
              flags TEXT NOT NULL,
              description TEXT NOT NULL,
              raw_line TEXT NOT NULL,
              default_value TEXT,
              minimum TEXT,
              maximum TEXT,
              choices_json TEXT NOT NULL DEFAULT '[]',
              FOREIGN KEY(component_id) REFERENCES components(id)
                ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE raw_scans (
              snapshot_id INTEGER NOT NULL,
              section TEXT NOT NULL,
              content TEXT NOT NULL,
              error TEXT,
              PRIMARY KEY(snapshot_id, section),
              FOREIGN KEY(snapshot_id) REFERENCES snapshots(id)
                ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX components_search_idx '
            'ON components(snapshot_id, kind, media_type, name)',
          );
          await _installFtsIndex(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE snapshots ADD COLUMN complete '
              'INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              "ALTER TABLE snapshots ADD COLUMN probe_path "
              "TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE snapshots ADD COLUMN probe_version "
              "TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE snapshots ADD COLUMN probe_configuration "
              "TEXT NOT NULL DEFAULT ''",
            );
          }
          if (oldVersion < 4) {
            await db.execute(
              'CREATE INDEX IF NOT EXISTS components_filter_idx '
              'ON components(snapshot_id, kind, media_type, name)',
            );
            await _installFtsIndex(db);
          }
        },
      ),
    );
    try {
      _database = await opening.timeout(openTimeout);
      _ftsAvailable = await _hasFtsIndex(_database!);
    } on TimeoutException {
      unawaited(
        opening.then((database) => database.close(), onError: (Object _) {}),
      );
      final mode = useWorkerIsolate ? 'w izolacie roboczym' : 'bez izolatu';
      AppLogger.error('SQLite', 'Przekroczono czas otwierania bazy $mode.');
      throw TimeoutException(
        'Nie udało się otworzyć bazy SQLite w czasie '
        '${openTimeout.inSeconds} sekund. Tryb: $mode.',
        openTimeout,
      );
    }
    AppLogger.info('SQLite', 'Baza katalogu została otwarta.');
  }

  Future<void> _installFtsIndex(DatabaseExecutor db) async {
    try {
      final existing = await db.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' "
        "AND name = 'components_fts' LIMIT 1",
      );
      if (existing.isNotEmpty) return;
      await db.execute(
        "CREATE VIRTUAL TABLE components_fts USING fts5("
        "name, description, flags, tokenize = 'trigram')",
      );
      await db.execute('''
        CREATE TRIGGER components_fts_insert AFTER INSERT ON components BEGIN
          INSERT INTO components_fts(rowid, name, description, flags)
          VALUES (new.id, new.name, new.description, new.flags);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER components_fts_delete AFTER DELETE ON components BEGIN
          DELETE FROM components_fts WHERE rowid = old.id;
        END
      ''');
      await db.execute('''
        CREATE TRIGGER components_fts_update
        AFTER UPDATE OF name, description, flags ON components BEGIN
          DELETE FROM components_fts WHERE rowid = old.id;
          INSERT INTO components_fts(rowid, name, description, flags)
          VALUES (new.id, new.name, new.description, new.flags);
        END
      ''');
      await db.execute('''
        INSERT INTO components_fts(rowid, name, description, flags)
        SELECT id, name, description, flags FROM components
      ''');
    } on DatabaseException catch (error) {
      AppLogger.info(
        'SQLite',
        'FTS5 niedostępne; katalog użyje indeksu podstawowego: $error',
      );
    }
  }

  Future<bool> _hasFtsIndex(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name = 'components_fts' LIMIT 1",
    );
    return rows.isNotEmpty;
  }

  Future<void> close() async {
    final database = _database;
    if (database == null) return;
    AppLogger.info('SQLite', 'Zamykanie bazy katalogu.');
    await database.close();
    _database = null;
    _ftsAvailable = false;
    AppLogger.info('SQLite', 'Baza katalogu została zamknięta.');
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('Repozytorium katalogu nie zostało zainicjalizowane.');
    }
    return database;
  }

  Future<CapabilitySnapshot?> findSnapshot(String fingerprint) async {
    final rows = await _db.query(
      'snapshots',
      where: 'fingerprint = ? AND complete = 1',
      whereArgs: [fingerprint],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _snapshotFromRow(rows.first);
  }

  Future<CapabilitySnapshot> createSnapshot({
    required String fingerprint,
    required BinaryInstallation ffmpeg,
    required BinaryInstallation ffprobe,
  }) async {
    await _db.delete(
      'snapshots',
      where: 'binary_path = ? AND fingerprint <> ?',
      whereArgs: [ffmpeg.path, fingerprint],
    );
    final now = DateTime.now();
    final id = await _db.insert('snapshots', {
      'fingerprint': fingerprint,
      'binary_path': ffmpeg.path,
      'version': ffmpeg.version,
      'configuration': ffmpeg.configuration,
      'probe_path': ffprobe.path,
      'probe_version': ffprobe.version,
      'probe_configuration': ffprobe.configuration,
      'created_at': now.toIso8601String(),
      'complete': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return CapabilitySnapshot(
      id: id,
      fingerprint: fingerprint,
      binaryPath: ffmpeg.path,
      version: ffmpeg.version,
      configuration: ffmpeg.configuration,
      probePath: ffprobe.path,
      probeVersion: ffprobe.version,
      probeConfiguration: ffprobe.configuration,
      createdAt: now,
    );
  }

  Future<void> addComponents(
    int snapshotId,
    List<FfmpegComponent> components,
  ) async {
    if (components.isEmpty) return;
    await _db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final component in components) {
        batch.insert(
          'components',
          _componentMap(snapshotId, component),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
      final withOptions = components
          .where((item) => item.options.isNotEmpty)
          .toList();
      if (withOptions.isEmpty) return;
      final rows = await transaction.query(
        'components',
        columns: ['id', 'kind', 'name', 'flags'],
        where: 'snapshot_id = ?',
        whereArgs: [snapshotId],
      );
      final ids = <String, int>{
        for (final row in rows)
          _componentKey(
            row['kind'] as String,
            row['name'] as String,
            row['flags'] as String,
          ): row['id'] as int,
      };
      final optionBatch = transaction.batch();
      for (final component in withOptions) {
        final id =
            ids[_componentKey(
              component.kind.storageKey,
              component.name,
              component.flags,
            )];
        if (id == null) continue;
        for (final option in component.options) {
          optionBatch.insert('options', _optionMap(id, option));
        }
      }
      await optionBatch.commit(noResult: true);
    });
  }

  Future<void> markSnapshotComplete(int snapshotId) async {
    await _db.update(
      'snapshots',
      {'complete': 1},
      where: 'id = ?',
      whereArgs: [snapshotId],
    );
  }

  Future<void> storeRawScan({
    required int snapshotId,
    required String section,
    required String content,
    String? error,
  }) async {
    await _db.insert('raw_scans', {
      'snapshot_id': snapshotId,
      'section': section,
      'content': content,
      'error': error,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> rawScanError({
    required int snapshotId,
    required String section,
  }) async {
    final rows = await _db.query(
      'raw_scans',
      columns: ['error'],
      where: 'snapshot_id = ? AND section = ?',
      whereArgs: [snapshotId, section],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['error'] as String?;
  }

  Future<List<FfmpegComponent>> search({
    required int snapshotId,
    String query = '',
    ComponentKind? kind,
    MediaType? mediaType,
    required int limit,
  }) async {
    final where = <String>['components.snapshot_id = ?'];
    final args = <Object?>[snapshotId];
    final ftsQuery = _buildFtsQuery(query);
    if (query.trim().isNotEmpty && ftsQuery == null) {
      where.add(
        '(components.name LIKE ? OR components.description LIKE ? '
        'OR components.flags LIKE ?)',
      );
      final like = '%${query.trim()}%';
      args.addAll([like, like, like]);
    }
    if (kind != null) {
      where.add('components.kind = ?');
      args.add(kind.storageKey);
    }
    if (mediaType != null) {
      where.add('components.media_type = ?');
      args.add(mediaType.name);
    }
    final rows = ftsQuery == null
        ? await _db.query(
            'components',
            where: where.join(' AND ').replaceAll('components.', ''),
            whereArgs: args,
            orderBy: 'kind, name COLLATE NOCASE',
            limit: limit,
          )
        : await _searchFts(
            where: where,
            args: args,
            ftsQuery: ftsQuery,
            rawQuery: query,
            limit: limit,
          );
    return rows.map(_componentFromRow).toList();
  }

  Future<List<Map<String, Object?>>> _searchFts({
    required List<String> where,
    required List<Object?> args,
    required String ftsQuery,
    required String rawQuery,
    required int limit,
  }) async {
    if (!_ftsAvailable) {
      return _searchWithLikeFallback(
        where: where,
        args: args,
        rawQuery: rawQuery,
        limit: limit,
      );
    }
    try {
      return await _db.rawQuery(
        'SELECT components.* FROM components '
        'INNER JOIN components_fts ON components_fts.rowid = components.id '
        'WHERE components_fts MATCH ? AND ${where.join(' AND ')} '
        'ORDER BY components.kind, components.name COLLATE NOCASE LIMIT ?',
        [ftsQuery, ...args, limit],
      );
    } on DatabaseException catch (error) {
      AppLogger.info('SQLite', 'Błąd wyszukiwania FTS5; używam LIKE: $error');
      return _searchWithLikeFallback(
        where: where,
        args: args,
        rawQuery: rawQuery,
        limit: limit,
      );
    }
  }

  Future<List<Map<String, Object?>>> _searchWithLikeFallback({
    required List<String> where,
    required List<Object?> args,
    required String rawQuery,
    required int limit,
  }) {
    final fallbackWhere = List<String>.from(where);
    final fallbackArgs = List<Object?>.from(args);
    final queryIndex = fallbackWhere.indexWhere(
      (value) => value.contains('LIKE'),
    );
    if (queryIndex == -1) {
      fallbackWhere.add(
        '(components.name LIKE ? OR components.description LIKE ? '
        'OR components.flags LIKE ?)',
      );
      final like = '%${rawQuery.trim()}%';
      fallbackArgs.addAll([like, like, like]);
    }
    return _db.rawQuery(
      'SELECT components.* FROM components WHERE ${fallbackWhere.join(' AND ')} '
      'ORDER BY components.kind, components.name COLLATE NOCASE LIMIT ?',
      [...fallbackArgs, limit],
    );
  }

  String? _buildFtsQuery(String query) {
    final trimmed = query.trim();
    if (!_ftsAvailable || trimmed.isEmpty) return null;
    final terms = trimmed
        .split(RegExp(r'[^A-Za-z0-9_ąćęłńóśźż]+', caseSensitive: false))
        .where((term) => term.length >= 3)
        .toList();
    if (terms.isEmpty) return null;
    return terms.join(' AND ');
  }

  Future<List<FfmpegComponent>> commandOptions(int snapshotId) async {
    final rows = await _db.query(
      'components',
      where: 'snapshot_id = ? AND kind = ?',
      whereArgs: [snapshotId, ComponentKind.globalOption.storageKey],
      orderBy: 'name COLLATE NOCASE, flags, description',
    );
    return rows.map(_componentFromRow).toList();
  }

  Future<Map<ComponentKind, int>> counts(int snapshotId) async {
    final rows = await _db.rawQuery(
      'SELECT kind, COUNT(*) AS count FROM components '
      'WHERE snapshot_id = ? GROUP BY kind',
      [snapshotId],
    );
    return {
      for (final row in rows)
        ComponentKind.fromStorageKey(row['kind'] as String):
            (row['count'] as num).toInt(),
    };
  }

  Future<FfmpegComponent> loadComponent(int componentId) async {
    final rows = await _db.query(
      'components',
      where: 'id = ?',
      whereArgs: [componentId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Nie znaleziono elementu katalogu.');
    final component = _componentFromRow(rows.first);
    final options = await _db.query(
      'options',
      where: 'component_id = ?',
      whereArgs: [componentId],
      orderBy: 'id',
    );
    return component.copyWith(options: options.map(_optionFromRow).toList());
  }

  Future<void> saveDetails(int componentId, HelpParseResultData details) async {
    await _db.transaction((transaction) async {
      await transaction.update(
        'components',
        {'raw_help': details.rawHelp, 'details_loaded': 1},
        where: 'id = ?',
        whereArgs: [componentId],
      );
      await transaction.delete(
        'options',
        where: 'component_id = ?',
        whereArgs: [componentId],
      );
      final batch = transaction.batch();
      for (final option in details.options) {
        batch.insert('options', _optionMap(componentId, option));
      }
      await batch.commit(noResult: true);
    });
  }

  Map<String, Object?> _componentMap(
    int snapshotId,
    FfmpegComponent component,
  ) {
    return {
      'snapshot_id': snapshotId,
      'kind': component.kind.storageKey,
      'name': component.name,
      'description': component.description,
      'flags': component.flags,
      'media_type': component.mediaType.name,
      'help_target': component.helpTarget,
      'raw_line': component.rawLine,
      'raw_help': component.rawHelp,
      'details_loaded': component.detailsLoaded ? 1 : 0,
    };
  }

  Map<String, Object?> _optionMap(int componentId, OptionDefinition option) {
    return {
      'component_id': componentId,
      'name': option.name,
      'value_type': option.valueType,
      'flags': option.flags,
      'description': option.description,
      'raw_line': option.rawLine,
      'default_value': option.defaultValue,
      'minimum': option.minimum,
      'maximum': option.maximum,
      'choices_json': jsonEncode(
        option.choices.map((choice) => choice.toJson()).toList(),
      ),
    };
  }

  CapabilitySnapshot _snapshotFromRow(Map<String, Object?> row) {
    return CapabilitySnapshot(
      id: row['id'] as int,
      fingerprint: row['fingerprint'] as String,
      binaryPath: row['binary_path'] as String,
      version: row['version'] as String,
      configuration: row['configuration'] as String,
      probePath: row['probe_path'] as String,
      probeVersion: row['probe_version'] as String,
      probeConfiguration: row['probe_configuration'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  FfmpegComponent _componentFromRow(Map<String, Object?> row) {
    return FfmpegComponent(
      id: row['id'] as int,
      kind: ComponentKind.fromStorageKey(row['kind'] as String),
      name: row['name'] as String,
      description: row['description'] as String,
      flags: row['flags'] as String,
      mediaType: MediaType.values.firstWhere(
        (type) => type.name == row['media_type'],
        orElse: () => MediaType.unknown,
      ),
      helpTarget: row['help_target'] as String,
      rawLine: row['raw_line'] as String,
      rawHelp: row['raw_help'] as String,
      detailsLoaded: (row['details_loaded'] as int) == 1,
    );
  }

  OptionDefinition _optionFromRow(Map<String, Object?> row) {
    final decoded = jsonDecode(row['choices_json'] as String) as List<dynamic>;
    return OptionDefinition(
      name: row['name'] as String,
      valueType: row['value_type'] as String,
      flags: row['flags'] as String,
      description: row['description'] as String,
      rawLine: row['raw_line'] as String,
      defaultValue: row['default_value'] as String?,
      minimum: row['minimum'] as String?,
      maximum: row['maximum'] as String?,
      choices: decoded
          .whereType<Map>()
          .map(
            (entry) => OptionChoice.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
    );
  }

  String _componentKey(String kind, String name, String flags) {
    return '$kind\u0000$name\u0000$flags';
  }
}

class HelpParseResultData {
  const HelpParseResultData({required this.rawHelp, required this.options});
  final String rawHelp;
  final List<OptionDefinition> options;
}
