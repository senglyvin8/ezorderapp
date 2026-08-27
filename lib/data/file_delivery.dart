import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a generated file to the person who asked for it.
///
/// What that means depends on where the app is running, and neither platform
/// has a notion of "save to disk" the other shares:
///
///  * On a phone it is the share sheet — Files, Mail, AirDrop, whatever they
///    have. There is no user-visible filesystem to save into.
///  * On the web the browser downloads it.
///
/// `share_plus` covers both, so the calling screen does not have to care.
abstract class FileDelivery {
  /// Returns false if the person dismissed the share sheet, so the caller can
  /// stay quiet rather than claiming success.
  static Future<bool> send({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? subject,
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
        subject: subject,
        // iPadOS presents the share sheet as a popover and needs somewhere to
        // point it. Given nothing it can decline to appear at all, so the
        // caller passes the rect of whatever was tapped.
        sharePositionOrigin: origin,
        fileNameOverrides: [filename],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  /// The rect of the widget behind [context], in global coordinates — what
  /// iPadOS wants to anchor the popover to.
  static Rect? originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
