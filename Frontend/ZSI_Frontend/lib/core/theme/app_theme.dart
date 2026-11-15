import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Protection status used across the app. Colours follow the coastal
/// colour-coded warning convention fishers already read at a glance.
enum ProtectionStatus { scheduleI, scheduleII, unsure, notListed }

extension ProtectionStatusX on ProtectionStatus {
  Color get color => switch (this) {
        ProtectionStatus.scheduleI => const Color(0xFFC62828),
        ProtectionStatus.scheduleII => const Color(0xFFBF4800),
        ProtectionStatus.unsure => const Color(0xFFF9C440),
        ProtectionStatus.notListed => const Color(0xFF2E7D32),
      };

  Color get onColor => this == ProtectionStatus.unsure
      ? const Color(0xFF2B2100)
      : Colors.white;

  /// Short tag text, e.g. on list rows.
  String get tag => switch (this) {
        ProtectionStatus.scheduleI => 'SCH. I',
        ProtectionStatus.scheduleII => 'SCH. II',
        ProtectionStatus.unsure => 'UNSURE',
        ProtectionStatus.notListed => 'NOT LISTED',
      };

  static ProtectionStatus fromSchedule(int? schedule) => switch (schedule) {
        1 => ProtectionStatus.scheduleI,
        2 => ProtectionStatus.scheduleII,
        _ => ProtectionStatus.notListed,
      };
}

/// Colour tokens that are not Material roles. Read with `WildColors.of(context)`.
@immutable
class WildColors extends ThemeExtension<WildColors> {
  const WildColors({
    required this.ground,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.shell,
    required this.onShell,
    required this.shellMuted,
    required this.shellRaised,
    required this.accent,
    required this.onAccent,
    required this.warning,
  });

  /// Page background.
  final Color ground;

  /// Lists and panels on the ground.
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;

  /// Deep sea-green header band.
  final Color shell;
  final Color onShell;
  final Color shellMuted;
  final Color shellRaised;

  /// Logo lime, for the one primary action on the shell.
  final Color accent;
  final Color onAccent;

  /// Amber used for "offline / queued" notices on the shell.
  final Color warning;

  static const light = WildColors(
    ground: Color(0xFFF2F5F0),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF0E1F18),
    muted: Color(0xFF4A5C53),
    line: Color(0xFFDDE5DF),
    shell: Color(0xFF0B3D2E),
    onShell: Color(0xFFF2F5F0),
    shellMuted: Color(0xFFB5CEC1),
    shellRaised: Color(0xFF12503D),
    accent: Color(0xFF8BD13A),
    onAccent: Color(0xFF0B2A1F),
    warning: Color(0xFFF9D46B),
  );

  static const dark = WildColors(
    ground: Color(0xFF0B1411),
    card: Color(0xFF14211C),
    ink: Color(0xFFE4EDE8),
    muted: Color(0xFFA3B6AC),
    line: Color(0xFF253530),
    shell: Color(0xFF082A20),
    onShell: Color(0xFFE4EDE8),
    shellMuted: Color(0xFFA3B6AC),
    shellRaised: Color(0xFF0F3B2E),
    accent: Color(0xFF8BD13A),
    onAccent: Color(0xFF0B2A1F),
    warning: Color(0xFFF9D46B),
  );

  static WildColors of(BuildContext context) =>
      Theme.of(context).extension<WildColors>() ?? light;

  @override
  WildColors copyWith() => this;

  @override
  WildColors lerp(ThemeExtension<WildColors>? other, double t) {
    if (other is! WildColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return WildColors(
      ground: l(ground, other.ground),
      card: l(card, other.card),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      shell: l(shell, other.shell),
      onShell: l(onShell, other.onShell),
      shellMuted: l(shellMuted, other.shellMuted),
      shellRaised: l(shellRaised, other.shellRaised),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      warning: l(warning, other.warning),
    );
  }
}

class AppTheme {
  AppTheme._();

  // Legacy names kept so screens that were not rebuilt still compile; they
  // now resolve to the Sea-warning palette.
  static const Color primaryColor = Color(0xFF0B3D2E);
  static const Color primaryLight = Color(0xFF12503D);
  static const Color primaryDark = Color(0xFF082A20);
  static const Color secondaryColor = Color(0xFF3E7A62);
  static const Color accentColor = Color(0xFF8BD13A);
  static const Color backgroundColor = Color(0xFFF2F5F0);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF0E1F18);
  static const Color textSecondaryColor = Color(0xFF4A5C53);
  static const Color dividerColor = Color(0xFFDDE5DF);
  static const Color errorColor = Color(0xFFC62828);

  /// Condensed display style for verdicts and big headings.
  static TextStyle display(double size, Color color) => GoogleFonts.anekLatin(
        fontSize: size,
        height: 0.95,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: color,
      );

  static ThemeData get theme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final wild = brightness == Brightness.light ? WildColors.light : WildColors.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B3D2E),
      brightness: brightness,
    ).copyWith(
      primary: brightness == Brightness.light ? wild.shell : wild.accent,
      onPrimary: brightness == Brightness.light ? Colors.white : wild.onAccent,
      secondaryContainer: brightness == Brightness.light
          ? const Color(0xFFCFEAB0)
          : const Color(0xFF2C4A1A),
      onSecondaryContainer: brightness == Brightness.light
          ? const Color(0xFF0B2A1F)
          : const Color(0xFFD6F0BC),
      surface: wild.card,
      onSurface: wild.ink,
      onSurfaceVariant: wild.muted,
      outline: wild.muted,
      outlineVariant: wild.line,
      error: const Color(0xFFC62828),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: wild.ground,
      extensions: [wild],
    );
    final text = GoogleFonts.anekLatinTextTheme(base.textTheme).apply(
      bodyColor: wild.ink,
      displayColor: wild.ink,
    );

    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
    final label = GoogleFonts.anekLatin(fontSize: 16, fontWeight: FontWeight.w700);

    return base.copyWith(
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.4),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: wild.ground,
        foregroundColor: wild.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.anekLatin(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: wild.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: pill,
          textStyle: label,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: pill,
          textStyle: label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brightness == Brightness.light ? wild.shell : wild.ink,
          side: BorderSide(color: wild.muted.withValues(alpha: 0.6), width: 1.5),
          minimumSize: const Size(64, 48),
          shape: pill,
          textStyle: label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brightness == Brightness.light ? wild.shell : wild.accent,
          minimumSize: const Size(48, 48),
          textStyle: label.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: wild.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: wild.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: wild.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: TextStyle(color: wild.muted),
        hintStyle: TextStyle(color: wild.muted),
      ),
      cardTheme: CardThemeData(
        color: wild.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        backgroundColor: wild.card,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: wild.line),
        labelStyle: GoogleFonts.anekLatin(fontSize: 14, fontWeight: FontWeight.w600, color: wild.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: wild.card,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        height: 80,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.anekLatin(fontSize: 12, fontWeight: FontWeight.w600, color: wild.ink),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: wild.ink,
        contentTextStyle: GoogleFonts.anekLatin(fontSize: 15, color: wild.ground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: wild.line, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: wild.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: wild.card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
