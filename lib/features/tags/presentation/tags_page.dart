import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui/text_prompt.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../entry/application/entry_meta_service.dart';
import '../data/tag_repository.dart';

class TagsController extends GetxController {
  TagsController(this._repo, this.meta);

  final TagRepository _repo;
  final EntryMetaService meta;

  Future<void> add(String name) => _repo.add(name);
  Future<void> rename(String id, String name) => _repo.rename(id, name);
  Future<void> delete(String id) => _repo.delete(id);

  /// How many entries use the tag.
  int usage(String tagId) =>
      meta.tagLinks.values.where((ids) => ids.contains(tagId)).length;
}

class TagsPage extends GetView<TagsController> {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tagsTitle),
        actions: [
          IconButton(
            tooltip: l10n.tagNew,
            icon: const Icon(Icons.add),
            onPressed: () async {
              final name = await showTextPrompt(
                context,
                title: l10n.tagNew,
                label: l10n.tagName,
              );
              if (name != null) await controller.add(name);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final tags = controller.meta.tags;
          // Read the links so the counts update.
          controller.meta.tagLinks.length;
          if (tags.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.tagsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            children: [
              for (final t in tags)
                ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: Text('#${t.name}'),
                  subtitle: Text('${controller.usage(t.id)}'),
                  onTap: () async {
                    final name = await showTextPrompt(
                      context,
                      title: l10n.tagRename,
                      label: l10n.tagName,
                      initial: t.name,
                    );
                    if (name != null) await controller.rename(t.id, name);
                  },
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.tagDeleteTitle),
                          content: Text(l10n.tagDeleteBody),
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
                      if (ok == true) await controller.delete(t.id);
                    },
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
