import 'package:flutter/material.dart';

/// Lays cards out in one column on a phone and in two or three columns on a
/// tablet or desktop, without forcing every card to the same height.
class CardGrid extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.children,
    this.minTileWidth = 380,
    this.spacing = 14,
    this.maxColumns = 3,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 28),
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final int maxColumns;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - padding.horizontal;
        final columns =
            (available / minTileWidth).floor().clamp(1, maxColumns).toInt();

        if (columns <= 1) {
          return ListView.separated(
            padding: padding,
            itemCount: children.length,
            separatorBuilder: (_, __) => SizedBox(height: spacing),
            itemBuilder: (context, index) => children[index],
          );
        }

        final columnChildren = List.generate(columns, (_) => <Widget>[]);
        for (var i = 0; i < children.length; i++) {
          columnChildren[i % columns].add(children[i]);
        }

        return SingleChildScrollView(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < columnChildren[c].length; i++) ...[
                        if (i > 0) SizedBox(height: spacing),
                        columnChildren[c][i],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
