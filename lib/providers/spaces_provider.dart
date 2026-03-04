import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_local_rag/services/db_service.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// DB provider – resolves the async singleton once, shared by all providers
// ---------------------------------------------------------------------------
final dbProvider = FutureProvider<Database>((ref) async {
  return DatabaseHelper.singleInstance.database;
});

// ---------------------------------------------------------------------------
// Spaces – AsyncNotifier for full CRUD support
// ---------------------------------------------------------------------------
class SpacesNotifier extends AsyncNotifier<List<SpaceData>> {
  @override
  Future<List<SpaceData>> build() async {
    final db = await ref.watch(dbProvider.future);
    final rows = await db.query(
      DatabaseHelper.tableSpaces,
      orderBy: 'created_at DESC',
    );
    return rows.map(SpaceData.fromMap).toList();
  }

  Future<void> addSpace(String name) async {
    final db = await ref.read(dbProvider.future);
    final space = SpaceData(id: const Uuid().v4(), name: name);
    await db.insert(DatabaseHelper.tableSpaces, space.toMap());
    ref.invalidateSelf();
  }

  Future<void> deleteSpace(String id) async {
    final db = await ref.read(dbProvider.future);
    await db.delete(
      DatabaseHelper.tableSpaces,
      where: 'id = ?',
      whereArgs: [id],
    );
    ref.invalidateSelf();
  }
}

final spacesProvider = AsyncNotifierProvider<SpacesNotifier, List<SpaceData>>(
  SpacesNotifier.new,
);
