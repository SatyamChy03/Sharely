import 'package:flutter/material.dart';
import 'package:sharely/design/tokens.dart';
import 'package:sharely/design/widgets/file_kind.dart';

typedef _Landscape = ({Color sky, Color sun, Color hill});

// Illustration colours from the design's thumbnail component, not UI tokens.
const _landscapes = <_Landscape>[
  (sky: Color(0xFF2B5D7C), sun: Color(0xFFF2C46D), hill: Color(0xFF173B55)),
  (sky: Color(0xFF6FA9BE), sun: Color(0xFFF5FAFC), hill: Color(0xFF2F6E6B)),
  (sky: Color(0xFFB98668), sun: Color(0xFFF6D9A8), hill: Color(0xFF5E433B)),
  (sky: Color(0xFF5868A0), sun: Color(0xFFE9B7C9), hill: Color(0xFF2C3A68)),
];
const _paperColor = Color(0xFFE6EFF3);
const _paperHeading = Color(0xFF6F8798);
const _paperLine = Color(0xFFAFC0CC);
const _pdfBand = Color(0xFFE0475F);
const _videoBase = Color(0xFF0A1626);

/// Draws the photo, video and PDF thumbnails on a 40-unit grid.
class FileThumbPainter extends CustomPainter {
  const new({required this.kind, required this.tone});

  final FileKind kind;
  final int tone;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40);
    final landscape = _landscapes[tone % _landscapes.length];
    switch (kind) {
      case FileKind.video:
        _paintVideo(canvas, landscape);
      case FileKind.pdf:
        _paintPdf(canvas);
      case _:
        _paintPhoto(canvas, landscape);
    }
  }

  void _paintPhoto(Canvas canvas, _Landscape landscape) {
    const frame = Rect.fromLTWH(0, 0, 40, 40);
    final hill = Path()
      ..moveTo(0, 40)
      ..lineTo(0, 29)
      ..lineTo(10, 18)
      ..lineTo(19, 28)
      ..lineTo(25, 22)
      ..lineTo(40, 36)
      ..lineTo(40, 40)
      ..close();
    canvas
      ..drawRect(frame, Paint()..color = landscape.sky)
      ..drawCircle(const Offset(28, 12), 5, Paint()..color = landscape.sun)
      ..drawPath(hill, Paint()..color = landscape.hill);
  }

  void _paintVideo(Canvas canvas, _Landscape landscape) {
    const frame = Rect.fromLTWH(0, 0, 40, 40);
    final hill = Path()
      ..moveTo(0, 40)
      ..lineTo(0, 30)
      ..lineTo(12, 20)
      ..lineTo(22, 29)
      ..lineTo(29, 24)
      ..lineTo(40, 34)
      ..lineTo(40, 40)
      ..close();
    final play = Path()
      ..moveTo(17.6, 16.3)
      ..lineTo(17.6, 23.7)
      ..lineTo(23.8, 20)
      ..close();
    canvas
      ..drawRect(frame, Paint()..color = _videoBase)
      ..drawRect(frame, Paint()..color = landscape.sky.withValues(alpha: 0.55))
      ..drawPath(hill, Paint()..color = landscape.hill.withValues(alpha: 0.7))
      ..drawCircle(
        const Offset(20, 20),
        8.5,
        Paint()..color = SharelyColors.background.withValues(alpha: 0.78),
      )
      ..drawPath(play, Paint()..color = SharelyColors.text);
  }

  void _paintPdf(Canvas canvas) {
    RRect bar(double top, double width, double height) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, top, width, height),
          Radius.circular(height / 2),
        );
    final line = Paint()..color = _paperLine;
    canvas
      ..drawRect(
        const Rect.fromLTWH(0, 0, 40, 40),
        Paint()..color = _paperColor,
      )
      ..drawRRect(bar(7, 18, 2.4), Paint()..color = _paperHeading)
      ..drawRRect(bar(12, 24, 1.6), line)
      ..drawRRect(bar(15.5, 22, 1.6), line)
      ..drawRRect(bar(19, 24, 1.6), line)
      ..drawRect(const Rect.fromLTWH(0, 27, 40, 13), Paint()..color = _pdfBand);
    final label = TextPainter(
      text: const TextSpan(
        text: 'PDF',
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          height: 1,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(20 - label.width / 2, 33.5 - label.height / 2));
  }

  @override
  bool shouldRepaint(FileThumbPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.tone != tone;
}
