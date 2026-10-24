import 'dart:ui';
import 'package:flutter/material.dart';

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
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget textField = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      textInputAction: widget.isPassword ? TextInputAction.done : null,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onTap: widget.onTap,
      style: widget.isGlass ? TextStyle(color: Colors.white) : null,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: widget.isGlass ? TextStyle(color: Colors.white70) : null,
        filled: widget.isGlass,
        fillColor: Colors.transparent,
        border: widget.isGlass ? InputBorder.none : null,
        enabledBorder: widget.isGlass ? InputBorder.none : null,
        focusedBorder: widget.isGlass ? InputBorder.none : null,
        prefixIcon: widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                size: 20,
                color: widget.isGlass ? Colors.white70 : null,
              )
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: widget.isGlass ? Colors.white70 : null,
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
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: widget.isGlass ? Colors.white : null,
          ),
        ),
        const SizedBox(height: 8),
        textField,
      ],
    );
  }
}
