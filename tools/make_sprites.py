"""
Generador de sprites (pixel art) para el juego.

Uso (solo si quieres regenerar/modificar los dibujos):
    pip install pillow
    python3 tools/make_sprites.py

Crea en assets/sprites/:
  - char_<id>.png   hoja de sprites de cada personaje (6 columnas x 8 filas de 64x64)
  - proj_<id>.png   proyectil animado (4 frames de 16x16)
  - tile_*.png      texturas del escenario
  - background.png  fondo
Puedes reemplazar cualquiera de estos PNG por tus propios dibujos MIENTRAS respetes
el tamaño y el orden de los cuadros (mira docs/GUIA_PASO_A_PASO.md).
"""
import math
import os
import random

from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
FRAME = 64
OX, OY = 12, 16  # desplazamiento del personaje dentro del cuadro (deja margen para efectos)
COLS = 6
OUTLINE = (24, 20, 38, 255)
WHITE = (255, 255, 255, 255)
BLACK = (20, 16, 30, 255)

# Filas de la hoja (nombre, cantidad de cuadros). El orden DEBE coincidir con fighter.gd.
ANIMS = [
    ("idle", 4),
    ("run", 6),
    ("jump", 1),
    ("fall", 1),
    ("attack", 5),
    ("special", 4),
    ("hurt", 1),
    ("shield", 1),
]

CHARACTERS = {
    "rojo": dict(
        skin=(246, 200, 160, 255), hair=(214, 64, 40, 255), hair_style="spiky",
        top=(240, 240, 236, 255), pants=(60, 70, 140, 255), shoes=(150, 70, 40, 255),
        accent=(220, 40, 50, 255), glow=(255, 150, 40, 255),
        torso_w=12, head_r=9, eye=(30, 30, 40, 255),
    ),
    "azul": dict(
        skin=(240, 196, 168, 255), hair=(70, 150, 240, 255), hair_style="ponytail",
        top=(40, 52, 96, 255), pants=(32, 38, 70, 255), shoes=(220, 220, 240, 255),
        accent=(90, 220, 240, 255), glow=(120, 230, 255, 255),
        torso_w=10, head_r=9, eye=(20, 30, 60, 255),
    ),
    "verde": dict(
        skin=(120, 190, 90, 255), hair=(60, 40, 30, 255), hair_style="horns",
        top=(130, 90, 50, 255), pants=(90, 60, 40, 255), shoes=(60, 40, 30, 255),
        accent=(240, 210, 80, 255), glow=(170, 255, 90, 255),
        torso_w=16, head_r=10, eye=(40, 20, 10, 255),
    ),
}


# ---------------------------------------------------------------- utilidades de dibujo
def circle(d, c, r, col):
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=col)


def limb(d, a, b, bend, w, col, end_col=None, end_r=None):
    """Dibuja una extremidad de 2 segmentos (a -> rodilla/codo -> b)."""
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1
    px, py = -dy / n, dx / n
    k = (mx + px * bend, my + py * bend)
    d.line([a, k], fill=col, width=w)
    d.line([k, b], fill=col, width=w)
    circle(d, k, w / 2 - 0.2, col)
    circle(d, a, w / 2 - 0.2, col)
    circle(d, b, (end_r if end_r else w / 2), end_col or col)


def dilate_outline(img):
    """Agrega un contorno oscuro de 1 pixel alrededor del dibujo."""
    px = img.load()
    w, h = img.size
    out = img.copy()
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                        opx[x, y] = OUTLINE
                        break
    return out


def shade(col, f):
    return tuple(max(0, min(255, int(c * f))) for c in col[:3]) + (255,)


