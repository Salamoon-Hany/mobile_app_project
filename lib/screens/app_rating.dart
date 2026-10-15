import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../services/marketplace_service.dart';

Future<bool?> showAppRating(BuildContext context) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => AppRatingSheet(
    initialRating: Marketplace.shared.rating?['stars'] as int?,
    initialComment: Marketplace.shared.rating?['comment'] as String? ?? '',
  ),
);

class AppRatingSheet extends StatefulWidget {
  const AppRatingSheet({
    super.key,
    this.initialRating,
    this.onSubmit,
    this.initialComment = '',
    this.onFeedback,
  });
  final int? initialRating;
  final String initialComment;
  final Future<void> Function(int, String)? onFeedback;
  final Future<void> Function(int)? onSubmit;
  @override
  State<AppRatingSheet> createState() => _AppRatingSheetState();
}

class _AppRatingSheetState extends State<AppRatingSheet> {
  late int _stars;
  late final TextEditingController _comment;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _comment = TextEditingController(text: widget.initialComment);
    final value = widget.initialRating ?? 0;
    _stars = value >= 1 && value <= 5 ? value : 0;
  }

  Future<void> _submit() async {
    if (_stars < 1 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.onFeedback != null) {
        await widget.onFeedback!(_stars, _comment.text.trim());
      } else if (widget.onSubmit != null) {
        await widget.onSubmit!(_stars);
      } else {
        await Marketplace.shared.rateApp(_stars, comment: _comment.text.trim());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Could not save your rating. Please retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Material(
      child: PopScope(
        canPop: !_busy,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 52,
                        color: Color(0xFFf4b400),
                      ),
                      const SizedBox(height: 14),
                      const AppText(
                        'Rate the app',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const AppText(
                        'How was your experience with Sanad?',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Semantics(
                              selected: i == _stars,
                              child: IconButton(
                                key: Key('app-rating-$i'),
                                tooltip: tr(i == 1 ? '1 star' : '$i stars'),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _stars = i),
                                icon: Icon(
                                  i <= _stars
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: const Color(0xFFf4b400),
                                  size: 34,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_stars > 0)
                        AppText(
                          '${tr('Your rating')}: $_stars/5',
                          textAlign: TextAlign.center,
                        ),
                      TextField(
                        key: const Key('app-rating-comment'),
                        controller: _comment,
                        enabled: !_busy,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: tr('Your feedback (optional)'),
                          hintText: tr(
                            'Tell us about your experience or how we can improve.',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: AppText(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),
                      FilledButton(
                        key: const Key('app-rating-submit'),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFd7ff00)
                              : const Color(0xFF252525),
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _busy || _stars == 0 ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const AppText('Submit rating'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const AppText('Not now'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
