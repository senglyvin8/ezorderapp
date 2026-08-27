import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/order.dart';

/// Palette.
///
/// Every value here comes from [Palette] in `lib/config/app_config.dart` —
/// that is the file to edit. This class exists so the rest of the app has one
/// short, stable name to reach for.
abstract class AppColors {
  static const brand = Palette.accent;
  static const brandDark = Palette.accentDark;
  static const brandTint = Palette.accentTint;

  static const surface = Palette.surface;
  static const card = Palette.card;
  static const border = Palette.border;
  static const borderStrong = Palette.borderStrong;

  static const ink = Palette.ink;
  static const inkSoft = Palette.inkSoft;
  static const inkFaint = Palette.inkFaint;

  static const statusNew = Palette.statusNew;
  static const statusCooking = Palette.statusCooking;
  static const statusReady = Palette.statusReady;
  static const statusPaid = Palette.statusPaid;
  static const statusCompleted = Palette.statusCompleted;

  static const danger = Palette.danger;
  static const note = Palette.note;
}

/// Colour used for a status badge, tracker dot or dashboard tile.
Color statusColor(OrderStatus status) => switch (status) {
      OrderStatus.newOrder => AppColors.statusNew,
      OrderStatus.cooking => AppColors.statusCooking,
      OrderStatus.ready => AppColors.statusReady,
      OrderStatus.paid => AppColors.statusPaid,
      OrderStatus.completed => AppColors.statusCompleted,
      OrderStatus.cancelled => AppColors.danger,
    };

/// A pale wash of [color], flattened against white so it can be used as a
/// solid fill behind badges and tiles.
Color tint(Color color) =>
    Color.alphaBlend(color.withAlpha(28), AppColors.card);

abstract class AppRadius {
  static const card = Style.cardRadius;
  static const control = Style.controlRadius;
  static const small = Style.smallRadius;
}

/// Two steps of elevation. Cards get the first, anything that floats over
/// content gets the second.
abstract class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x0A0F1319),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0D0F1319),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const raised = [
    BoxShadow(
      color: Color(0x140F1319),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x1A0F1319),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

/// The theme configures only widely stable `*ThemeData` slots. Cards, app bars,
/// dialogs and text fields are styled through the shared widgets in
/// `lib/widgets/` so the look stays identical across Flutter versions that have
/// reshuffled those theme classes.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.light,
  ).copyWith(primary: AppColors.brand);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    // One family for both scripts.
    fontFamily: Style.fontFamily,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: Style.fontFamily,
          fontSize: 16.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 54),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.borderStrong),
        textStyle: const TextStyle(
          fontFamily: Style.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandDark,
        textStyle: const TextStyle(
          fontFamily: Style.fontFamily,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.brandTint,
      height: 74,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12.5,
          letterSpacing: -0.05,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.brandDark
              : AppColors.inkSoft,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 25,
          color: states.contains(WidgetState.selected)
              ? AppColors.brandDark
              : AppColors.inkSoft,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),
  );
}

/// Type scale. Explicit so headings stay consistent across screens without
/// each widget inventing its own size and weight.
abstract class AppType {
  static const screenTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.25,
  );
  static const screenSubtitle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: AppColors.inkSoft,
  );
  static const cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.25,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.inkSoft,
  );
  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: AppColors.inkSoft,
  );
  static const price = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );
  static const numeral = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.9,
    height: 1.1,
  );
}
