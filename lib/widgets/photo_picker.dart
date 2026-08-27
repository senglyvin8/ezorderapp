import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_text.dart';
import '../theme/app_theme.dart';
import 'app_chrome.dart';

/// Roughly 700 KB of base64. Photos are downscaled before this is checked, so
/// hitting the cap means something unusual — better to refuse than to blow the
/// browser's local storage quota.
const int _maxPhotoBytes = 700 * 1024;

/// Outcome of a photo pick.
sealed class PhotoPickResult {
  const PhotoPickResult();
}

class PhotoPicked extends PhotoPickResult {
  const PhotoPicked(this.base64);
  final String base64;
}

class PhotoRejected extends PhotoPickResult {
  const PhotoRejected(this.message);
  final String message;
}

class PhotoCancelled extends PhotoPickResult {
  const PhotoCancelled();
}

/// Picks an image from the gallery/file system or the camera and returns it
/// base64 encoded, downscaled so it fits comfortably in local storage.
Future<PhotoPickResult> pickFoodPhoto(
  ImageSource source,
  AppText t,
) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 78,
    );
    if (file == null) return const PhotoCancelled();

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _maxPhotoBytes) {
      return PhotoRejected(t.photoTooLarge);
    }
    return PhotoPicked(base64Encode(bytes));
  } catch (error) {
    // Surfaced to the admin as a toast; the detail is not useful to them.
    return PhotoRejected(t.photoFailed);
  }
}

/// Upload / camera / remove buttons shown above the illustration picker.
class PhotoSourceButtons extends StatelessWidget {
  const PhotoSourceButtons({
    super.key,
    required this.t,
    required this.hasPhoto,
    required this.onPicked,
    required this.onRemoved,
  });

  final AppText t;
  final bool hasPhoto;
  final ValueChanged<String> onPicked;
  final VoidCallback onRemoved;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final result = await pickFoodPhoto(source, t);
    if (!context.mounted) return;
    switch (result) {
      case PhotoPicked(:final base64):
        onPicked(base64);
      case PhotoRejected(:final message):
        showToast(context, message, error: true);
      case PhotoCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pick(context, ImageSource.gallery),
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: Text(t.uploadPhoto),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
        ),
        OutlinedButton.icon(
          onPressed: () => _pick(context, ImageSource.camera),
          icon: const Icon(Icons.photo_camera_rounded, size: 18),
          label: Text(t.takePhoto),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
        ),
        if (hasPhoto)
          OutlinedButton.icon(
            onPressed: onRemoved,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(t.removePhoto),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              foregroundColor: AppColors.danger,
            ),
          ),
      ],
    );
  }
}
