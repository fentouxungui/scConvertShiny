#!/usr/bin/env python3
"""Generate icon candidates for scConvertShiny from the graphical abstract.

Usage:
    pip install pillow
    python icons/make_icons.py

Outputs (into icons/generated/):
    <candidate>.png            1024x1024 master
    <candidate>_<size>.png     16 / 32 / 48 / 64 / 128 / 256 / 512 PNGs
    <candidate>.ico            multi-size Windows icon (16..256)
    icon_mac_<candidate>.png   1024x1024 for macOS (.icns feed)
    preview.png                contact sheet of all candidates

Pick a candidate, then copy it for the desktop build:
    Windows : icons/generated/<candidate>.ico   -> icons/ico/<candidate>.ico
    macOS   : icons/generated/icon_mac_<candidate>.png -> icons/mac/<candidate>.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "graphical_abstract.png")
OUT = os.path.join(HERE, "generated")
os.makedirs(OUT, exist_ok=True)

MASTER = 1024
PNG_SIZES = [16, 32, 48, 64, 128, 256, 512]
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]

src = Image.open(SRC).convert("RGBA")
W, H = src.size
print(f"source: {SRC}  {W}x{H}")


def square_pad(img, size, bg=(255, 255, 255, 0)):
    """Fit the whole image inside a square canvas (letterbox)."""
    r = min(size / img.width, size / img.height)
    nw, nh = max(1, round(img.width * r)), max(1, round(img.height * r))
    res = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), bg)
    canvas.alpha_composite(res, ((size - nw) // 2, (size - nh) // 2))
    return canvas


def square_crop(img, size, frac=1.0, cx=0.5, cy=0.5):
    """Crop a centered square (cover) and resize."""
    side = max(1, int(min(img.width, img.height) * frac))
    x = int(img.width * cx)
    y = int(img.height * cy)
    left = max(0, min(x - side // 2, img.width - side))
    top = max(0, min(y - side // 2, img.height - side))
    return img.crop((left, top, left + side, top + side)).resize(
        (size, size), Image.LANCZOS
    )


def rounded(img, radius_frac=0.18):
    size = img.width
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_frac), fill=255
    )
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def circle(img):
    size = img.width
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def on_bg(img, color):
    c = Image.new("RGBA", img.size, color)
    c.alpha_composite(img)
    return c


WHITE = (255, 255, 255, 255)
DARK = (17, 24, 39, 255)
BLUE = (37, 99, 235, 255)

# ---- candidate definitions -------------------------------------------
candidates = {
    "01_contain_transparent": square_pad(src, MASTER, (0, 0, 0, 0)),
    "02_contain_white": square_pad(src, MASTER, WHITE),
    "03_contain_dark": square_pad(src, MASTER, DARK),
    "04_cover_center": square_crop(src, MASTER, 1.0, 0.50, 0.50),
    "05_cover_left": square_crop(src, MASTER, 1.0, 0.25, 0.50),
    "06_cover_right": square_crop(src, MASTER, 1.0, 0.75, 0.50),
    "07_zoom_center": square_crop(src, MASTER, 0.65, 0.50, 0.50),
    "08_zoom_left": square_crop(src, MASTER, 0.65, 0.25, 0.50),
    "09_zoom_right": square_crop(src, MASTER, 0.65, 0.75, 0.50),
}
# rounded / circular masks on the two most useful bases
candidates["10_rounded_cover_center"] = rounded(
    on_bg(square_crop(src, MASTER, 1.0), WHITE)
)
candidates["11_circle_contain_white"] = circle(square_pad(src, MASTER, WHITE))
candidates["12_rounded_contain_dark"] = rounded(
    square_pad(src, MASTER, DARK), 0.22
)
candidates["13_circle_cover_center"] = circle(
    on_bg(square_crop(src, MASTER, 1.0), WHITE)
)
# blue-accented badge versions
candidates["14_badge_blue"] = circle(
    on_bg(square_pad(src, MASTER, WHITE), BLUE)
)


def _inset(img, size, frac, bg):
    base = square_pad(img, int(size * frac), bg)
    canvas = Image.new("RGBA", (size, size), bg)
    off = (size - base.width) // 2
    canvas.alpha_composite(base, (off, off))
    return canvas


# inset variants matter most when the source is already square (full-bleed
# vs. padded look).
candidates["15_inset_white"] = _inset(src, MASTER, 0.85, WHITE)
candidates["16_inset_dark"] = _inset(src, MASTER, 0.85, DARK)
candidates["17_inset_transparent"] = _inset(src, MASTER, 0.85, (0, 0, 0, 0))

# ---- export -----------------------------------------------------------
try:
    font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
except Exception:
    font = ImageFont.load_default()

for name, im in candidates.items():
    im = im.convert("RGBA")
    im.save(os.path.join(OUT, f"{name}.png"))
    im.save(os.path.join(OUT, f"icon_mac_{name}.png"))
    # multi-size ICO (Windows)
    im.save(os.path.join(OUT, f"{name}.ico"), sizes=[(s, s) for s in ICO_SIZES])
    for s in PNG_SIZES:
        im.resize((s, s), Image.LANCZOS).save(
            os.path.join(OUT, f"{name}_{s}.png")
        )
    print(f"  wrote {name}")

# ---- contact sheet ----------------------------------------------------
cols = 4
cell = 260
rows = (len(candidates) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * cell, rows * cell), (245, 245, 245, 255))
draw = ImageDraw.Draw(sheet)
for i, (name, im) in enumerate(candidates.items()):
    r, c = divmod(i, cols)
    thumb = on_bg(square_pad(im, 220, WHITE), WHITE)
    x = c * cell + 20
    y = r * cell + 20
    sheet.alpha_composite(thumb, (x, y))
    draw.text((x, y + 222), name, fill=(0, 0, 0, 255), font=font)
sheet.save(os.path.join(OUT, "preview.png"))
print(f"\ncontact sheet: {os.path.join(OUT, 'preview.png')}")
print(f"{len(candidates)} candidates in {OUT}")
print("pick one, then copy its .ico (Windows) / icon_mac_*.png (macOS) "
      "into icons/ico/ or icons/mac/.")
