"""
Dibuja los objetos y proyectiles de los personajes de Boulevard Smash (assets/sprites/):
  prop_fish (pez de Schizov), prop_mic (micrófono de Abnielito), prop_pistol (pistola de Lamont),
  prop_croissant, prop_jacket (chaqueta de Ilunna), prop_money (billete del préstamo de Lamont),
  proj_<id>.png (el proyectil del especial: 4 cuadros de 32x32).

    pip install pillow numpy scipy
    python3 tools/make_props.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
SS = 4   # se dibuja 4 veces más grande y luego se reduce (bordes suaves)


def canvas(w, h):
    im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def P(*pts):
    return [(x * SS, y * SS) for x, y in pts]


def E(x0, y0, x1, y1):
    return [x0 * SS, y0 * SS, x1 * SS, y1 * SS]


def finish(im, outline=True):
    w, h = im.width // SS, im.height // SS
    im = im.resize((w, h), Image.LANCZOS)
    if not outline:
        return im
    a = np.asarray(im).astype(np.float32)
    solid = a[..., 3] > 90
    ring = ndimage.binary_dilation(solid, structure=np.ones((3, 3))) & ~solid
    out = a.copy()
    out[ring] = (22, 18, 28, 230)
    out[solid, 3] = np.maximum(out[solid, 3], 255)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + ".png"))


def strip(frames):
    s = Image.new("RGBA", (32 * len(frames), 32), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (32 * i, 0))
    return s


# ------------------------------------------------------------------------------------ objetos
def fish():
    im, d = canvas(50, 22)   # se agarra por la cola (izquierda)
    d.polygon(P((2, 3), (11, 11), (2, 19)), fill=(90, 120, 150, 255))           # cola
    d.ellipse(E(8, 3, 48, 19), fill=(120, 160, 190, 255))                      # cuerpo
    d.chord(E(8, 3, 48, 19), 0, 180, fill=(225, 230, 220, 255))                # panza
    d.ellipse(E(8, 3, 48, 15), fill=(110, 150, 185, 255))
    for x in range(16, 40, 5):
        d.arc(E(x, 6, x + 6, 14), 290, 70, fill=(80, 110, 140, 255), width=SS)
    d.polygon(P((24, 4), (30, 0), (36, 4)), fill=(90, 120, 150, 255))         # aleta
    d.ellipse(E(38, 7, 43, 12), fill=(255, 255, 255, 255))                     # ojo
    d.ellipse(E(40, 8, 42.5, 10.5), fill=(10, 10, 10, 255))
    d.line(P((46, 13), (43, 14)), fill=(60, 30, 40, 255), width=SS)            # boca
    save(finish(im), "prop_fish")


def mic():
    im, d = canvas(14, 34)   # la mano va abajo (en el mango)
    d.rounded_rectangle(E(4, 12, 10, 33), radius=2 * SS, fill=(30, 30, 36, 255))
    d.rectangle(E(4, 14, 10, 16), fill=(210, 170, 60, 255))
    d.ellipse(E(1, 1, 13, 14), fill=(150, 150, 160, 255))
    for i in range(3, 13, 2):
        d.line(P((i, 2), (i, 13)), fill=(95, 95, 105, 255), width=SS // 2)
        d.line(P((2, i), (12, i)), fill=(95, 95, 105, 255), width=SS // 2)
    d.ellipse(E(3, 3, 7, 6), fill=(235, 235, 245, 200))
    save(finish(im), "prop_mic")


def pistol():
    im, d = canvas(34, 20)   # la mano va en la empuñadura (abajo a la izquierda)
    d.polygon(P((3, 7), (32, 7), (32, 12), (14, 12), (12, 19), (5, 19), (6, 12), (3, 12)), fill=(48, 50, 58, 255))
    d.rectangle(E(3, 5, 26, 8), fill=(70, 72, 82, 255))
    d.line(P((5, 6), (25, 6)), fill=(140, 145, 160, 255), width=SS)
    d.rectangle(E(6, 13, 12, 18), fill=(120, 70, 40, 255))                     # cacha de madera
    d.arc(E(12, 10, 18, 16), 0, 180, fill=(30, 30, 36, 255), width=SS)        # guardamonte
    d.rectangle(E(30, 4, 32, 6), fill=(30, 30, 36, 255))                        # mira
    save(finish(im), "prop_pistol")


def croissant():
    im, d = canvas(34, 22)
    segs = [(4, 10, 11, 20), (9, 5, 17, 19), (15, 3, 23, 18), (21, 5, 29, 19), (26, 10, 33, 20)]
    cols = [(196, 120, 50), (214, 142, 62), (230, 164, 78), (214, 142, 62), (196, 120, 50)]
    for (x0, y0, x1, y1), c in zip(segs, cols):
        d.ellipse(E(x0, y0, x1, y1), fill=c + (255,))
        d.arc(E(x0 + 1, y0 + 1, x1 - 1, y1 - 1), 200, 320, fill=(250, 210, 140, 255), width=SS)
    save(finish(im), "prop_croissant")


def jacket():
    im, d = canvas(44, 36)
    d.rounded_rectangle(E(10, 4, 34, 34), radius=6 * SS, fill=(28, 30, 36, 255))
    d.rounded_rectangle(E(1, 6, 13, 30), radius=5 * SS, fill=(24, 26, 32, 255))
    d.rounded_rectangle(E(31, 6, 43, 30), radius=5 * SS, fill=(24, 26, 32, 255))
    for y in (11, 18, 25):
        d.line(P((11, y), (33, y)), fill=(55, 58, 68, 255), width=SS)
        d.line(P((2, y), (12, y)), fill=(50, 52, 62, 255), width=SS)
        d.line(P((32, y), (42, y)), fill=(50, 52, 62, 255), width=SS)
    d.line(P((22, 5), (22, 33)), fill=(110, 112, 120, 255), width=SS)
    save(finish(im), "prop_jacket")


def cap():
    im, d = canvas(40, 26)   # birrete de graduación
    d.polygon(P((2, 9), (20, 2), (38, 9), (20, 16)), fill=(30, 30, 38, 255))
    d.polygon(P((20, 2), (38, 9), (20, 16)), fill=(44, 44, 54, 255))
    d.rounded_rectangle(E(10, 11, 30, 22), radius=2 * SS, fill=(24, 24, 30, 255))
    d.line(P((20, 9), (33, 12), (34, 21)), fill=(230, 185, 60, 255), width=int(1.5 * SS))
    d.ellipse(E(32, 20, 36, 25), fill=(240, 195, 70, 255))
    save(finish(im), "prop_cap")


def money():
    im, d = canvas(30, 16)
    d.rounded_rectangle(E(1, 1, 29, 15), radius=2 * SS, fill=(110, 190, 110, 255))
    d.rounded_rectangle(E(3, 3, 27, 13), radius=2 * SS, outline=(60, 130, 70, 255), width=SS)
    d.ellipse(E(11, 4, 19, 12), fill=(80, 160, 90, 255))
    d.text((13.2 * SS, 3.2 * SS), "%", fill=(240, 255, 240, 255), font_size=8 * SS)
    save(finish(im), "prop_money")


# -------------------------------------------------------------------------------- proyectiles
def proj_lamont():
    fr = []
    for i in range(4):
        im, d = canvas(32, 32)
        L = 10 + i * 2
        d.polygon(P((2, 15), (22 - L * 0.2, 13.5), (22 - L * 0.2, 18.5)), fill=(255, 220, 120, 120))
        d.rounded_rectangle(E(16, 13, 29, 19), radius=3 * SS, fill=(222, 170, 70, 255))
        d.ellipse(E(24, 13, 31, 19), fill=(200, 140, 60, 255))
        d.line(P((17, 14.5), (27, 14.5)), fill=(255, 235, 170, 255), width=SS)
        fr.append(finish(im))
    save(strip(fr), "proj_lamont")


def proj_ilunna():
    fr = []
    for i in range(4):
        im, d = canvas(32, 32)
        w = i % 2
        d.chord(E(2, 2 - w, 30, 30 + w), -70, 70, fill=(120, 225, 255, 230))
        d.ellipse(E(-8 - w, 5, 20 - w, 27), fill=(0, 0, 0, 0))
        d.arc(E(3, 3, 29, 29), -65, 65, fill=(245, 255, 255, 255), width=2 * SS)
        fr.append(finish(im, outline=False))
    save(strip(fr), "proj_ilunna")


def proj_abnielito():
    fr = []
    for i in range(4):
        im, d = canvas(32, 32)
        for k, r in enumerate((6, 11, 16)):
            rr = r + i * 0.7
            a = 255 - k * 50
            d.arc(E(14 - rr, 16 - rr, 14 + rr, 16 + rr), -50, 50, fill=(255, 215, 70, a), width=int(2.5 * SS))
        d.ellipse(E(6, 13, 12, 19), fill=(255, 245, 190, 255))
        fr.append(finish(im, outline=False))
    save(strip(fr), "proj_abnielito")


def proj_panadero():
    fr = []
    rng = np.random.default_rng(3)
    blobs = [(rng.uniform(6, 26), rng.uniform(8, 24), rng.uniform(4, 8)) for _ in range(9)]
    for i in range(4):
        im, d = canvas(32, 32)
        for bx, by, br in blobs:
            r = br * (0.85 + 0.12 * i)
            d.ellipse(E(bx - r, by - r, bx + r, by + r), fill=(246, 242, 232, 235))
        for bx, by, br in blobs[:4]:
            r = br * 0.5
            d.ellipse(E(bx - r - 1, by - r - 1, bx + r - 1, by + r - 1), fill=(255, 255, 255, 255))
        fr.append(finish(im, outline=False))
    save(strip(fr), "proj_panadero")


def proj_schizov():
    fr = []
    covers = [(230, 60, 90), (60, 150, 230), (250, 190, 40), (120, 200, 90)]
    for i in range(4):
        im, d = canvas(32, 32)
        c = covers[i % 4]
        open_ = [0, 3, 6, 3][i]
        d.polygon(P((4, 8), (16, 9 - open_ * 0.3), (16, 25), (4, 24)), fill=c + (255,))
        d.polygon(P((16, 9 - open_ * 0.3), (28, 8 + open_), (28, 24), (16, 25)), fill=tuple(int(v * 0.8) for v in c) + (255,))
        d.rectangle(E(6, 11, 14, 14), fill=(255, 255, 255, 255))                 # título
        d.rectangle(E(6, 16, 12, 22), fill=(250, 220, 190, 255))                 # foto
        d.line(P((16, 9), (16, 25)), fill=(40, 30, 40, 255), width=SS)
        fr.append(finish(im))
    save(strip(fr), "proj_schizov")


def main():
    fish(); mic(); pistol(); croissant(); jacket(); money(); cap()
    proj_lamont(); proj_ilunna(); proj_abnielito(); proj_panadero(); proj_schizov()
    print("Objetos generados en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
