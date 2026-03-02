import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static const _databaseName = "doc_spaces.db";
  static const _databaseVersion = 1;

  static const tableSpaces = 'spaces';
  static const tableDocuments = 'documents';
  static const tableChunks = 'chunks';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper singleInstance =
      DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = p.join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSpaces (
        id         TEXT PRIMARY KEY,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        name       TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableDocuments (
        id            TEXT PRIMARY KEY,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        document_name TEXT,
        path          TEXT,
        processed     TEXT NOT NULL,
        space_id      TEXT,
        FOREIGN KEY (space_id) REFERENCES $tableSpaces(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableChunks (
        id          TEXT PRIMARY KEY,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        space_id    TEXT NOT NULL,
        document_id TEXT NOT NULL,
        content     TEXT NOT NULL,
        embedding   TEXT NOT NULL,
        page_no     INTEGER NOT NULL CHECK (page_no > 0),
        FOREIGN KEY (space_id)    REFERENCES $tableSpaces(id),
        FOREIGN KEY (document_id) REFERENCES $tableDocuments(id)
      )
    ''');
  }
}

// ---------------------------------------------------------------------------
// Model classes
// ---------------------------------------------------------------------------

class SpaceData {
  String id;
  String? createdAt;
  String name;

  SpaceData({required this.id, this.createdAt, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory SpaceData.fromMap(Map<String, dynamic> m) => SpaceData(
    id: m['id'] as String,
    createdAt: m['created_at'] as String?,
    name: m['name'] as String,
  );
}

class DocumentData {
  String id;
  String? createdAt;
  String? documentName;
  String? path;
  String processed;
  String? spaceId;

  DocumentData({
    required this.id,
    this.createdAt,
    this.documentName,
    this.path,
    required this.processed,
    this.spaceId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'document_name': documentName,
    'path': path,
    'processed': processed,
    'space_id': spaceId,
  };

  factory DocumentData.fromMap(Map<String, dynamic> m) => DocumentData(
    id: m['id'] as String,
    createdAt: m['created_at'] as String?,
    documentName: m['document_name'] as String?,
    path: m['path'] as String?,
    processed: m['processed'] as String,
    spaceId: m['space_id'] as String?,
  );
}

class ChunkData {
  String id;
  String? createdAt;
  String spaceId;
  String documentId;
  String content;

  /// JSON-encoded list of floats, e.g. "[0.1, 0.2, ...]"
  String embedding;
  int pageNo;

  ChunkData({
    required this.id,
    this.createdAt,
    required this.spaceId,
    required this.documentId,
    required this.content,
    required this.embedding,
    required this.pageNo,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'space_id': spaceId,
    'document_id': documentId,
    'content': content,
    'embedding': embedding,
    'page_no': pageNo,
  };

  factory ChunkData.fromMap(Map<String, dynamic> m) => ChunkData(
    id: m['id'] as String,
    createdAt: m['created_at'] as String?,
    spaceId: m['space_id'] as String,
    documentId: m['document_id'] as String,
    content: m['content'] as String,
    embedding: m['embedding'] as String,
    pageNo: m['page_no'] as int,
  );
}
