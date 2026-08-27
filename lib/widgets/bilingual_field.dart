import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// A label with its English and Khmer inputs stacked and tagged, so it is
/// obvious the two boxes are the same field in two languages rather than two
/// unrelated fields.
class BilingualField extends StatelessWidget {
  const BilingualField({
    super.key,
    required this.t,
    required this.label,
    required this.english,
    required this.khmer,
    this.maxLines = 1,
    this.englishValidator,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final AppText t;
  final String label;
  final TextEditingController english;
  final TextEditingController khmer;
  final int maxLines;
  final String? Function(String?)? englishValidator;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        _Row(
          tag: 'EN',
          child: TextFormField(
            controller: english,
            maxLines: maxLines,
            textCapitalization: textCapitalization,
            decoration: appInput(hint: t.english),
            validator: englishValidator,
          ),
        ),
        const SizedBox(height: 8),
        _Row(
          tag: 'ខ្មែរ',
          child: TextFormField(
            controller: khmer,
            maxLines: maxLines,
            decoration: appInput(hint: t.khmer),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.tag, required this.child});

  final String tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 46,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(right: 9),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
