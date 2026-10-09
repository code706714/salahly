import 'package:flutter/painting.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Inside a multi-line field: 12 of padding plus the 1.5 border; the lines
  /// are rounded up by a pixel, so the vertical part is a little shorter.
  static const EdgeInsets textArea = EdgeInsets.symmetric(
    horizontal: 13.5,
    vertical: 12.5,
  );
}
