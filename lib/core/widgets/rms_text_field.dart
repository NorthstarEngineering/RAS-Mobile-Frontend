import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// Labeled input field matching the Stitch form fields:
/// label row (with optional [trailing] action), white `h-12` field with
/// `shadow-sm`, a leading [prefixIcon], and an optional password toggle.
class RmsTextField extends StatefulWidget {
  const RmsTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.trailing,
    this.isPassword = false,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.textDirection,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;

  /// Widget shown at the end of the label row (e.g. "نسيت كلمة المرور؟").
  final Widget? trailing;
  final bool isPassword;

  /// Shown below the field, outside the shadowed box.
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Override for LTR-only values (emails, codes) inside the RTL layout.
  final TextDirection? textDirection;

  @override
  State<RmsTextField> createState() => _RmsTextFieldState();
}

class _RmsTextFieldState extends State<RmsTextField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label, style: AppTypography.labelMd)),
            ?widget.trailing,
          ],
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.sm,
          ),
          child: SizedBox(
            height: AppSizes.controlHeight,
            child: TextField(
              controller: widget.controller,
              obscureText: _obscured,
              obscuringCharacter: '•',
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textDirection: widget.textDirection,
              style: AppTypography.bodyMd,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: widget.prefixIcon == null
                    ? null
                    : Icon(widget.prefixIcon, size: AppSizes.iconMd),
                suffixIcon: widget.isPassword ? _visibilityToggle() : null,
                enabledBorder: hasError
                    ? Theme.of(context).inputDecorationTheme.errorBorder
                    : null,
                focusedBorder: hasError
                    ? Theme.of(context).inputDecorationTheme.focusedErrorBorder
                    : null,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.errorText!,
            style: AppTypography.labelSm.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Widget _visibilityToggle() {
    return IconButton(
      tooltip: 'تبديل إظهار كلمة المرور',
      onPressed: () => setState(() => _obscured = !_obscured),
      icon: Icon(
        _obscured ? Symbols.visibility : Symbols.visibility_off,
        size: AppSizes.iconMd,
      ),
    );
  }
}
