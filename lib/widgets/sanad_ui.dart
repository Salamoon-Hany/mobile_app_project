import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_language.dart';

/// Visual tokens adapted from Services App / Final UI.
class SanadUi {
  static const lime = Color(0xFFCCFD04);
  static const ink = Color(0xFF282828);
  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color canvas(BuildContext c) =>
      dark(c) ? const Color(0xFF171A1E) : const Color(0xFFF3F5FD);
  static Color surface(BuildContext c) =>
      dark(c) ? const Color(0xFF24282E) : Colors.white;
  static Color text(BuildContext c) => dark(c) ? const Color(0xFFF4F5F7) : ink;
  static Color muted(BuildContext c) =>
      dark(c) ? const Color(0xFFB5BAC4) : const Color(0xFF838383);
}

class ReferenceIcon extends StatelessWidget {
  const ReferenceIcon(
    this.name, {
    super.key,
    this.color,
    this.muted = false,
    this.mirror = false,
  });
  final String name;
  final Color? color;
  final bool muted, mirror;
  static const sizes = {
    'home': Size(17.0347, 18.7382),
    'orders': Size(19.3038, 19.304),
    'orders-active': Size(19.3038, 19.304),
    'bell': Size(24, 24),
    'search': Size(24, 24),
    'time': Size(15.0865, 15.0865),
    'next': Size(24, 24),
    'back': Size(24, 24),
  };
  @override
  Widget build(BuildContext context) {
    final size = sizes[name]!;
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Transform.flip(
          flipX: mirror && AppLanguage.isArabic,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: SvgPicture.asset(
              'assets/figma/' + name + '.svg',
              colorFilter: ColorFilter.mode(
                color ??
                    (muted ? SanadUi.muted(context) : SanadUi.text(context)),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SanadStatus extends StatelessWidget {
  const SanadStatus(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => const Color(0xFFFF8800),
      'accepted' || 'confirmed' => const Color(0xFF0F9918),
      'completed' || 'assigned' => const Color(0xFF2F80ED),
      'rejected' || 'cancelled' => const Color(0xFFD92D20),
      _ => SanadUi.muted(context),
    };
    final label = status.isEmpty
        ? 'Unknown'
        : status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(30),
      ),
      child: AppText(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class SanadTabs extends StatelessWidget {
  const SanadTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SanadUi.surface(context),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 8,
                    ),
                    child: AppText(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: i == selected
                            ? SanadUi.text(context)
                            : SanadUi.muted(context),
                        fontWeight: i == selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: i == selected
                        ? SanadUi.text(context)
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

ThemeData sanadTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: SanadUi.lime,
        brightness: brightness,
      ).copyWith(
        primary: dark ? SanadUi.lime : SanadUi.ink,
        onPrimary: dark ? SanadUi.ink : Colors.white,
        surface: dark ? const Color(0xFF24282E) : Colors.white,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF171A1E)
        : const Color(0xFFF3F5FD),
    cardColor: colors.surface,
    textTheme: ThemeData(
      brightness: brightness,
    ).textTheme.apply(decoration: TextDecoration.none),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: dark ? const Color(0xFF383D45) : const Color(0xFFE4E7EF),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0xFF383D45) : const Color(0xFFE4E7EF),
      thickness: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: colors.onSurface,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.surface,
      selectedItemColor: colors.onSurface,
      unselectedItemColor: dark
          ? const Color(0xFFADB3BE)
          : const Color(0xFFADADAD),
      elevation: 0,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF20AD54)
            : null,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : null,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class SanadPanel extends StatelessWidget {
  const SanadPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? SanadUi.surface(context),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: SanadUi.dark(context)
            ? const Color(0xFF383D45)
            : const Color(0xFFE4E7EF),
      ),
    ),
    child: Padding(padding: padding, child: child),
  );
}
