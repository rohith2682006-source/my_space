import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final int maxLines;
  final void Function(String)? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool isGlass;
  final bool enabled;
  final bool readOnly;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.isGlass = false,
    this.enabled = true,
    this.readOnly = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.enabled && !widget.readOnly;
    Widget textField = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      textInputAction: widget.isPassword ? TextInputAction.done : null,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onTap: widget.onTap,
      style: widget.isGlass
          ? GoogleFonts.outfit(
              color: isInteractive ? Colors.white : Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            )
          : TextStyle(
              color: isInteractive ? null : Colors.black54,
            ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: widget.isGlass
            ? GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 14,
              )
            : null,
        filled: widget.isGlass,
        fillColor: Colors.transparent,
        contentPadding: widget.isGlass
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
            : null,
        border: widget.isGlass ? InputBorder.none : null,
        enabledBorder: widget.isGlass ? InputBorder.none : null,
        focusedBorder: widget.isGlass ? InputBorder.none : null,
        prefixIcon: widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                size: 20,
                color: widget.isGlass ? const Color(0xFFA78BFA) : null,
              )
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: widget.isGlass ? Colors.white60 : null,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
      ),
    );

    if (widget.isGlass) {
      textField = Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1931).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1.2,
          ),
        ),
        child: textField,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: widget.isGlass
              ? GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE2E8F0),
                )
              : const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
        ),
        const SizedBox(height: 8),
        textField,
      ],
    );
  }
}
