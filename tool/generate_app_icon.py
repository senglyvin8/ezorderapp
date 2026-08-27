"""Draws the iOS app icon from the restaurant's logo.

The logo and the brand colours live in `lib/config/app_config.dart`; this
script reads them from there rather than keeping a second copy, so changing
`Brand.logo` or `Palette.accent` and re-running is all it takes to rebrand the
home-screen icon:

    python3 tool/generate_app_icon.py

It rewrites every PNG in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
Rebuild the app afterwards for the new icon to reach the device.

The logo is normally an emoji, drawn with Apple Color Emoji. That font only
ships one bitmap strike, at 160px, so every size is rendered there and scaled
down with a good filter — sharper than asking the rasteriser for a size it
does not have. Initials or any other short text fall back to a plain bold
face, drawn in white.
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, 'lib', 'config', 'app_config.dart')
ICONSET = os.path.join(
    ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')

EMOJI_FONT = '/System/Library/Fonts/Apple Color Emoji.ttc'
EMOJI_STRIKE = 160  # the only bitmap size Apple Color Emoji provides
TEXT_FONT_CANDIDATES = [
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
]

# How much of the icon's width the logo fills. iOS rounds the corners itself,
# so leaving margin keeps the mark clear of the mask.
LOGO_SCALE = 0.62

# Rendered at 4x the largest icon, then scaled down, so the gradient is smooth
# and the emoji edges stay clean.
CANVAS = 1024


def read_config_string(name):
    """Pulls `static const String <name> = '...';` out of app_config.dart."""
    src = open(CONFIG, encoding='utf-8').read()
    m = re.search(
        r"static const String %s\s*=\s*r?['\"](.*?)['\"]\s*;" % name, src)
    if not m:
        sys.exit('could not find Brand.%s in %s' % (name, CONFIG))
    return m.group(1)


def read_config_color(name):
    """Pulls `static const Color <name> = Color(0xAARRGGBB);` as an RGB tuple."""
    src = open(CONFIG, encoding='utf-8').read()
    m = re.search(
        r"static const Color %s\s*=\s*Color\(0x([0-9A-Fa-f]{8})\)" % name, src)
    if not m:
        sys.exit('could not find Palette.%s in %s' % (name, CONFIG))
    v = int(m.group(1), 16)
    return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)


def background(size, top, bottom):
    """A soft vertical gradient — flat colour reads dead at icon scale."""
    img = Image.new('RGB', (size, size), top)
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(size - 1, 1)
        draw.line(
            [(0, y), (size, y)],
            fill=tuple(round(top[i] + (bottom[i] - top[i]) * t)
                       for i in range(3)),
        )
    return img


def render_logo(logo, target_px):
    """The logo as an RGBA layer `target_px` wide, transparent elsewhere."""
    try:
        font = ImageFont.truetype(EMOJI_FONT, EMOJI_STRIKE)
        layer = Image.new('RGBA', (EMOJI_STRIKE * 2, EMOJI_STRIKE * 2),
                          (0, 0, 0, 0))
        ImageDraw.Draw(layer).text(
            (EMOJI_STRIKE, EMOJI_STRIKE), logo, font=font,
            anchor='mm', embedded_color=True)
        if layer.getbbox():
            layer = layer.crop(layer.getbbox())
            scale = target_px / max(layer.size)
            return layer.resize(
                (max(1, round(layer.width * scale)),
                 max(1, round(layer.height * scale))),
                Image.LANCZOS)
    except (OSError, ValueError):
        pass

    # Not an emoji (or the emoji font refused it): draw it as white text.
    for path in TEXT_FONT_CANDIDATES:
        if os.path.exists(path):
            font = ImageFont.truetype(path, round(target_px * 0.8))
            break
    else:
        font = ImageFont.load_default()
    layer = Image.new('RGBA', (target_px * 2, target_px * 2), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(
        (target_px, target_px), logo, font=font, anchor='mm',
        fill=(255, 255, 255, 255))
    box = layer.getbbox()
    return layer.crop(box) if box else layer


def main():
    logo = read_config_string('logo')
    accent = read_config_color('accent')
    accent_dark = read_config_color('accentDark')

    master = background(CANVAS, accent, accent_dark)
    mark = render_logo(logo, round(CANVAS * LOGO_SCALE))
    master.paste(
        mark,
        ((CANVAS - mark.width) // 2, (CANVAS - mark.height) // 2),
        mark,
    )

    contents = json.load(open(os.path.join(ICONSET, 'Contents.json')))
    written = {}
    for image in contents['images']:
        name = image.get('filename')
        if not name:
            continue
        side = float(image['size'].split('x')[0])
        px = round(side * float(image['scale'].rstrip('x')))
        if name not in written:
            # RGB, not RGBA — the App Store rejects icons with an alpha channel.
            master.resize((px, px), Image.LANCZOS).save(
                os.path.join(ICONSET, name), format='PNG')
            written[name] = px

    for name in sorted(written):
        print('%-32s %dpx' % (name, written[name]))
    print('\n%d icons written from Brand.logo %r' % (len(written), logo))


if __name__ == '__main__':
    main()
