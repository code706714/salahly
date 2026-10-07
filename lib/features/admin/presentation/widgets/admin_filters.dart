import 'dart:async';

import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// A search box that reports what was typed once typing pauses, or at
/// once on enter.
class AdminSearchField extends StatefulWidget {
  const AdminSearchField({
    required this.hint,
    required this.onChanged,
    this.initialText = '',
    super.key,
  });

  /// How long typing must pause before the search runs.
  static const debounce = Duration(milliseconds: 400);

  final String hint;
  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _timer?.cancel();
    _timer = Timer(AdminSearchField.debounce, () => widget.onChanged(text));
  }

  void _submitted(String text) {
    _timer?.cancel();
    widget.onChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      controller: _controller,
      onChanged: _typed,
      onSubmitted: _submitted,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: colors.inkMuted, fontSize: 14),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: colors.inkMuted,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: _border(colors.fieldBorder),
        enabledBorder: _border(colors.fieldBorder),
        focusedBorder: _border(colors.primary, width: 2),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// A drop-down for narrowing a list. A null value stands for "all", which
/// [allLabel] names.
class AdminDropdown<T extends Object> extends StatelessWidget {
  const AdminDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    required this.allLabel,
    super.key,
  });

  /// What the control is for, for screen readers.
  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onChanged;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: label,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: colors.fieldBorder, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T?>(
            value: value,
            onChanged: onChanged,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            dropdownColor: colors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            style: TextStyle(
              fontSize: 14,
              color: colors.ink,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            items: [
              DropdownMenuItem<T?>(child: Text(allLabel)),
              for (final item in values)
                DropdownMenuItem<T?>(value: item, child: Text(labelOf(item))),
            ],
          ),
        ),
      ),
    );
  }
}