# ---------------------------------------------------------------- dibujo del personaje
def draw_character(ch, pose):
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    bob = pose.get("bob", 0)
    lean = pose.get("lean", 0)
    tw = ch["torso_w"]
    hr = ch["head_r"]
    hip = (24 + OX, 33 + bob + OY)
    neck = (24 + lean + OX, 22 + bob + OY)
    shoulder = (24 + lean + OX, 24 + bob + OY)
    head = (25 + lean + pose.get("head_dx", 0), neck[1] - hr + 3 + pose.get("head_dy", 0))

    def foot(key):
        fx, fy = pose[key]
        return (hip[0] + fx, hip[1] + fy)

    def hand(key):
        hx, hy = pose[key]
        return (shoulder[0] + hx, shoulder[1] + hy)

    arm_w = 4 if tw < 15 else 5
    leg_w = 5 if tw < 15 else 6

    # --- brazo de atrás y pierna de atrás
    limb(d, (shoulder[0] - 2, shoulder[1]), hand("handB"), pose.get("elbowB", -2), arm_w,
         shade(ch["skin"], 0.85), shade(ch["skin"], 0.85), arm_w / 2 + 0.8)
    limb(d, (hip[0] - 2, hip[1]), foot("footB"), pose.get("kneeB", 3), leg_w,
         shade(ch["pants"], 0.8))
    fb = foot("footB")
    d.ellipse([fb[0] - 3, fb[1] - 2, fb[0] + 4, fb[1] + 2], fill=shade(ch["shoes"], 0.8))

    # --- detalles de atrás (coleta, bufanda)
    if ch["hair_style"] == "ponytail":
        sway = pose.get("tail", 0)
        base = (head[0] - hr + 2, head[1] - 2)
        d.line([base, (base[0] - 5, base[1] + 2 + sway), (base[0] - 9, base[1] + 8 + sway)],
               fill=ch["hair"], width=4)
        circle(d, (base[0] - 9, base[1] + 8 + sway), 2.2, ch["hair"])
        # bufanda
        sc = pose.get("scarf", 0)
        d.polygon([(neck[0] - 4, neck[1]), (neck[0] - 14, neck[1] + 3 + sc),
                   (neck[0] - 13, neck[1] + 6 + sc), (neck[0] - 3, neck[1] + 4)],
                  fill=ch["accent"])

    # --- torso
    top_l, top_r = neck[0] - tw / 2, neck[0] + tw / 2
    bot_l, bot_r = hip[0] - tw / 2 + 1, hip[0] + tw / 2 - 1
    d.polygon([(top_l, neck[1]), (top_r, neck[1]), (bot_r, hip[1] + 1), (bot_l, hip[1] + 1)],
              fill=ch["top"])
    # sombra lateral
    d.polygon([(top_l, neck[1]), (top_l + 3, neck[1]), (bot_l + 3, hip[1] + 1), (bot_l, hip[1] + 1)],
              fill=shade(ch["top"], 0.82))
    # cinturón
    d.rectangle([bot_l, hip[1] - 2, bot_r, hip[1]], fill=ch["accent"])
    # pantalón (cadera)
    d.rectangle([bot_l, hip[1] + 1, bot_r, hip[1] + 4], fill=ch["pants"])

    # --- pierna de adelante
    limb(d, (hip[0] + 2, hip[1]), foot("footF"), pose.get("kneeF", 3), leg_w, ch["pants"])
    ff = foot("footF")
    d.ellipse([ff[0] - 3, ff[1] - 2, ff[0] + 5, ff[1] + 2], fill=ch["shoes"])

    # --- cabeza
    hx, hy = head
    d.ellipse([hx - hr, hy - hr + 1, hx + hr, hy + hr - 1], fill=ch["skin"])
    style = ch["hair_style"]
    if style == "spiky":
        pts = [(hx - hr, hy + 1), (hx - hr - 4, hy - 6), (hx - 6, hy - 5), (hx - 8, hy - hr - 6),
               (hx - 1, hy - hr + 1), (hx + 2, hy - hr - 7), (hx + 5, hy - hr + 1),
               (hx + hr + 1, hy - hr - 2), (hx + hr - 1, hy - 3), (hx + 4, hy - 4), (hx - 2, hy - 2)]
        d.polygon(pts, fill=ch["hair"])
        d.rectangle([hx - hr + 1, hy - 4, hx + hr - 1, hy - 2], fill=ch["accent"])  # cinta
        d.polygon([(hx - hr + 1, hy - 4), (hx - hr - 7, hy - 2 + pose.get("tail", 0)),
                   (hx - hr - 6, hy + 1 + pose.get("tail", 0)), (hx - hr + 1, hy - 2)],
                  fill=ch["accent"])
    elif style == "ponytail":
        d.pieslice([hx - hr - 1, hy - hr, hx + hr + 1, hy + hr], 180, 360, fill=ch["hair"])
        d.polygon([(hx - hr, hy - 1), (hx - hr + 3, hy - 2), (hx - hr + 4, hy + 5), (hx - hr, hy + 4)],
                  fill=ch["hair"])
        d.polygon([(hx + 1, hy - hr + 1), (hx + hr + 1, hy - 3), (hx + 3, hy - 3)], fill=ch["hair"])
    elif style == "horns":
        d.polygon([(hx - 7, hy - hr + 3), (hx - 10, hy - hr - 6), (hx - 3, hy - hr + 1)],
                  fill=(240, 235, 210, 255))
        d.polygon([(hx + 2, hy - hr + 1), (hx + 7, hy - hr - 7), (hx + 8, hy - hr + 3)],
                  fill=(240, 235, 210, 255))
        d.pieslice([hx - hr, hy - hr + 1, hx + hr, hy + hr], 195, 345, fill=ch["hair"])

    # --- cara
    ex = hx + 2
    ey = hy - 1
    if pose.get("hurt"):
        for ox in (0, 5):
            d.line([(ex + ox - 1, ey - 2), (ex + ox + 2, ey + 1)], fill=ch["eye"], width=1)
            d.line([(ex + ox + 2, ey - 2), (ex + ox - 1, ey + 1)], fill=ch["eye"], width=1)
        d.ellipse([ex + 2, ey + 4, ex + 5, ey + 7], fill=(120, 30, 40, 255))
    else:
        for ox in (0, 5):
            d.rectangle([ex + ox, ey - 2, ex + ox + 1, ey + 1], fill=WHITE)
            d.rectangle([ex + ox + 1, ey - 1, ex + ox + 1, ey + 1], fill=ch["eye"])
        d.line([(ex + 1, ey + 5), (ex + 5, ey + 5)], fill=(150, 60, 60, 255), width=1)
        if style == "horns":  # colmillos
            d.rectangle([ex + 1, ey + 3, ex + 1, ey + 4], fill=WHITE)
            d.rectangle([ex + 5, ey + 3, ex + 5, ey + 4], fill=WHITE)

    # --- brazo de adelante
    limb(d, shoulder, hand("handF"), pose.get("elbowF", 3), arm_w, ch["skin"], ch["skin"],
         arm_w / 2 + 1)
    # manga
    d.ellipse([shoulder[0] - 3, shoulder[1] - 3, shoulder[0] + 3, shoulder[1] + 3], fill=ch["top"])

    # --- efectos
    fx = pose.get("effect")
    if fx == "slash":
        hxp, hyp = hand("handF")
        c = ch["glow"]
        pts = []
        for a in range(-70, 71, 14):
            r = 13 + pose.get("slash_r", 0)
            pts.append((hxp - 2 + math.cos(math.radians(a)) * r, hyp + math.sin(math.radians(a)) * r))
        inner = []
        for a in range(70, -71, -14):
            r = 8 + pose.get("slash_r", 0)
            inner.append((hxp - 2 + math.cos(math.radians(a)) * r, hyp + math.sin(math.radians(a)) * r))
        d.polygon(pts + inner, fill=(255, 255, 255, 235))
        d.line(pts, fill=c, width=2)
    orb = pose.get("orb", 0)
    if orb:
        ox, oy = hand("handF")
        ox += 4
        circle(d, (ox, oy), orb + 2, shade(ch["glow"], 0.9))
        circle(d, (ox, oy), orb, (255, 255, 255, 255))
        circle(d, (ox, oy), max(1, orb - 2), ch["glow"])
    return dilate_outline(img)


