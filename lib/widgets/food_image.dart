import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/menu_item.dart';
import '../theme/app_theme.dart';

/// Renders a dish picture: the photo the admin uploaded if there is one,
/// otherwise the bundled illustration, otherwise a neutral plate.
class FoodImage extends StatelessWidget {
  const FoodImage(this.imageKey, {super.key, this.photo, this.fit = BoxFit.cover});

  /// Convenience constructor for the common case of drawing a [MenuItem].
  FoodImage.forItem(MenuItem item, {super.key, this.fit = BoxFit.cover})
      : imageKey = item.image,
        photo = item.photo;

  final String imageKey;

  /// Base64 encoded photo bytes.
  final String? photo;
  final BoxFit fit;

  static final Map<String, Uint8List> _decoded = {};

  Uint8List? get _bytes {
    final raw = photo;
    if (raw == null || raw.isEmpty) return null;
    final cached = _decoded[raw];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(raw);
      _decoded[raw] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, _, __) => _asset(),
      );
    }
    return _asset();
  }

  Widget _asset() => Image.asset(
        'assets/food/$imageKey.png',
        fit: fit,
        errorBuilder: (context, _, __) => Image.asset(
          'assets/food/placeholder.png',
          fit: fit,
          errorBuilder: (context, _, __) => const ColoredBox(
            color: AppColors.surface,
            child: Center(
              child: Icon(Icons.restaurant, color: AppColors.inkFaint),
            ),
          ),
        ),
      );
}
