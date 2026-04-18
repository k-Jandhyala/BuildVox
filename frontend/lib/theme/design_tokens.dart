import 'package:flutter/material.dart';

/// Global spacing — 16dp horizontal padding, 12dp section gaps.
abstract final class BVSpacing {
  static const double screenHorizontal = 16;
  static const double sectionGap = 12;
  static const double minTapTarget = 48;
}

/// Role / trade pill colours (solid fills with dark text where noted).
abstract final class BVRoleColors {
  static const Color electrician = Color(0xFFF5A623);
  static const Color plumber = Color(0xFF2D9CDB);
  static const Color gc = Color(0xFF2DC653);
  static const Color manager = Color(0xFF9B59B6);
}
