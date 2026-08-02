"""Generate the game's app icons from the TUMP bottlecap artwork.

Produces two files, both from the same 1080x1080 RGBA source:

  icon.png  -- the Godot project icon (`application/config/icon`), 256x256.
  icon.ico  -- the Windows executable icon baked into TumbangPreso.exe by the
               export preset's `application/icon`. Multi-size, because Windows
               picks a different frame for the taskbar (32), Explorer's list
               view (16) and the large-tile view (256); an .ico with only one
               big frame gets downscaled badly by the shell.

The bottlecap has transparent corners, so nothing is matted onto a background --
a white matte would show as a square halo on the taskbar.

Run from the repo root:  python tools/make_icon.py <source.png>
"""

import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: python tools/make_icon.py <source.png>")
        return 1

    src = Image.open(sys.argv[1]).convert("RGBA")

    # Square it up if the artwork ever arrives non-square, keeping it centred.
    if src.width != src.height:
        side = max(src.width, src.height)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(src, ((side - src.width) // 2, (side - src.height) // 2))
        src = square

    png_path = REPO / "icon.png"
    src.resize((256, 256), Image.LANCZOS).save(png_path)
    print(f"wrote {png_path} 256x256")

    ico_path = REPO / "icon.ico"
    src.save(ico_path, format="ICO", sizes=[(s, s) for s in ICO_SIZES])
    print(f"wrote {ico_path} sizes={ICO_SIZES}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
