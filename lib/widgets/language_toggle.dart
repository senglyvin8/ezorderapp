import 'package:flutter/material.dart';

import '../l10n/app_text.dart';

/// The language mark: a black disc, so it reads as its own thing rather than
/// another pill in whatever row it sits in.
const Color _mark = Color(0xFF000000);
const Color _markEdge = Color(0xFF2C3342);

/// Handle for the language mark, so tests reach it by identity rather than by
/// whichever glyph the design happens to use.
const Key languageToggleKey = Key('session-bar-language');

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.language,
    required this.onTap,
  });

  final AppLanguage language;
  final VoidCallback onTap;

  /// Diameter of the mark. With the bar's padding around it this clears the
  /// 44pt minimum tap target.
  static const double _size = 38;

  @override
  Widget build(BuildContext context) {
    // A black disc carrying the language's own two characters. It reads as a
    // mark rather than one more pill in the row, and it says which language
    // you are in as well as offering the switch — a bare globe would only do
    // the second.
    return Semantics(
      button: true,
      label: '${language.label} — tap to switch',
      child: Tooltip(
        message: language.label,
        child: Material(
          color: _mark,
          shape: const CircleBorder(
            side: BorderSide(color: _markEdge),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _size,
              height: _size,
              child: Center(
                child: Text(
                  language.short,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  // Khmer is one letter against English's two, and its glyph
                  // carries more detail — it needs the larger size to weigh
                  // the same inside the disc.
                  style: TextStyle(
                    fontSize: language == AppLanguage.km ? 18 : 13.5,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
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
