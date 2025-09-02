import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/haptic_service.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final VoidCallback? onToggleVisibility;
  final List<TextInputFormatter>? inputFormatters;
  final Color? borderColor;
  final String? errorText;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.onToggleVisibility,
    this.inputFormatters,
    this.borderColor,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onTap: () {
        // For password fields, give a small selection feedback when focused/tapped
        if (obscureText) HapticService.instance.selection();
      },
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText, // <-- Set error text dynamically
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: borderColor ?? Colors.grey,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: borderColor ?? Colors.grey,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: borderColor ?? Colors.black,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
            width: 2.0,
          ),
        ),
        suffixIcon: onToggleVisibility != null
            ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: () {
            // Feedback when toggling password visibility
            HapticService.instance.selection();
            if (onToggleVisibility != null) onToggleVisibility!();
          },
        )
            : null,
      ),
      onChanged: onChanged,
    );
  }
}