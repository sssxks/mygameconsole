#!/usr/bin/env python3
"""
merge_tile_hex.py
-----------------
Utility to convert tile PNG assets into a single `tile_textures.hex` file that can
be consumed by `tile_texture_rom.v` via `$readmemh`.

Address mapping used by the Verilog is:
{ tile_val[3:0], off_y[5:0], off_x[5:0] } => 16-bit address

Thus there are 16 tiles and each tile is 64×64 pixels.  For every address we must
emit one 12-bit RGB value encoded as 3 hexadecimal digits (R4 G4 B4) in lower-case
hex with no leading “0x”.  There must be exactly 65 536 lines in the output file.

At the moment the script only consumes the PNGs that already exist under
`assets/` and pads / resizes them to 64×64 pixels as needed.  If a tile PNG is
missing it falls back to the “blank” tile or black pixels.

Usage (from project root):
    python tool/merge_tile_hex.py

The script will write/overwrite:
    src/memory/tile_textures.hex
    project/mygameconsole.sim/sim_1/behav/xsim/xsim.dir/tile_textures.hex

Additional destinations can be added to the `OUTPUT_PATHS` list below.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Dict, List

try:
    from PIL import Image  # type: ignore
except ImportError as e:
    sys.stderr.write("ERROR: Pillow is required – install with `pip install pillow`\n")
    raise

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parent.parent  # project root directory
ASSET_DIR = ROOT / "assets"

# Map tile value (0–15) -> PNG filename (relative to ASSET_DIR)
# Only the tiles that exist in the original 2048 game are mapped; the remainder
# will be filled with the blank tile.
TILE_PNG_MAP: Dict[int, str] = {
    0: "tile_blank.png",
    1: "tile_2.png",
    2: "tile_4.png",
    3: "tile_8.png",
    4: "tile_16.png",
    5: "tile_32.png",
    6: "tile_64.png",
    7: "tile_128.png",
    8: "tile_256.png",
    9: "tile_512.png",
    10: "tile_1024.png",
    11: "tile_2048.png",
    # 12-15 left unmapped – will default to blank
}

# Destination(s) for the generated hexadecimal file (relative to project root)
OUTPUT_PATHS: List[Path] = [
    ROOT / "src/memory/tile_texture.hex",
    ROOT / "project/mygameconsole.sim/sim_1/behav/xsim/xsim.dir/tile_texture.hex",
]

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

def load_tile_image(filename: Path, size: int = 64) -> Image.Image:
    """Load a PNG, **pad** it to *size×size* without stretching.

    Behaviour:
    • If the image already matches *size×size* → return as-is.
    • If it is smaller → centre it on a transparent canvas of *size×size*.
    • If it is larger → first shrink it (keeping aspect ratio) so that the
      larger dimension becomes *size-4* (60 px), then centre and pad.
    This guarantees that the visible 60×60 area used by the renderer is never
    distorted, while leaving a symmetrical border that may be discarded.
    """
    if not filename.exists():
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    img = Image.open(filename).convert("RGBA")

    # If image is larger than the canvas, downscale to fit within (size-4)x(size-4)
    if img.width > size or img.height > size:
        max_dim = size - 4  # 60 px visible area
        img.thumbnail((max_dim, max_dim), Image.LANCZOS)

    # If image is smaller than the canvas, pad (centre) it
    if img.size != (size, size):
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        # Paste at top-left so off_x/off_y = 0 aligns with first visible pixel
        canvas.paste(img, (0, 0))
        img = canvas

    return img


def rgba_to_rgb444(r: int, g: int, b: int, a: int) -> int:
    """Convert 8-bit RGBA to 12-bit packed RGB444 (ignoring alpha)."""
    # Simple alpha-blend against black background for transparent images
    if a != 255:
        r = (r * a) // 255
        g = (g * a) // 255
        b = (b * a) // 255
    return ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)


def tile_to_hex_lines(img: Image.Image) -> List[str]:
    """Convert a 64×64 RGBA image into a list of 4096 3-digit hex strings."""
    pixels = img.load()
    out: List[str] = []
    for y in range(64):
        for x in range(64):
            r, g, b, a = pixels[x, y]
            rgb444 = rgba_to_rgb444(r, g, b, a)
            out.append(f"{rgb444:03x}")
    return out


# -----------------------------------------------------------------------------
# Main script
# -----------------------------------------------------------------------------

def main() -> None:
    # Preload / resize all tiles
    blank_tile = load_tile_image(ASSET_DIR / TILE_PNG_MAP[0])

    tile_images: Dict[int, Image.Image] = {}
    for tile_val in range(16):
        png_name = TILE_PNG_MAP.get(tile_val)
        if png_name is None:
            tile_images[tile_val] = blank_tile.copy()
        else:
            tile_images[tile_val] = load_tile_image(ASSET_DIR / png_name)

    # Convert to hex lines in tile order 0..15
    hex_lines: List[str] = []
    for tile_val in range(16):
        hex_lines.extend(tile_to_hex_lines(tile_images[tile_val]))

    assert len(hex_lines) == 65536, "Expected exactly 65 536 lines of output"

    # Write outputs
    for path in OUTPUT_PATHS:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="ascii") as fp:
            fp.write("\n".join(hex_lines) + "\n")
        print(f"Wrote {path.relative_to(ROOT)} ({len(hex_lines)} lines)")


if __name__ == "__main__":
    main()
