import 'package:material_ui/material_ui.dart';

/// Brand colors: the same in light and dark themes.
abstract final class PortalColors {
  static const primary = Color(0xFFFACC15);
  static const primaryHover = Color(0xFFEAB308);
  static const primaryActive = Color(0xFFCA8A04);
  static const primaryFocus = Color(0xFFA16207);
  static const onPrimary = Color(0xFF18181B);
  static const danger = Color(0xFFEF4444);
}

/// Neutral and accent colors that change with the theme. Read with `context.palette`.
@immutable
class PortalPalette extends ThemeExtension<PortalPalette> {
  const PortalPalette({
    required this.canvas, required this.surface, required this.subtle, required this.border,
    required this.text, required this.muted, required this.primarySoft, required this.link,
    required this.chartLine, required this.chartFill,
  });
  /// Page background, cards/bars, quiet fills, lines, body text, secondary text.
  final Color canvas, surface, subtle, border, text, muted;
  /// Selected menu item and soft brand fills; links and focus rings.
  final Color primarySoft, link;
  final Color chartLine, chartFill;

  static const light = PortalPalette(
    canvas: Color(0xFFFAFAF9), surface: Color(0xFFFFFFFF), subtle: Color(0xFFF4F4F5), border: Color(0xFFE4E4E7),
    text: Color(0xFF18181B), muted: Color(0xFF71717A), primarySoft: Color(0xFFFEF9C3), link: PortalColors.primaryFocus,
    chartLine: PortalColors.primaryActive, chartFill: Color(0x80FEF9C3),
  );
  static const dark = PortalPalette(
    canvas: Color(0xFF0F0F11), surface: Color(0xFF18181B), subtle: Color(0xFF27272A), border: Color(0xFF3F3F46),
    text: Color(0xFFF4F4F5), muted: Color(0xFFA1A1AA), primarySoft: Color(0xFF3B3212), link: Color(0xFFFDE047),
    chartLine: PortalColors.primary, chartFill: Color(0x26FACC15),
  );

  @override
  PortalPalette copyWith({Color? canvas, Color? surface, Color? subtle, Color? border, Color? text, Color? muted,
      Color? primarySoft, Color? link, Color? chartLine, Color? chartFill}) => PortalPalette(
    canvas: canvas ?? this.canvas, surface: surface ?? this.surface, subtle: subtle ?? this.subtle,
    border: border ?? this.border, text: text ?? this.text, muted: muted ?? this.muted,
    primarySoft: primarySoft ?? this.primarySoft, link: link ?? this.link,
    chartLine: chartLine ?? this.chartLine, chartFill: chartFill ?? this.chartFill,
  );

  @override
  PortalPalette lerp(covariant PortalPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return PortalPalette(
      canvas: mix(canvas, other.canvas), surface: mix(surface, other.surface), subtle: mix(subtle, other.subtle),
      border: mix(border, other.border), text: mix(text, other.text), muted: mix(muted, other.muted),
      primarySoft: mix(primarySoft, other.primarySoft), link: mix(link, other.link),
      chartLine: mix(chartLine, other.chartLine), chartFill: mix(chartFill, other.chartFill),
    );
  }
}

