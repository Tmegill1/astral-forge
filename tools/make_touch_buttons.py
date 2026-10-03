#!/usr/bin/env python3
"""Draws the placeholder on-screen touch buttons into assets/ui/touch/.

Each is a translucent dark disc with a brass rim and a short label, until
real art replaces them. Run: python3 tools/make_touch_buttons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "touch"
RIM = (184, 143, 72, 230)
FILL = (16, 18, 24, 150)
TEXT = (240, 228, 200, 255)

# name: (size, label)
BUTTONS = {
    "use": (80, "USE"),
    "manage": (80, "MANAGE"),
    "ability": (80, "Q"),
    "wave": (80, "WAVE"),
    "pause": (56, "II"),
    "stick_base": (140, ""),
    "stick_knob": (60, ""),
}


def font(size: int) -> ImageFont.ImageFont:
    for name in ("DejaVuSans-Bold.ttf", "LiberationSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def draw(size: int, label: str, knob: bool) -> Image.Image:
    scale = 4  # draw big, then shrink, for smooth edges
    big = size * scale
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rim = 3 * scale
    fill = (184, 143, 72, 200) if knob else FILL
    d.ellipse((rim, rim, big - rim, big - rim), fill=fill, outline=RIM, width=rim)
    if label:
        f = font(int(big * (0.34 if len(label) <= 2 else 0.18)))
        box = d.textbbox((0, 0), label, font=f)
        d.text(((big - (box[2] - box[0])) / 2 - box[0], (big - (box[3] - box[1])) / 2 - box[1]),
               label, font=f, fill=TEXT)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (size, label) in BUTTONS.items():
        draw(size, label, name == "stick_knob").save(OUT / f"{name}.png")
        print(f"wrote {OUT / name}.png")


if __name__ == "__main__":
    main()
