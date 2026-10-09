import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/ui/category_sheet.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../entry/data/category_repository.dart';

class CategoriesController extends GetxController {
  CategoriesController(this._repo);

  final CategoryRepository _repo;

  final kind = 'expense'.obs;
  final categories = <CategoryRow>[].obs;
  final usage = <String, int>{}.obs;

  StreamSubscription<List<CategoryRow>>? _catSub;
  StreamSubscription<Map<String, int>>? _useSub;

  @override
  void onInit() {
    super.onInit();
    _listen();
    ever(kind, (_) => _listen());
    _useSub = _repo.watchUsage().listen((m) {
      usage
        ..clear()
        ..addAll(m);
    });
  }

  void _listen() {
    _catSub?.cancel();
    _catSub = _repo.watchManage(kind.value).listen(categories.assignAll);
  }

  Future<void> add(String name, String icon) =>
      _repo.add(name: name, icon: icon, kind: kind.value);

  Future<void> edit(String id, String name, String icon) =>
      _repo.update(id, name: name, icon: icon);

  Future<void> setHidden(String id, bool hidden) => _repo.setHidden(id, hidden);

  Future<bool> isInUse(String id) => _repo.isInUse(id);

  Future<void> delete(String id, String moveTo) =>
      _repo.delete(id, moveTo: moveTo);

  @override
  void onClose() {
    _catSub?.cancel();
    _useSub?.cancel();
    super.onClose();
  }
}

class CategoriesPage extends GetView<CategoriesController> {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesTitle),
        actions: [
          IconButton(
            tooltip: l10n.addCategory,
            icon: const Icon(Icons.add),
            onPressed: () => CategoryEditSheet.show(
              context,
              title: l10n.addCategory,
              submitLabel: l10n.add,
              onSubmit: controller.add,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Obx(
                () => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'expense',
                        label: Text(l10n.expense),
                      ),
                      ButtonSegment(value: 'income', label: Text(l10n.income)),
                    ],
                    selected: {controller.kind.value},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => controller.kind.value = s.first,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                final list = controller.categories;
                final usage = controller.usage;
                if (list.isEmpty) {
                  return Center(child: Text(l10n.categoryNone));
                }
                return ListView(
                  children: [
                    for (final c in list)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorForCategory(
                            c.id,
                          ).withValues(alpha: c.isHidden ? 0.06 : 0.14),
                          child: Icon(
                            iconFor(c.icon),
                            color: colorForCategory(
                              c.id,
                            ).withValues(alpha: c.isHidden ? 0.4 : 1),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          categoryDisplayName(l10n, c),
                          style: c.isHidden
                              ? TextStyle(color: theme.disabledColor)
                              : null,
                        ),
                        subtitle: Text(
                          [
                            if (c.isDefault) l10n.categoryBuiltIn,
                            l10n.categoryEntries(usage[c.id] ?? 0),
                          ].join(' · '),
                        ),
                        onTap: c.isDefault
                            ? null
                            : () => CategoryEditSheet.show(
                                context,
                                title: l10n.categoryEdit,
                                submitLabel: l10n.save,
                                initialName: c.name,
                                initialIcon: c.icon,
                                onSubmit: (name, icon) =>
                                    controller.edit(c.id, name, icon),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: !c.isHidden,
                              onChanged: (v) => controller.setHidden(c.id, !v),
                            ),
                            if (!c.isDefault)
                              IconButton(
                                tooltip: l10n.delete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(context, c),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, CategoryRow c) async {
    final l10n = AppLocalizations.of(context);
    final inUse = await controller.isInUse(c.id);
    if (!context.mounted) return;

    final others = controller.categories.where((x) => x.id != c.id).toList();
    String? target;
    if (inUse) {
      if (others.isEmpty) return;
      target = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.categoryDeleteTitle),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.categoryDeleteBody),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                l10n.categoryMoveTo,
                style: Theme.of(ctx).textTheme.labelLarge,
              ),
            ),
            for (final o in others)
              ListTile(
                leading: Icon(iconFor(o.icon)),
                title: Text(categoryDisplayName(l10n, o)),
                onTap: () => Navigator.pop(ctx, o.id),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
              ),
            ),
          ],
        ),
      );
      if (target == null) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.categoryDeleteTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );
      if (ok != true) return;
      // Nothing uses it, so any category of the same kind works as target.
      if (others.isEmpty) return;
      target = others.first.id;
    }
    await controller.delete(c.id, target);
  }
}
