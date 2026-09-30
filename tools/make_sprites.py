"""
Generador de sprites (pixel art) para el juego.

Uso (solo si quieres regenerar/modificar los dibujos):
    pip install pillow
    python3 tools/make_sprites.py

Crea en assets/sprites/:
  - char_<id>.png   hoja de sprites de cada personaje (6 columnas x 13 filas de 64x64)
  - proj_<id>.png   proyectil animado (4 frames de 16x16)
  - item_*.png      objetos (bate, arco, flecha)
  - tile_*.png      texturas de los escenarios
  - bg_*.png        fondos de los escenarios
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
WHITE = (255, 255, 255, 255)

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
    ("crouch", 2),
    ("taunt", 4),
    ("win", 6),
    ("ledge", 1),
    ("upspecial", 2),
]

CHARACTERS = {
    "rojo": dict(
        skin=(246, 200, 160), hair=(222, 70, 44), hair_style="spiky",
        top=(244, 244, 240), pants=(58, 72, 150), shoes=(160, 76, 44),
        accent=(226, 44, 56), glow=(255, 150, 40),
        torso_w=12, head_r=9, eye=(30, 30, 40), taunt="flex",
    ),
    "azul": dict(
        skin=(240, 196, 168), hair=(76, 156, 246), hair_style="ponytail",
        top=(44, 58, 108), pants=(34, 40, 76), shoes=(226, 226, 244),
        accent=(92, 224, 244), glow=(130, 236, 255),
        torso_w=10, head_r=9, eye=(20, 30, 60), taunt="sign",
    ),
    "verde": dict(
        skin=(126, 196, 94), hair=(64, 42, 30), hair_style="horns",
        top=(138, 94, 54), pants=(92, 62, 40), shoes=(62, 42, 30),
        accent=(244, 214, 84), glow=(170, 255, 90),
        torso_w=16, head_r=10, eye=(40, 20, 10), taunt="pound",
    ),
    "morado": dict(
        skin=(40, 30, 60), hair=(96, 56, 150), hair_style="hood",
        top=(74, 44, 118), pants=(44, 30, 70), shoes=(30, 22, 44),
        accent=(190, 120, 255), glow=(200, 130, 255),
        torso_w=12, head_r=9, eye=(235, 200, 255), taunt="float", cloak=True,
    ),
}


def rgba(c, a=255):
    return tuple(int(v) for v in c[:3]) + (a,)


def shade(col, f):
    return tuple(max(0, min(255, int(c * f))) for c in col[:3]) + (255,)


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


def light_pass(img):
    """Sombreado moderno: luz arriba-derecha, sombra abajo-izquierda."""
    px = img.load()
    w, h = img.size
    src = img.copy().load()
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if p[3] == 0:
                continue
            up = src[x, y - 1][3] if y > 0 else 0
            right = src[x + 1, y][3] if x < w - 1 else 0
            down = src[x, y + 1][3] if y < h - 1 else 0
            left = src[x - 1, y][3] if x > 0 else 0
            f = 1.0
            if up == 0 or right == 0:
                f = 1.22
            elif down == 0 or left == 0:
                f = 0.78
            if f != 1.0:
                px[x, y] = tuple(max(0, min(255, int(c * f + (12 if f > 1 else 0)))) for c in p[:3]) + (p[3],)
    return img


def outline(img):
    """Contorno de color (más oscuro que el pixel vecino), estilo pixel art moderno."""
    px = img.load()
    w, h = img.size
    out = img.copy()
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                        n = px[nx, ny]
                        opx[x, y] = (int(n[0] * 0.25) + 10, int(n[1] * 0.22) + 8, int(n[2] * 0.3) + 18, 255)
                        break
    return out


def finish(img):
    return outline(light_pass(img))


# ---------------------------------------------------------------- dibujo del personaje
def draw_character(ch, pose):
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin, hair, top, pants, shoes = (rgba(ch[k]) for k in ("skin", "hair", "top", "pants", "shoes"))
    accent, glow, eye = rgba(ch["accent"]), rgba(ch["glow"]), rgba(ch["eye"])

    bob = pose.get("bob", 0)
    lean = pose.get("lean", 0)
    tw = ch["torso_w"]
    hr = ch["head_r"]
    hip = (24 + OX, 33 + bob + OY)
    neck = (24 + lean + OX, 22 + bob + OY)
    shoulder = (24 + lean + OX, 24 + bob + OY)
    head = (25 + lean + OX + pose.get("head_dx", 0), neck[1] - hr + 3 + pose.get("head_dy", 0))

    def foot(key):
        fx, fy = pose[key]
        return (hip[0] + fx, hip[1] + fy)

    def hand(key):
        hx, hy = pose[key]
        return (shoulder[0] + hx, shoulder[1] + hy)

    arm_w = 4 if tw < 15 else 5
    leg_w = 5 if tw < 15 else 6
    hand_col = accent if ch.get("cloak") else skin

    # --- capa (detrás de todo)
    if ch.get("cloak"):
        fl = pose.get("scarf", 0)
        d.polygon([(neck[0] - 5, neck[1]), (neck[0] + 4, neck[1]), (hip[0] + 4, hip[1] + 10),
                   (hip[0] - 14 - fl, hip[1] + 12 + fl // 2), (hip[0] - 10, hip[1] + 4)], fill=shade(top, 0.7))

    # --- brazo de atrás y pierna de atrás
    limb(d, (shoulder[0] - 2, shoulder[1]), hand("handB"), pose.get("elbowB", -2), arm_w,
         shade(top if ch.get("cloak") else skin, 0.8), shade(hand_col, 0.8), arm_w / 2 + 0.8)
    limb(d, (hip[0] - 2, hip[1]), foot("footB"), pose.get("kneeB", 3), leg_w, shade(pants, 0.78))
    fb = foot("footB")
    d.ellipse([fb[0] - 3, fb[1] - 2, fb[0] + 4, fb[1] + 2], fill=shade(shoes, 0.78))

    # --- detalles de atrás (coleta, bufanda)
    if ch["hair_style"] == "ponytail":
        sway = pose.get("tail", 0)
        base = (head[0] - hr + 2, head[1] - 2)
        d.line([base, (base[0] - 5, base[1] + 2 + sway), (base[0] - 9, base[1] + 8 + sway)], fill=hair, width=4)
        circle(d, (base[0] - 9, base[1] + 8 + sway), 2.2, hair)
        sc = pose.get("scarf", 0)
        d.polygon([(neck[0] - 4, neck[1]), (neck[0] - 15, neck[1] + 3 + sc),
                   (neck[0] - 14, neck[1] + 6 + sc), (neck[0] - 3, neck[1] + 4)], fill=accent)

    # --- torso
    top_l, top_r = neck[0] - tw / 2, neck[0] + tw / 2
    bot_l, bot_r = hip[0] - tw / 2 + 1, hip[0] + tw / 2 - 1
    d.polygon([(top_l, neck[1]), (top_r, neck[1]), (bot_r, hip[1] + 1), (bot_l, hip[1] + 1)], fill=top)
    d.polygon([(top_l, neck[1]), (top_l + 3, neck[1]), (bot_l + 3, hip[1] + 1), (bot_l, hip[1] + 1)],
              fill=shade(top, 0.8))
    if ch.get("cloak"):
        d.line([(neck[0] + 1, neck[1] + 1), (hip[0] + 1, hip[1])], fill=accent, width=1)
    else:
        d.rectangle([bot_l, hip[1] - 2, bot_r, hip[1]], fill=accent)
    d.rectangle([bot_l, hip[1] + 1, bot_r, hip[1] + 4], fill=pants)

    # --- pierna de adelante
    limb(d, (hip[0] + 2, hip[1]), foot("footF"), pose.get("kneeF", 3), leg_w, pants)
    ff = foot("footF")
    d.ellipse([ff[0] - 3, ff[1] - 2, ff[0] + 5, ff[1] + 2], fill=shoes)

    def front_arm():
        limb(d, shoulder, hand("handF"), pose.get("elbowF", 3), arm_w, top if ch.get("cloak") else skin,
             hand_col, arm_w / 2 + 1)
        d.ellipse([shoulder[0] - 3, shoulder[1] - 3, shoulder[0] + 3, shoulder[1] + 3], fill=top)

    # brazo levantado: se dibuja detrás de la cabeza para no tapar la cara
    arm_behind = pose["handF"][1] < -6
    if arm_behind:
        front_arm()

    # --- cabeza
    hx, hy = head
    d.ellipse([hx - hr, hy - hr + 1, hx + hr, hy + hr - 1], fill=skin)
    style = ch["hair_style"]
    if style == "spiky":
        pts = [(hx - hr, hy + 1), (hx - hr - 4, hy - 6), (hx - 6, hy - 5), (hx - 8, hy - hr - 6),
               (hx - 1, hy - hr + 1), (hx + 2, hy - hr - 7), (hx + 5, hy - hr + 1),
               (hx + hr + 1, hy - hr - 2), (hx + hr - 1, hy - 3), (hx + 4, hy - 4), (hx - 2, hy - 2)]
        d.polygon(pts, fill=hair)
        d.rectangle([hx - hr + 1, hy - 4, hx + hr - 1, hy - 2], fill=accent)
        t = pose.get("tail", 0)
        d.polygon([(hx - hr + 1, hy - 4), (hx - hr - 7, hy - 2 + t), (hx - hr - 6, hy + 1 + t),
                   (hx - hr + 1, hy - 2)], fill=accent)
    elif style == "ponytail":
        d.pieslice([hx - hr - 1, hy - hr, hx + hr + 1, hy + hr], 180, 360, fill=hair)
        d.polygon([(hx - hr, hy - 1), (hx - hr + 3, hy - 2), (hx - hr + 4, hy + 5), (hx - hr, hy + 4)], fill=hair)
        d.polygon([(hx + 1, hy - hr + 1), (hx + hr + 1, hy - 3), (hx + 3, hy - 3)], fill=hair)
    elif style == "horns":
        horn = (240, 235, 210, 255)
        d.polygon([(hx - 7, hy - hr + 3), (hx - 10, hy - hr - 6), (hx - 3, hy - hr + 1)], fill=horn)
        d.polygon([(hx + 2, hy - hr + 1), (hx + 7, hy - hr - 7), (hx + 8, hy - hr + 3)], fill=horn)
        d.pieslice([hx - hr, hy - hr + 1, hx + hr, hy + hr], 195, 345, fill=hair)
    elif style == "hood":
        d.polygon([(hx - hr - 2, hy + hr - 1), (hx - hr - 3, hy - 2), (hx - 4, hy - hr - 4),
                   (hx + 4, hy - hr - 2), (hx + hr + 2, hy - 3), (hx + hr + 1, hy + 2),
                   (hx + 4, hy - 4), (hx - 2, hy + 1), (hx - 3, hy + hr)], fill=hair)
        d.line([(hx - 4, hy - hr - 3), (hx + hr, hy - 3)], fill=shade(hair, 1.3), width=1)

    # --- cara
    ex = hx + 2
    ey = hy - 1
    if style == "hood":
        glow_eye = pose.get("hurt") and (255, 120, 160, 255) or eye
        for ox in (1, 6):
            d.rectangle([ex + ox, ey - 1, ex + ox + 1, ey], fill=glow_eye)
    elif pose.get("hurt"):
        for ox in (0, 5):
            d.line([(ex + ox - 1, ey - 2), (ex + ox + 2, ey + 1)], fill=eye, width=1)
            d.line([(ex + ox + 2, ey - 2), (ex + ox - 1, ey + 1)], fill=eye, width=1)
        d.ellipse([ex + 2, ey + 4, ex + 5, ey + 7], fill=(120, 30, 40, 255))
    else:
        happy = pose.get("happy")
        for ox in (0, 5):
            if happy:
                d.line([(ex + ox - 1, ey), (ex + ox, ey - 2), (ex + ox + 2, ey)], fill=eye, width=1)
            else:
                d.rectangle([ex + ox, ey - 2, ex + ox + 1, ey + 1], fill=WHITE)
                d.rectangle([ex + ox + 1, ey - 1, ex + ox + 1, ey + 1], fill=eye)
        if happy:
            d.pieslice([ex + 1, ey + 2, ex + 7, ey + 8], 0, 180, fill=(150, 40, 50, 255))
        else:
            d.line([(ex + 1, ey + 5), (ex + 5, ey + 5)], fill=(150, 60, 60, 255), width=1)
        if style == "horns":
            d.rectangle([ex + 1, ey + 3, ex + 1, ey + 4], fill=WHITE)
            d.rectangle([ex + 5, ey + 3, ex + 5, ey + 4], fill=WHITE)

    # --- brazo de adelante
    if not arm_behind:
        front_arm()

    # --- efectos
    fx = pose.get("effect")
    if fx == "slash":
        hxp, hyp = hand("handF")
        outer, inner = [], []
        for a in range(-70, 71, 14):
            r = 13 + pose.get("slash_r", 0)
            outer.append((hxp - 2 + math.cos(math.radians(a)) * r, hyp + math.sin(math.radians(a)) * r))
        for a in range(70, -71, -14):
            r = 8 + pose.get("slash_r", 0)
            inner.append((hxp - 2 + math.cos(math.radians(a)) * r, hyp + math.sin(math.radians(a)) * r))
        d.polygon(outer + inner, fill=(255, 255, 255, 235))
        d.line(outer, fill=glow, width=2)
    elif fx == "sparkle":
        for (sx, sy) in pose.get("sparks", []):
            d.line([(sx - 2, sy), (sx + 2, sy)], fill=glow, width=1)
            d.line([(sx, sy - 2), (sx, sy + 2)], fill=glow, width=1)
    orb = pose.get("orb", 0)
    if orb:
        ox, oy = hand("handF")
        ox += 4
        circle(d, (ox, oy), orb + 2, shade(glow, 0.9))
        circle(d, (ox, oy), orb, WHITE)
        circle(d, (ox, oy), max(1, orb - 2), glow)
    return finish(img)


def stance(footF, footB, handF, handB, **extra):
    p = dict(footF=footF, footB=footB, handF=handF, handB=handB)
    p.update(extra)
    return p


def taunt_poses(kind):
    if kind == "flex":  # puño en alto
        return [stance((6, 12), (-5, 12), (8, 2), (2, 6)),
                stance((6, 12), (-5, 12), (6, -12), (2, 6), bob=-1, happy=True),
                stance((6, 12), (-5, 12), (7, -14), (-3, 4), bob=-1, happy=True, effect="sparkle",
                        sparks=[(46, 12), (52, 20)]),
                stance((6, 12), (-5, 12), (6, -12), (2, 6), happy=True)]
    if kind == "sign":  # sello ninja
        return [stance((5, 12), (-5, 12), (6, 2), (5, 3)),
                stance((5, 12), (-5, 12), (5, -2), (4, -2), tail=2, scarf=2),
                stance((5, 12), (-5, 12), (5, -3), (4, -3), tail=3, scarf=3, effect="sparkle",
                        sparks=[(44, 26), (50, 18), (40, 16)]),
                stance((5, 12), (-5, 12), (5, -2), (4, -2), tail=1, scarf=1)]
    if kind == "pound":  # golpearse el pecho
        return [stance((8, 12), (-7, 12), (2, 4), (-2, 4), lean=-1),
                stance((8, 12), (-7, 12), (-1, 8), (1, 7), lean=1, happy=True),
                stance((8, 12), (-7, 12), (4, 1), (-4, 2), lean=-1, head_dy=-1, happy=True),
                stance((8, 12), (-7, 12), (-1, 8), (1, 7), lean=1, happy=True)]
    # float: brazos abiertos flotando
    return [stance((4, 10), (-4, 11), (9, 0), (-8, 1), bob=-1, scarf=1),
            stance((4, 9), (-4, 10), (11, -4), (-10, -3), bob=-2, scarf=2, effect="sparkle",
                   sparks=[(50, 20), (22, 22)]),
            stance((4, 8), (-4, 9), (12, -6), (-11, -5), bob=-3, scarf=3, effect="sparkle",
                   sparks=[(52, 16), (20, 18), (36, 8)]),
            stance((4, 9), (-4, 10), (11, -4), (-10, -3), bob=-2, scarf=2)]


def build_poses(ch):
    poses = {}
    idle = []
    for i, (bob, hy) in enumerate([(0, 3), (0, 2), (1, 1), (1, 2)]):
        idle.append(stance((6, 12 - bob), (-5, 12 - bob), (8, hy + 1), (2, 6 + (i % 2)),
                           bob=bob, tail=[0, 1, 2, 1][i], scarf=[0, 1, 2, 1][i]))
    poses["idle"] = idle
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
    poses["jump"] = [stance((7, 8), (-1, 10), (9, -8), (-5, -5), bob=-2, tail=-3, scarf=-3, kneeF=-5, kneeB=4)]
    poses["fall"] = [stance((8, 12), (-7, 11), (11, -2), (-9, -1), tail=-4, scarf=-4)]
    poses["attack"] = [
        stance((9, 12), (-6, 12), (-4, 4), (-2, 6), lean=-2, elbowF=-4),
        stance((9, 12), (-6, 12), (13, 1), (-3, 5), lean=3, effect="slash", slash_r=-3),
        stance((10, 12), (-7, 12), (17, 0), (-4, 5), lean=4, effect="slash", slash_r=1),
        stance((10, 12), (-7, 12), (17, 1), (-4, 5), lean=4, effect="slash", slash_r=3),
        stance((8, 12), (-5, 12), (9, 3), (0, 6), lean=1),
    ]
    poses["special"] = [
        stance((8, 12), (-6, 12), (-5, 3), (-6, 4), lean=-2, bob=1),
        stance((8, 12), (-6, 12), (8, 4), (6, 5), orb=3),
        stance((9, 12), (-7, 12), (13, 2), (11, 3), lean=3, orb=5),
        stance((9, 12), (-6, 12), (15, 1), (13, 2), lean=3),
    ]
    poses["hurt"] = [stance((6, 9), (-6, 11), (8, -8), (-4, -6), lean=-4, head_dx=-2, hurt=True,
                            bob=-1, tail=-3, scarf=-3, kneeF=-4)]
    poses["shield"] = [stance((8, 12), (-7, 12), (7, 2), (6, 4), lean=2, bob=3, kneeF=-6, kneeB=-6)]
    poses["crouch"] = [stance((8, 4), (-7, 4), (8, 4), (3, 6), bob=8, lean=3, kneeF=-7, kneeB=-7),
                       stance((8, 4), (-7, 4), (8, 5), (3, 7), bob=9, lean=3, kneeF=-7, kneeB=-7)]
    poses["taunt"] = taunt_poses(ch["taunt"])
    poses["win"] = [
        stance((7, 8), (-6, 8), (6, 4), (-4, 4), bob=4, kneeF=-6, kneeB=-6, happy=True),
        stance((5, 12), (-4, 12), (7, -16), (-6, -15), bob=-6, happy=True, tail=-3, scarf=-3),
        stance((5, 10), (-4, 11), (9, -17), (-8, -15), bob=-9, happy=True, tail=-4, scarf=-4,
               effect="sparkle", sparks=[(50, 10), (20, 12)]),
        stance((5, 12), (-4, 12), (6, -16), (-5, -15), bob=-5, happy=True, tail=-2, scarf=-2),
        stance((7, 9), (-6, 9), (7, -14), (-6, -13), bob=3, happy=True, kneeF=-5, kneeB=-5),
        stance((6, 12), (-5, 12), (7, -15), (-3, 5), happy=True, effect="sparkle", sparks=[(48, 8)]),
    ]
    poses["ledge"] = [stance((3, 12), (-3, 13), (5, -15), (0, -15), kneeF=-3, kneeB=3, tail=2, scarf=2)]
    poses["upspecial"] = [
        stance((4, 12), (-3, 13), (5, -17), (-4, 3), lean=2, bob=-2, kneeF=-3, tail=4, scarf=4),
        stance((2, 14), (-3, 13), (6, -18), (-5, 5), lean=2, bob=-3, tail=5, scarf=5, effect="sparkle",
               sparks=[(44, 4), (40, 10)]),
    ]
    return poses


def make_character(cid, ch):
    poses = build_poses(ch)
    sheet = Image.new("RGBA", (FRAME * COLS, FRAME * len(ANIMS)), (0, 0, 0, 0))
    for row, (name, n) in enumerate(ANIMS):
        for col in range(n):
            sheet.paste(draw_character(ch, poses[name][col]), (col * FRAME, row * FRAME))
    sheet.save(os.path.join(OUT_DIR, f"char_{cid}.png"))


# ---------------------------------------------------------------- proyectiles
def make_projectile(cid, ch):
    glow = rgba(ch["glow"])
    sheet = Image.new("RGBA", (16 * 4, 16), (0, 0, 0, 0))
    for i in range(4):
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        wob = [0, 1, 0, -1][i]
        if cid == "azul":  # fragmento de hielo
            d.polygon([(15, 8), (8, 5 + wob * 0.5), (2, 8), (8, 11 - wob * 0.5)], fill=glow)
            d.polygon([(14, 8), (8, 6), (8, 8)], fill=WHITE)
        elif cid == "verde":  # roca
            pts = []
            for k in range(8):
                a = k / 8 * math.tau + i * 0.4
                r = 6 + ((k * 7 + i) % 3) * 0.7
                pts.append((8 + math.cos(a) * r, 8 + math.sin(a) * r))
            d.polygon(pts, fill=(140, 120, 100, 255))
            circle(d, (6, 6), 1.5, (180, 165, 150, 255))
            circle(d, (10, 10), 1.2, (100, 86, 72, 255))
        elif cid == "morado":  # orbe de sombra
            circle(d, (8, 8), 6 + wob * 0.4, (60, 30, 90, 255))
            circle(d, (8, 8), 4, glow)
            a = i * math.pi / 2
            d.line([(8, 8), (8 + math.cos(a) * 6, 8 + math.sin(a) * 6)], fill=WHITE, width=1)
        else:  # bola de fuego
            for k in range(3):
                circle(d, (5 - k * 2 - wob, 8), 3 - k, shade(glow, 0.75 - k * 0.15))
            circle(d, (9, 8), 5 + wob * 0.6, shade(glow, 0.9))
            circle(d, (9, 8), 3.4, WHITE)
        sheet.paste(outline(img), (i * 16, 0))
    sheet.save(os.path.join(OUT_DIR, f"proj_{cid}.png"))


# ---------------------------------------------------------------- objetos
def make_items():
    # Bate: 40x12, mango a la izquierda (se agarra por x=4, y=6)
    bat = Image.new("RGBA", (40, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(bat)
    d.polygon([(2, 5), (14, 4), (37, 2), (39, 6), (37, 10), (14, 8), (2, 7)], fill=(214, 170, 110, 255))
    d.line([(14, 4), (37, 2)], fill=(240, 206, 150, 255), width=1)
    d.rectangle([1, 4, 8, 8], fill=(60, 40, 110, 255))
    d.rectangle([0, 4, 1, 8], fill=(90, 70, 140, 255))
    bat = outline(bat)
    bat.save(os.path.join(OUT_DIR, "item_bat.png"))

    # Arco estilo Minecraft: 3 cuadros de 20x28 (quieto, medio tenso, tenso)
    bow = Image.new("RGBA", (20 * 3, 28), (0, 0, 0, 0))
    for i in range(3):
        img = Image.new("RGBA", (20, 28), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        wood, dark = (150, 100, 50, 255), (100, 64, 30, 255)
        pts = [(4, 2), (7, 3), (10, 6), (12, 10), (13, 14), (12, 18), (10, 22), (7, 25), (4, 26)]
        for a, b in zip(pts, pts[1:]):
            d.line([a, b], fill=wood, width=3)
        for p in pts[::2]:
            d.point([p], fill=dark)
        pull = [0, 4, 8][i]
        d.line([(4, 3), (4 - pull, 14), (4, 25)], fill=(230, 230, 230, 255), width=1)
        if i > 0:
            d.line([(4 - pull, 14), (19, 14)], fill=(170, 130, 80, 255), width=1)
            d.polygon([(19, 12), (19, 16), (17, 14)], fill=(200, 200, 210, 255))
        bow.paste(outline(img), (i * 20, 0))
    bow.save(os.path.join(OUT_DIR, "item_bow.png"))

    arrow = Image.new("RGBA", (24, 7), (0, 0, 0, 0))
    d = ImageDraw.Draw(arrow)
    d.line([(3, 3), (19, 3)], fill=(170, 130, 80, 255), width=1)
    d.polygon([(23, 3), (19, 0), (19, 6)], fill=(200, 200, 215, 255))
    d.polygon([(0, 0), (5, 3), (0, 6), (3, 3)], fill=(240, 240, 240, 255))
    outline(arrow).save(os.path.join(OUT_DIR, "item_arrow.png"))


# ---------------------------------------------------------------- escenarios
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


def save(img, name):
    img.save(os.path.join(OUT_DIR, name))


def make_tiles():
    # --- Pradera
    dirt = noise_tile((120, 82, 56, 255), seed=3, amount=8, dots=((92, 60, 42, 255), 14))
    save(dirt, "tile_dirt.png")
    grass = dirt.copy()
    d = ImageDraw.Draw(grass)
    d.rectangle([0, 0, 31, 9], fill=(92, 176, 70, 255))
    rnd = random.Random(5)
    for x in range(0, 32, 2):
        d.rectangle([x, 8, x + 1, rnd.randint(9, 13)], fill=(92, 176, 70, 255))
    d.rectangle([0, 0, 31, 3], fill=(130, 214, 96, 255))
    d.rectangle([0, 9, 31, 9], fill=(60, 130, 52, 255))
    for x in range(1, 32, 7):
        d.rectangle([x, 5, x, 6], fill=(70, 150, 58, 255))
    save(grass, "tile_grass.png")
    plat = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(plat)
    d.rectangle([0, 0, 31, 15], fill=(176, 130, 84, 255))
    d.rectangle([0, 0, 31, 3], fill=(214, 168, 112, 255))
    d.rectangle([0, 13, 31, 15], fill=(120, 84, 56, 255))
    d.line([(15, 4), (15, 12)], fill=(120, 84, 56, 255), width=1)
    d.line([(0, 4), (31, 4)], fill=(140, 100, 64, 255), width=1)
    save(plat, "tile_platform.png")

    # --- Cosmos (metal y luces)
    metal = noise_tile((52, 58, 84, 255), seed=8, amount=5)
    d = ImageDraw.Draw(metal)
    d.rectangle([0, 0, 31, 0], fill=(70, 78, 110, 255))
    d.rectangle([0, 31, 31, 31], fill=(36, 40, 60, 255))
    for p in [(3, 3), (28, 3), (3, 28), (28, 28)]:
        d.point([p], fill=(120, 130, 170, 255))
    save(metal, "tile_metal.png")
    mtop = metal.copy()
    d = ImageDraw.Draw(mtop)
    d.rectangle([0, 0, 31, 7], fill=(150, 160, 200, 255))
    d.rectangle([0, 0, 31, 1], fill=(210, 220, 255, 255))
    d.rectangle([0, 8, 31, 9], fill=(90, 240, 255, 255))
    d.rectangle([0, 10, 31, 10], fill=(40, 120, 150, 255))
    save(mtop, "tile_metal_top.png")
    mplat = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(mplat)
    d.rectangle([0, 0, 31, 15], fill=(70, 78, 120, 255))
    d.rectangle([0, 0, 31, 2], fill=(190, 200, 240, 255))
    d.rectangle([0, 11, 31, 12], fill=(90, 240, 255, 255))
    d.rectangle([0, 13, 31, 15], fill=(40, 44, 70, 255))
    save(mplat, "tile_platform_metal.png")

    # --- Ciudad (azotea)
    brick = Image.new("RGBA", (32, 32), (150, 70, 60, 255))
    d = ImageDraw.Draw(brick)
    rnd = random.Random(21)
    for row in range(4):
        y = row * 8
        off = 0 if row % 2 == 0 else 8
        for x in range(-8, 32, 16):
            c = (150 + rnd.randint(-15, 15), 70 + rnd.randint(-10, 10), 60, 255)
            d.rectangle([x + off, y, x + off + 14, y + 6], fill=c)
    save(brick, "tile_brick.png")
    roof = brick.copy()
    d = ImageDraw.Draw(roof)
    d.rectangle([0, 0, 31, 9], fill=(150, 150, 160, 255))
    d.rectangle([0, 0, 31, 2], fill=(200, 200, 210, 255))
    d.rectangle([0, 9, 31, 11], fill=(90, 90, 100, 255))
    for x in range(0, 32, 8):
        d.point([(x + 3, 5)], fill=(120, 120, 130, 255))
    save(roof, "tile_roof.png")
    girder = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(girder)
    d.rectangle([0, 0, 31, 3], fill=(230, 170, 40, 255))
    d.rectangle([0, 12, 31, 15], fill=(190, 130, 30, 255))
    d.line([(0, 4), (8, 11), (16, 4), (24, 11), (31, 4)], fill=(210, 150, 35, 255), width=2)
    d.rectangle([0, 0, 31, 0], fill=(255, 210, 100, 255))
    save(girder, "tile_platform_city.png")


def gradient(w, h, top, bot):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        t = y / h
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    return img


def ridge(d, w, h, base_y, amp, col, seed, step=(40, 80)):
    r = random.Random(seed)
    pts = [(0, h)]
    x = 0
    while x <= w + 40:
        pts.append((x, base_y - r.randint(0, amp)))
        x += r.randint(*step)
    pts.append((w, h))
    d.polygon(pts, fill=col)


def make_backgrounds():
    w, h = 640, 360
    # Pradera
    img = gradient(w, h, (92, 160, 240), (200, 232, 250))
    d = ImageDraw.Draw(img)
    circle(d, (500, 70), 30, (255, 244, 180, 255))
    circle(d, (500, 70), 22, (255, 252, 220, 255))
    rnd = random.Random(7)
    for _ in range(9):
        cx, cy = rnd.randint(20, 620), rnd.randint(30, 170)
        for k in range(4):
            circle(d, (cx + k * 14, cy + rnd.randint(-4, 4)), rnd.randint(10, 16), WHITE)
        d.rectangle([cx - 10, cy + 6, cx + 4 * 14, cy + 12], fill=WHITE)
    ridge(d, w, h, 250, 70, (140, 170, 210, 255), 11)
    ridge(d, w, h, 290, 50, (104, 150, 180, 255), 12)
    ridge(d, w, h, 330, 30, (80, 136, 120, 255), 13)
    save(img, "bg_pradera.png")

    # Cosmos
    img = gradient(w, h, (12, 8, 36), (40, 20, 70))
    d = ImageDraw.Draw(img)
    rnd = random.Random(31)
    for _ in range(18):  # nebulosa
        cx, cy = rnd.randint(0, w), rnd.randint(40, 260)
        col = rnd.choice([(90, 40, 140), (40, 60, 150), (140, 40, 110)])
        for k in range(6):
            r = rnd.randint(18, 40)
            circle(d, (cx + rnd.randint(-40, 40), cy + rnd.randint(-20, 20)), r,
                   tuple(int(c * 0.55) + 12 for c in col) + (255,))
    for _ in range(260):
        x, y = rnd.randint(0, w - 1), rnd.randint(0, h - 1)
        b = rnd.randint(150, 255)
        d.point([(x, y)], fill=(b, b, 255, 255))
        if rnd.random() < 0.06:
            d.line([(x - 2, y), (x + 2, y)], fill=(b, b, 255, 255))
            d.line([(x, y - 2), (x, y + 2)], fill=(b, b, 255, 255))
    circle(d, (120, 90), 42, (230, 140, 90, 255))
    d.ellipse([78, 48, 162, 132], outline=(255, 190, 140, 255), width=2)
    d.pieslice([78, 48, 162, 132], 90, 270, fill=(200, 110, 70, 255))
    d.ellipse([60, 80, 180, 100], outline=(240, 220, 200, 255), width=2)
    circle(d, (520, 300), 110, (60, 50, 110, 255))
    circle(d, (520, 300), 100, (80, 64, 140, 255))
    save(img, "bg_cosmos.png")

    # Ciudad al atardecer
    img = gradient(w, h, (60, 40, 110), (250, 150, 110))
    d = ImageDraw.Draw(img)
    circle(d, (320, 250), 60, (255, 200, 120, 255))
    circle(d, (320, 250), 48, (255, 225, 160, 255))
    rnd = random.Random(44)
    for layer, (col, base, hmin, hmax) in enumerate([((110, 70, 130), 300, 60, 150),
                                                     ((60, 40, 80), 330, 50, 120)]):
        x = -10
        while x < w:
            bw = rnd.randint(30, 70)
            bh = rnd.randint(hmin, hmax)
            d.rectangle([x, base - bh, x + bw, h], fill=col + (255,))
            if layer == 1:
                for wy in range(base - bh + 8, h - 10, 10):
                    for wx in range(x + 5, x + bw - 5, 9):
                        if rnd.random() < 0.35:
                            d.rectangle([wx, wy, wx + 3, wy + 4], fill=(255, 220, 130, 255))
            x += bw + rnd.randint(2, 10)
    save(img, "bg_ciudad.png")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for cid, ch in CHARACTERS.items():
        make_character(cid, ch)
        make_projectile(cid, ch)
    make_items()
    make_tiles()
    make_backgrounds()
    print("Sprites generados en", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