def stance(footF, footB, handF, handB, **extra):
    p = dict(footF=footF, footB=footB, handF=handF, handB=handB)
    p.update(extra)
    return p


def build_poses():
    poses = {}
    # idle
    idle = []
    for i, (bob, hy) in enumerate([(0, 3), (0, 2), (1, 1), (1, 2)]):
        idle.append(stance((6, 12 - bob), (-5, 12 - bob), (8, hy + 1), (2, 6 + (i % 2)),
                           bob=bob, tail=[0, 1, 2, 1][i], scarf=[0, 1, 2, 1][i]))
    poses["idle"] = idle
    # run
    run = []
    for i in range(6):
        p = i / 6.0 * math.tau
        s, c = math.sin(p), math.cos(p)
        run.append(stance(
            (s * 9 + 1, 12 - max(0, c) * 5), (-s * 9 + 1, 12 - max(0, -c) * 5),
            (-s * 7 + 4, 5 - abs(c) * 2), (s * 7 + 2, 5 - abs(c) * 2),
            lean=3, bob=round(abs(s) * 1.2), tail=round(c * 2), scarf=round(-c * 2),
            kneeF=-3, kneeB=-3, elbowF=-3, elbowB=-3))
    poses["run"] = run
    poses["jump"] = [stance((7, 8), (-1, 10), (9, -8), (-5, -5), bob=-2, tail=-3, scarf=-3,
                            kneeF=-5, kneeB=4)]
    poses["fall"] = [stance((8, 12), (-7, 11), (11, -2), (-9, -1), bob=0, tail=-4, scarf=-4)]
    poses["attack"] = [
        stance((9, 12), (-6, 12), (-4, 4), (-2, 6), lean=-2, elbowF=-4),
        stance((9, 12), (-6, 12), (13, 1), (-3, 5), lean=3, effect="slash", slash_r=-3),
        stance((10, 12), (-7, 12), (17, 0), (-4, 5), lean=4, effect="slash", slash_r=1),
        stance((10, 12), (-7, 12), (17, 1), (-4, 5), lean=4, effect="slash", slash_r=3),
        stance((8, 12), (-5, 12), (9, 3), (0, 6), lean=1),
    ]
    poses["special"] = [
        stance((8, 12), (-6, 12), (-5, 3), (-6, 4), lean=-2, bob=1),
        stance((8, 12), (-6, 12), (8, 4), (6, 5), lean=0, orb=3),
        stance((9, 12), (-7, 12), (13, 2), (11, 3), lean=3, orb=5),
        stance((9, 12), (-6, 12), (15, 1), (13, 2), lean=3),
    ]
    poses["hurt"] = [stance((6, 9), (-6, 11), (8, -8), (-4, -6), lean=-4, head_dx=-2, hurt=True,
                            bob=-1, tail=-3, scarf=-3, kneeF=-4)]
    poses["shield"] = [stance((8, 12), (-7, 12), (7, 2), (6, 4), lean=2, bob=3, kneeF=-6, kneeB=-6)]
    return poses


