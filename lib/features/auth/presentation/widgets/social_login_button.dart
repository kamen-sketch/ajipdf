import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Social login button widget for Google and Apple sign in
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkTextHint
                : AppTheme.textHint,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // For now, use icon from Icons since we don't have SVG assets yet
            // When SVG assets are available, use: SvgPicture.asset(icon, width: 20, height: 20)
            Icon(
              label == 'Google' ? Icons.g_mobiledata : Icons.apple,
              size: 24,
              color: theme.brightness == Brightness.dark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
