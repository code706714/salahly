import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/auth/domain/entities/phone_number.dart';

/// The "+20 | 100 234 5678" field. Always left-to-right, like the number.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    required this.onChanged,
    required this.onSubmitted,
    required this.hasError,
    this.readOnly = false,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool hasError;

  /// True while the code is being sent, so the number can't change.
  final bool readOnly;

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final borderColor = widget.hasError
        ? colors.danger
        : _focusNode.hasFocus
        ? colors.primary
        : colors.fieldBorder;
    final radius = BorderRadius.circular(AppRadii.lg);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: 62,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _focusNode.requestFocus,
              child: Container(
                width: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border(
                    right: BorderSide(color: colors.border, width: 1.5),
                  ),
                ),
                child: Text(
                  '+20',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                focusNode: _focusNode,
                autofocus: true,
                readOnly: widget.readOnly,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: const [_NationalNumberFormatter()],
                onChanged: widget.onChanged,
                onSubmitted: (_) => widget.onSubmitted(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: colors.ink,
                ),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the national digits only, grouped as "100 234 5678".
class _NationalNumberFormatter extends TextInputFormatter {
  const _NationalNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = groupNationalDigits(nationalDigitsFrom(newValue.text));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
