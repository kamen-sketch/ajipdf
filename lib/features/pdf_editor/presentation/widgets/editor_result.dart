import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'download_helper.dart';

/// Dialog hasil operasi editor: menampilkan info file & tombol simpan/unduh.
class EditorResultDialog extends StatelessWidget {
  const EditorResultDialog({
    super.key,
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Berhasil'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File: $fileName'),
          const SizedBox(height: 4),
          Text('Ukuran: ${(bytes.length / 1024).toStringAsFixed(0)} KB'),
          const SizedBox(height: 12),
          Text(
            kIsWeb
                ? 'Klik Unduh untuk menyimpan file ke perangkat.'
                : 'Klik Simpan untuk menyimpan file.',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final ok = await saveOrDownloadPdf(fileName, bytes);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'File "$fileName" berhasil disimpan.'
                      : 'Penyimpanan dibatalkan.'),
                ),
              );
            }
          },
          icon: Icon(kIsWeb ? Icons.download : Icons.save),
          label: Text(kIsWeb ? 'Unduh' : 'Simpan'),
        ),
      ],
    );
  }
}