def make_character(cid, ch):
    poses = build_poses()
    sheet = Image.new("RGBA", (FRAME * COLS, FRAME * len(ANIMS)), (0, 0, 0, 0))
    for row, (name, n) in enumerate(ANIMS):
        for col in range(n):
            frame = draw_character(ch, poses[name][col])
            sheet.paste(frame, (col * FRAME, row * FRAME))
    sheet.save(os.path.join(OUT_DIR, f"char_{cid}.png"))
    return sheet


# ---------------------------------------------------------------- proyectiles
def make_projectile(cid, ch):
    sheet = Image.new("RGBA", (16 * 4, 16), (0, 0, 0, 0))
    for i in range(4):
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        wob = [0, 1, 0, -1][i]
        # estela
        for k in range(3):
            circle(d, (5 - k * 2 - wob, 8), 3 - k, shade(ch["glow"], 0.75 - k * 0.15))
        circle(d, (9, 8), 5 + wob * 0.6, shade(ch["glow"], 0.9))
        circle(d, (9, 8), 3.4, (255, 255, 255, 255))
        d.point([(11, 6)], fill=ch["glow"])
        img = dilate_outline(img)
        sheet.paste(img, (i * 16, 0))
    sheet.save(os.path.join(OUT_DIR, f"proj_{cid}.png"))


