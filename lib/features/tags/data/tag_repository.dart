import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<TagRow>> watchAll() {
    final query = _db.select(_db.tags)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  /// Entry id -> ids of its tags.
  Stream<Map<String, List<String>>> watchLinks() {
    final query = _db.select(_db.transactionTags)
      ..where((l) => l.deletedAt.isNull());
    return query.watch().map((rows) {
      final map = <String, List<String>>{};
      for (final r in rows) {
        (map[r.transactionId] ??= []).add(r.tagId);
      }
      return map;
    });
  }

  Future<String> add(String name, {int colorIndex = 0}) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(
              id: id,
              name: name,
              colorIndex: Value(colorIndex),
              updatedAt: DateTime.now(),
            ),
          );
      await _db.enqueue('tags', id, 'upsert');
    });
    return id;
  }

  Future<void> rename(String id, String name) async {
    await _db.transaction(() async {
      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
        TagsCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('tags', id, 'upsert');
    });
  }

  /// Deletes the tag and removes it from every entry.
  Future<void> delete(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
        TagsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('tags', id, 'delete');

      final links = await (_db.select(
        _db.transactionTags,
      )..where((l) => l.tagId.equals(id) & l.deletedAt.isNull())).get();
      for (final l in links) {
        await _softDeleteLink(l.id, now);
      }
    });
  }

  /// Makes the tags of an entry exactly [tagIds].
  Future<void> setTags(String transactionId, Set<String> tagIds) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.transactionTags,
      )..where((l) => l.transactionId.equals(transactionId))).get();
      final byTag = {for (final l in existing) l.tagId: l};

      for (final l in existing) {
        if (l.deletedAt == null && !tagIds.contains(l.tagId)) {
          await _softDeleteLink(l.id, now);
        }
      }
      for (final tagId in tagIds) {
        final link = byTag[tagId];
        if (link == null) {
          final id = linkId(transactionId, tagId);
          await _db
              .into(_db.transactionTags)
              .insert(
                TransactionTagsCompanion.insert(
                  id: id,
                  transactionId: transactionId,
                  tagId: tagId,
                  updatedAt: now,
                ),
              );
          await _db.enqueue('transaction_tags', id, 'upsert');
        } else if (link.deletedAt != null) {
          await (_db.update(
            _db.transactionTags,
          )..where((l) => l.id.equals(link.id))).write(
            TransactionTagsCompanion(
              deletedAt: const Value(null),
              updatedAt: Value(now),
              syncState: const Value('pending'),
            ),
          );
          await _db.enqueue('transaction_tags', link.id, 'upsert');
        }
      }
    });
  }

  Future<void> _softDeleteLink(String id, DateTime now) async {
    await (_db.update(
      _db.transactionTags,
    )..where((l) => l.id.equals(id))).write(
      TransactionTagsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncState: const Value('pending'),
      ),
    );
    await _db.enqueue('transaction_tags', id, 'delete');
  }

  /// Same id on every phone for the same entry and tag.
  static String linkId(String transactionId, String tagId) =>
      const Uuid().v5(Namespace.url.value, 'tag|$transactionId|$tagId');
}
