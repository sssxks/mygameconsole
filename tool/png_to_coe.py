#!/usr/bin/env python3
"""
png_to_coe.py
--------------
Convert a PNG image into a Xilinx/Intel style *.coe file for initialising a
Block Memory Generator ROM with 12-bit RGB444 pixel values.

The script will:
1. Load the given PNG (any size / colour depth).
2. Downscale **with aspect-ratio preserved** so that it fits within 320×240.
3. Center it on a 320×240 RGB image (black background) so we always output
   exactly 320×240 = 76 800 pixels.
4. Convert each pixel into 12-bit RGB444 and emit them as 3-digit lower-case
   hexadecimal values separated by a comma + space, exactly matching the format
   understood by Vivadoʼs Block Memory Generator (see example in the project
   README or below).

Usage
-----
$ python tool/png_to_coe.py assets/start_screen.png src/memory/start_screen_rom.coe

Repeat for *win_screen.png* and *over_screen.png* (or any other image of your
choice).

Example output (for a two-pixel image):
    memory_initialization_radix=16;
    memory_initialization_vector=
    fff, 000,
    ... ;

Where the last value is **NOT** followed by a comma but instead a semicolon
terminator, in accordance with the COE grammar.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image  # type: ignore
except ImportError:
    sys.stderr.write("ERROR: Pillow is required – install with `pip install pillow`\n")
    sys.exit(1)

WIDTH, HEIGHT = 320, 240
NUM_PIXELS = WIDTH * HEIGHT  # 76 800


def rgba_to_rgb444(r: int, g: int, b: int, a: int) -> int:
    """Convert 8-bit RGBA to packed 12-bit RGB444 (ignoring alpha)."""
    if a != 255:
        # Simple alpha blend against black background
        r = (r * a) // 255
        g = (g * a) // 255
        b = (b * a) // 255
    return ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)


def load_and_prepare_image(path: Path, pixelate_factor: int = 2) -> Image.Image:
    """Load *path* as RGBA, scale **to cover** 320×240 (no borders) and add pixelation.

    1. Scale image with *nearest* filter so that it completely covers the 320×240
       canvas (may crop edges if aspect ratio differs).
    2. Centre-crop to exactly 320×240 → no black borders.
    3. Pixelate by down-scaling to (W/px, H/px) then back up, again with
       *nearest* filter.  *pixelate_factor* = 1 disables this effect.
    """
    img = Image.open(path).convert("RGBA")

    # -------- Step 1: resize to cover --------
    scale = max(WIDTH / img.width, HEIGHT / img.height)
    new_size = (int(img.width * scale + 0.5), int(img.height * scale + 0.5))
    img = img.resize(new_size, Image.NEAREST)

    # -------- Step 2: centre-crop --------
    left = (img.width - WIDTH) // 2
    top = (img.height - HEIGHT) // 2
    img = img.crop((left, top, left + WIDTH, top + HEIGHT))

    # -------- Step 3: pixelate (optional) --------
    if pixelate_factor > 1:
        small_size = (WIDTH // pixelate_factor, HEIGHT // pixelate_factor)
        img = img.resize(small_size, Image.NEAREST)
        img = img.resize((WIDTH, HEIGHT), Image.NEAREST)

    return img


def image_to_hex_values(img: Image.Image) -> list[str]:
    """Return a flat list of 3-hex-digit strings (length = 76 800)."""
    pixels = img.load()
    out: list[str] = []
    for y in range(HEIGHT):
        for x in range(WIDTH):
            r, g, b, a = pixels[x, y]
            out.append(f"{rgba_to_rgb444(r, g, b, a):03x}")
    return out


def write_coe(hex_vals: list[str], dest: Path) -> None:
    """Write *hex_vals* to *dest* in COE syntax."""
    if len(hex_vals) != NUM_PIXELS:
        raise ValueError("Expected exactly 76 800 values for 320×240 image")

    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("w", encoding="ascii") as fp:
        fp.write("memory_initialization_radix=16;\n")
        fp.write("memory_initialization_vector=\n")

        # Write values separated by comma + space, 20 per line for readability
        for i, val in enumerate(hex_vals):
            is_last = i == len(hex_vals) - 1
            fp.write(val)
            fp.write(";\n" if is_last else ", ")
            if not is_last and ((i + 1) % 20 == 0):
                fp.write("\n")
    print(f"Wrote {dest} ({len(hex_vals)} values)")


def main() -> None:
    ap = argparse.ArgumentParser(description="Convert PNG to COE (RGB444 320×240)")
    ap.add_argument("input_png", type=Path, help="Source PNG image")
    ap.add_argument("output_coe", type=Path, help="Destination .coe file")
    ap.add_argument("-p", "--preview", action="store_true", help="Show a preview of the prepared 320×240 image before writing the COE file")
    args = ap.parse_args()

    img = load_and_prepare_image(args.input_png, 1)

    # Optional preview for visual verification
    if args.preview:
        img.show(title="Prepared 320×240 Preview")

    hex_vals = image_to_hex_values(img)
    write_coe(hex_vals, args.output_coe)


if __name__ == "__main__":
    main()