# ---------------------------------------------------------------- escenario
def noise_tile(base, size=32, seed=1, amount=14, dots=None):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size, size), base)
    px = img.load()
    for y in range(size):
        for x in range(size):
            v = rnd.randint(-amount, amount)
            px[x, y] = tuple(max(0, min(255, base[i] + v)) for i in range(3)) + (255,)
    if dots:
        d = ImageDraw.Draw(img)
        for _ in range(dots[1]):
            x, y = rnd.randint(1, size - 3), rnd.randint(1, size - 3)
            d.rectangle([x, y, x + 2, y + 1], fill=dots[0])
    return img


def make_tiles():
    dirt = noise_tile((120, 82, 56, 255), seed=3, amount=8, dots=((92, 60, 42, 255), 14))
    dirt.save(os.path.join(OUT_DIR, "tile_dirt.png"))

    grass = dirt.copy()
    d = ImageDraw.Draw(grass)
    d.rectangle([0, 0, 31, 9], fill=(92, 176, 70, 255))
    rnd = random.Random(5)
    for x in range(0, 32, 2):
        h = rnd.randint(9, 13)
        d.rectangle([x, 8, x + 1, h], fill=(92, 176, 70, 255))
    d.rectangle([0, 0, 31, 3], fill=(130, 214, 96, 255))
    d.rectangle([0, 9, 31, 9], fill=(60, 130, 52, 255))
    for x in range(1, 32, 7):
        d.rectangle([x, 5, x, 6], fill=(70, 150, 58, 255))
    grass.save(os.path.join(OUT_DIR, "tile_grass.png"))

    plat = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(plat)
    d.rectangle([0, 0, 31, 15], fill=(176, 130, 84, 255))
    d.rectangle([0, 0, 31, 3], fill=(214, 168, 112, 255))
    d.rectangle([0, 13, 31, 15], fill=(120, 84, 56, 255))
    d.line([(15, 4), (15, 12)], fill=(120, 84, 56, 255), width=1)
    d.line([(0, 4), (31, 4)], fill=(140, 100, 64, 255), width=1)
    plat.save(os.path.join(OUT_DIR, "tile_platform.png"))


def make_background():
    w, h = 640, 360
    img = Image.new("RGBA", (w, h))
    px = img.load()
    top, bot = (92, 160, 240), (200, 232, 250)
    for y in range(h):
        t = y / h
        for x in range(w):
            px[x, y] = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
    d = ImageDraw.Draw(img)
    circle(d, (500, 70), 30, (255, 244, 180, 255))
    circle(d, (500, 70), 22, (255, 252, 220, 255))
    rnd = random.Random(7)
    for _ in range(9):
        cx, cy = rnd.randint(20, 620), rnd.randint(30, 170)
        for k in range(4):
            circle(d, (cx + k * 14, cy + rnd.randint(-4, 4)), rnd.randint(10, 16), (255, 255, 255, 255))
        d.rectangle([cx - 10, cy + 6, cx + 4 * 14, cy + 12], fill=(255, 255, 255, 255))
    # montañas lejanas
    def range_poly(base_y, amp, col, seed):
        r = random.Random(seed)
        pts = [(0, h)]
        x = 0
        while x <= w + 40:
            pts.append((x, base_y - r.randint(0, amp)))
            x += r.randint(40, 80)
        pts.append((w, h))
        d.polygon(pts, fill=col)
    range_poly(250, 70, (140, 170, 210, 255), 11)
    range_poly(290, 50, (104, 150, 180, 255), 12)
    range_poly(330, 30, (80, 136, 120, 255), 13)
    img.save(os.path.join(OUT_DIR, "background.png"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for cid, ch in CHARACTERS.items():
        make_character(cid, ch)
        make_projectile(cid, ch)
    make_tiles()
    make_background()
    print("Sprites generados en", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
