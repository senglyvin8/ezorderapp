"""Generates the bundled placeholder food images used by the prototype.

Flat-vector style illustrations drawn with Pillow, supersampled 4x for smooth
edges. Run with:  python3 tool/generate_food_images.py
"""
import os
from PIL import Image, ImageDraw

S = 4                      # supersample factor
W, H = 800, 600            # final size
CW, CH = W * S, H * S      # canvas size
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "food")


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def canvas(top, bottom):
    img = Image.new("RGB", (CW, CH), top)
    d = ImageDraw.Draw(img)
    for y in range(CH):
        d.line([(0, y), (CW, y)], fill=lerp(top, bottom, y / CH))
    return img


def blob(d, cx, cy, r, color):
    """Soft circular accent used to add depth behind the dish."""
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def bowl(d, cx, cy, rw, body, rim, inner):
    """A bowl seen at a slight angle: rounded body + elliptical rim."""
    d.pieslice([cx - rw, cy - rw * 0.95, cx + rw, cy + rw * 1.55], 0, 180, fill=body)
    d.ellipse([cx - rw, cy - rw * 0.34, cx + rw, cy + rw * 0.34], fill=rim)
    d.ellipse([cx - rw * 0.9, cy - rw * 0.28, cx + rw * 0.9, cy + rw * 0.28], fill=inner)
    # foot of the bowl
    d.rounded_rectangle(
        [cx - rw * 0.34, cy + rw * 1.42, cx + rw * 0.34, cy + rw * 1.72],
        radius=rw * 0.1, fill=body)


def rice_mound(d, cx, cy, rw, color, shade):
    d.ellipse([cx - rw * 0.78, cy - rw * 0.52, cx + rw * 0.78, cy + rw * 0.22], fill=color)
    d.ellipse([cx - rw * 0.5, cy - rw * 0.62, cx + rw * 0.34, cy - rw * 0.1], fill=shade)


def garnish(d, cx, cy, rw, colors):
    spots = [(-0.5, -0.3, 0.12), (0.2, -0.42, 0.1), (0.46, -0.14, 0.13),
             (-0.16, -0.5, 0.09), (-0.34, -0.02, 0.1), (0.02, -0.1, 0.11)]
    for i, (dx, dy, rr) in enumerate(spots):
        c = colors[i % len(colors)]
        d.ellipse([cx + rw * dx - rw * rr, cy + rw * dy - rw * rr,
                   cx + rw * dx + rw * rr, cy + rw * dy + rw * rr], fill=c)


def noodles(d, cx, cy, rw, color, shade):
    d.ellipse([cx - rw * 0.8, cy - rw * 0.5, cx + rw * 0.8, cy + rw * 0.2], fill=color)
    for i in range(5):
        y = cy - rw * (0.34 - i * 0.13)
        d.arc([cx - rw * (0.66 - i * 0.05), y - rw * 0.2,
               cx + rw * (0.66 - i * 0.05), y + rw * 0.2], 200, 340,
              fill=shade, width=int(rw * 0.06))


def chopsticks(d, cx, cy, rw, color):
    for off in (-0.07, 0.07):
        d.line([(cx + rw * (0.15 + off * 3), cy - rw * 1.25),
                (cx + rw * (0.62 + off), cy + rw * 0.1)],
               fill=color, width=int(rw * 0.075))


def glass(d, cx, cy, rw, liquid, rim, straw, ice=True):
    top_w, bot_w, h = rw, rw * 0.72, rw * 2.0
    d.polygon([(cx - top_w, cy - h * 0.5), (cx + top_w, cy - h * 0.5),
               (cx + bot_w, cy + h * 0.5), (cx - bot_w, cy + h * 0.5)], fill=(255, 255, 255))
    lt = cy - h * 0.5 + h * 0.22
    ratio = (h * 0.5 - (lt - cy)) / h
    lw = bot_w + (top_w - bot_w) * (1 - ratio) * 0 + (top_w - bot_w) * ((h * 0.5 - (lt - cy)) / h)
    lw = bot_w + (top_w - bot_w) * ((cy + h * 0.5 - lt) / h)
    d.polygon([(cx - lw, lt), (cx + lw, lt),
               (cx + bot_w, cy + h * 0.5), (cx - bot_w, cy + h * 0.5)], fill=liquid)
    if ice:
        for dx, dy, sz in ((-0.36, 0.12, 0.2), (0.18, 0.3, 0.17), (-0.05, 0.56, 0.15)):
            d.rounded_rectangle([cx + rw * dx - rw * sz, cy + rw * dy - rw * sz,
                                 cx + rw * dx + rw * sz, cy + rw * dy + rw * sz],
                                radius=rw * 0.05, fill=(255, 255, 255, 255))
    d.line([(cx + rw * 0.28, cy - h * 0.78), (cx - rw * 0.1, cy + h * 0.3)],
           fill=straw, width=int(rw * 0.11))
    d.ellipse([cx - top_w, cy - h * 0.5 - top_w * 0.26,
               cx + top_w, cy - h * 0.5 + top_w * 0.26], fill=rim)
    d.ellipse([cx - top_w * 0.86, cy - h * 0.5 - top_w * 0.2,
               cx + top_w * 0.86, cy - h * 0.5 + top_w * 0.2], fill=liquid)


