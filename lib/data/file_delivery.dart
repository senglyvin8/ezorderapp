import 'dart:typed_data';

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
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
        subject: subject,
        // iOS needs somewhere to anchor the sheet on iPad; without it the
        // share sheet can refuse to appear at all.
        sharePositionOrigin: null,
        fileNameOverrides: [filename],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}
