import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hive_service.dart';

/// Signature type enum
enum SignatureType {
  drawn,
  uploaded,
  typed;

  String get label => switch (this) {
        SignatureType.drawn => 'Drawn',
        SignatureType.uploaded => 'Uploaded Image',
        SignatureType.typed => 'Typed Text',
      };
}

/// Signature model
class SignatureModel {
  final String id;
  final String name;
  final SignatureType type;
  final Uint8List imageData;
  final String? text;
  final DateTime createdAt;

  const SignatureModel({
    required this.id,
    required this.name,
    required this.type,
    required this.imageData,
    this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'imageData': imageData,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SignatureModel.fromMap(Map<String, dynamic> map) => SignatureModel(
        id: map['id'] as String,
        name: map['name'] as String,
        type: SignatureType.values.firstWhere((t) => t.name == map['type']),
        imageData: map['imageData'] as Uint8List,
        text: map['text'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}

/// Signatures notifier — manages saved signatures (max 10 per Pro user)
class SignaturesNotifier extends StateNotifier<List<SignatureModel>> {
  SignaturesNotifier() : super([]) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = HiveService.instance.signaturesBox;
    final raw = box.get('signatures');
    if (raw != null) {
      final list = (raw as List).cast<Map>();
      state = list
          .map((m) => SignatureModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
  }

  Future<void> _saveToHive() async {
    final box = HiveService.instance.signaturesBox;
    await box.put('signatures', state.map((s) => s.toMap()).toList());
  }

  void addSignature(SignatureModel signature) {
    if (state.length >= 10) return; // max 10
    state = [signature, ...state];
    _saveToHive();
  }

  void removeSignature(String id) {
    state = state.where((s) => s.id != id).toList();
    _saveToHive();
  }

  void updateSignature(SignatureModel updated) {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
    _saveToHive();
  }
}

/// Provider for signatures
final signaturesProvider =
    StateNotifierProvider<SignaturesNotifier, List<SignatureModel>>((ref) {
  return SignaturesNotifier();
});
