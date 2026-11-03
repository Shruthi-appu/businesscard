import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// True when the app is running as the iPhone build.
bool get iphoneApp => defaultTargetPlatform == TargetPlatform.iOS;

Widget? phaseBack(BuildContext context) {
  if (!iphoneApp || !context.canPop()) return null;
  return CupertinoNavigationBarBackButton(onPressed: () => context.pop());
}

class SoftxuField extends StatelessWidget {
  const SoftxuField({
    super.key,
    required this.controller,
    this.label,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final caption = (label == null || label!.isEmpty) ? null : label;
    if (iphoneApp) {
      return CupertinoTextField(
        controller: controller,
        placeholder: caption,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE4D9C8)),
        ),
      );
    }
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: caption,
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE4D9C8)),
        ),
      ),
    );
  }
}

class SoftxuPrimaryButton extends StatelessWidget {
  const SoftxuPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (iphoneApp) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(onPressed: onPressed, child: Text(label)),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class SoftxuLink extends StatelessWidget {
  const SoftxuLink({super.key, required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (iphoneApp) {
      return CupertinoButton(onPressed: onPressed, child: Text(label));
    }
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

class SoftxuSecondaryButton extends StatelessWidget {
  const SoftxuSecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (iphoneApp) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          color: const Color(0xFFE7F3EF),
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(color: Color(0xFF0F6E56))),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class SoftxuPage extends StatelessWidget {
  const SoftxuPage({
    super.key,
    required this.body,
    this.title,
    this.trailing,
    this.leading,
  });

  final String? title;
  final Widget? trailing;
  final Widget? leading;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (iphoneApp) {
      return CupertinoPageScaffold(
        navigationBar: title == null
            ? null
            : CupertinoNavigationBar(
                middle: Text(title!),
                trailing: trailing,
                leading: leading,
              ),
        child: SafeArea(child: body),
      );
    }
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              leading: leading,
              title: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: trailing == null ? null : [trailing!],
            ),
      body: SafeArea(child: body),
    );
  }
}
