import 'package:flutter/services.dart';

/// Lets only Western and Arabic digits into a field, up to [maxLength].
List<TextInputFormatter> digitInputFormatters({required int maxLength}) => [
  FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
  LengthLimitingTextInputFormatter(maxLength),
];
