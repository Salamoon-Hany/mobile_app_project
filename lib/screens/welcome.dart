import '../l10n/app_language.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/verification_service.dart';
import 'auth_gate.dart';

const sanadLime = Color(0xFFD7FF00);
const sanadInk = Color(0xFF171917);

class SanadBrand extends StatelessWidget {
  const SanadBrand({super.key, this.height = 110});
  final double height;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'Pics & Icons/Logo.png',
        height: height,
        width: height * 2.2,
        fit: BoxFit.contain,
        semanticLabel: 'سند — SANAD',
      ),
      const SizedBox(height: 12),
      AppText(
        'ساندينك في كل حاجة',
        textDirection: AppLanguage.isArabic
            ? TextDirection.rtl
            : TextDirection.ltr,
        style: TextStyle(color: sanadInk, fontSize: 17),
      ),
    ],
  );
}

class LogoScreen extends StatelessWidget {
  const LogoScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFFF7F8F0),
    body: Center(child: SanadBrand(height: 150)),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  Timer? _timer;
  bool _started = false;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
    _timer = Timer(Duration(milliseconds: reduceMotion ? 150 : 2700), () {
      if (!mounted) return;
      final returning = VerificationService().currentUser != null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => returning ? const AuthGate() : const WelcomeScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8F0),
    body: SafeArea(
      child: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: .92, end: 1).animate(
              CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
            ),
            child: const SanadBrand(height: 150),
          ),
        ),
      ),
    ),
  );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onComplete});
  final VoidCallback? onComplete;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _completed = false;
  static const _steps = [
    (
      icon: Icons.home_repair_service_rounded,
      title: 'كل خدمات بيتك،\nفي مكان واحد',
      body:
          'كهربائي، سبّاك، نجّار وخدمات تانية. اختار الخدمة اللي محتاجها وابدأ طلبك بسهولة.',
    ),
    (
      icon: Icons.location_on_rounded,
      title: 'حدّد مكانك،\nوسيب الباقي علينا',
      body:
          'استخدم Locate me أو ابحث عن منطقتك، وبعدها ضيف عنوانك وتفاصيل الشغل.',
    ),
    (
      icon: Icons.task_alt_rounded,
      title: 'احجز خدمتك،\nوتابع طلبك',
      body:
          'سجّل حسابك، أكّد إيميلك، واختار الخدمة المناسبة. تفاصيل طلبك تفضل معاك خطوة بخطوة.',
    ),
  ];
  void _complete() {
    if (_completed) return;
    _completed = true;
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: AppLanguage.isArabic ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8F0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText(
                        'سند',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: sanadInk,
                        ),
                      ),
                      TextButton(
                        onPressed: _complete,
                        child: const AppText('تخطي'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _steps.length,
                      onPageChanged: (value) => setState(() => _page = value),
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 36),
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: sanadLime,
                                  borderRadius: BorderRadius.circular(48),
                                ),
                                child: Icon(
                                  step.icon,
                                  size: 94,
                                  color: sanadInk,
                                  semanticLabel: step.title.replaceAll(
                                    '\n',
                                    ' ',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),
                              AppText(
                                step.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 30,
                                  height: 1.4,
                                  fontWeight: FontWeight.w800,
                                  color: sanadInk,
                                ),
                              ),
                              const SizedBox(height: 18),
                              AppText(
                                step.body,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  height: 1.8,
                                  color: Color(0xFF596055),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => Semantics(
                        label: tr('خطوة ${index + 1} من ${_steps.length}'),
                        selected: index == _page,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          width: index == _page ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == _page
                                ? sanadInk
                                : const Color(0xFFCDD2C1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: sanadLime,
                        foregroundColor: sanadInk,
                        minimumSize: const Size.fromHeight(58),
                      ),
                      onPressed: () {
                        if (_page == _steps.length - 1) {
                          _complete();
                        } else {
                          _pages.nextPage(
                            duration: Duration(
                              milliseconds:
                                  MediaQuery.disableAnimationsOf(context)
                                  ? 0
                                  : 280,
                            ),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      child: AppText(
                        _page == _steps.length - 1 ? 'يلا نبدأ' : 'التالي',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AppText(
                    'ساندينك في كل حاجة',
                    style: TextStyle(color: Color(0xFF596055)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
