import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/providers/document_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/preview_result_screen.dart';

/// Rotate & Reorder Pages Screen
class RotateReorderScreen extends ConsumerStatefulWidget {
  const RotateReorderScreen({super.key});

  @override
  ConsumerState<RotateReorderScreen> createState() =>
      _RotateReorderScreenState();
}

class _RotateReorderScreenState extends ConsumerState<RotateReorderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PdfDocumentInfo? _doc;
  int _totalPages = 0;
  bool _processing = false;

  // Reorder
  List<int> _pageOrder = []; // 0-indexed page indices

  // Rotate
  Map<int, int> _rotations = {}; // pageIndex -> rotation degrees

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Use active document if available
    final active = ref.read(activeDocumentProvider);
    if (active != null) {
      _doc = active;
      _loadPages();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPages() async {
    if (_doc?.bytes == null) return;
    final pdf = PdfDocument(inputBytes: _doc!.bytes!);
    final count = pdf.pages.count;
    pdf.dispose();
    setState(() {
      _totalPages = count;
      _pageOrder = List.generate(count, (i) => i);
      _rotations = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotate & Reorder Pages'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.rotate_90_degrees_ccw), text: 'Rotate'),
            Tab(icon: Icon(Icons.reorder), text: 'Reorder'),
          ],
        ),
      ),
      body: Column(
        children: [
          // File picker
          if (_doc == null)
            Expanded(child: _buildPickerPlaceholder())
          else ...[
            _buildDocumentHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRotateTab(),
                  _buildReorderTab(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickerPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_outlined,
              size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          const Text('No document selected',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickDocument,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf,
              color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _doc!.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$_totalPages pages',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _processing ? null : _pickDocument,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  // ============ ROTATE TAB ============

  Widget _buildRotateTab() {
    if (_totalPages == 0)
      return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Quick actions
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : () => _rotateAll(90),
                  icon: const Icon(Icons.rotate_right, size: 16),
                  label: const Text('All +90°'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : () => _rotateAll(180),
                  icon: const Icon(Icons.rotate_90_degrees_cw, size: 16),
                  label: const Text('All 180°'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : () => _rotateAll(270),
                  icon: const Icon(Icons.rotate_left, size: 16),
                  label: const Text('All -90°'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _totalPages,
            itemBuilder: (_, i) => _buildRotateTile(i),
          ),
        ),
        // Apply button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  (_rotations.isEmpty || _processing) ? null : _applyRotations,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Apply Rotations'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRotateTile(int pageIndex) {
    final rotation = _rotations[pageIndex] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${pageIndex + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text('Page ${pageIndex + 1}'),
        subtitle: Text(rotation == 0 ? 'No rotation' : 'Rotated ${rotation}°'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.rotate_left, size: 20),
              tooltip: '-90°',
              onPressed: () => _rotatePage(pageIndex, -90),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rotation != 0
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$rotation°',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            IconButton(
              icon: const Icon(Icons.rotate_right, size: 20),
              tooltip: '+90°',
              onPressed: () => _rotatePage(pageIndex, 90),
            ),
          ],
        ),
      ),
    );
  }

  // ============ REORDER TAB ============

  Widget _buildReorderTab() {
    if (_totalPages == 0)
      return const Center(child: CircularProgressIndicator());

    final hasChanges = !_isDefaultOrder();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator,
                  color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 8),
              const Text('Drag pages to reorder them',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              if (hasChanges)
                TextButton(
                  onPressed: () => setState(
                      () => _pageOrder = List.generate(_totalPages, (i) => i)),
                  child: const Text('Reset'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _pageOrder.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _pageOrder.removeAt(oldIndex);
                _pageOrder.insert(newIndex, item);
              });
            },
            itemBuilder: (_, i) {
              final originalPage = _pageOrder[i];
              return Card(
                key: ValueKey(originalPage),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_indicator,
                        color: AppTheme.textSecondary),
                  ),
                  title: Text('Page ${i + 1}'),
                  subtitle: originalPage != i
                      ? Text('Original: page ${originalPage + 1}',
                          style: const TextStyle(
                              color: AppTheme.warningColor, fontSize: 12))
                      : null,
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${originalPage + 1}',
                        style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (!hasChanges || _processing) ? null : _applyReorder,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: const Text('Apply New Order'),
            ),
          ),
        ),
      ],
    );
  }

  // ============ HELPERS & ACTIONS ============

  bool _isDefaultOrder() {
    for (int i = 0; i < _pageOrder.length; i++) {
      if (_pageOrder[i] != i) return false;
    }
    return true;
  }

  void _rotatePage(int pageIndex, int degrees) {
    setState(() {
      final current = _rotations[pageIndex] ?? 0;
      final newRotation = ((current + degrees) % 360 + 360) % 360;
      if (newRotation == 0) {
        _rotations.remove(pageIndex);
      } else {
        _rotations[pageIndex] = newRotation;
      }
    });
  }

  void _rotateAll(int degrees) {
    setState(() {
      for (int i = 0; i < _totalPages; i++) {
        final current = _rotations[i] ?? 0;
        final newRotation = ((current + degrees) % 360 + 360) % 360;
        if (newRotation == 0) {
          _rotations.remove(i);
        } else {
          _rotations[i] = newRotation;
        }
      }
    });
  }

  Future<void> _pickDocument() async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc == null) return;
    setState(() {
      _doc = doc;
      _totalPages = 0;
      _pageOrder = [];
      _rotations = {};
    });
    ref.read(activeDocumentProvider.notifier).state = doc;
    await _loadPages();
  }

  Future<void> _applyRotations() async {
    if (_doc?.bytes == null) return;
    setState(() => _processing = true);
    try {
      final pdf = PdfDocument(inputBytes: _doc!.bytes!);

      for (final entry in _rotations.entries) {
        final pageIndex = entry.key;
        final degrees = entry.value;
        if (pageIndex < pdf.pages.count) {
          final page = pdf.pages[pageIndex];
          page.rotation = _degreesToPdfRotation(degrees);
        }
      }

      final result = Uint8List.fromList(await pdf.save());
      pdf.dispose();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewResultScreen(
              fileName: 'rotated_${_doc!.name}',
              bytes: result,
              title: 'Pratinjau Rotasi',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _applyReorder() async {
    if (_doc?.bytes == null) return;
    setState(() => _processing = true);
    try {
      final src = PdfDocument(inputBytes: _doc!.bytes!);
      final out = PdfDocument();
      if (out.pages.count > 0) out.pages.removeAt(0);

      for (final origIndex in _pageOrder) {
        if (origIndex >= src.pages.count) continue;
        final srcPage = src.pages[origIndex];
        final template = srcPage.createTemplate();
        final newPage = out.pages.insert(out.pages.count, srcPage.size);
        newPage.graphics
            .drawPdfTemplate(template, const Offset(0, 0), newPage.size);
      }

      final result = Uint8List.fromList(await out.save());
      src.dispose();
      out.dispose();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewResultScreen(
              fileName: 'reordered_${_doc!.name}',
              bytes: result,
              title: 'Pratinjau Urutan',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  PdfPageRotateAngle _degreesToPdfRotation(int degrees) {
    return switch (degrees) {
      90 => PdfPageRotateAngle.rotateAngle90,
      180 => PdfPageRotateAngle.rotateAngle180,
      270 => PdfPageRotateAngle.rotateAngle270,
      _ => PdfPageRotateAngle.rotateAngle0,
    };
  }
}
