import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/file_kind.dart';
import 'package:sharely/design/widgets/file_thumb_painter.dart';

/// One thumbnail for every file kind: a small picture for photos, videos
/// and PDFs, a glyph for the rest.
class FileThumb extends StatelessWidget {
  const new({
    required this.kind,
    super.key,
    this.size = 40,
    this.radius = SharelyRadii.row,
    this.tone = 0,
  });

  /// Picks the kind from [fileName] and a stable tone from its characters.
  factory forName(String fileName, {Key? key, double size = 40}) {
    final tone = fileName.codeUnits.fold(0, (sum, unit) => sum + unit);
    return FileThumb(
      key: key,
      kind: FileKind.fromName(fileName),
      size: size,
      tone: tone,
    );
  }

  final FileKind kind;
  final double size;
  final Radius radius;

  /// Varies the picture's palette so a list of photos does not look cloned.
  final int tone;

  @override
  Widget build(BuildContext context) {
    final isPainted = switch (kind) {
      FileKind.image || FileKind.video || FileKind.pdf => true,
      _ => false,
    };
    return ClipRRect(
      borderRadius: BorderRadius.all(radius),
      child: SizedBox.square(
        dimension: size,
        child: isPainted
            ? CustomPaint(
                painter: FileThumbPainter(kind: kind, tone: tone),
              )
            : ColoredBox(
                color: SharelyColors.elevated,
                child: Icon(kind.glyph, size: size * 0.5, color: _glyphColor),
              ),
      ),
    );
  }

  Color get _glyphColor => switch (kind) {
    FileKind.link || FileKind.text => SharelyColors.primary,
    FileKind.folder => SharelyColors.primarySoft,
    _ => SharelyColors.textSecondary,
  };
}
