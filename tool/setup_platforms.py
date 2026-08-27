"""Adds the camera entitlements mobile_scanner needs.

`flutter create .` regenerates the native shells from Flutter's own templates,
which do not know about the QR scanner. Run this once afterwards:

    python3 tool/setup_platforms.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

IOS_PLIST = os.path.join(ROOT, 'ios', 'Runner', 'Info.plist')
ANDROID_MANIFEST = os.path.join(
    ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')

CAMERA_USAGE = (
    '\t<key>NSCameraUsageDescription</key>\n'
    '\t<string>The camera is used to scan table QR codes and to photograph '
    'dishes for the menu.</string>\n'
    '\t<key>NSPhotoLibraryUsageDescription</key>\n'
    '\t<string>Photos are used to illustrate dishes on the menu.</string>\n'
)
CAMERA_PERMISSION = (
    '    <uses-permission android:name="android.permission.CAMERA"/>\n'
)


def patch_ios():
    if not os.path.exists(IOS_PLIST):
        return 'skipped (no ios/ folder — run `flutter create .` first)'
    body = open(IOS_PLIST, encoding='utf-8').read()
    if 'NSCameraUsageDescription' in body:
        return 'already set'
    index = body.rfind('</dict>')
    if index < 0:
        return 'could not find </dict>'
    body = body[:index] + CAMERA_USAGE + body[index:]
    open(IOS_PLIST, 'w', encoding='utf-8').write(body)
    return 'added camera + photo library usage descriptions'


def patch_android():
    if not os.path.exists(ANDROID_MANIFEST):
        return 'skipped (no android/ folder — run `flutter create .` first)'
    body = open(ANDROID_MANIFEST, encoding='utf-8').read()
    if 'android.permission.CAMERA' in body:
        return 'already set'
    match = re.search(r'<manifest[^>]*>\n', body)
    if not match:
        return 'could not find <manifest>'
    body = body[:match.end()] + CAMERA_PERMISSION + body[match.end():]
    open(ANDROID_MANIFEST, 'w', encoding='utf-8').write(body)
    return 'added CAMERA permission'


print('ios     :', patch_ios())
print('android :', patch_android())
sys.exit(0)
