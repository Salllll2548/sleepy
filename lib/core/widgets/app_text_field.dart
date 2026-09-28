import 'package:flutter/material.dart';

/// ช่องกรอกแบบในดีไซน์ (Username, Password, Name, Confirm password, ...)
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: label,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
