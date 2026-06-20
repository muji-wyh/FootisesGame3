"""Downscale the licensed Maskman albedo textures to small web-friendly PNGs.
Source TGAs stay in the user's Unity project; only small PNGs land in assets/models/tex/
(also gitignored). Run: python tools/gen_textures.py
"""
import os
from PIL import Image

SRC = r"C:\uworks\FootisesGame2\Assets\FightingAnimsetPro\Models\Maskman\Materials"
DST = os.path.join(os.path.dirname(__file__), "..", "assets", "models", "tex")

JOBS = [
    ("Body_D.tga", "body.png", 512),
    ("Head_D.tga", "head.png", 512),
    ("Mask_D.tga", "mask.png", 512),
    ("Eye_Blue_D.tga", "eye.png", 128),
]

if __name__ == "__main__":
    os.makedirs(DST, exist_ok=True)
    for src, dst, size in JOBS:
        path = os.path.join(SRC, src)
        if not os.path.exists(path):
            print("MISSING", path)
            continue
        im = Image.open(path).convert("RGB").resize((size, size), Image.LANCZOS)
        out = os.path.join(DST, dst)
        im.save(out)
        print("wrote", dst, im.size, round(os.path.getsize(out) / 1024, 1), "KB")
    print("done")
