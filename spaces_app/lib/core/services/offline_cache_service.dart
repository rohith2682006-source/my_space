import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/file_model.dart';
import '../../data/models/space_model.dart';

class OfflineCacheService {
  static OfflineCacheService? _instance;
  static Database? _db;

  OfflineCacheService._();
  static OfflineCacheService get instance {
    _instance ??= OfflineCacheService._();
    return _instance!;
  }

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'spaces_offline.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _createSchema,
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createSchema(db, newVersion);
      },
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_spaces (
        id TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        cached_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_files (
        id TEXT PRIMARY KEY,
        space_id TEXT NOT NULL,
        json TEXT NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        cached_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_actions (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
  }

  // ── Spaces ─────────────────────────────────────────────────────────────────

  Future<void> cacheSpaces(List<SpaceModel> spaces) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final space in spaces) {
      batch.insert(
        'cached_spaces',
        {
          'id': space.id,
          'json': jsonEncode(space.toJson()),
          'pinned': 0,
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<SpaceModel>> getCachedSpaces() async {
    final db = await database;
    final maps = await db.query('cached_spaces', orderBy: 'cached_at DESC');
    return maps.map((m) => SpaceModel.fromJson(jsonDecode(m['json'] as String))).toList();
  }

  Future<void> toggleSpacePin(String spaceId, bool pinned) async {
    final db = await database;
    await db.update(
      'cached_spaces',
      {'pinned': pinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [spaceId],
    );
  }

  Future<bool> isSpacePinned(String spaceId) async {
    final db = await database;
    final result = await db.query(
      'cached_spaces',
      where: 'id = ? AND pinned = 1',
      whereArgs: [spaceId],
    );
    return result.isNotEmpty;
  }

  // ── Files ──────────────────────────────────────────────────────────────────

  Future<void> cacheFiles(String spaceId, List<FileModel> files) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final file in files) {
      batch.insert(
        'cached_files',
        {
          'id': file.id,
          'space_id': spaceId,
          'json': jsonEncode(_fileToJson(file)),
          'pinned': 0,
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<FileModel>> getCachedFiles(String spaceId) async {
    final db = await database;
    final maps = await db.query(
      'cached_files',
      where: 'space_id = ?',
      whereArgs: [spaceId],
      orderBy: 'cached_at DESC',
    );
    return maps.map((m) => FileModel.fromJson(jsonDecode(m['json'] as String))).toList();
  }

  Future<void> toggleFilePin(String fileId, bool pinned) async {
    final db = await database;
    await db.update(
      'cached_files',
      {'pinned': pinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [fileId],
    );
  }

  Future<bool> isFilePinned(String fileId) async {
    final db = await database;
    final result = await db.query(
      'cached_files',
      where: 'id = ? AND pinned = 1',
      whereArgs: [fileId],
    );
    return result.isNotEmpty;
  }

  Future<List<FileModel>> getAllPinnedFiles() async {
    final db = await database;
    final maps = await db.query(
      'cached_files',
      where: 'pinned = 1',
      orderBy: 'cached_at DESC',
    );
    return maps.map((m) => FileModel.fromJson(jsonDecode(m['json'] as String))).toList();
  }

  // ── Offline Queue ──────────────────────────────────────────────────────────

  Future<void> queueAction({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await db.insert('offline_actions', {
      'id': id,
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': int.parse(id),
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await database;
    final maps = await db.query(
      'offline_actions',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => {
      'id': m['id'],
      'action': m['action'],
      'payload': jsonDecode(m['payload'] as String),
    }).toList();
  }

  Future<void> markActionDone(String id) async {
    final db = await database;
    await db.update(
      'offline_actions',
      {'status': 'done'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> pendingActionsCount() async {
    final db = await database;
    final result =
        await db.rawQuery("SELECT COUNT(*) as c FROM offline_actions WHERE status='pending'");
    return result.first['c'] as int;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _fileToJson(FileModel f) => {
        'id': f.id,
        'name': f.name,
        'originalName': f.originalName,
        'mimeType': f.mimeType,
        'extension': f.extension,
        'size': f.size,
        'storageKey': f.storageKey,
        'thumbnailKey': f.thumbnailKey,
        'spaceId': f.spaceId,
        'uploadedBy': f.uploadedBy,
        'category': f.category,
        'isStarred': f.isStarred,
        'content': f.content,
        'openedAt': f.openedAt?.toIso8601String(),
        'createdAt': f.createdAt.toIso8601String(),
        'updatedAt': f.updatedAt.toIso8601String(),
        'indexStatus': f.indexStatus,
        'indexError': f.indexError,
        'aiSearchEnabled': f.aiSearchEnabled,
      };

  Future<void> clearOldCache() async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    // Only delete non-pinned entries older than 7 days
    await db.delete('cached_files',
        where: 'pinned = 0 AND cached_at < ?', whereArgs: [cutoff]);
    await db.delete('cached_spaces',
        where: 'pinned = 0 AND cached_at < ?', whereArgs: [cutoff]);
  }
}
