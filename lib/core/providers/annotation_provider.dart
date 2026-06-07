import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hive_service.dart';
import 'document_provider.dart';
import 'subscription_provider.dart';

/// Annotation type
enum AnnotationType {
  highlight,
  text,
  underline,
  strikethrough,
  drawing,
  stamp;

  String get label => switch (this) {
        AnnotationType.highlight => 'Highlight',
        AnnotationType.text => 'Sticky Note',
        AnnotationType.underline => 'Underline',
        AnnotationType.strikethrough => 'Strikethrough',
        AnnotationType.drawing => 'Drawing',
        AnnotationType.stamp => 'Stamp',
      };

  IconData get icon => switch (this) {
        AnnotationType.highlight => Icons.highlight,
        AnnotationType.text => Icons.sticky_note_2_outlined,
        AnnotationType.underline => Icons.format_underline,
        AnnotationType.strikethrough => Icons.format_strikethrough,
        AnnotationType.drawing => Icons.draw_outlined,
        AnnotationType.stamp => Icons.approval_outlined,
      };

  bool get requiresPro => switch (this) {
        AnnotationType.highlight => false,
        AnnotationType.text => false,
        AnnotationType.underline => true,
        AnnotationType.strikethrough => true,
        AnnotationType.drawing => true,
        AnnotationType.stamp => true,
      };
}

/// Annotation data model
class AnnotationModel {
  final String id;
  final AnnotationType type;
  final String documentId;
  final int pageIndex;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? text;
  final Color color;
  final double opacity;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AnnotationModel({
    required this.id,
    required this.type,
    required this.documentId,
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.text,
    required this.color,
    this.opacity = 1.0,
    required this.createdAt,
    required this.updatedAt,
  });

  AnnotationModel copyWith({
    String? text,
    Color? color,
    double? opacity,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return AnnotationModel(
      id: id,
      type: type,
      documentId: documentId,
      pageIndex: pageIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'documentId': documentId,
        'pageIndex': pageIndex,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'text': text,
        'color': color.toARGB32(),
        'opacity': opacity,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AnnotationModel.fromMap(Map<String, dynamic> map) => AnnotationModel(
        id: map['id'] as String,
        type: AnnotationType.values.firstWhere((t) => t.name == map['type']),
        documentId: map['documentId'] as String,
        pageIndex: map['pageIndex'] as int,
        x: (map['x'] as num).toDouble(),
        y: (map['y'] as num).toDouble(),
        width: (map['width'] as num).toDouble(),
        height: (map['height'] as num).toDouble(),
        text: map['text'] as String?,
        color: Color(map['color'] as int),
        opacity: (map['opacity'] as num).toDouble(),
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}

/// Annotations state — keyed by documentId
typedef AnnotationsState = Map<String, List<AnnotationModel>>;

class AnnotationNotifier extends StateNotifier<AnnotationsState> {
  AnnotationNotifier(this._ref) : super({}) {
    _loadFromHive();
  }

  final Ref _ref;

  static const int _freeLimit = 50;
  static const int _proLimit = 500;

  int get _limit {
    final isPro = _ref.read(subscriptionProvider).isPro;
    return isPro ? _proLimit : _freeLimit;
  }

  void _loadFromHive() {
    final box = HiveService.instance.annotationsBox;
    final raw = box.get('annotations');
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw as Map);
      final result = <String, List<AnnotationModel>>{};
      for (final entry in map.entries) {
        final list = (entry.value as List)
            .map((m) =>
                AnnotationModel.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList();
        result[entry.key] = list;
      }
      state = result;
    }
  }

  Future<void> _saveToHive() async {
    final box = HiveService.instance.annotationsBox;
    final map = state.map(
      (docId, list) => MapEntry(docId, list.map((a) => a.toMap()).toList()),
    );
    await box.put('annotations', map);
  }

  List<AnnotationModel> getForDocument(String documentId) {
    return state[documentId] ?? [];
  }

  /// Update document ID when document is saved/updated
  void updateDocumentId(String oldId, String newId) {
    final annotations = state.remove(oldId);
    if (annotations != null) {
      state[newId] = annotations;
      _saveToHive();
    }
  }

  /// Returns null if successful, or an error message
  String? addAnnotation(AnnotationModel annotation) {
    final isPro = _ref.read(subscriptionProvider).isPro;

    // Check if Pro feature
    if (annotation.type.requiresPro && !isPro) {
      return 'This annotation type requires Pro subscription.';
    }

    final current = state[annotation.documentId] ?? [];

    // Check limits
    if (current.length >= _limit) {
      return 'Annotation limit reached (${isPro ? _proLimit : _freeLimit} per document).';
    }

    final updated = {...state};
    updated[annotation.documentId] = [annotation, ...current];
    state = updated;
    _saveToHive();
    return null;
  }

  void updateAnnotation(AnnotationModel updated) {
    final docAnnotations = state[updated.documentId];
    if (docAnnotations == null) return;
    final newList =
        docAnnotations.map((a) => a.id == updated.id ? updated : a).toList();
    state = {...state, updated.documentId: newList};
    _saveToHive();
  }

  void removeAnnotation(String documentId, String annotationId) {
    final current = state[documentId] ?? [];
    final updated = current.where((a) => a.id != annotationId).toList();
    state = {...state, documentId: updated};
    _saveToHive();
  }

  void clearDocumentAnnotations(String documentId) {
    final updated = {...state};
    updated.remove(documentId);
    state = updated;
    _saveToHive();
  }
}

final annotationProvider =
    StateNotifierProvider<AnnotationNotifier, AnnotationsState>((ref) {
  return AnnotationNotifier(ref);
});

/// Helper: get annotations for active document
final activeDocumentAnnotationsProvider =
    Provider<List<AnnotationModel>>((ref) {
  final annotations = ref.watch(annotationProvider);
  final activeDoc = ref.watch(activeDocumentProvider);

  if (activeDoc == null) return [];

  // Filter annotations by active document ID
  return annotations[activeDoc.id] ?? [];
});