def can(d, cx, cy, rw, body, band, label):
    h = rw * 2.1
    d.rounded_rectangle([cx - rw * 0.62, cy - h * 0.5, cx + rw * 0.62, cy + h * 0.5],
                        radius=rw * 0.2, fill=body)
    d.rounded_rectangle([cx - rw * 0.62, cy - h * 0.08, cx + rw * 0.62, cy + h * 0.14],
                        radius=rw * 0.04, fill=band)
    d.ellipse([cx - rw * 0.62, cy - h * 0.5 - rw * 0.16,
               cx + rw * 0.62, cy - h * 0.5 + rw * 0.16], fill=label)


def plate(d, cx, cy, rw, rim, inner):
    d.ellipse([cx - rw, cy - rw * 0.42, cx + rw, cy + rw * 0.42], fill=rim)
    d.ellipse([cx - rw * 0.8, cy - rw * 0.33, cx + rw * 0.8, cy + rw * 0.33], fill=inner)


def finish(img, name):
    img.resize((W, H), Image.LANCZOS).save(os.path.join(OUT, name + ".png"), optimize=True)
    print("wrote", name + ".png")


def draw_rice(name, bg, body, mound, spots):
    img = canvas(*bg)
    d = ImageDraw.Draw(img)
    cx, cy, rw = CW // 2, int(CH * 0.44), int(CW * 0.21)
    blob(d, cx, cy - rw * 0.3, rw * 1.5, lerp(bg[0], (255, 255, 255), 0.45))
    bowl(d, cx, cy, rw, body[0], body[1], body[2])
    rice_mound(d, cx, cy, rw, mound[0], mound[1])
    garnish(d, cx, cy, rw, spots)
    finish(img, name)


def draw_noodles(name, bg, body, broth, strands, spots):
    img = canvas(*bg)
    d = ImageDraw.Draw(img)
    cx, cy, rw = CW // 2, int(CH * 0.44), int(CW * 0.21)
    blob(d, cx, cy - rw * 0.3, rw * 1.5, lerp(bg[0], (255, 255, 255), 0.45))
    chopsticks(d, cx, cy, rw, (150, 106, 66))
    bowl(d, cx, cy, rw, body[0], body[1], broth)
    noodles(d, cx, cy, rw, strands[0], strands[1])
    garnish(d, cx, cy, rw, spots)
    finish(img, name)


def draw_drink(name, bg, liquid, rim, straw, ice=True):
    img = canvas(*bg)
    d = ImageDraw.Draw(img)
    cx, cy, rw = CW // 2, int(CH * 0.5), int(CW * 0.16)
    blob(d, cx, cy, rw * 2.1, lerp(bg[0], (255, 255, 255), 0.45))
    glass(d, cx, cy, rw, liquid, rim, straw, ice)
    finish(img, name)


def draw_can(name, bg, body, band, label):
    img = canvas(*bg)
    d = ImageDraw.Draw(img)
    cx, cy, rw = CW // 2, int(CH * 0.5), int(CW * 0.17)
    blob(d, cx, cy, rw * 2.0, lerp(bg[0], (255, 255, 255), 0.45))
    can(d, cx, cy, rw, body, band, label)
    finish(img, name)


