import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';
export 'translations.dart';

class AppLanguage {
  static final code = ValueNotifier<String>('en');
  static SharedPreferences? _preferences;
  static bool get isArabic => code.value == 'ar';
  static Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences!.getString('sanad.language.v1');
    code.value = saved == 'ar' ? 'ar' : 'en';
  }

  static Future<void> select(String value) async {
    if (value != 'ar' && value != 'en') return;
    final ok = await _preferences?.setString('sanad.language.v1', value);
    if (ok == false)
      throw const FormatException(
        'Could not save your language preference. Please retry.',
      );
    code.value = value;
  }

  static void watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<LanguageScope>();
  }
}

class LanguageScope extends InheritedNotifier<ValueNotifier<String>> {
  LanguageScope({super.key, required super.child})
    : super(notifier: AppLanguage.code);
}

String tr(String text) => translateText(text, AppLanguage.code.value);
String? trNullable(String? text) => text == null ? null : tr(text);

/// Keeps canonical strings in state so changing the language updates existing
/// notifications and order statuses as well as newly-created screens.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Text(
      tr(data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: trNullable(semanticsLabel),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

class AuthLanguageButton extends StatelessWidget {
  const AuthLanguageButton({super.key});
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return PopupMenuButton<String>(
      key: const Key('auth-language'),
      tooltip: tr('Language'),
      icon: const Icon(Icons.language),
      initialValue: AppLanguage.code.value,
      onSelected: AppLanguage.select,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'ar', child: Text('العربية')),
      ],
    );
  }
}

class AuthAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AuthAppBar({super.key, this.title});
  final Widget? title;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: AppBar(title: title, actions: const [AuthLanguageButton()]),
  );
}