extension PortalPaletteContext on BuildContext {
  PortalPalette get palette => Theme.of(this).extension<PortalPalette>() ?? PortalPalette.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Yellow + white brand theme. Every scheme colour is set explicitly: `ColorScheme.fromSeed`
/// would add olive/brown secondary tones and a yellow tint on menus and dialogs.
ThemeData portalTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final p = dark ? PortalPalette.dark : PortalPalette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: PortalColors.primary,
    onPrimary: PortalColors.onPrimary,
    primaryContainer: p.primarySoft,
    onPrimaryContainer: p.text,
    secondary: PortalColors.primaryHover,
    onSecondary: PortalColors.onPrimary,
    secondaryContainer: p.primarySoft,
    onSecondaryContainer: p.text,
    tertiary: PortalColors.primaryHover,
    onTertiary: PortalColors.onPrimary,
    tertiaryContainer: p.primarySoft,
    onTertiaryContainer: p.text,
    error: dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
    onError: dark ? PortalColors.onPrimary : const Color(0xFFFFFFFF),
    errorContainer: dark ? const Color(0xFF3B1414) : const Color(0xFFFEE2E2),
    onErrorContainer: p.text,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    surfaceDim: p.canvas,
    surfaceBright: p.surface,
    // Menus, dialogs and drawers use these: keep them plain white (or the dark surface).
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surface,
    surfaceContainerHighest: p.subtle,
    surfaceTint: Colors.transparent,
    outline: p.border,
    outlineVariant: p.border,
    inverseSurface: dark ? p.text : const Color(0xFF18181B),
    onInverseSurface: dark ? p.surface : const Color(0xFFFFFFFF),
    inversePrimary: PortalColors.primary,
    shadow: Colors.black,
    scrim: Colors.black,
  );
  final radius = BorderRadius.circular(8);
  final border = OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.border));
  WidgetStateProperty<Color?> selectedOr(Color selected, Color? other) =>
      WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? selected : other);
  final menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(p.surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    side: WidgetStatePropertyAll(BorderSide(color: p.border)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius)),
    elevation: const WidgetStatePropertyAll(4),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.canvas,
    canvasColor: p.surface,
    dividerColor: p.border,
    extensions: [p],
    cardTheme: CardThemeData(
      color: p.surface, surfaceTintColor: Colors.transparent, elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.border)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
    drawerTheme: DrawerThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
    appBarTheme: AppBarTheme(backgroundColor: p.surface, foregroundColor: p.text, elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
    menuTheme: MenuThemeData(style: menuStyle),
    dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
    popupMenuTheme: PopupMenuThemeData(color: p.surface, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true, filled: true, fillColor: p.surface, border: border, enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: PortalColors.primary, width: 2)),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) =>
          TextStyle(color: states.contains(WidgetState.error) ? scheme.error : p.text)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.text,
      selectionColor: PortalColors.primary.withValues(alpha: .45),
      selectionHandleColor: PortalColors.primary,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: PortalColors.primary, foregroundColor: PortalColors.onPrimary,
      minimumSize: const Size(0, 44), shape: RoundedRectangleBorder(borderRadius: radius),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: p.text, backgroundColor: p.surface, minimumSize: const Size(0, 44),
      side: BorderSide(color: p.border), shape: RoundedRectangleBorder(borderRadius: radius),
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.link)),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.text)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: PortalColors.primary, foregroundColor: PortalColors.onPrimary),
    segmentedButtonTheme: SegmentedButtonThemeData(style: ButtonStyle(
      backgroundColor: selectedOr(PortalColors.primary, p.surface),
      foregroundColor: selectedOr(PortalColors.onPrimary, p.text),
      iconColor: selectedOr(PortalColors.onPrimary, p.text),
      side: WidgetStatePropertyAll(BorderSide(color: p.border)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius)),
    )),
    checkboxTheme: CheckboxThemeData(
      fillColor: selectedOr(PortalColors.primary, Colors.transparent),
      checkColor: const WidgetStatePropertyAll(PortalColors.onPrimary),
      side: BorderSide(color: p.muted, width: 1.5),
    ),
    radioTheme: RadioThemeData(fillColor: selectedOr(PortalColors.primaryActive, p.muted)),
    switchTheme: SwitchThemeData(
      thumbColor: selectedOr(PortalColors.onPrimary, p.muted),
      trackColor: selectedOr(PortalColors.primary, p.subtle),
      trackOutlineColor: selectedOr(PortalColors.primary, p.border),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.primarySoft,
      selectedColor: PortalColors.primary,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(color: p.text),
      deleteIconColor: p.text,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    listTileTheme: ListTileThemeData(selectedColor: p.text, selectedTileColor: p.primarySoft, iconColor: p.muted),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: dark ? PortalColors.primary : PortalColors.primaryActive, linearTrackColor: p.subtle, circularTrackColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      actionTextColor: PortalColors.primary,
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: radius), textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12)),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: PortalColors.primary,
      headerForegroundColor: PortalColors.onPrimary,
      dayBackgroundColor: selectedOr(PortalColors.primary, null),
      dayForegroundColor: selectedOr(PortalColors.onPrimary, null),
      todayBackgroundColor: selectedOr(PortalColors.primary, null),
      todayForegroundColor: selectedOr(PortalColors.onPrimary, p.text),
      todayBorder: const BorderSide(color: PortalColors.primary),
      yearBackgroundColor: selectedOr(PortalColors.primary, null),
      yearForegroundColor: selectedOr(PortalColors.onPrimary, null),
      cancelButtonStyle: TextButton.styleFrom(foregroundColor: p.text),
      confirmButtonStyle: TextButton.styleFrom(foregroundColor: p.link),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(p.subtle),
      headingTextStyle: TextStyle(fontWeight: FontWeight.w600, color: p.text),
      dataRowColor: selectedOr(p.primarySoft, null),
    ),
  );
}