def draw_dessert(name, bg):
    img = canvas(*bg)
    d = ImageDraw.Draw(img)
    cx, cy, rw = CW // 2, int(CH * 0.54), int(CW * 0.24)
    blob(d, cx, cy - rw * 0.2, rw * 1.4, lerp(bg[0], (255, 255, 255), 0.45))
    plate(d, cx, cy, rw, (236, 240, 246), (252, 253, 255))
    d.rounded_rectangle([cx - rw * 0.62, cy - rw * 0.42, cx - rw * 0.04, cy + rw * 0.12],
                        radius=rw * 0.09, fill=(255, 252, 240))
    d.rounded_rectangle([cx - rw * 0.62, cy - rw * 0.42, cx - rw * 0.04, cy - rw * 0.24],
                        radius=rw * 0.09, fill=(255, 255, 255))
    for i, dx in enumerate((0.08, 0.32, 0.56)):
        d.rounded_rectangle([cx + rw * dx, cy - rw * (0.36 - i * 0.03),
                             cx + rw * (dx + 0.2), cy + rw * 0.1],
                            radius=rw * 0.08, fill=(250, 186, 60))
        d.rounded_rectangle([cx + rw * dx, cy - rw * (0.36 - i * 0.03),
                             cx + rw * (dx + 0.2), cy - rw * (0.22 - i * 0.03)],
                            radius=rw * 0.06, fill=(253, 208, 108))
    for dx, dy in ((-0.5, -0.5), (-0.2, -0.58), (0.3, -0.52)):
        d.ellipse([cx + rw * dx - rw * 0.045, cy + rw * dy - rw * 0.045,
                   cx + rw * dx + rw * 0.045, cy + rw * dy + rw * 0.045], fill=(120, 200, 120))
    finish(img, name)


def draw_placeholder(name):
    img = canvas((243, 244, 246), (226, 229, 235))
    d = ImageDraw.Draw(img)
    cx, cy, rw = CW // 2, int(CH * 0.52), int(CW * 0.2)
    plate(d, cx, cy, rw * 1.25, (214, 218, 226), (236, 239, 244))
    d.ellipse([cx - rw * 0.5, cy - rw * 0.34, cx + rw * 0.5, cy + rw * 0.16], fill=(200, 205, 214))
    for off, tilt in ((-1.55, 0), (1.55, 0)):
        d.rounded_rectangle([cx + rw * off - rw * 0.05, cy - rw * 0.6,
                             cx + rw * off + rw * 0.05, cy + rw * 0.5],
                            radius=rw * 0.05, fill=(205, 210, 219))
    finish(img, name)


os.makedirs(OUT, exist_ok=True)

draw_rice("chicken_fried_rice", ((255, 243, 224), (255, 224, 178)),
          ((214, 122, 66), (240, 158, 96), (255, 234, 205)),
          ((252, 220, 150), (255, 236, 190)),
          [(226, 138, 70), (126, 184, 90), (240, 190, 96)])
draw_rice("beef_fried_rice", ((255, 236, 227), (255, 213, 196)),
          ((150, 90, 62), (188, 124, 86), (250, 231, 214)),
          ((246, 214, 152), (253, 233, 190)),
          [(140, 78, 62), (126, 184, 90), (200, 108, 74)])
draw_rice("pork_rice", ((255, 241, 240), (255, 219, 214)),
          ((196, 96, 96), (226, 130, 128), (255, 235, 231)),
          ((255, 250, 240), (255, 255, 252)),
          [(226, 126, 118), (126, 184, 90), (246, 178, 120)])
draw_noodles("beef_noodles", ((255, 240, 226), (252, 214, 182)),
             ((176, 92, 62), (210, 124, 88)), (188, 122, 74),
             ((246, 206, 128), (226, 178, 96)),
             [(140, 78, 62), (110, 176, 84), (226, 130, 76)])
draw_noodles("chicken_noodles", ((255, 248, 226), (252, 230, 176)),
             ((214, 152, 60), (238, 182, 92)), (238, 196, 110),
             ((252, 226, 156), (232, 196, 116)),
             [(238, 214, 150), (110, 176, 84), (226, 152, 76)])
draw_drink("iced_latte", ((246, 238, 230), (226, 208, 190)),
           (146, 100, 66), (222, 198, 172), (232, 108, 96))
draw_can("coca_cola", ((255, 233, 233), (250, 200, 200)),
         (206, 60, 58), (245, 245, 245), (216, 220, 226))
draw_drink("iced_tea", ((255, 246, 226), (250, 224, 168)),
           (196, 132, 48), (236, 210, 160), (110, 176, 120))
draw_dessert("mango_sticky_rice", ((255, 249, 226), (253, 232, 176)))
draw_placeholder("placeholder")
