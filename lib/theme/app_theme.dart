import 'package:flutter/material.dart';
import 'finance_colors.dart';

/// Finance app themes per Gemini-style guidelines: data-centric clarity,
/// high-contrast light/dark, semantic success/danger, 12–20px rounded corners.
class AppTheme {
  AppTheme._();

  static const double cardRadius = 16;
  static const double buttonRadius = 14;

  // ----- Light: Clarity — Paper Gray bg, Pure White cards -----
  static const Color surfaceLight = Color(0xFFF5F5F0);
  static const Color surfaceVariantLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLight = Color(0xFFEEEEEA);
  static const Color onSurfaceLight = Color(0xFF1A1A1A);
  static const Color onSurfaceVariantLight = Color(0xFF5A5A5A);
  static const Color outlineLight = Color(0xFFE0E0DC);
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color successGainLight = Color(0xFF166534);
  static const Color dangerLossLight = Color(0xFFDC2626);

  // ----- Dark: Focus — Deep Charcoal, Dark Slate cards -----
  static const Color surfaceDark = Color(0xFF0F1419);
  static const Color surfaceVariantDark = Color(0xFF1C2530);
  static const Color surfaceContainerDark = Color(0xFF252D38);
  static const Color onSurfaceDark = Color(0xFFE8EAED);
  static const Color onSurfaceVariantDark = Color(0xFF9CA3AF);
  static const Color outlineDark = Color(0xFF374151);
  static const Color primaryDark = Color(0xFF60A5FA);
  static const Color successGainDark = Color(0xFF84CC16);
  static const Color dangerLossDark = Color(0xFFFB7185);

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFF1D4ED8);
  static const Color primaryContainerDark = Color(0xFF3B82F6);

  // ----- Aesthetic (Overview light + Analytics dark): orange #FF7A00, soft radius 20/24 -----
  static const Color aestheticOrange = Color(0xFFFF7A00);
  static const double aestheticCardRadius = 20;
  static const double aestheticButtonRadius = 18;
  // Aesthetic Light (Overview): #F5F5F5 bg, pure white cards
  static const Color surfaceAestheticLight = Color(0xFFF5F5F5);
  static const Color surfaceVariantAestheticLight = Color(0xFFFFFFFF);
  static const Color onSurfaceAestheticLight = Color(0xFF1A1A1A);
  static const Color onSurfaceVariantAestheticLight = Color(0xFF6B6B6B);
  static const Color outlineAestheticLight = Color(0xFFE5E5E5);
  // Aesthetic Dark (Analytics): #121212 bg, dark cards
  static const Color surfaceAestheticDark = Color(0xFF121212);
  static const Color surfaceVariantAestheticDark = Color(0xFF1E1E1E);
  static const Color onSurfaceAestheticDark = Color(0xFFFFFFFF);
  static const Color onSurfaceVariantAestheticDark = Color(0xFF9CA3AF);
  static const Color outlineAestheticDark = Color(0xFF2D2D2D);

  /// Light (white) theme.
  static ThemeData get themeLight {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        onPrimary: onPrimary,
        primaryContainer: primaryContainerLight,
        secondary: primaryLight,
        surface: surfaceLight,
        onSurface: onSurfaceLight,
        onSurfaceVariant: onSurfaceVariantLight,
        outline: outlineLight,
        error: dangerLossLight,
        onError: onPrimary,
      ),
      extensions: const [
        FinanceColors(successGain: successGainLight, dangerLoss: dangerLossLight),
      ],
      scaffoldBackgroundColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceVariantLight,
        foregroundColor: onSurfaceLight,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurfaceLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: onSurfaceLight, size: 24),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariantLight,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      cardColor: surfaceVariantLight,
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        titleTextStyle: TextStyle(
          color: onSurfaceLight,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: const TextStyle(
          color: onSurfaceVariantLight,
          fontSize: 13,
        ),
        iconColor: primaryLight,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: onPrimary,
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(buttonRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: outlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        labelStyle: const TextStyle(color: onSurfaceVariantLight),
        hintStyle: const TextStyle(color: onSurfaceVariantLight),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceVariantLight,
        elevation: 8,
        height: 65,
        indicatorColor: primaryLight.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primaryLight,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(color: onSurfaceVariantLight, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryLight, size: 24);
          }
          return const IconThemeData(color: onSurfaceVariantLight, size: 24);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainerLight,
        contentTextStyle: const TextStyle(color: onSurfaceLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryLight,
        linearTrackColor: surfaceContainerLight,
        circularTrackColor: surfaceContainerLight,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primaryLight;
            return surfaceVariantLight;
          }),
          foregroundColor: const WidgetStatePropertyAll(onSurfaceLight),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outlineLight, thickness: 1),
      textTheme: _textThemeLight,
    );
  }

  /// Dark (Onyx-style) theme.
  static ThemeData get themeDark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        onPrimary: Color(0xFF0F172A),
        primaryContainer: primaryContainerDark,
        secondary: primaryDark,
        surface: surfaceDark,
        onSurface: onSurfaceDark,
        onSurfaceVariant: onSurfaceVariantDark,
        outline: outlineDark,
        error: dangerLossDark,
        onError: Color(0xFF0F172A),
      ),
      extensions: const [
        FinanceColors(successGain: successGainDark, dangerLoss: dangerLossDark),
      ],
      scaffoldBackgroundColor: surfaceDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceVariantDark,
        foregroundColor: onSurfaceDark,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurfaceDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: onSurfaceDark, size: 24),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariantDark,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: outlineDark, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      cardColor: surfaceVariantDark,
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        titleTextStyle: TextStyle(
          color: onSurfaceDark,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: const TextStyle(
          color: onSurfaceVariantDark,
          fontSize: 13,
        ),
        iconColor: primaryDark,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Color(0xFF0F172A),
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Color(0xFF0F172A),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(buttonRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: outlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        labelStyle: const TextStyle(color: onSurfaceVariantDark),
        hintStyle: const TextStyle(color: onSurfaceVariantDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceVariantDark,
        elevation: 8,
        height: 65,
        indicatorColor: primaryDark.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primaryDark,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(color: onSurfaceVariantDark, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryDark, size: 24);
          }
          return const IconThemeData(color: onSurfaceVariantDark, size: 24);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainerDark,
        contentTextStyle: const TextStyle(color: onSurfaceDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryDark,
        linearTrackColor: surfaceContainerDark,
        circularTrackColor: surfaceContainerDark,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primaryDark;
            return surfaceVariantDark;
          }),
          foregroundColor: const WidgetStatePropertyAll(onSurfaceDark),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outlineDark, thickness: 1),
      textTheme: _textThemeDark,
    );
  }

  /// Aesthetic Light (Overview): #F5F5F5 bg, white cards, orange accent, soft radius.
  static ThemeData get themeAestheticLight {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: aestheticOrange,
        onPrimary: onPrimary,
        primaryContainer: aestheticOrange,
        secondary: aestheticOrange,
        surface: surfaceAestheticLight,
        onSurface: onSurfaceAestheticLight,
        onSurfaceVariant: onSurfaceVariantAestheticLight,
        outline: outlineAestheticLight,
        error: dangerLossLight,
        onError: onPrimary,
      ),
      extensions: const [
        FinanceColors(successGain: successGainLight, dangerLoss: dangerLossLight),
      ],
      scaffoldBackgroundColor: surfaceAestheticLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceVariantAestheticLight,
        foregroundColor: onSurfaceAestheticLight,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurfaceAestheticLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: onSurfaceAestheticLight, size: 24),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariantAestheticLight,
        elevation: 3,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(aestheticCardRadius)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      cardColor: surfaceVariantAestheticLight,
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(aestheticCardRadius)),
        titleTextStyle: TextStyle(
          color: onSurfaceAestheticLight,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: const TextStyle(
          color: onSurfaceVariantAestheticLight,
          fontSize: 13,
        ),
        iconColor: aestheticOrange,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: aestheticOrange,
        foregroundColor: onPrimary,
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: aestheticOrange,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(aestheticButtonRadius)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAestheticLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(aestheticButtonRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(aestheticButtonRadius),
          borderSide: const BorderSide(color: outlineAestheticLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(aestheticButtonRadius),
          borderSide: const BorderSide(color: aestheticOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: onSurfaceVariantAestheticLight),
        hintStyle: const TextStyle(color: onSurfaceVariantAestheticLight),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceVariantAestheticLight,
        elevation: 8,
        height: 65,
        indicatorColor: aestheticOrange.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: aestheticOrange,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(color: onSurfaceVariantAestheticLight, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: aestheticOrange, size: 24);
          }
          return const IconThemeData(color: onSurfaceVariantAestheticLight, size: 24);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariantAestheticLight,
        contentTextStyle: const TextStyle(color: onSurfaceAestheticLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(aestheticButtonRadius)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: aestheticOrange,
        linearTrackColor: outlineAestheticLight,
        circularTrackColor: outlineAestheticLight,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return aestheticOrange;
            return surfaceVariantAestheticLight;
          }),
          foregroundColor: const WidgetStatePropertyAll(onPrimary),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outlineAestheticLight, thickness: 1),
      textTheme: _textThemeAestheticLight,
    );
  }

  /// Aesthetic Dark (Analytics): #121212 bg, dark cards, orange accent.
  static ThemeData get themeAestheticDark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: aestheticOrange,
        onPrimary: Color(0xFF1A1A1A),
        primaryContainer: aestheticOrange,
        secondary: aestheticOrange,
        surface: surfaceAestheticDark,
        onSurface: onSurfaceAestheticDark,
        onSurfaceVariant: onSurfaceVariantAestheticDark,
        outline: outlineAestheticDark,
        error: dangerLossDark,
        onError: Color(0xFF1A1A1A),
      ),
      extensions: const [
        FinanceColors(successGain: successGainDark, dangerLoss: dangerLossDark),
      ],
      scaffoldBackgroundColor: surfaceAestheticDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceVariantAestheticDark,
        foregroundColor: onSurfaceAestheticDark,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurfaceAestheticDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: onSurfaceAestheticDark, size: 24),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariantAestheticDark,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(aestheticCardRadius),
          side: const BorderSide(color: outlineAestheticDark, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),
      cardColor: surfaceVariantAestheticDark,
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(aestheticCardRadius)),
        titleTextStyle: TextStyle(
          color: onSurfaceAestheticDark,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: const TextStyle(
          color: onSurfaceVariantAestheticDark,
          fontSize: 13,
        ),
        iconColor: aestheticOrange,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: aestheticOrange,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: aestheticOrange,
          foregroundColor: Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(aestheticButtonRadius)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAestheticDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(aestheticButtonRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(aestheticButtonRadius),
          borderSide: const BorderSide(color: outlineAestheticDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(aestheticButtonRadius),
          borderSide: const BorderSide(color: aestheticOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: onSurfaceVariantAestheticDark),
        hintStyle: const TextStyle(color: onSurfaceVariantAestheticDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceVariantAestheticDark,
        elevation: 8,
        height: 65,
        indicatorColor: aestheticOrange.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: aestheticOrange,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(color: onSurfaceVariantAestheticDark, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: aestheticOrange, size: 24);
          }
          return const IconThemeData(color: onSurfaceVariantAestheticDark, size: 24);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariantAestheticDark,
        contentTextStyle: const TextStyle(color: onSurfaceAestheticDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(aestheticButtonRadius)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: aestheticOrange,
        linearTrackColor: outlineAestheticDark,
        circularTrackColor: outlineAestheticDark,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return aestheticOrange;
            return surfaceVariantAestheticDark;
          }),
          foregroundColor: const WidgetStatePropertyAll(onSurfaceAestheticDark),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outlineAestheticDark, thickness: 1),
      textTheme: _textThemeAestheticDark,
    );
  }

  /// Default theme (dark) for backward compatibility.
  static ThemeData get theme => themeDark;

  static TextTheme get _textThemeLight {
    const bold = FontWeight.w700;
    const semi = FontWeight.w600;
    const medium = FontWeight.w500;
    const normal = FontWeight.w400;
    return TextTheme(
      displayLarge: const TextStyle(color: onSurfaceLight, fontSize: 32, fontWeight: bold, letterSpacing: -0.5),
      displayMedium: const TextStyle(color: onSurfaceLight, fontSize: 28, fontWeight: bold),
      displaySmall: const TextStyle(color: onSurfaceLight, fontSize: 24, fontWeight: bold),
      headlineLarge: const TextStyle(color: onSurfaceLight, fontSize: 22, fontWeight: semi),
      headlineMedium: const TextStyle(color: onSurfaceLight, fontSize: 20, fontWeight: semi),
      headlineSmall: const TextStyle(color: onSurfaceLight, fontSize: 18, fontWeight: semi),
      titleLarge: const TextStyle(color: onSurfaceLight, fontSize: 16, fontWeight: semi),
      titleMedium: const TextStyle(color: onSurfaceLight, fontSize: 14, fontWeight: medium),
      titleSmall: const TextStyle(color: onSurfaceLight, fontSize: 12, fontWeight: medium),
      bodyLarge: const TextStyle(color: onSurfaceLight, fontSize: 16, fontWeight: normal),
      bodyMedium: const TextStyle(color: onSurfaceLight, fontSize: 14, fontWeight: normal),
      bodySmall: const TextStyle(color: onSurfaceVariantLight, fontSize: 12, fontWeight: normal),
      labelLarge: const TextStyle(color: onSurfaceLight, fontSize: 14, fontWeight: semi),
      labelMedium: const TextStyle(color: onSurfaceVariantLight, fontSize: 12, fontWeight: normal),
      labelSmall: const TextStyle(color: onSurfaceVariantLight, fontSize: 10, fontWeight: normal),
    );
  }

  static TextTheme get _textThemeDark {
    const bold = FontWeight.w700;
    const semi = FontWeight.w600;
    const medium = FontWeight.w500;
    const normal = FontWeight.w400;
    return TextTheme(
      displayLarge: const TextStyle(color: onSurfaceDark, fontSize: 32, fontWeight: bold, letterSpacing: -0.5),
      displayMedium: const TextStyle(color: onSurfaceDark, fontSize: 28, fontWeight: bold),
      displaySmall: const TextStyle(color: onSurfaceDark, fontSize: 24, fontWeight: bold),
      headlineLarge: const TextStyle(color: onSurfaceDark, fontSize: 22, fontWeight: semi),
      headlineMedium: const TextStyle(color: onSurfaceDark, fontSize: 20, fontWeight: semi),
      headlineSmall: const TextStyle(color: onSurfaceDark, fontSize: 18, fontWeight: semi),
      titleLarge: const TextStyle(color: onSurfaceDark, fontSize: 16, fontWeight: semi),
      titleMedium: const TextStyle(color: onSurfaceDark, fontSize: 14, fontWeight: medium),
      titleSmall: const TextStyle(color: onSurfaceDark, fontSize: 12, fontWeight: medium),
      bodyLarge: const TextStyle(color: onSurfaceDark, fontSize: 16, fontWeight: normal),
      bodyMedium: const TextStyle(color: onSurfaceDark, fontSize: 14, fontWeight: normal),
      bodySmall: const TextStyle(color: onSurfaceVariantDark, fontSize: 12, fontWeight: normal),
      labelLarge: const TextStyle(color: onSurfaceDark, fontSize: 14, fontWeight: semi),
      labelMedium: const TextStyle(color: onSurfaceVariantDark, fontSize: 12, fontWeight: normal),
      labelSmall: const TextStyle(color: onSurfaceVariantDark, fontSize: 10, fontWeight: normal),
    );
  }

  static TextTheme get _textThemeAestheticLight {
    const bold = FontWeight.w700;
    const semi = FontWeight.w600;
    const medium = FontWeight.w500;
    const normal = FontWeight.w400;
    return TextTheme(
      displayLarge: const TextStyle(color: onSurfaceAestheticLight, fontSize: 32, fontWeight: bold, letterSpacing: -0.5),
      displayMedium: const TextStyle(color: onSurfaceAestheticLight, fontSize: 28, fontWeight: bold),
      displaySmall: const TextStyle(color: onSurfaceAestheticLight, fontSize: 24, fontWeight: bold),
      headlineLarge: const TextStyle(color: onSurfaceAestheticLight, fontSize: 22, fontWeight: semi),
      headlineMedium: const TextStyle(color: onSurfaceAestheticLight, fontSize: 20, fontWeight: semi),
      headlineSmall: const TextStyle(color: onSurfaceAestheticLight, fontSize: 18, fontWeight: semi),
      titleLarge: const TextStyle(color: onSurfaceAestheticLight, fontSize: 16, fontWeight: semi),
      titleMedium: const TextStyle(color: onSurfaceAestheticLight, fontSize: 14, fontWeight: medium),
      titleSmall: const TextStyle(color: onSurfaceAestheticLight, fontSize: 12, fontWeight: medium),
      bodyLarge: const TextStyle(color: onSurfaceAestheticLight, fontSize: 16, fontWeight: normal),
      bodyMedium: const TextStyle(color: onSurfaceAestheticLight, fontSize: 14, fontWeight: normal),
      bodySmall: const TextStyle(color: onSurfaceVariantAestheticLight, fontSize: 12, fontWeight: normal),
      labelLarge: const TextStyle(color: onSurfaceAestheticLight, fontSize: 14, fontWeight: semi),
      labelMedium: const TextStyle(color: onSurfaceVariantAestheticLight, fontSize: 12, fontWeight: normal),
      labelSmall: const TextStyle(color: onSurfaceVariantAestheticLight, fontSize: 10, fontWeight: normal),
    );
  }

  static TextTheme get _textThemeAestheticDark {
    const bold = FontWeight.w700;
    const semi = FontWeight.w600;
    const medium = FontWeight.w500;
    const normal = FontWeight.w400;
    return TextTheme(
      displayLarge: const TextStyle(color: onSurfaceAestheticDark, fontSize: 32, fontWeight: bold, letterSpacing: -0.5),
      displayMedium: const TextStyle(color: onSurfaceAestheticDark, fontSize: 28, fontWeight: bold),
      displaySmall: const TextStyle(color: onSurfaceAestheticDark, fontSize: 24, fontWeight: bold),
      headlineLarge: const TextStyle(color: onSurfaceAestheticDark, fontSize: 22, fontWeight: semi),
      headlineMedium: const TextStyle(color: onSurfaceAestheticDark, fontSize: 20, fontWeight: semi),
      headlineSmall: const TextStyle(color: onSurfaceAestheticDark, fontSize: 18, fontWeight: semi),
      titleLarge: const TextStyle(color: onSurfaceAestheticDark, fontSize: 16, fontWeight: semi),
      titleMedium: const TextStyle(color: onSurfaceAestheticDark, fontSize: 14, fontWeight: medium),
      titleSmall: const TextStyle(color: onSurfaceAestheticDark, fontSize: 12, fontWeight: medium),
      bodyLarge: const TextStyle(color: onSurfaceAestheticDark, fontSize: 16, fontWeight: normal),
      bodyMedium: const TextStyle(color: onSurfaceAestheticDark, fontSize: 14, fontWeight: normal),
      bodySmall: const TextStyle(color: onSurfaceVariantAestheticDark, fontSize: 12, fontWeight: normal),
      labelLarge: const TextStyle(color: onSurfaceAestheticDark, fontSize: 14, fontWeight: semi),
      labelMedium: const TextStyle(color: onSurfaceVariantAestheticDark, fontSize: 12, fontWeight: normal),
      labelSmall: const TextStyle(color: onSurfaceVariantAestheticDark, fontSize: 10, fontWeight: normal),
    );
  }
}
