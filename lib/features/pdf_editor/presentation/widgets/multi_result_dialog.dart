import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'download_helper.dart';

/// Satu file hasil operasi (mis. hasil split per halaman).
class ResultFile {
  ResultFile({required this.fileName, required this.bytes});
  final String fileName;
  final Uint8List bytes;
}

/// Dialog menampilkan beberapa file hasil (mis. split menjadi banyak PDF).
class MultiResultDialog extends StatelessWidget {
  const MultiResultDialog({super.key, required this.files});

  final List<ResultFile> files;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text('${files.length} file dihasilkan'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Unduh tiap file:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (_, i) {
                  final f = files[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf,
                        color: Colors.redAccent),
                    title: Text(f.fileName, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${(f.bytes.length / 1024).toStringAsFixed(0)} KB'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => saveOrDownloadPdf(f.fileName, f.bytes),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: () async {
            for (final f in files) {
              await saveOrDownloadPdf(f.fileName, f.bytes);
              await Future.delayed(const Duration(milliseconds: 400));
            }
          },
          icon: const Icon(Icons.download_for_offline),
          label: const Text('Unduh semua'),
        ),
      ],
    );
  }
}
