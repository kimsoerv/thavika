import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/sync/domain/row_codec.dart';

void main() {
  test('snake and camel names', () {
    expect(RowCodec.snake('amountMinor'), 'amount_minor');
    expect(RowCodec.snake('id'), 'id');
    expect(RowCodec.camel('amount_minor'), 'amountMinor');
    expect(RowCodec.camel('server_updated_at'), 'serverUpdatedAt');
  });

  test('a local row becomes a server row', () {
    final day = DateTime(2026, 3, 9);
    final stamp = DateTime.utc(2026, 3, 9, 12, 30);
    final remote = RowCodec.toRemote({
      'id': 'a',
      'type': 'expense',
      'amountMinor': 450,
      'categoryId': 'cat_food',
      'occurredOn': day.millisecondsSinceEpoch,
      'updatedAt': stamp.millisecondsSinceEpoch,
      'deletedAt': null,
      'syncState': 'pending',
      'ownerId': null,
      'receiptPath': '/data/user/0/app/receipt.jpg',
    }, 'user-1');

    expect(remote['amount_minor'], 450);
    expect(remote['category_id'], 'cat_food');
    expect(remote['occurred_on'], '2026-03-09');
    expect(remote['updated_at'], '2026-03-09T12:30:00.000Z');
    expect(remote['deleted_at'], isNull);
    expect(remote['owner_id'], 'user-1');
    expect(remote.containsKey('sync_state'), isFalse);
    // A path on this phone is never sent.
    expect(remote['receipt_path'], isNull);
  });

  test('a server row becomes a synced local row', () {
    final local = RowCodec.fromRemote({
      'id': 'a',
      'amount_minor': 450,
      'occurred_on': '2026-03-09',
      'updated_at': '2026-03-09T12:30:00.123456+00:00',
      'deleted_at': '2026-03-10T00:00:00+00:00',
      'owner_id': 'user-1',
      'server_updated_at': '2026-03-09T12:30:01+00:00',
    });
    expect(local['amountMinor'], 450);
    expect(local['occurredOn'], DateTime(2026, 3, 9).millisecondsSinceEpoch);
    expect(
      local['updatedAt'],
      DateTime.utc(2026, 3, 9, 12, 30, 0, 123, 456).millisecondsSinceEpoch,
    );
    expect(
      local['deletedAt'],
      DateTime.utc(2026, 3, 10).millisecondsSinceEpoch,
    );
    expect(local['ownerId'], 'user-1');
    expect(local['syncState'], 'synced');
    expect(local.containsKey('serverUpdatedAt'), isFalse);
  });

  test('a day survives the round trip', () {
    final day = DateTime(2026, 12, 31);
    final remote = RowCodec.toRemote({
      'occurredOn': day.millisecondsSinceEpoch,
    }, 'u');
    final back = RowCodec.fromRemote(remote);
    expect(back['occurredOn'], day.millisecondsSinceEpoch);
  });
}
