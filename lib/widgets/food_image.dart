import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/menu_item.dart';
import '../theme/app_theme.dart';

/// Renders a dish picture, in order of preference: the photo in Storage, a
/// photo held on the device, the bundled illustration, a neutral plate.
///
/// The URL comes first because that is where photos live on a real backend —
/// served from a CDN and cached by the browser, rather than carried inside the
/// menu JSON on every single load.
class FoodImage extends StatelessWidget {
  const FoodImage(
    this.imageKey, {
    super.key,
    this.photo,
    this.photoUrl,
    this.fit = BoxFit.cover,
  });

  /// Convenience constructor for the common case of drawing a [MenuItem].
  FoodImage.forItem(MenuItem item, {super.key, this.fit = BoxFit.cover})
      : imageKey = item.image,
        photo = item.photo,
        photoUrl = item.photoUrl;

  final String imageKey;

  /// Base64 encoded photo bytes — the on-device demo only.
  final String? photo;

  /// Public URL of the photo in Storage.
  final String? photoUrl;
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
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: fit,
        gaplessPlayback: true,
        // A dish that has not loaded yet should look like a dish, not like a
        // hole in the menu.
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _asset(),
        errorBuilder: (context, _, __) => _asset(),
      );
    }
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
