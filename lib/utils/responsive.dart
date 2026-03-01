import 'package:flutter/widgets.dart';

class Responsive {
  static const double tabletBreakpoint = 600.0;
  static const double contentMaxWidth = 600.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;
  }
}
