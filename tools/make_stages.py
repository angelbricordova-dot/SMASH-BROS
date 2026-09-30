"""
Generador de fondos (en capas, para efecto de profundidad) y texturas HD de los escenarios.

Uso:
    pip install pillow numpy
    python3 tools/make_stages.py

Crea assets/stages/<mapa>/sky.png, far.png, mid.png  y  assets/stages/tiles/*.png
Los fondos se dibujan con antialiasing (suaves, no pixelados). Las capas far/mid se repiten
horizontalmente sin costuras.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "stages")
W, H = 1280, 720        # cielo (pantalla)
LW = 2560               # ancho de las capas que se repiten
SS = 2                  # supersampling


# ---------------------------------------------------------------- utilidades
def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def gradient(w, h, stops):
    """stops: [(0.0, color), (0.5, color), (1.0, color)] vertical."""
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    ys = np.linspace(0, 1, h)
    for i, y in enumerate(ys):
        for j in range(len(stops) - 1):
            if stops[j][0] <= y <= stops[j + 1][0]:
                t = (y - stops[j][0]) / max(1e-6, stops[j + 1][0] - stops[j][0])
                c = lerp(stops[j][1], stops[j + 1][1], t)
                break
        arr[i, :, :3] = c[:3]
        arr[i, :, 3] = 255
    return Image.fromarray(arr, "RGBA")


class Big:
    """Lienzo con supersampling (dibuja al doble y reduce con suavizado)."""

    def __init__(self, w, h, bg=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), bg)
        self.d = ImageDraw.Draw(self.img)

    def S(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, col, wrap=False):
        self.d.polygon(self.S(pts), fill=col)
        if wrap:
            for off in (-self.w, self.w):
                self.d.polygon(self.S([(x + off, y) for x, y in pts]), fill=col)

    def ellipse(self, cx, cy, rx, ry, col, wrap=False):
        for off in ((-self.w, 0, self.w) if wrap else (0,)):
            x = cx + off
            self.d.ellipse([(x - rx) * SS, (cy - ry) * SS, (x + rx) * SS, (cy + ry) * SS], fill=col)

    def rect(self, x0, y0, x1, y1, col, wrap=False):
        for off in ((-self.w, 0, self.w) if wrap else (0,)):
            self.d.rectangle([(x0 + off) * SS, y0 * SS, (x1 + off) * SS, y1 * SS], fill=col)

    def line(self, pts, col, width=1, wrap=False):
        for off in ((-self.w, 0, self.w) if wrap else (0,)):
            self.d.line(self.S([(x + off, y) for x, y in pts]), fill=col, width=int(width * SS))

    def done(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def periodic(x, w, terms, seed):
    """Función suave y periódica (sin costuras al repetir)."""
    r = random.Random(seed)
    v = 0.0
    for k, amp in terms:
        v += amp * math.sin(2 * math.pi * k * x / w + r.random() * 10 + k)
    return v


def ridge_pts(w, h, base, terms, seed, step=8):
    pts = [(0, h)]
    for x in range(0, w + step, step):
        pts.append((x, base + periodic(x, w, terms, seed)))
    pts.append((w, h))
    return pts


def glow(img, radius, strength=1.0):
    blurred = img.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        a = np.array(blurred).astype(np.float32)
        a[..., 3] = np.clip(a[..., 3] * strength, 0, 255)
        blurred = Image.fromarray(a.astype(np.uint8), "RGBA")
    return blurred


def comp(*layers):
    base = layers[0].copy()
    for l in layers[1:]:
        base.alpha_composite(l)
    return base


def haze(img, color, amount):
    """Mezcla con el color del cielo (perspectiva atmosférica)."""
    a = np.array(img).astype(np.float32)
    a[..., :3] = a[..., :3] * (1 - amount) + np.array(color[:3]) * amount
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def vshade(img, top=1.0, bottom=0.6):
    a = np.array(img).astype(np.float32)
    k = np.linspace(top, bottom, a.shape[0])[:, None, None]
    a[..., :3] *= k
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def stars(img, n, seed, maxy=1.0, big=0.05):
    d = ImageDraw.Draw(img)
    r = random.Random(seed)
    for _ in range(n):
        x, y = r.randint(0, img.width - 1), r.randint(0, int(img.height * maxy))
        b = r.randint(140, 255)
        s = r.random()
        if s < big:
            d.line([(x - 4, y), (x + 4, y)], fill=(b, b, 255, 200))
            d.line([(x, y - 4), (x, y + 4)], fill=(b, b, 255, 200))
            d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(255, 255, 255, 255))
        else:
            rr = 0.6 if s < 0.7 else 1.1
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(b, b, min(255, b + 20), 255))
    return img


def sun(cx, cy, r, core, halo, w=W, h=H):
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - r * 2.6, cy - r * 2.6, cx + r * 2.6, cy + r * 2.6], fill=halo[:3] + (70,))
    layer = glow(layer, r * 0.9)
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=core)
    return layer


def cloud_layer(w, h, n, seed, col=(255, 255, 255), shade_col=(200, 214, 236), ymin=40, ymax=260, scale=1.0):
    b = Big(w, h)
    r = random.Random(seed)
    for _ in range(n):
        cx, cy = r.uniform(0, w), r.uniform(ymin, ymax)
        size = r.uniform(40, 90) * scale
        for k in range(7):
            ox = r.uniform(-1.6, 1.6) * size
            oy = r.uniform(-0.35, 0.2) * size
            rr = r.uniform(0.45, 0.8) * size
            b.ellipse(cx + ox, cy + oy + rr * 0.15, rr, rr * 0.75, shade_col + (255,), wrap=True)
            b.ellipse(cx + ox, cy + oy, rr * 0.95, rr * 0.7, col + (255,), wrap=True)
    return glow(b.done(), 1.2)


def trees_pine(b, xs, ground, heights, col, snow=False, seed=0):
    r = random.Random(seed)
    for x in xs:
        hgt = r.uniform(*heights)
        gy = ground(x)
        wdt = hgt * 0.38
        b.rect(x - wdt * 0.06, gy - hgt * 0.15, x + wdt * 0.06, gy + 4, (60, 40, 30, 255), wrap=True)
        for k in range(4):
            y0 = gy - hgt * (0.15 + k * 0.2)
            ww = wdt * (1 - k * 0.2)
            b.poly([(x - ww, y0), (x + ww, y0), (x, y0 - hgt * 0.38)], col, wrap=True)
            if snow:
                b.poly([(x - ww * 0.45, y0 - hgt * 0.2), (x + ww * 0.45, y0 - hgt * 0.2), (x, y0 - hgt * 0.38)],
                       (240, 246, 255, 255), wrap=True)


def trees_round(b, xs, ground, heights, col, light, seed=0):
    r = random.Random(seed)
    for x in xs:
        hgt = r.uniform(*heights)
        gy = ground(x)
        b.rect(x - hgt * 0.05, gy - hgt * 0.5, x + hgt * 0.05, gy + 4, (90, 62, 40, 255), wrap=True)
        for k in range(5):
            ox, oy = r.uniform(-0.25, 0.25) * hgt, r.uniform(-0.2, 0.1) * hgt
            rr = r.uniform(0.22, 0.32) * hgt
            b.ellipse(x + ox, gy - hgt * 0.65 + oy, rr, rr, col, wrap=True)
        b.ellipse(x + hgt * 0.06, gy - hgt * 0.78, hgt * 0.16, hgt * 0.12, light, wrap=True)


def save(img, stage, name):
    d = os.path.join(OUT, stage)
    os.makedirs(d, exist_ok=True)
    img.save(os.path.join(d, name + ".png"), optimize=True)


# ---------------------------------------------------------------- mapas
def pradera():
    sky = gradient(W, H, [(0, (64, 132, 230)), (0.55, (150, 200, 245)), (1, (222, 238, 250))])
    sky = comp(sky, sun(980, 130, 46, (255, 250, 220, 255), (255, 230, 150)))
    save(sky, "pradera", "sky")
    save(cloud_layer(LW, 400, 10, 3), "pradera", "clouds")
    b = Big(LW, H)
    b.poly(ridge_pts(LW, H, 430, [(3, 50), (7, 30), (13, 12)], 1), (146, 172, 214, 255))
    far = b.done()
    snow = Big(LW, H)
    snow.poly(ridge_pts(LW, H, 430, [(3, 50), (7, 30), (13, 12)], 1), (240, 246, 255, 255))
    snowimg = snow.done()
    mask = Image.new("L", (LW, H), 0)
    ImageDraw.Draw(mask).rectangle([0, 0, LW, 420], fill=255)
    far.paste(snowimg, (0, 0), Image.composite(snowimg, Image.new("RGBA", (LW, H)), mask).split()[3])
    far = haze(far, (170, 205, 240), 0.35)
    save(far, "pradera", "far")
    b = Big(LW, H)
    g = lambda x: 560 + periodic(x, LW, [(4, 26), (9, 10)], 5)  # noqa: E731
    b.poly(ridge_pts(LW, H, 560, [(4, 26), (9, 10)], 5), (92, 166, 98, 255))
    trees_round(b, [i * 140 + random.Random(i).uniform(-40, 40) for i in range(LW // 140)], g, (70, 130),
                (60, 132, 76, 255), (110, 186, 110, 255), 4)
    b.poly(ridge_pts(LW, H, 640, [(5, 16), (11, 6)], 9), (70, 142, 80, 255))
    mid = vshade(b.done(), 1.05, 0.75)
    save(mid, "pradera", "mid")


def cosmos():
    sky = gradient(W, H, [(0, (8, 6, 26)), (0.6, (30, 14, 60)), (1, (52, 20, 80))])
    neb = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(neb)
    r = random.Random(31)
    for _ in range(40):
        cx, cy = r.uniform(0, W), r.uniform(0, H * 0.8)
        col = r.choice([(150, 60, 200), (60, 90, 220), (220, 70, 150), (70, 190, 210)])
        rr = r.uniform(60, 180)
        d.ellipse([cx - rr, cy - rr * 0.6, cx + rr, cy + rr * 0.6], fill=col + (40,))
    neb = glow(neb, 50, 1.6)
    sky = comp(sky, neb)
    stars(sky, 700, 32)
    # planeta con anillo
    pl = Big(W, H)
    pl.ellipse(250, 170, 150, 40, (255, 210, 170, 160))
    pl.ellipse(250, 170, 90, 90, (230, 130, 90, 255))
    pl.ellipse(275, 150, 70, 70, (246, 164, 112, 255))
    pl.ellipse(290, 140, 34, 30, (255, 196, 150, 255))
    ring = Big(W, H)
    ring.ellipse(250, 170, 150, 40, (255, 220, 190, 190))
    ring.ellipse(250, 170, 128, 30, (0, 0, 0, 0))
    planet = pl.done()
    save(comp(sky, glow(planet, 25, 0.8), planet), "cosmos", "sky")
    b = Big(LW, H)
    r = random.Random(33)
    for i in range(22):  # asteroides lejanos
        cx, cy, rr = r.uniform(0, LW), r.uniform(120, 520), r.uniform(8, 30)
        pts = [(cx + math.cos(k / 8 * math.tau) * rr * r.uniform(0.7, 1.2), cy + math.sin(k / 8 * math.tau) * rr *
                r.uniform(0.7, 1.2)) for k in range(8)]
        b.poly(pts, (86, 76, 110, 255), wrap=True)
        b.ellipse(cx - rr * 0.3, cy - rr * 0.3, rr * 0.35, rr * 0.3, (120, 108, 150, 255), wrap=True)
    save(b.done(), "cosmos", "far")
    b = Big(LW, H)
    b.ellipse(LW * 0.7, 900, 700, 420, (60, 48, 110, 255))
    b.ellipse(LW * 0.7, 900, 660, 390, (84, 66, 150, 255))
    b.ellipse(LW * 0.2, 980, 500, 330, (46, 60, 110, 255))
    save(glow(b.done(), 2), "cosmos", "mid")
    save(Image.new("RGBA", (8, 8), (0, 0, 0, 0)), "cosmos", "clouds")


def ciudad():
    sky = gradient(W, H, [(0, (40, 30, 90)), (0.45, (170, 80, 130)), (0.75, (250, 150, 110)), (1, (255, 200, 140))])
    sky = comp(sky, sun(640, 470, 70, (255, 214, 150, 255), (255, 170, 110)))
    save(sky, "ciudad", "sky")
    save(cloud_layer(LW, 400, 10, 44, (255, 190, 170), (220, 130, 140), 60, 220, 1.3), "ciudad", "clouds")
    for name, (col, base, hmin, hmax, lit, seed) in {
        "far": ((120, 80, 140), 540, 80, 260, 0.0, 41), "mid": ((56, 38, 78), 620, 60, 220, 0.3, 42)}.items():
        b = Big(LW, H)
        r = random.Random(seed)
        x = 0
        while x < LW:
            bw, bh = r.uniform(50, 130), r.uniform(hmin, hmax)
            b.rect(x, base - bh, x + bw, H, col + (255,))
            if r.random() < 0.3:
                b.rect(x + bw * 0.45, base - bh - 26, x + bw * 0.5, base - bh, col + (255,))
                b.ellipse(x + bw * 0.475, base - bh - 28, 3, 3, (255, 90, 90, 255))
            if lit:
                for wy in range(int(base - bh + 12), H - 10, 16):
                    for wx in range(int(x + 8), int(x + bw - 8), 13):
                        if r.random() < lit:
                            b.rect(wx, wy, wx + 6, wy + 8, (255, 222, 140, 255))
            x += bw + r.uniform(4, 16)
        img = b.done()
        save(haze(img, (220, 130, 130), 0.3) if name == "far" else img, "ciudad", name)


def volcan():
    sky = gradient(W, H, [(0, (26, 10, 22)), (0.5, (90, 24, 30)), (0.85, (190, 70, 40)), (1, (240, 120, 50))])
    save(stars(sky, 120, 51, 0.4), "volcan", "sky")
    b = Big(LW, H)
    b.poly(ridge_pts(LW, H, 520, [(3, 40), (8, 18)], 52), (60, 26, 30, 255))
    for cx in (LW * 0.3, LW * 0.8):  # volcanes
        b.poly([(cx - 420, H), (cx - 70, 250), (cx + 70, 250), (cx + 420, H)], (74, 30, 32, 255), wrap=True)
        b.poly([(cx - 70, 250), (cx + 70, 250), (cx + 50, 262), (cx - 50, 262)], (255, 150, 60, 255), wrap=True)
        for k in (-1, 0.4):
            b.line([(cx + k * 40, 260), (cx + k * 90, 420), (cx + k * 140, 600)], (255, 110, 40, 255), 6, wrap=True)
    far = b.done()
    smoke = Big(LW, H)
    r = random.Random(53)
    for cx in (LW * 0.3, LW * 0.8):
        for k in range(14):
            smoke.ellipse(cx + r.uniform(-60, 60) + k * 14, 230 - k * 28, 50 + k * 6, 40 + k * 4, (70, 50, 60, 150),
                          wrap=True)
    far = comp(glow(far, 8, 0.8), far, glow(smoke.done(), 12))
    save(far, "volcan", "far")
    b = Big(LW, H)
    b.poly(ridge_pts(LW, H, 600, [(5, 30), (12, 12)], 54), (40, 18, 22, 255))
    lava = Big(LW, H)
    lava.poly([(0, H)] + [(x, 690 + 6 * math.sin(x / 90.0)) for x in range(0, LW + 10, 10)] + [(LW, H)],
              (255, 110, 30, 255))
    lava.poly([(0, H)] + [(x, 700 + 4 * math.sin(x / 60.0 + 1)) for x in range(0, LW + 10, 10)] + [(LW, H)],
              (255, 190, 80, 255))
    lv = lava.done()
    mid = comp(b.done(), glow(lv, 14, 1.4), lv)
    save(mid, "volcan", "mid")
    save(Image.new("RGBA", (8, 8), (0, 0, 0, 0)), "volcan", "clouds")


def bosque():
    sky = gradient(W, H, [(0, (8, 12, 36)), (0.6, (20, 36, 76)), (1, (40, 70, 110))])
    stars(sky, 400, 61, 0.7)
    sky = comp(sky, sun(900, 150, 60, (240, 244, 255, 255), (180, 200, 255)))
    moon = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(moon)
    for (x, y, rr) in ((880, 140, 12), (920, 170, 8), (905, 120, 6)):
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(210, 216, 236, 255))
    save(comp(sky, moon), "bosque", "sky")
    for name, (col, base, hts, seed, hz) in {"far": ((30, 52, 80), 470, (160, 260), 62, 0.25),
                                              "mid": ((14, 28, 40), 560, (200, 320), 63, 0.0)}.items():
        b = Big(LW, H)
        g = lambda x, base=base, seed=seed: base + periodic(x, LW, [(4, 18), (9, 8)], seed)  # noqa: E731
        b.poly(ridge_pts(LW, H, base, [(4, 18), (9, 8)], seed), col + (255,))
        xs = [i * 70 + random.Random(i + seed).uniform(-25, 25) for i in range(LW // 70)]
        trees_pine(b, xs, g, hts, col + (255,), seed=seed)
        img = b.done()
        save(haze(img, (60, 90, 140), hz) if hz else img, "bosque", name)
    fog = Big(LW, 400)
    r = random.Random(64)
    for _ in range(30):
        fog.ellipse(r.uniform(0, LW), r.uniform(200, 380), r.uniform(150, 300), r.uniform(20, 40),
                    (180, 200, 240, 60), wrap=True)
    save(glow(fog.done(), 20, 1.3), "bosque", "clouds")


def nieve():
    sky = gradient(W, H, [(0, (70, 120, 190)), (0.5, (150, 190, 230)), (1, (230, 240, 252))])
    aur = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(aur)
    for k, col in enumerate([(120, 255, 190), (170, 140, 255)]):
        pts = [(x, 110 + k * 50 + 30 * math.sin(x / 140 + k)) for x in range(0, W + 20, 20)]
        for i in range(len(pts) - 1):
            d.line([pts[i], pts[i + 1]], fill=col + (90,), width=40)
    sky = comp(sky, glow(aur, 22, 1.2))
    save(sky, "nieve", "sky")
    save(cloud_layer(LW, 400, 12, 71, (250, 252, 255), (210, 222, 240), 80, 240), "nieve", "clouds")
    b = Big(LW, H)
    b.poly(ridge_pts(LW, H, 400, [(2, 70), (5, 40), (11, 16)], 72), (160, 180, 214, 255))
    far = b.done()
    s = Big(LW, H)
    s.poly(ridge_pts(LW, H, 400, [(2, 70), (5, 40), (11, 16)], 72), (246, 250, 255, 255))
    s_img = s.done()
    m = Image.new("L", (LW, H), 0)
    ImageDraw.Draw(m).rectangle([0, 0, LW, 440], fill=255)
    far.paste(s_img, (0, 0), Image.composite(s_img, Image.new("RGBA", (LW, H)), m).split()[3])
    save(haze(far, (200, 220, 245), 0.3), "nieve", "far")
    b = Big(LW, H)
    g = lambda x: 580 + periodic(x, LW, [(4, 20), (10, 8)], 73)  # noqa: E731
    b.poly(ridge_pts(LW, H, 580, [(4, 20), (10, 8)], 73), (236, 242, 252, 255))
    trees_pine(b, [i * 110 + random.Random(i).uniform(-30, 30) for i in range(LW // 110)], g, (90, 150),
               (40, 90, 90, 255), snow=True, seed=74)
    save(vshade(b.done(), 1.0, 0.85), "nieve", "mid")


# ---------------------------------------------------------------- texturas HD (se repiten)
def tile(w, h, base, seed, noise=10):
    r = np.random.default_rng(seed)
    a = np.zeros((h, w, 4), dtype=np.float32)
    a[..., :3] = np.array(base[:3], dtype=np.float32)
    n = r.normal(0, noise, (h // 4 + 1, w // 4 + 1))
    n = np.kron(n, np.ones((4, 4)))[:h, :w]
    a[..., :3] += n[..., None]
    a[..., 3] = 255
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def draw_wrapped(img, fn):
    """Dibuja con envoltura horizontal y vertical (textura sin costuras)."""
    d = ImageDraw.Draw(img)
    for ox in (-img.width, 0, img.width):
        fn(d, ox)


def tiles():
    T = os.path.join(OUT, "tiles")
    os.makedirs(T, exist_ok=True)
    r = random.Random(5)

    def pebbles(img, cols, n, seed, ymin=0):
        rr = random.Random(seed)
        items = [(rr.uniform(0, img.width), rr.uniform(ymin, img.height), rr.uniform(3, 8), rr.choice(cols))
                 for _ in range(n)]
        draw_wrapped(img, lambda d, ox: [d.ellipse([x + ox - s, y - s * 0.7, x + ox + s, y + s * 0.7], fill=c)
                                        for x, y, s, c in items])

    # Pradera
    dirt = tile(128, 128, (122, 84, 58), 1, 8)
    pebbles(dirt, [(96, 64, 46, 255), (150, 110, 80, 255), (86, 58, 40, 255)], 26, 2)
    dirt.save(os.path.join(T, "pradera_body.png"))
    top = tile(128, 64, (122, 84, 58), 3, 8)
    d = ImageDraw.Draw(top)
    d.rectangle([0, 0, 128, 22], fill=(84, 168, 70, 255))
    for i in range(70):
        x = r.uniform(0, 128)
        hh = r.uniform(8, 18)
        col = r.choice([(96, 184, 76), (70, 150, 60), (120, 200, 90)])
        for ox in (-128, 0, 128):
            d.polygon([(x + ox - 2.5, 20), (x + ox + 2.5, 20), (x + ox + r.uniform(-2, 2), 20 + hh)], fill=col + (255,))
    d.rectangle([0, 0, 128, 5], fill=(140, 214, 100, 255))
    top.save(os.path.join(T, "pradera_top.png"))
    plat = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(plat)
    d.rounded_rectangle([0, 2, 127, 30], radius=6, fill=(178, 128, 80, 255))
    d.rectangle([0, 2, 127, 9], fill=(214, 166, 110, 255))
    for x in (31, 63, 95):
        d.line([(x, 10), (x, 28)], fill=(130, 90, 56, 255), width=2)
    d.line([(0, 24), (127, 24)], fill=(150, 104, 66, 255), width=1)
    plat.save(os.path.join(T, "pradera_plat.png"))

    # Cósmico (metal)
    body = tile(128, 128, (50, 56, 84), 11, 4)
    d = ImageDraw.Draw(body)
    d.rectangle([0, 0, 127, 1], fill=(80, 90, 130, 255))
    d.rectangle([62, 0, 64, 127], fill=(38, 42, 64, 255))
    for p in ((10, 10), (118, 10), (10, 118), (118, 118), (54, 64), (74, 64)):
        d.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], fill=(110, 120, 160, 255))
    body.save(os.path.join(T, "cosmos_body.png"))
    top = tile(128, 64, (50, 56, 84), 12, 4)
    d = ImageDraw.Draw(top)
    d.rectangle([0, 0, 128, 16], fill=(150, 160, 204, 255))
    d.rectangle([0, 0, 128, 4], fill=(216, 226, 255, 255))
    d.rectangle([0, 17, 128, 22], fill=(90, 240, 255, 255))
    d.rectangle([0, 23, 128, 26], fill=(40, 120, 150, 255))
    top.save(os.path.join(T, "cosmos_top.png"))
    plat = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(plat)
    d.rounded_rectangle([0, 2, 127, 30], radius=8, fill=(70, 78, 124, 255))
    d.rectangle([4, 3, 123, 7], fill=(196, 206, 246, 255))
    d.rectangle([6, 22, 121, 25], fill=(90, 240, 255, 255))
    plat.save(os.path.join(T, "cosmos_plat.png"))

    # Ciudad
    brick = Image.new("RGBA", (128, 128), (150, 70, 60, 255))
    d = ImageDraw.Draw(brick)
    for row in range(8):
        y = row * 16
        off = 0 if row % 2 == 0 else 16
        for x in range(-32, 128, 32):
            c = (150 + r.randint(-18, 18), 72 + r.randint(-10, 10), 60 + r.randint(-8, 8), 255)
            d.rounded_rectangle([x + off + 1, y + 1, x + off + 30, y + 14], radius=2, fill=c)
    brick.save(os.path.join(T, "ciudad_body.png"))
    top = brick.crop((0, 0, 128, 64)).copy()
    d = ImageDraw.Draw(top)
    d.rectangle([0, 0, 128, 20], fill=(156, 156, 168, 255))
    d.rectangle([0, 0, 128, 5], fill=(208, 208, 220, 255))
    d.rectangle([0, 20, 128, 25], fill=(96, 96, 108, 255))
    top.save(os.path.join(T, "ciudad_top.png"))
    plat = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(plat)
    d.rectangle([0, 2, 127, 8], fill=(236, 176, 44, 255))
    d.rectangle([0, 24, 127, 30], fill=(196, 136, 34, 255))
    for x in range(0, 128, 32):
        d.line([(x, 8), (x + 16, 24), (x + 32, 8)], fill=(216, 156, 40, 255), width=4)
    d.rectangle([0, 2, 127, 3], fill=(255, 220, 120, 255))
    plat.save(os.path.join(T, "ciudad_plat.png"))

    # Volcán (basalto con grietas de lava)
    body = tile(128, 128, (46, 36, 40), 21, 8)
    d = ImageDraw.Draw(body)
    for _ in range(5):
        x, y = r.uniform(0, 128), r.uniform(0, 128)
        pts = [(x, y)]
        for k in range(5):
            x += r.uniform(-14, 14)
            y += r.uniform(6, 16)
            pts.append((x, y))
        for ox in (-128, 0, 128):
            for oy in (-128, 0):
                d.line([(p[0] + ox, p[1] + oy) for p in pts], fill=(255, 110, 30, 255), width=3)
    body = comp(glow(body, 3, 1.0), body)
    body.save(os.path.join(T, "volcan_body.png"))
    top = body.crop((0, 0, 128, 64)).copy()
    d = ImageDraw.Draw(top)
    d.rectangle([0, 0, 128, 18], fill=(70, 56, 58, 255))
    d.rectangle([0, 0, 128, 4], fill=(110, 90, 88, 255))
    for i in range(20):
        x = r.uniform(0, 128)
        d.ellipse([x - 6, 14, x + 6, 22], fill=(58, 46, 48, 255))
    top.save(os.path.join(T, "volcan_top.png"))
    plat = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(plat)
    d.rounded_rectangle([0, 2, 127, 30], radius=10, fill=(60, 48, 52, 255))
    d.rectangle([6, 3, 121, 7], fill=(110, 90, 88, 255))
    d.line([(10, 26), (40, 20), (70, 26), (110, 21)], fill=(255, 120, 40, 255), width=2)
    plat.save(os.path.join(T, "volcan_plat.png"))

    # Bosque (piedra con musgo)
    body = Image.new("RGBA", (128, 128), (70, 76, 84, 255))
    d = ImageDraw.Draw(body)
    for row in range(4):
        y = row * 32
        off = 0 if row % 2 == 0 else 32
        for x in range(-64, 128, 64):
            c = (78 + r.randint(-10, 10), 84 + r.randint(-10, 10), 92 + r.randint(-10, 10), 255)
            d.rounded_rectangle([x + off + 2, y + 2, x + off + 61, y + 29], radius=6, fill=c)
    pebbles(body, [(70, 110, 60, 255), (60, 96, 52, 255)], 14, 7)
    body.save(os.path.join(T, "bosque_body.png"))
    top = body.crop((0, 0, 128, 64)).copy()
    d = ImageDraw.Draw(top)
    for i in range(40):
        x = r.uniform(-10, 138)
        rr = r.uniform(6, 12)
        d.ellipse([x - rr, 4 - rr * 0.4, x + rr, 12 + rr * 0.6], fill=r.choice([(70, 130, 60), (84, 150, 70),
                                                                                 (60, 112, 52)]) + (255,))
    d.rectangle([0, 0, 128, 4], fill=(110, 170, 90, 255))
    top.save(os.path.join(T, "bosque_top.png"))
    plat = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(plat)
    d.rounded_rectangle([0, 4, 127, 30], radius=12, fill=(110, 78, 52, 255))
    d.line([(0, 16), (127, 16)], fill=(90, 62, 40, 255), width=2)
    d.rounded_rectangle([0, 2, 127, 9], radius=4, fill=(84, 150, 70, 255))
    plat.save(os.path.join(T, "bosque_plat.png"))

    # Nieve
    body = tile(128, 128, (120, 140, 170), 31, 6)
    d = ImageDraw.Draw(body)
    for _ in range(8):
        x, y = r.uniform(0, 128), r.uniform(0, 128)
        for ox in (-128, 0, 128):
            d.polygon([(x + ox, y), (x + ox + 14, y + 6), (x + ox + 6, y + 18)], fill=(170, 200, 230, 255))
    body.save(os.path.join(T, "nieve_body.png"))
    top = body.crop((0, 0, 128, 64)).copy()
    d = ImageDraw.Draw(top)
    d.rectangle([0, 0, 128, 18], fill=(246, 250, 255, 255))
    for i in range(10):
        x = r.uniform(0, 128)
        for ox in (-128, 0, 128):
            d.ellipse([x + ox - 9, 12, x + ox + 9, 24], fill=(246, 250, 255, 255))
            d.polygon([(x + ox - 3, 22), (x + ox + 3, 22), (x + ox, 22 + r.uniform(6, 14))], fill=(210, 236, 255, 255))
    d.rectangle([0, 18, 128, 20], fill=(200, 220, 246, 255))
    top.save(os.path.join(T, "nieve_top.png"))
    plat = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(plat)
    d.rounded_rectangle([0, 3, 127, 30], radius=8, fill=(170, 214, 246, 230))
    d.rounded_rectangle([0, 2, 127, 10], radius=5, fill=(246, 250, 255, 255))
    d.line([(20, 16), (40, 26)], fill=(230, 246, 255, 255), width=2)
    d.line([(80, 14), (96, 24)], fill=(230, 246, 255, 255), width=2)
    plat.save(os.path.join(T, "nieve_plat.png"))


def main():
    for f in (pradera, cosmos, ciudad, volcan, bosque, nieve):
        f()
        print("mapa", f.__name__)
    tiles()
    print("Escenarios generados en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
