import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Touch point for drawing
class _TouchPoint {
  final Offset point;
  final bool isStart;
  const _TouchPoint(this.point, {this.isStart = false});
}

/// Signature drawing canvas widget
class SignatureCanvas extends StatefulWidget {
  const SignatureCanvas({
    super.key,
    required this.strokeWidth,
    required this.color,
    required this.onSave,
  });

  final double strokeWidth;
  final Color color;
  final Future<void> Function(Uint8List imageData) onSave;

  @override
  State<SignatureCanvas> createState() => _SignatureCanvasState();
}

class _SignatureCanvasState extends State<SignatureCanvas> {
  final List<List<_TouchPoint>> _strokes = [];
  List<_TouchPoint> _currentStroke = [];
  bool _isEmpty = true;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drawing area
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  // Canvas
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _currentStroke = [
                          _TouchPoint(details.localPosition, isStart: true)
                        ];
                        _isEmpty = false;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _currentStroke.add(_TouchPoint(details.localPosition));
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _strokes.add(List.from(_currentStroke));
                        _currentStroke = [];
                      });
                    },
                    child: RepaintBoundary(
                      key: _canvasKey,
                      child: CustomPaint(
                        painter: _SignaturePainter(
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                          color: widget.color,
                          strokeWidth: widget.strokeWidth,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  // Hint when empty
                  if (_isEmpty)
                    const Center(
                      child: Text(
                        'Sign here',
                        style: TextStyle(
                          color: Color(0xFFBBBBBB),
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isEmpty ? null : _clearCanvas,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_strokes.isNotEmpty && !_isEmpty) ? _undo : null,
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: (_isEmpty || _isSaving) ? null : _saveSignature,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  final GlobalKey _canvasKey = GlobalKey();

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _isEmpty = true;
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.removeLast();
      if (_strokes.isEmpty) _isEmpty = true;
    });
  }

  Future<void> _saveSignature() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      await widget.onSave(bytes);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
  });

  final List<List<_TouchPoint>> strokes;
  final List<_TouchPoint> currentStroke;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in [...strokes, currentStroke]) {
      if (stroke.isEmpty) continue;
      final path = Path();
      path.moveTo(stroke.first.point.dx, stroke.first.point.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].point.dx, stroke[i].point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
