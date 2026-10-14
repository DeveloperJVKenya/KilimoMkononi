// lib/widgets/fluid_grid.dart
//
// Fluid grids: as many columns as fit the available width (each at least
// [minTileWidth], at most [maxColumns]), and every row as tall as its
// tallest tile — so cards never overflow a fixed height, whatever the screen
// size or the user's text size. Tiles in a row share that height, so cards
// line up.
//
//   FluidGrid(minTileWidth: 150, children: [...])         inside a scroll view
//   FluidGrid.builder(itemCount: n, itemBuilder: …)       same, from a builder
//   SliverFluidGrid(itemCount: n, itemBuilder: …)          in a CustomScrollView
//                                                          (rows built lazily)
//
// Use these instead of GridView / SliverGrid with a childAspectRatio or a
// fixed mainAxisExtent for anything holding text.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Columns that fit [width]: tiles at least [minTileWidth] wide.
int fluidColumns(double width, {required double minTileWidth, double spacing = 12, int maxColumns = 6}) {
  if (!width.isFinite || width <= 0) return 1;
  final n = ((width + spacing) / (minTileWidth + spacing)).floor();
  return n.clamp(1, math.max(1, maxColumns));
}

Widget _row(List<Widget> tiles, int columns, double spacing, bool equalHeights, double minTileHeight) {
  final cells = <Widget>[];
  for (var i = 0; i < columns; i++) {
    if (i > 0) cells.add(SizedBox(width: spacing));
    // Empty cells keep the last row's tiles the same width as the others.
    final tile = i < tiles.length ? tiles[i] : const SizedBox.shrink();
    cells.add(Expanded(
      child: minTileHeight > 0 && i < tiles.length
          ? ConstrainedBox(constraints: BoxConstraints(minHeight: minTileHeight), child: tile)
          : tile,
    ));
  }
  final row = Row(
    crossAxisAlignment: equalHeights ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
    children: cells,
  );
  return equalHeights ? IntrinsicHeight(child: row) : row;
}

class FluidGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  /// Tiles in a row stretch to the tallest one (cards line up).
  final bool equalHeights;

  /// Tiles are at least this tall (they still grow with their content).
  final double minTileHeight;

  FluidGrid({
    super.key,
    required List<Widget> children,
    required this.minTileWidth,
    this.maxColumns = 6,
    this.spacing = 12,
    this.runSpacing = 12,
    this.equalHeights = true,
    this.minTileHeight = 0,
  })  : itemCount = children.length,
        itemBuilder = ((_, i) => children[i]);

  const FluidGrid.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.minTileWidth,
    this.maxColumns = 6,
    this.spacing = 12,
    this.runSpacing = 12,
    this.equalHeights = true,
    this.minTileHeight = 0,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = fluidColumns(c.maxWidth, minTileWidth: minTileWidth, spacing: spacing, maxColumns: maxColumns);
        final rows = <Widget>[];
        for (var start = 0; start < itemCount; start += cols) {
          if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
          rows.add(_row(
            [for (var i = start; i < math.min(start + cols, itemCount); i++) itemBuilder(context, i)],
            cols,
            spacing,
            equalHeights,
            minTileHeight,
          ));
        }
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      });
}

/// [FluidGrid] for a CustomScrollView; rows are built as they scroll in.
class SliverFluidGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;
  final bool equalHeights;
  final double minTileHeight;

  const SliverFluidGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.minTileWidth,
    this.maxColumns = 6,
    this.spacing = 12,
    this.runSpacing = 12,
    this.equalHeights = true,
    this.minTileHeight = 0,
  });

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(builder: (context, c) {
        final cols = fluidColumns(c.crossAxisExtent, minTileWidth: minTileWidth, spacing: spacing, maxColumns: maxColumns);
        final rowCount = (itemCount / cols).ceil();
        return SliverList.builder(
          itemCount: rowCount,
          itemBuilder: (context, r) {
            final start = r * cols;
            return Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : runSpacing),
              child: _row(
                [for (var i = start; i < math.min(start + cols, itemCount); i++) itemBuilder(context, i)],
                cols,
                spacing,
                equalHeights,
                minTileHeight,
              ),
            );
          },
        );
      });
}
