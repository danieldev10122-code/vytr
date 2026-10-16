"""Regenerate the VYTR app icon.

The icon is the app's own progress ring: the same near-black background
and the same lime, so the home screen and the Today screen read as one
thing. Generating it from code keeps it reproducible from Windows, where
no image editor is involved.

    python scripts/make_icon.py

Requires Pillow (pip install pillow).
"""

from PIL import Image, ImageDraw
import math
import os

SUPERSAMPLE = 4
SIZE = 1024
CANVAS = SIZE * SUPERSAMPLE

# Must stay in step with Theme.Palette in VYTR/Design/Theme.swift.
BACKGROUND = (10, 13, 15)
LIME = (184, 242, 102)
TRACK = (34, 38, 45)

RADIUS_RATIO = 0.29
WIDTH_RATIO = 0.078
ARC_START = -90
ARC_END = 190

OUTPUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "VYTR", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png",
)


def build() -> Image.Image:
    image = Image.new("RGB", (CANVAS, CANVAS), BACKGROUND)
    draw = ImageDraw.Draw(image)

    centre = CANVAS / 2
    radius = CANVAS * RADIUS_RATIO
    width = CANVAS * WIDTH_RATIO
    box = [centre - radius, centre - radius, centre + radius, centre + radius]

    draw.ellipse(box, outline=TRACK, width=int(width))
    draw.arc(box, start=ARC_START, end=ARC_END, fill=LIME, width=int(width))

    # Pillow has no round line caps, and it strokes inward from the
    # bounding box, so the centre line of the band sits at
    # radius - width / 2. Caps drawn at `radius` bulge outside the band.
    cap_centre_radius = radius - width / 2
    for angle in (ARC_START, ARC_END):
        radians = math.radians(angle)
        x = centre + cap_centre_radius * math.cos(radians)
        y = centre + cap_centre_radius * math.sin(radians)
        r = width / 2
        draw.ellipse([x - r, y - r, x + r, y + r], fill=LIME)

    # Drawn large and reduced, because Pillow does not antialias shapes.
    return image.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    icon = build()
    # RGB, never RGBA: iOS rejects an app icon with an alpha channel.
    icon.convert("RGB").save(OUTPUT, "PNG")
    print("wrote %s (%d bytes)" % (OUTPUT, os.path.getsize(OUTPUT)))
