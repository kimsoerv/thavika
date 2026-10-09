import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/core/services/settings_service.dart';
import 'package:thavika/features/settings/application/backup_service.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late BackupService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db, SettingsService(db));
    final tx = TransactionRepository(db);
    await tx.add(
      type: 'expense',
      amountMinor: 450,
      currency: 'USD',
      categoryId: 'cat_food',
      note: 'coffee, large',
      date: DateTime(2026, 10, 9),
    );
    await tx.add(
      type: 'expense',
      amountMinor: 1050,
      currency: 'USD',
      categoryId: 'cat_food',
      note: '',
      date: DateTime(2026, 10, 10),
    );
    await tx.add(
      type: 'income',
      amountMinor: 200000,
      currency: 'USD',
      categoryId: 'cat_salary',
      note: 'Salary',
      date: DateTime(2026, 9, 30),
    );
  });

  tearDown(() => db.close());

  test('nothing to export gives null', () async {
    expect(
      await service.buildXlsx(from: DateTime(2020), to: DateTime(2021)),
      isNull,
    );
  });

  test('the workbook has the entries with real numbers', () async {
    final bytes = await service.buildXlsx();
    expect(bytes, isNotNull);
    final book = Excel.decodeBytes(bytes!);

    expect(book.tables.keys, containsAll(['Entries', 'By category']));
    final sheet = book['Entries'];
    expect(sheet.maxRows, 4); // header + 3 entries

    String text(int row, int col) => sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value
        .toString();

    expect(text(0, 0), 'Date');
    // Oldest first: the salary of 30 Sep.
    expect(text(1, 1), 'income');
    expect(text(1, 2), 'Salary');
    expect(text(2, 2), 'Food');
    expect(text(2, 7), 'coffee, large');
    final amount = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2))
        .value;
    expect(amount, isA<DoubleCellValue>());
    expect((amount as DoubleCellValue).value, 4.5);
  });

  test('the summary adds up per category', () async {
    final book = Excel.decodeBytes((await service.buildXlsx())!);
    final rows = book['By category'].rows
        .map((r) => r.map((c) => c?.value.toString()).toList())
        .toList();
    final food = rows.firstWhere((r) => r[1] == 'Food');
    expect(food[0], 'expense');
    expect(double.parse(food[2]!), 15.0);
  });

  test('the range limits the sheet', () async {
    final book = Excel.decodeBytes(
      (await service.buildXlsx(
        from: DateTime(2026, 10),
        to: DateTime(2026, 11),
      ))!,
    );
    expect(book['Entries'].maxRows, 3);
  });
}
