import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lp_colors.dart';
import 'lp_dimens.dart';
import 'lp_typography.dart';

/// Builds the two official ThemeData objects from the LastPuff token set.
abstract final class LpTheme {
  static ThemeData midnight() => _build(const LpColors.midnight());

  static ThemeData daylight() => _build(const LpColors.daylight());

  static SystemUiOverlayStyle overlayStyle(LpColors lp) => lp.isDark
      ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

  static ThemeData _build(LpColors lp) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: lp.brightness,
      fontFamily: LpType.body,
    );

    final colorScheme = ColorScheme(
      brightness: lp.brightness,
      primary: lp.volt,
      onPrimary: lp.onVolt,
      secondary: lp.ember,
      onSecondary: lp.onVolt,
      tertiary: lp.oxygen,
      onTertiary: lp.onVolt,
      error: lp.danger,
      onError: lp.onVolt,
      surface: lp.surface,
      onSurface: lp.textPrimary,
      surfaceContainerHighest: lp.surfaceSubtle,
      outline: lp.border,
      outlineVariant: lp.borderSubtle,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lp.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: lp.border,
      extensions: [lp],
      textTheme: base.textTheme.apply(
        bodyColor: lp.textPrimary,
        displayColor: lp.textPrimary,
        fontFamily: LpType.body,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lp.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle(lp),
        iconTheme: IconThemeData(color: lp.textSecondary),
        titleTextStyle: LpType.titleSm(lp.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: lp.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: lp.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LpDimens.rSheet),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: lp.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lp.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LpDimens.rBento),
        ),
        titleTextStyle: LpType.heading(lp.textPrimary, size: 18),
        contentTextStyle: LpType.body14(lp.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lp.surfaceSubtle,
        contentTextStyle: LpType.body13(lp.textBody),
        actionTextColor: lp.voltText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LpDimens.rInput),
          side: BorderSide(color: lp.border, width: 1.5),
        ),
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? lp.onVolt
              : lp.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? lp.volt
              : lp.surfaceSubtle,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? lp.volt : lp.border,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: lp.oxygen,
        inactiveTrackColor: lp.border,
        thumbColor: lp.oxygen,
        overlayColor: lp.oxygenSoft,
        trackHeight: 8,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: lp.volt,
        selectionColor: lp.voltSoft,
        selectionHandleColor: lp.voltStrong,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: lp.voltStrong,
        linearTrackColor: lp.border,
        circularTrackColor: lp.border,
      ),
    );
  }
}
