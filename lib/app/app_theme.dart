import 'package:flutter/material.dart';

/// Màu cam thương hiệu FPT. Trắng trên nền này chỉ đạt 2,95:1 nên ở giao
/// diện sáng nó không làm nền cho chữ; nền nút dùng [_orangeDeep] (5,18:1).
/// Ở giao diện tối, chữ tối trên cam FPT đạt 5,93:1 nên dùng đúng màu gốc.
///
/// [fapNavy] là màu thanh tiêu đề / thanh tab của myFAP gốc (#1a2e4a).
const fptOrange = Color(0xFFF27024);
const _orangeDeep = Color(0xFFC2410C);
const fapNavy = Color(0xFF1A2E4A);

/// Bo góc thống nhất: nút, ô nhập, thẻ, hộp thoại = 12; nhãn trạng thái = 6.
const appRadius = 12.0;
const tagRadius = 6.0;

const _fontFamily = 'BeVietnamPro';

ThemeData buildLightTheme() => _build(
  ColorScheme.fromSeed(seedColor: fptOrange).copyWith(
    primary: _orangeDeep,
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFFFEDD5),
    onPrimaryContainer: const Color(0xFF7C2D12),
    secondaryContainer: const Color(0xFFFFEDD5),
    onSecondaryContainer: const Color(0xFF7C2D12),
    surface: const Color(0xFFFAFAF9),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFF5F5F4),
    surfaceContainer: const Color(0xFFF0EFED),
    surfaceContainerHigh: const Color(0xFFEAE8E6),
    surfaceContainerHighest: const Color(0xFFE7E5E4),
    onSurface: const Color(0xFF1C1917),
    onSurfaceVariant: const Color(0xFF57534E),
    outline: const Color(0xFF78716C),
    outlineVariant: const Color(0xFFE7E5E4),
    error: const Color(0xFFB91C1C),
    onError: const Color(0xFFFFFFFF),
    inverseSurface: const Color(0xFF292524),
    onInverseSurface: const Color(0xFFF5F5F4),
    inversePrimary: const Color(0xFFFDBA74),
    surfaceTint: Colors.transparent,
  ),
  StatusColors.light,
);

ThemeData buildDarkTheme() => _build(
  ColorScheme.fromSeed(
    seedColor: fptOrange,
    brightness: Brightness.dark,
  ).copyWith(
    primary: fptOrange,
    onPrimary: const Color(0xFF1C1917),
    primaryContainer: const Color(0xFF431407),
    onPrimaryContainer: const Color(0xFFFED7AA),
    secondaryContainer: const Color(0xFF431407),
    onSecondaryContainer: const Color(0xFFFED7AA),
    surface: const Color(0xFF0F0E0D),
    surfaceContainerLowest: const Color(0xFF171514),
    surfaceContainerLow: const Color(0xFF1C1917),
    surfaceContainer: const Color(0xFF211E1C),
    surfaceContainerHigh: const Color(0xFF292524),
    surfaceContainerHighest: const Color(0xFF312C29),
    onSurface: const Color(0xFFF5F5F4),
    onSurfaceVariant: const Color(0xFFA8A29E),
    outline: const Color(0xFF78716C),
    outlineVariant: const Color(0xFF292524),
    error: const Color(0xFFF87171),
    onError: const Color(0xFF1C1917),
    inverseSurface: const Color(0xFFE7E5E4),
    onInverseSurface: const Color(0xFF1C1917),
    inversePrimary: _orangeDeep,
    surfaceTint: Colors.transparent,
  ),
  StatusColors.dark,
);

ThemeData _build(ColorScheme scheme, StatusColors status) {
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: scheme.surface,
  );
  // ThemeData.textTheme chưa có cỡ chữ (Theme.of mới ghép geometry vào), nên
  // ghép sẵn ở đây để các component theme bên dưới nhận đúng cỡ.
  final text = base.typography.englishLike.merge(base.textTheme);
  const rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(appRadius)),
  );
  const buttonSize = Size(64, 48);
  final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w600);

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(appRadius)),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    extensions: [status],
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.55),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: fapNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: text.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(appRadius)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: rounded,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: rounded,
        textStyle: buttonText,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: rounded, textStyle: buttonText),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 1,
      shape: rounded,
      extendedTextStyle: buttonText,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder(scheme.outline),
      enabledBorder: inputBorder(scheme.outline),
      disabledBorder: inputBorder(scheme.outlineVariant),
      focusedBorder: inputBorder(scheme.primary, 2),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error, 2),
    ),
    chipTheme: ChipThemeData(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(appRadius)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: scheme.primary,
      textColor: scheme.onPrimary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: rounded,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}

/// Sắc thái trạng thái: tốt (có mặt, đã duyệt, qua môn), chờ, xấu.
enum Tone { good, pending, bad }

/// Màu ngữ nghĩa cho trạng thái (không phải màu nhấn thương hiệu).
/// Mỗi cặp chữ/nền đạt ≥ 6:1 ở cả hai chế độ.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.pending,
    required this.pendingBg,
    required this.approved,
    required this.approvedBg,
    required this.rejected,
    required this.rejectedBg,
  });

  static const light = StatusColors(
    pending: Color(0xFF92400E),
    pendingBg: Color(0xFFFEF3C7),
    approved: Color(0xFF166534),
    approvedBg: Color(0xFFDCFCE7),
    rejected: Color(0xFF991B1B),
    rejectedBg: Color(0xFFFEE2E2),
  );

  static const dark = StatusColors(
    pending: Color(0xFFFCD34D),
    pendingBg: Color(0xFF3A2A0C),
    approved: Color(0xFF86EFAC),
    approvedBg: Color(0xFF12301E),
    rejected: Color(0xFFFCA5A5),
    rejectedBg: Color(0xFF3A1414),
  );

  final Color pending;
  final Color pendingBg;
  final Color approved;
  final Color approvedBg;
  final Color rejected;
  final Color rejectedBg;

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ?? light;

  /// (chữ, nền) cho một sắc thái.
  (Color, Color) forTone(Tone tone) => switch (tone) {
    Tone.pending => (pending, pendingBg),
    Tone.good => (approved, approvedBg),
    Tone.bad => (rejected, rejectedBg),
  };

  @override
  StatusColors copyWith() => this;

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      pending: Color.lerp(pending, other.pending, t)!,
      pendingBg: Color.lerp(pendingBg, other.pendingBg, t)!,
      approved: Color.lerp(approved, other.approved, t)!,
      approvedBg: Color.lerp(approvedBg, other.approvedBg, t)!,
      rejected: Color.lerp(rejected, other.rejected, t)!,
      rejectedBg: Color.lerp(rejectedBg, other.rejectedBg, t)!,
    );
  }
}
