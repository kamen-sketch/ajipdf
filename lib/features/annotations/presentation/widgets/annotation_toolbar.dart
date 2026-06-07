import 'package:flutter/material.dart';

import '../../../../core/providers/annotation_provider.dart';
import '../../../../core/theme/app_theme.dart';

/// Annotation toolbar with tool selection, color picker, and opacity slider
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.opacity,
    required this.isPro,
    required this.onToolSelected,
    required this.onColorChanged,
    required this.onOpacityChanged,
  });

  final AnnotationType selectedTool;
  final Color selectedColor;
  final double opacity;
  final bool isPro;
  final ValueChanged<AnnotationType> onToolSelected;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onOpacityChanged;

  static const _colors = [
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF5722), // Red-Orange
    Color(0xFF9C27B0), // Purple
    Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          // Tool selection
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: AnnotationType.values.map((tool) {
                final isSelected = selectedTool == tool;
                final isLocked = tool.requiresPro && !isPro;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      isLocked ? Icons.lock : tool.icon,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isLocked ? AppTheme.textHint : null),
                    ),
                    label: Text(tool.label),
                    selected: isSelected,
                    onSelected: (_) => onToolSelected(tool),
                    backgroundColor: isLocked
                        ? AppTheme.textHint.withValues(alpha: 0.1)
                        : null,
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isLocked ? AppTheme.textHint : null),
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Color and opacity row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                // Color picker
                ..._colors.map(
                  (c) => GestureDetector(
                    onTap: () => onColorChanged(c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == c
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.opacity,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                SizedBox(
                  width: 80,
                  child: Slider(
                    value: opacity,
                    min: 0.1,
                    max: 1.0,
                    onChanged: onOpacityChanged,
                  ),
                ),
                Text('${(opacity * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
