import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/providers/document_provider.dart';
import '../../../../core/providers/signature_provider.dart';
import '../widgets/signature_canvas.dart';
import '../widgets/signature_apply_widget.dart';

/// Digital Signature Screen
/// Allows users to create signatures via drawing, image upload, or typed text
class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  String _selectedFont = 'Cursive';
  Color _signatureColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(isProProvider);
    final signatures = ref.watch(signaturesProvider);

    if (!isPro) {
      return Scaffold(
        appBar: AppBar(title: const Text('Digital Signature')),
        body: _buildLockedNotice(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signature'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.draw), text: 'Draw'),
            Tab(icon: Icon(Icons.image), text: 'Image'),
            Tab(icon: Icon(Icons.text_fields), text: 'Typed'),
          ],
        ),
        actions: [
          if (signatures.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: 'Saved Signatures',
              onPressed: () => _showSavedSignatures(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Signature count indicator
          if (signatures.isNotEmpty)
            Container(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '${signatures.length}/10 signatures saved',
                    style: const TextStyle(
                        color: AppTheme.primaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDrawTab(),
                _buildImageTab(),
                _buildTypedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ DRAW TAB ============

  Widget _buildDrawTab() {
    return Column(
      children: [
        // Toolbar
        _buildDrawToolbar(),
        // Canvas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SignatureCanvas(
              strokeWidth: _strokeWidth,
              color: _signatureColor,
              onSave: _saveDrawnSignature,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const Text('Color:', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          ...[Colors.black, Colors.blue, Colors.red, Colors.green].map(
            (c) => GestureDetector(
              onTap: () => setState(() => _signatureColor = c),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _signatureColor == c
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          const Text('Size:', style: TextStyle(fontSize: 12)),
          Expanded(
            flex: 2,
            child: Slider(
              value: _strokeWidth,
              min: 1,
              max: 8,
              divisions: 7,
              onChanged: (v) => setState(() => _strokeWidth = v),
            ),
          ),
        ],
      ),
    );
  }

  // ============ IMAGE TAB ============

  Widget _buildImageTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.upload_rounded,
                      size: 64, color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Upload Signature Image',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PNG or JPEG, max 5MB\nBackground will be made transparent',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _pickSignatureImage,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose Image'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ TYPED TAB ============

  Widget _buildTypedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Type your signature',
              hintText: 'Your Name',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 18),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // Font style selector
          DropdownButtonFormField<String>(
            value: _selectedFont,
            decoration: const InputDecoration(
              labelText: 'Font Style',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'Cursive',
                  child:
                      Text('Cursive', style: TextStyle(fontFamily: 'cursive'))),
              DropdownMenuItem(
                  value: 'Italic',
                  child: Text('Italic (Serif)',
                      style: TextStyle(fontStyle: FontStyle.italic))),
              DropdownMenuItem(
                  value: 'Bold',
                  child: Text('Bold',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            onChanged: (v) => setState(() => _selectedFont = v ?? 'Cursive'),
          ),
          const SizedBox(height: 16),
          // Color picker row
          Row(
            children: [
              const Text('Color: ',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              ...[Colors.black, Colors.blue, Colors.indigo, Colors.green].map(
                (c) => GestureDetector(
                  onTap: () => setState(() => _signatureColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _signatureColor == c
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Preview
          if (_textController.text.isNotEmpty) ...[
            const Text('Preview:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _textController.text,
                style: TextStyle(
                  fontSize: 36,
                  color: _signatureColor,
                  fontStyle: _selectedFont == 'Italic'
                      ? FontStyle.italic
                      : FontStyle.normal,
                  fontWeight: _selectedFont == 'Bold'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveTypedSignature,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Save Signature'),
            ),
          ],
        ],
      ),
    );
  }

  // ============ LOCKED NOTICE ============

  Widget _buildLockedNotice(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Digital Signature is a Pro Feature',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Upgrade to Pro to create and apply digital signatures to your documents.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/subscription'),
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Upgrade to Pro'),
            ),
          ],
        ),
      ),
    );
  }

  // ============ ACTIONS ============

  Future<void> _saveDrawnSignature(Uint8List imageData) async {
    final signatures = ref.read(signaturesProvider);
    if (signatures.length >= 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Maximum 10 signatures reached. Delete one to save new.')),
        );
      }
      return;
    }
    final name = await _askSignatureName();
    if (name == null) return;

    ref.read(signaturesProvider.notifier).addSignature(
          SignatureModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            type: SignatureType.drawn,
            imageData: imageData,
            createdAt: DateTime.now(),
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature saved successfully!')),
      );
      // Optionally offer to apply now
      _showApplyOption(imageData, name);
    }
  }

  Future<void> _pickSignatureImage() async {
    final signatures = ref.read(signaturesProvider);
    if (signatures.length >= 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Maximum 10 signatures reached. Delete one to save new.')),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image too large. Maximum size is 5MB.')),
        );
      }
      return;
    }

    final imageData = file.bytes;
    if (imageData == null) return;

    final name = await _askSignatureName();
    if (name == null) return;

    ref.read(signaturesProvider.notifier).addSignature(
          SignatureModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            type: SignatureType.uploaded,
            imageData: imageData,
            createdAt: DateTime.now(),
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature image saved!')),
      );
      _showApplyOption(imageData, name);
    }
  }

  Future<void> _saveTypedSignature() async {
    if (_textController.text.isEmpty) return;

    final signatures = ref.read(signaturesProvider);
    if (signatures.length >= 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Maximum 10 signatures reached. Delete one to save new.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Convert text to image
      final imageData = await _textToImage(_textController.text);
      final name = await _askSignatureName();
      if (name == null) return;

      ref.read(signaturesProvider.notifier).addSignature(
            SignatureModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              type: SignatureType.typed,
              imageData: imageData,
              text: _textController.text,
              createdAt: DateTime.now(),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Typed signature saved!')),
        );
        _showApplyOption(imageData, name);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List> _textToImage(String text) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const width = 400.0;
    const height = 120.0;

    // White background
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.transparent,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 48,
          color: _signatureColor,
          fontStyle:
              _selectedFont == 'Italic' ? FontStyle.italic : FontStyle.normal,
          fontWeight:
              _selectedFont == 'Bold' ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: width);
    textPainter.paint(
      canvas,
      Offset(
          (width - textPainter.width) / 2, (height - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<String?> _askSignatureName() async {
    final controller = TextEditingController(text: 'My Signature');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this signature'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Signature name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx,
                controller.text.trim().isEmpty
                    ? 'My Signature'
                    : controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showApplyOption(Uint8List imageData, String name) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Signature saved!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Would you like to apply it to a document now?'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf,
                  color: AppTheme.primaryColor),
              title: const Text('Apply to PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _applySignatureToDocument(imageData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Later'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _applySignatureToDocument(Uint8List signatureData) async {
    final doc = await ref.read(documentsProvider.notifier).pickPdf();
    if (doc == null || !mounted) return;

    ref.read(activeDocumentProvider.notifier).state = doc;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignatureApplyWidget(
          document: doc,
          signatureData: signatureData,
        ),
      ),
    );
  }

  void _showSavedSignatures(BuildContext context) {
    final signatures = ref.read(signaturesProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Saved Signatures',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: signatures.length,
                itemBuilder: (_, i) {
                  final sig = signatures[i];
                  return ListTile(
                    leading: SizedBox(
                      width: 60,
                      height: 40,
                      child: Image.memory(sig.imageData, fit: BoxFit.contain),
                    ),
                    title: Text(sig.name),
                    subtitle: Text(sig.type.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf,
                              color: AppTheme.primaryColor),
                          tooltip: 'Apply to PDF',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _applySignatureToDocument(sig.imageData);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.errorColor),
                          tooltip: 'Delete',
                          onPressed: () {
                            ref
                                .read(signaturesProvider.notifier)
                                .removeSignature(sig.id);
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
