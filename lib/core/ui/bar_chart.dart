import 'package:flutter/material.dart';

/// One column of a [BarChart]: a label under it and one or two bars.
class BarGroup {
  const BarGroup({required this.label, required this.values, this.highlight});

  final String label;

  /// One value per series, in minor units (never negative).
  final List<int> values;

  /// Draws the label in bold, e.g. for today.
  final bool? highlight;
}

/// A small bar chart made of plain widgets, so it follows the app theme and
/// text size. All groups share one scale.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.groups,
    required this.colors,
    this.height = 120,
    this.labelEvery = 1,
    this.semanticLabel,
  });

  final List<BarGroup> groups;
  final List<Color> colors;
  final double height;

  /// Shows every n-th label (for 31 days, 5 is readable).
  final int labelEvery;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var max = 0;
    for (final g in groups) {
      for (final v in g.values) {
        if (v > max) max = v;
      }
    }
    final scale = max == 0 ? 1 : max;

    return Semantics(
      label: semanticLabel,
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final g in groups)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var s = 0; s < g.values.length; s++)
                            Expanded(
                              child: FractionallySizedBox(
                                alignment: Alignment.bottomCenter,
                                heightFactor: g.values[s] == 0
                                    ? 0.0
                                    : (g.values[s] / scale).clamp(0.03, 1.0),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 0.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors[s % colors.length],
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < groups.length; i++)
                Expanded(
                  child: i % labelEvery == 0
                      ? Text(
                          groups[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: groups[i].highlight == true
                                ? FontWeight.w700
                                : null,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
