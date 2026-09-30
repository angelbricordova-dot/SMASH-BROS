"""
Generador de sprites (pixel art HD) para el juego.

Uso (solo si quieres regenerar/modificar los dibujos):
    pip install pillow numpy
    python3 tools/make_sprites.py

Crea en assets/sprites/:
  - char_<id>.png      hoja de sprites (8 columnas x 31 filas de cuadros de 160x144)
  - idle_<id>.png      solo la animación "idle" (para los menús)
  - portrait_<id>.png  retrato (cabeza) 60x60
  - proj_<id>.png      proyectil animado (4 cuadros de 32x32)
  - item_*.png         objetos
Puedes reemplazar cualquiera de estos PNG por tus propios dibujos MIENTRAS respetes
el tamaño y el orden de los cuadros (mira docs/GUIA_PASO_A_PASO.md).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
FW, FH = 160, 144            # tamaño de cada cuadro
HIP = (70, 114)              # cadera dentro del cuadro (los pies quedan en y=138)
K = 2                        # píxeles por unidad de pose
COLS = 8
WHITE = (255, 255, 255, 255)

# Filas de la hoja (nombre, cuadros). El orden DEBE coincidir con scripts/fighter.gd (ANIMS).
ANIMS = [
    ("idle", 6), ("walk", 8), ("run", 8), ("jump", 2), ("fall", 2), ("crouch", 2), ("shield", 1),
    ("dodge", 3), ("hurt", 2), ("ledge", 2), ("taunt", 6), ("win", 8),
    ("jab1", 3), ("jab2", 3), ("jab3", 4), ("ftilt", 4), ("utilt", 4), ("dtilt", 4), ("dash", 4),
    ("smash", 5), ("nair", 4), ("fair", 4), ("bair", 4), ("uair", 4), ("dair", 4),
    ("special", 4), ("upspecial", 3), ("downspecial", 4), ("charge", 4), ("throw", 3), ("ult", 4),
]

CHARACTERS = {
    "rojo": dict(skin=(246, 200, 160), hair=(226, 72, 46), hair_style="spiky", top=(246, 246, 242),
                 pants=(58, 74, 156), shoes=(166, 78, 46), accent=(226, 44, 56), glow=(255, 150, 40),
                 gloves=(210, 40, 50), torso_w=12, head_r=9, eye=(60, 40, 30), weapon=None, taunt="flex"),
    "azul": dict(skin=(242, 198, 170), hair=(78, 160, 248), hair_style="ponytail", top=(44, 60, 112),
                 pants=(34, 42, 80), shoes=(228, 228, 246), accent=(92, 226, 246), glow=(130, 236, 255),
                 gloves=None, torso_w=10, head_r=9, eye=(30, 70, 150), weapon=None, taunt="sign", scarf=True),
    "verde": dict(skin=(126, 198, 94), hair=(66, 44, 30), hair_style="horns", top=(140, 96, 56),
                  pants=(94, 64, 42), shoes=(64, 44, 30), accent=(246, 214, 84), glow=(170, 255, 90),
                  gloves=None, torso_w=16, head_r=10, eye=(200, 40, 20), weapon="club", taunt="pound"),
    "morado": dict(skin=(40, 30, 62), hair=(98, 58, 152), hair_style="hood", top=(76, 46, 120),
                   pants=(46, 32, 72), shoes=(32, 24, 46), accent=(192, 122, 255), glow=(206, 136, 255),
                   gloves=None, torso_w=12, head_r=9, eye=(240, 205, 255), weapon="claws", taunt="float",
                   cloak=True),
    "kaede": dict(skin=(248, 214, 186), hair=(40, 30, 44), hair_style="topknot", top=(236, 120, 160),
                  pants=(52, 44, 70), shoes=(70, 50, 40), accent=(250, 240, 245), glow=(255, 170, 210),
                  gloves=None, torso_w=12, head_r=9, eye=(60, 30, 50), weapon="katana", taunt="bow", hakama=True),
    "volta": dict(skin=(236, 190, 150), hair=(255, 222, 60), hair_style="bolt", top=(40, 40, 50),
                  pants=(36, 36, 46), shoes=(255, 210, 40), accent=(255, 214, 40), glow=(255, 240, 120),
                  gloves=(255, 214, 40), torso_w=11, head_r=9, eye=(40, 90, 200), weapon=None, taunt="flex",
                  goggles=True),
    "nova": dict(skin=(170, 180, 196), hair=(230, 120, 40), hair_style="helmet", top=(236, 128, 44),
                 pants=(84, 92, 110), shoes=(60, 66, 80), accent=(80, 230, 255), glow=(90, 240, 255),
                 gloves=(120, 130, 150), torso_w=13, head_r=9, eye=(90, 240, 255), weapon="cannon",
                 taunt="salute", jetpack=True),
    "bruma": dict(skin=(238, 206, 190), hair=(96, 40, 110), hair_style="witch", top=(30, 150, 150),
                  pants=(26, 90, 96), shoes=(50, 30, 60), accent=(250, 200, 70), glow=(120, 255, 220),
                  gloves=None, torso_w=11, head_r=9, eye=(120, 30, 140), weapon="staff", taunt="float",
                  cloak=True),
}


def rgba(c, a=255):
    return tuple(int(v) for v in c[:3]) + (a,)


def shade(col, f):
    return tuple(max(0, min(255, int(c * f))) for c in col[:3]) + (255,)


# ---------------------------------------------------------------- lienzo en "unidades"
class Canvas:
    """Dibuja en unidades de pose (1 unidad = K píxeles) respecto a la cadera."""

    def __init__(self, bob):
        self.img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.oy = bob

    def P(self, p):
        return (HIP[0] + p[0] * K, HIP[1] + (p[1] + self.oy) * K)

    def circle(self, c, r, col):
        x, y = self.P(c)
        r *= K
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=col)

    def ellipse(self, box, col):
        a, b = self.P(box[:2]), self.P(box[2:])
        self.d.ellipse([min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])], fill=col)

    def poly(self, pts, col):
        self.d.polygon([self.P(p) for p in pts], fill=col)

    def line(self, pts, col, w):
        self.d.line([self.P(p) for p in pts], fill=col, width=max(1, int(round(w * K))))

    def rect(self, a, b, col):
        pa, pb = self.P(a), self.P(b)
        self.d.rectangle([min(pa[0], pb[0]), min(pa[1], pb[1]), max(pa[0], pb[0]), max(pa[1], pb[1])], fill=col)


def limb(c, a, b, bend, w, col, end_col=None, end_r=None, mid_col=None):
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1
    px, py = -dy / n, dx / n
    k = (mx + px * bend, my + py * bend)
    c.line([a, k], col, w)
    c.line([k, b], mid_col or col, w)
    c.circle(k, w / 2 - 0.1, col)
    c.circle(a, w / 2 - 0.1, col)
    c.circle(b, end_r if end_r else w / 2, end_col or col)
    return k


def rotate_vec(v, deg):
    r = math.radians(deg)
    return (v[0] * math.cos(r) - v[1] * math.sin(r), v[0] * math.sin(r) + v[1] * math.cos(r))


def along(p, deg, dist):
    r = math.radians(deg)
    return (p[0] + math.cos(r) * dist, p[1] + math.sin(r) * dist)


# ---------------------------------------------------------------- post-proceso (numpy)
def _shift(a, dx, dy):
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


def finish(img):
    a = np.array(img).astype(np.float32)
    alpha = a[..., 3] > 0
    rgb = a[..., :3]
    # luz arriba-derecha (banda de 2 px) y sombra abajo-izquierda (banda de 3 px)
    edge_light = np.zeros_like(alpha)
    for d in (1, 2):
        edge_light |= ~_shift(alpha, 0, d) | ~_shift(alpha, -d, 0)
    edge_light &= alpha
    edge_dark = np.zeros_like(alpha)
    for d in (1, 2, 3):
        edge_dark |= ~_shift(alpha, 0, -d) | ~_shift(alpha, d, 0)
    edge_dark &= alpha & ~edge_light
    rgb[edge_light] = np.minimum(255, rgb[edge_light] * 1.18 + 14)
    rgb[edge_dark] = rgb[edge_dark] * 0.8
    a[..., :3] = rgb
    # contorno de color (1 px)
    out = a.copy()
    todo = ~alpha
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        n_alpha = _shift(alpha, dx, dy)
        n_rgb = _shift(a[..., :3], dx, dy)
        m = todo & n_alpha
        out[m, 0] = n_rgb[m, 0] * 0.25 + 10
        out[m, 1] = n_rgb[m, 1] * 0.22 + 8
        out[m, 2] = n_rgb[m, 2] * 0.3 + 18
        out[m, 3] = 255
        todo &= ~m
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- armas
def draw_weapon(c, kind, hand, ang, ch, big=False):
    glow = rgba(ch["glow"])
    if kind == "katana":
        tip = along(hand, ang, 27)
        base = along(hand, ang, 3.5)
        grip = along(hand, ang + 180, 4.5)
        c.line([grip, base], (40, 30, 40, 255), 2.6)
        for i in range(3):
            q = along(grip, ang, 1.5 + i * 2.2)
            c.circle(q, 0.7, (200, 60, 90, 255))
        perp = ang + 90
        c.poly([along(base, perp, 2.4), along(base, perp + 180, 2.4), along(along(base, ang, 0.8), perp + 180, 2.4),
                along(along(base, ang, 0.8), perp, 2.4)], (230, 190, 80, 255))
        mid = along(along(base, ang, 13), perp, -0.8)
        c.poly([along(base, perp, 1.2), along(mid, perp, 1.3), tip, along(mid, perp, -0.9),
                along(base, perp, -1.0)], (214, 222, 236, 255))
        c.line([along(base, perp, 0.9), along(mid, perp, 0.9), tip], (255, 255, 255, 255), 0.5)
    elif kind == "club":
        end = along(hand, ang, 19)
        grip = along(hand, ang + 180, 3)
        perp = ang + 90
        c.poly([along(grip, perp, 1.5), along(end, perp, 3.8), along(along(end, ang, 2), perp, 2.5),
                along(along(end, ang, 2), perp, -2.5), along(end, perp, -3.8), along(grip, perp, -1.5)],
               (150, 104, 62, 255))
        for k in (7, 12, 16):
            c.circle(along(along(hand, ang, k), perp, 1.5 if k % 2 else -1.8), 0.9, (104, 70, 40, 255))
        c.line([along(grip, perp, 0), along(hand, ang, 3)], (90, 60, 36, 255), 2.6)
    elif kind == "staff":
        top = along(hand, ang, 18)
        bot = along(hand, ang + 180, 12)
        c.line([bot, top], (120, 80, 50, 255), 1.8)
        c.line([bot, top], (160, 112, 70, 255), 0.7)
        c.circle(top, 3.2 if big else 2.6, shade(glow, 0.8))
        c.circle(top, 2.0 if big else 1.6, glow)
        c.circle(along(top, -135, 0.8), 0.7, WHITE)
        for s in (-1, 1):
            c.line([along(top, ang + 180, 2), along(along(top, ang + 180, 4), ang + 90 * s, 2.5)],
                   (230, 190, 80, 255), 0.8)
    elif kind == "claws":
        for i, off in enumerate((-1.6, 0, 1.6)):
            s = along(hand, ang + 90, off)
            c.line([s, along(along(s, ang, 7 + (1 if i == 1 else 0)), ang + 90, off * 0.4)], glow, 0.9)
    elif kind == "cannon":
        back = along(hand, ang + 180, 6)
        front = along(hand, ang, 4)
        c.line([back, front], (110, 120, 140, 255), 4.6)
        c.line([back, front], (236, 128, 44, 255), 3.0)
        c.circle(front, 2.2, (60, 66, 80, 255))
        c.circle(front, 1.3, glow)


# ---------------------------------------------------------------- dibujo del personaje
def draw_character(ch, pose):
    c = Canvas(pose.get("bob", 0))
    skin, hair, top, pants, shoes = (rgba(ch[k]) for k in ("skin", "hair", "top", "pants", "shoes"))
    accent, glow, eye = rgba(ch["accent"]), rgba(ch["glow"]), rgba(ch["eye"])
    gloves = rgba(ch["gloves"]) if ch.get("gloves") else None
    lean = pose.get("lean", 0)
    tw = ch["torso_w"]
    hr = ch["head_r"]
    hip = (0, 0)
    neck = (lean, -11)
    shoulder = (lean, -9)
    head = (1 + lean + pose.get("head_dx", 0), -11 - hr + 3 + pose.get("head_dy", 0))
    footF = pose["footF"]
    footB = pose["footB"]
    handF = (shoulder[0] + pose["handF"][0], shoulder[1] + pose["handF"][1])
    handB = (shoulder[0] + pose["handB"][0], shoulder[1] + pose["handB"][1])
    arm_w = 4.2 if tw < 15 else 5.2
    leg_w = 5.0 if tw < 15 else 6.2
    if ch.get("hakama"):
        leg_w += 1.4
    cloak = ch.get("cloak")
    hand_col = gloves or (accent if cloak and ch["hair_style"] == "hood" else skin)
    sleeve = top if cloak else skin
    weapon = ch.get("weapon")
    wang = pose.get("wa")
    if wang is None:
        wang = math.degrees(math.atan2(handF[1] - shoulder[1], handF[0] - shoulder[0])) - 20
    # --- capa / mochila
    if cloak:
        fl = pose.get("scarf", 0)
        c.poly([(neck[0] - 5, neck[1]), (neck[0] + 4, neck[1]), (4, 11), (-15 - fl, 13 + fl / 2), (-10, 4)],
               shade(top, 0.62))
    if ch.get("jetpack"):
        c.rect((neck[0] - 11, neck[1] + 1), (neck[0] - 5, neck[1] + 10), (110, 120, 140, 255))
        c.rect((neck[0] - 10, neck[1] + 2), (neck[0] - 6, neck[1] + 4), (236, 128, 44, 255))
        c.circle((neck[0] - 8, neck[1] + 11.5), 1.6, glow)
    # --- brazo y pierna de atrás
    limb(c, (shoulder[0] - 2, shoulder[1]), handB, pose.get("elbowB", -2), arm_w, shade(sleeve, 0.78),
         shade(hand_col, 0.78), arm_w / 2 + 0.9)
    limb(c, (-2, 0), footB, pose.get("kneeB", 3), leg_w, shade(pants, 0.76))
    c.ellipse((footB[0] - 3.2, footB[1] - 2.2, footB[0] + 4.2, footB[1] + 2.0), shade(shoes, 0.76))
    # --- detalles de atrás
    if ch["hair_style"] == "ponytail":
        sway = pose.get("tail", 0)
        base = (head[0] - hr + 2, head[1] - 2)
        c.line([base, (base[0] - 5, base[1] + 2 + sway), (base[0] - 9, base[1] + 8 + sway)], rgba(ch["hair"]), 4)
        c.circle((base[0] - 9, base[1] + 8 + sway), 2.2, hair)
    if ch.get("scarf") or ch["hair_style"] == "spiky":
        sc = pose.get("scarf", 0)
        col = accent
        if ch.get("scarf"):
            c.poly([(neck[0] - 4, neck[1]), (neck[0] - 16, neck[1] + 3 + sc), (neck[0] - 15, neck[1] + 6.5 + sc),
                    (neck[0] - 3, neck[1] + 4)], col)
    if ch["hair_style"] == "witch":
        c.poly([(head[0] - hr + 1, head[1]), (head[0] - hr - 4 - pose.get("tail", 0), head[1] + 14),
                (head[0] - 2, head[1] + 12), (head[0] + 2, head[1] + 2)], shade(hair, 0.9))
    # --- torso
    top_l, top_r = neck[0] - tw / 2, neck[0] + tw / 2
    bot_l, bot_r = -tw / 2 + 1, tw / 2 - 1
    c.poly([(top_l, neck[1]), (top_r, neck[1]), (bot_r, 1), (bot_l, 1)], top)
    c.poly([(top_l, neck[1]), (top_l + 3, neck[1]), (bot_l + 3, 1), (bot_l, 1)], shade(top, 0.8))
    if ch["hair_style"] == "helmet":  # placas de armadura
        c.line([(top_l + 2, neck[1] + 4), (top_r - 1, neck[1] + 4)], shade(top, 0.7), 0.7)
        c.circle((neck[0] + 1.5, neck[1] + 6), 1.2, glow)
    elif ch.get("hakama"):  # kimono cruzado
        c.poly([(neck[0] - 2, neck[1]), (neck[0] + 3, neck[1]), (neck[0] + 1, neck[1] + 5)], accent)
    elif ch["hair_style"] == "bolt":  # chaqueta con franja
        c.line([(neck[0] + 1, neck[1]), (1, 0)], accent, 1.2)
    elif not cloak:
        c.line([(neck[0] + 2, neck[1] + 2), (neck[0] + 1, neck[1] + 7)], shade(top, 0.85), 0.6)
    if cloak:
        c.line([(neck[0] + 1, neck[1] + 1), (1, 0)], accent, 0.8)
    else:
        c.rect((bot_l, -2), (bot_r, 0), accent)
        c.rect((1, -2.2), (2.5, 0.2), (240, 210, 90, 255))  # hebilla
    c.rect((bot_l, 1), (bot_r, 4), pants)
    # --- pierna de adelante
    limb(c, (2, 0), footF, pose.get("kneeF", 3), leg_w, pants)
    c.ellipse((footF[0] - 3.2, footF[1] - 2.2, footF[0] + 5.2, footF[1] + 2.0), shoes)
    c.line([(footF[0] - 2.8, footF[1] + 1.6), (footF[0] + 4.8, footF[1] + 1.6)], shade(shoes, 1.5), 0.6)

    def front_arm():
        limb(c, shoulder, handF, pose.get("elbowF", 3), arm_w, sleeve, hand_col, arm_w / 2 + 1)
        c.circle((shoulder[0] - 0.5, shoulder[1] + 0.8), 2.4, top)
        if weapon and weapon != "cannon":
            draw_weapon(c, weapon, handF, wang, ch, pose.get("big"))
        elif weapon == "cannon":
            draw_weapon(c, weapon, handF, math.degrees(math.atan2(handF[1] - shoulder[1], handF[0] - shoulder[0])),
                        ch)
        if ch["hair_style"] == "bolt":
            c.circle((handF[0] + 1.5, handF[1] - 1.5), 0.8, WHITE)

    arm_behind = pose["handF"][1] < -6 and not weapon
    if arm_behind:
        front_arm()

    # --- cabeza
    hx, hy = head
    style = ch["hair_style"]
    if style == "helmet":
        c.ellipse((hx - hr - 0.5, hy - hr, hx + hr + 0.5, hy + hr), skin)
        c.ellipse((hx - 1, hy - 4, hx + hr + 0.5, hy + 3), (30, 34, 50, 255))
        c.ellipse((hx, hy - 3, hx + hr - 0.5, hy + 2), shade(glow, 0.7))
        c.line([(hx + 1, hy - 1), (hx + hr - 1, hy - 1)], glow, 0.9)
        c.line([(hx - 3, hy - hr), (hx - 5, hy - hr - 4)], (110, 120, 140, 255), 0.8)
        c.circle((hx - 5, hy - hr - 4.5), 1.1, rgba(ch["hair"]))
    else:
        c.ellipse((hx - hr, hy - hr + 1, hx + hr, hy + hr - 1), skin)
        c.ellipse((hx + hr - 3, hy + 1, hx + hr - 0.5, hy + 4), shade(skin, 1.08) if style != "hood" else skin)
    if style == "spiky":
        pts = [(hx - hr, hy + 1), (hx - hr - 4, hy - 6), (hx - 6, hy - 5), (hx - 8, hy - hr - 6), (hx - 1, hy - hr + 1),
               (hx + 2, hy - hr - 7), (hx + 5, hy - hr + 1), (hx + hr + 1, hy - hr - 2), (hx + hr - 1, hy - 3),
               (hx + 4, hy - 4), (hx - 2, hy - 2)]
        c.poly(pts, hair)
        c.line([(hx - 5, hy - hr - 1), (hx - 1, hy - hr + 2)], shade(hair, 1.3), 0.6)
        c.rect((hx - hr + 1, hy - 4), (hx + hr - 1, hy - 2), accent)
        t = pose.get("tail", 0)
        c.poly([(hx - hr + 1, hy - 4), (hx - hr - 8, hy - 2 + t), (hx - hr - 7, hy + 1.5 + t), (hx - hr + 1, hy - 2)],
               accent)
    elif style == "ponytail":
        c.d.pieslice([*c.P((hx - hr - 1, hy - hr)), *c.P((hx + hr + 1, hy + hr))], 180, 360, fill=hair)
        c.poly([(hx - hr, hy - 1), (hx - hr + 3, hy - 2), (hx - hr + 4, hy + 5), (hx - hr, hy + 4)], hair)
        c.poly([(hx + 1, hy - hr + 1), (hx + hr + 1, hy - 3), (hx + 3, hy - 3)], hair)
        c.line([(hx - 4, hy - hr + 1), (hx + 3, hy - hr + 2)], shade(hair, 1.35), 0.6)
    elif style == "horns":
        horn = (242, 236, 214, 255)
        c.poly([(hx - 7, hy - hr + 3), (hx - 10, hy - hr - 6), (hx - 3, hy - hr + 1)], horn)
        c.poly([(hx + 2, hy - hr + 1), (hx + 7, hy - hr - 7), (hx + 8, hy - hr + 3)], horn)
        c.d.pieslice([*c.P((hx - hr, hy - hr + 1)), *c.P((hx + hr, hy + hr))], 195, 345, fill=hair)
    elif style == "hood":
        c.poly([(hx - hr - 2, hy + hr - 1), (hx - hr - 3, hy - 2), (hx - 4, hy - hr - 4), (hx + 4, hy - hr - 2),
                (hx + hr + 2, hy - 3), (hx + hr + 1, hy + 2), (hx + 4, hy - 4), (hx - 2, hy + 1), (hx - 3, hy + hr)],
               hair)
        c.line([(hx - 4, hy - hr - 3), (hx + hr, hy - 3)], shade(hair, 1.3), 0.7)
    elif style == "topknot":
        c.d.pieslice([*c.P((hx - hr - 0.5, hy - hr)), *c.P((hx + hr + 0.5, hy + hr))], 185, 355, fill=hair)
        c.poly([(hx - hr, hy - 1), (hx - hr + 3, hy - 3), (hx - hr + 3, hy + 4), (hx - hr, hy + 3)], hair)
        c.circle((hx - 3, hy - hr - 2), 3.0, hair)
        c.rect((hx - 4.5, hy - hr + 0.2), (hx - 1.5, hy - hr + 1.2), accent)
        c.line([(hx - 7 - pose.get("tail", 0), hy - hr - 1), (hx - 4, hy - hr)], accent, 0.8)
    elif style == "bolt":
        pts = [(hx - hr, hy + 2), (hx - hr - 5, hy - 3), (hx - hr + 1, hy - 4), (hx - 6, hy - hr - 8),
               (hx - 2, hy - hr - 1), (hx + 1, hy - hr - 9), (hx + 3, hy - hr), (hx + hr + 3, hy - hr - 5),
               (hx + hr, hy - 3), (hx + 3, hy - 4), (hx - 2, hy - 2)]
        c.poly(pts, hair)
        c.line([(hx - 5, hy - hr - 5), (hx - 2, hy - hr)], WHITE, 0.6)
        if ch.get("goggles"):
            c.rect((hx - hr + 0.5, hy - 5.5), (hx + hr - 0.5, hy - 4), (60, 60, 70, 255))
            c.circle((hx + 2, hy - 5), 1.7, (120, 220, 255, 255))
            c.circle((hx + 6, hy - 5), 1.7, (120, 220, 255, 255))
    elif style == "witch":
        c.d.pieslice([*c.P((hx - hr - 0.5, hy - hr)), *c.P((hx + hr + 0.5, hy + hr))], 180, 360, fill=hair)
        c.poly([(hx + 1, hy - hr + 1), (hx + hr + 1, hy - 2), (hx + 3, hy - 3)], hair)
        hat = rgba(ch["top"])
        c.ellipse((hx - hr - 5, hy - hr + 0.5, hx + hr + 5, hy - hr + 4), shade(hat, 0.75))
        tip_sway = pose.get("tail", 0)
        c.poly([(hx - 7, hy - hr + 2), (hx + 7, hy - hr + 2), (hx + 1, hy - hr - 8), (hx - 6 - tip_sway, hy - hr - 15)],
               hat)
        c.rect((hx - 7, hy - hr + 0.4), (hx + 7, hy - hr + 2), accent)

    # --- cara
    ex, ey = hx + 2, hy - 1
    if style == "hood":
        glow_eye = (255, 120, 160, 255) if pose.get("hurt") else eye
        for ox in (1, 6):
            c.rect((ex + ox, ey - 1.2), (ex + ox + 1.5, ey + 0.5), glow_eye)
    elif style == "helmet":
        pass
    elif pose.get("hurt"):
        for ox in (0, 5):
            c.line([(ex + ox - 1, ey - 2), (ex + ox + 2, ey + 1)], rgba((40, 20, 30)), 0.8)
            c.line([(ex + ox + 2, ey - 2), (ex + ox - 1, ey + 1)], rgba((40, 20, 30)), 0.8)
        c.ellipse((ex + 2, ey + 4, ex + 5, ey + 7), (120, 30, 40, 255))
    else:
        happy = pose.get("happy")
        for ox in (0, 5):
            if happy:
                c.line([(ex + ox - 1, ey), (ex + ox + 0.5, ey - 2), (ex + ox + 2, ey)], rgba((40, 20, 30)), 0.8)
            else:
                c.rect((ex + ox - 0.3, ey - 2.3), (ex + ox + 1.8, ey + 1.4), WHITE)
                c.rect((ex + ox + 0.6, ey - 1.6), (ex + ox + 1.8, ey + 1.4), eye)
                c.rect((ex + ox + 1.0, ey - 0.8), (ex + ox + 1.8, ey + 1.0), (20, 16, 24, 255))
                c.rect((ex + ox + 0.6, ey - 1.6), (ex + ox + 1.0, ey - 1.1), WHITE)
                c.line([(ex + ox - 0.5, ey - 3.3), (ex + ox + 2, ey - 3.6)], shade(ch["hair"], 0.7), 0.6)
        if happy:
            c.d.pieslice([*c.P((ex + 1, ey + 2)), *c.P((ex + 7, ey + 8))], 0, 180, fill=(150, 40, 50, 255))
        else:
            c.line([(ex + 1.5, ey + 5), (ex + 5, ey + 5)], (160, 70, 70, 255), 0.6)
        if style == "horns":
            c.rect((ex + 1, ey + 3.5), (ex + 1.6, ey + 5), WHITE)
            c.rect((ex + 5, ey + 3.5), (ex + 5.6, ey + 5), WHITE)
        c.circle((ex - 1, ey + 3), 1.0, shade(skin, 0.92)[:3] + (255,))  # mejilla

    if not arm_behind:
        front_arm()

    # --- efectos dibujados en el sprite
    fx = pose.get("effect")
    if fx == "sparkle":
        for (sx, sy) in pose.get("sparks", []):
            c.line([(sx - 2.5, sy), (sx + 2.5, sy)], glow, 0.8)
            c.line([(sx, sy - 2.5), (sx, sy + 2.5)], glow, 0.8)
            c.circle((sx, sy), 0.7, WHITE)
    orb = pose.get("orb", 0)
    if orb:
        o = (handF[0] + 4, handF[1])
        c.circle(o, orb + 2, shade(glow, 0.85))
        c.circle(o, orb, WHITE)
        c.circle(o, max(1, orb - 2), glow)

    img = c.img
    rot = pose.get("rot", 0)
    if rot:
        center = c.P((0, -9))
        img = img.rotate(-rot, resample=Image.NEAREST, center=center)
    return finish(img)


# ---------------------------------------------------------------- poses
def st(footF=(6, 12), footB=(-5, 12), handF=(8, 3), handB=(2, 6), **extra):
    p = dict(footF=footF, footB=footB, handF=handF, handB=handB)
    p.update(extra)
    return p


def fist_attacks():
    return {
        "jab1": [st(handF=(5, 3), handB=(1, 5)), st(handF=(16, 0), lean=2, footF=(8, 12)),
                 st(handF=(10, 2), lean=1)],
        "jab2": [st(handB=(7, 2), handF=(3, 4), lean=1), st(handB=(16, -1), handF=(0, 4), lean=3, footF=(9, 12)),
                 st(handB=(9, 3), handF=(3, 4), lean=2)],
        "jab3": [st(footF=(7, 4), kneeF=-9, handF=(6, -2), handB=(-6, 2), lean=-2),
                 st(footF=(20, -3), kneeF=-2, lean=-4, handF=(2, -4), handB=(-8, 0)),
                 st(footF=(20, -2), kneeF=-2, lean=-4, handF=(2, -4), handB=(-8, 0)),
                 st(footF=(10, 8), lean=-1)],
        "ftilt": [st(footF=(6, 3), kneeF=-9, lean=-2, handF=(4, 0)), st(footF=(22, 2), kneeF=-1, lean=-5, handF=(0, -2),
                                                                         handB=(-8, 2)),
                  st(footF=(21, 3), kneeF=-1, lean=-5, handF=(0, -2), handB=(-8, 2)), st(footF=(9, 10), lean=-1)],
        "utilt": [st(handF=(6, 6), bob=2, lean=1), st(handF=(8, -12), bob=-1), st(handF=(3, -20), bob=-2, head_dy=-1),
                  st(handF=(4, -8))],
        "dtilt": [st(footF=(10, 4), footB=(-7, 4), kneeF=-7, kneeB=-7, bob=8, lean=3, handF=(8, 4)),
                  st(footF=(23, 4), footB=(-7, 4), kneeF=-2, kneeB=-7, bob=8, lean=4, handF=(6, 6), handB=(0, 8)),
                  st(footF=(22, 4), footB=(-7, 4), kneeF=-2, kneeB=-7, bob=8, lean=4, handF=(6, 6), handB=(0, 8)),
                  st(footF=(12, 4), footB=(-7, 4), kneeF=-7, kneeB=-7, bob=8, lean=3)],
        "dash": [st(lean=5, handF=(10, 0), footF=(10, 11), footB=(-9, 9)),
                 st(footF=(19, -1), footB=(-8, 9), kneeF=-2, lean=6, bob=-2, handF=(4, -4), handB=(-8, -2)),
                 st(footF=(19, 0), footB=(-8, 9), kneeF=-2, lean=6, bob=-2, handF=(4, -4), handB=(-8, -2)),
                 st(lean=2)],
        "smash": [st(bob=3, lean=-4, handF=(-8, 3), handB=(-6, 5), footF=(10, 12), footB=(-8, 12), kneeF=-5, kneeB=-5),
                  st(bob=2, lean=-6, handF=(-11, 0), handB=(-7, 4), footF=(10, 12), footB=(-8, 12)),
                  st(lean=7, handF=(19, -1), handB=(-6, 4), footF=(13, 12), footB=(-11, 12)),
                  st(lean=6, handF=(18, 1), handB=(-5, 5), footF=(13, 12), footB=(-11, 12)),
                  st(lean=2, handF=(10, 3))],
        "nair": [st(footF=(8, 10), footB=(-8, 10), handF=(12, -2), handB=(-11, -2), kneeF=0, kneeB=0, rot=r)
                 for r in (0, 90, 180, 270)],
        "fair": [st(handF=(4, -10), footF=(6, 6), kneeF=-6), st(handF=(16, -2), lean=3, footF=(10, 6), kneeF=-6),
                 st(handF=(14, 6), lean=3, footF=(9, 7), kneeF=-6), st(handF=(8, 4), footF=(6, 8))],
        "bair": [st(lean=2, footB=(-6, 6), kneeB=6, footF=(5, 8)),
                 st(footB=(-21, 2), kneeB=2, lean=5, handF=(8, 4), handB=(2, 6), footF=(5, 8)),
                 st(footB=(-20, 3), kneeB=2, lean=5, handF=(8, 4), handB=(2, 6), footF=(5, 8)),
                 st(footB=(-8, 8), lean=2, footF=(5, 9))],
        "uair": [st(handF=(6, -4), footF=(6, 8), kneeF=-5),
                 st(handF=(4, -19), lean=-1, footF=(7, 6), kneeF=-6, bob=-2, rot=-15),
                 st(handF=(-2, -18), footF=(7, 6), kneeF=-6, bob=-2, rot=-25), st(handF=(6, 0), footF=(6, 9))],
        "dair": [st(footF=(6, 6), footB=(-3, 8), kneeF=-6, kneeB=-6, handF=(6, -8), handB=(-6, -8)),
                 st(footF=(3, 17), footB=(-2, 17), kneeF=0, kneeB=0, handF=(8, -10), handB=(-7, -10)),
                 st(footF=(3, 17), footB=(-2, 17), kneeF=0, kneeB=0, handF=(8, -10), handB=(-7, -10)),
                 st(footF=(6, 10), footB=(-3, 11), handF=(6, -2))],
    }


def weapon_attacks():
    return {
        "jab1": [st(handF=(4, -6), wa=-110), st(handF=(15, 2), wa=10, lean=2), st(handF=(10, 4), wa=35, lean=1)],
        "jab2": [st(handF=(8, 6), wa=60), st(handF=(12, -8), wa=-60, lean=2), st(handF=(6, -10), wa=-100, lean=1)],
        "jab3": [st(handF=(-2, -12), wa=-140, lean=-2), st(handF=(17, -2), wa=0, lean=5, footF=(12, 12)),
                 st(handF=(17, -1), wa=2, lean=5, footF=(12, 12)), st(handF=(9, 2), wa=-30)],
        "ftilt": [st(handF=(2, 2), wa=0, lean=-2), st(handF=(19, 0), wa=0, lean=6, footF=(13, 12), footB=(-10, 12)),
                  st(handF=(18, 1), wa=0, lean=6, footF=(13, 12), footB=(-10, 12)), st(handF=(9, 2), wa=-20)],
        "utilt": [st(handF=(10, 2), wa=0), st(handF=(8, -12), wa=-60), st(handF=(0, -16), wa=-120),
                  st(handF=(-6, -10), wa=-170)],
        "dtilt": [st(handF=(6, 6), wa=40, bob=7, footF=(9, 5), footB=(-7, 5), kneeF=-6, kneeB=-6),
                  st(handF=(17, 8), wa=8, bob=7, lean=4, footF=(10, 5), footB=(-8, 5), kneeF=-6, kneeB=-6),
                  st(handF=(17, 9), wa=4, bob=7, lean=4, footF=(10, 5), footB=(-8, 5), kneeF=-6, kneeB=-6),
                  st(handF=(8, 5), wa=30, bob=7, footF=(9, 5), footB=(-7, 5), kneeF=-6, kneeB=-6)],
        "dash": [st(handF=(10, 0), wa=0, lean=5), st(handF=(19, 0), wa=0, lean=7, footF=(15, 10), footB=(-10, 10)),
                 st(handF=(19, 1), wa=0, lean=7, footF=(15, 10), footB=(-10, 10)), st(handF=(10, 2), wa=-20, lean=2)],
        "smash": [st(handF=(-8, -10), wa=-150, lean=-4, bob=2, footF=(10, 12), footB=(-8, 12)),
                  st(handF=(-6, -14), wa=-170, lean=-5, bob=1, footF=(10, 12), footB=(-8, 12), big=True),
                  st(handF=(17, 4), wa=30, lean=7, footF=(13, 12), footB=(-11, 12), big=True),
                  st(handF=(13, 8), wa=60, lean=6, footF=(13, 12), footB=(-11, 12)), st(handF=(9, 3), wa=-20, lean=2)],
        "nair": [st(footF=(8, 10), footB=(-8, 10), handF=(12, 0), handB=(-11, -2), wa=0, kneeF=0, kneeB=0, rot=r)
                 for r in (0, 90, 180, 270)],
        "fair": [st(handF=(0, -12), wa=-120, footF=(6, 7), kneeF=-6), st(handF=(15, -2), wa=0, lean=3, footF=(8, 7)),
                 st(handF=(12, 8), wa=60, lean=3, footF=(8, 7)), st(handF=(8, 4), wa=20)],
        "bair": [st(handF=(4, 2), wa=0), st(handF=(-15, 0), wa=180, lean=3, handB=(4, 4)),
                 st(handF=(-15, 1), wa=178, lean=3, handB=(4, 4)), st(handF=(2, 4), wa=90)],
        "uair": [st(handF=(8, -4), wa=-30), st(handF=(2, -18), wa=-90, bob=-2), st(handF=(-6, -14), wa=-150, bob=-2),
                 st(handF=(6, 0), wa=-20)],
        "dair": [st(handF=(4, -8), wa=-90, footF=(6, 7), kneeF=-6), st(handF=(4, 12), wa=90, footF=(6, 6), kneeF=-7),
                 st(handF=(4, 13), wa=90, footF=(6, 6), kneeF=-7), st(handF=(8, 2), wa=30)],
    }


def taunt_poses(kind, weapon):
    sp = lambda pts: dict(effect="sparkle", sparks=pts)  # noqa: E731
    if kind == "flex":
        base = [st(handF=(8, 2)), st(handF=(6, -12), bob=-1, happy=True),
                st(handF=(7, -14), handB=(-3, 4), bob=-1, happy=True, **sp([(10, -30), (14, -24)])),
                st(handF=(6, -12), happy=True)]
    elif kind == "sign":
        base = [st(handF=(6, 2), handB=(5, 3), footF=(5, 12)), st(handF=(5, -2), handB=(4, -2), tail=2, scarf=2),
                st(handF=(5, -3), handB=(4, -3), tail=3, scarf=3, **sp([(8, -16), (12, -22), (4, -24)])),
                st(handF=(5, -2), handB=(4, -2), tail=1, scarf=1)]
    elif kind == "pound":
        base = [st(handF=(2, 4), handB=(-2, 4), lean=-1, footF=(8, 12), footB=(-7, 12)),
                st(handF=(-1, 8), handB=(1, 7), lean=1, happy=True), st(handF=(4, 1), handB=(-4, 2), lean=-1, head_dy=-1,
                                                                       happy=True),
                st(handF=(-1, 8), handB=(1, 7), lean=1, happy=True)]
    elif kind == "bow":
        base = [st(handF=(6, 6), wa=80), st(handF=(5, 8), wa=90, lean=3, head_dy=2),
                st(handF=(5, 8), wa=90, lean=4, head_dy=3, **sp([(16, -6)])), st(handF=(6, -2), wa=-60)]
    elif kind == "salute":
        base = [st(handF=(6, 2)), st(handF=(3, -11), bob=-1), st(handF=(3, -12), bob=-1, **sp([(10, -26)])),
                st(handF=(3, -11))]
    else:  # float
        base = [st(footF=(4, 10), footB=(-4, 11), handF=(9, 0), handB=(-8, 1), bob=-1, scarf=1),
                st(footF=(4, 9), footB=(-4, 10), handF=(11, -4), handB=(-10, -3), bob=-2, scarf=2,
                   **sp([(20, -14), (-12, -12)])),
                st(footF=(4, 8), footB=(-4, 9), handF=(12, -6), handB=(-11, -5), bob=-3, scarf=3,
                   **sp([(22, -18), (-14, -16), (4, -30)])),
                st(footF=(4, 9), footB=(-4, 10), handF=(11, -4), handB=(-10, -3), bob=-2, scarf=2)]
    return base + [base[1], base[2]]


def build_poses(ch):
    wpn = ch.get("weapon") in ("katana", "club", "staff")
    guard_wa = {"katana": -45, "club": -60, "staff": -80}.get(ch.get("weapon"))
    P = {}
    P["idle"] = [st(footF=(6, 12 - b), footB=(-5, 12 - b), handF=(7 if wpn else 8, h), handB=(2, 6 + i % 2), bob=b,
                    tail=t, scarf=t, wa=guard_wa)
                 for i, (b, h, t) in enumerate([(0, 3, 0), (0, 2, 1), (1, 2, 2), (1, 1, 2), (1, 2, 1), (0, 3, 0)])]
    walk, run = [], []
    for i in range(8):
        p = i / 8.0 * math.tau
        s, co = math.sin(p), math.cos(p)
        walk.append(st(footF=(s * 6 + 1, 12 - max(0, co) * 3), footB=(-s * 6 + 1, 12 - max(0, -co) * 3),
                       handF=(-s * 3 + 6, 4), handB=(s * 4 + 1, 6), lean=1, bob=round(abs(s) * 0.8),
                       tail=round(co), scarf=round(-co), wa=guard_wa))
        run.append(st(footF=(s * 10 + 1, 12 - max(0, co) * 5), footB=(-s * 10 + 1, 12 - max(0, -co) * 5),
                      handF=(-s * 7 + 4, 5 - abs(co) * 2), handB=(s * 7 + 2, 5 - abs(co) * 2), lean=4,
                      bob=round(abs(s) * 1.4), tail=round(co * 2), scarf=round(-co * 2), kneeF=-3, kneeB=-3,
                      elbowF=-3, elbowB=-3, wa=(guard_wa or 0) + 25 if wpn else None))
    P["walk"], P["run"] = walk, run
    P["jump"] = [st(footF=(7, 8), footB=(-1, 10), handF=(9, -8), handB=(-5, -5), bob=-2, tail=-3, scarf=-3, kneeF=-5,
                    kneeB=4, wa=guard_wa),
                 st(footF=(6, 9), footB=(0, 11), handF=(10, -5), handB=(-6, -3), bob=-1, tail=-2, scarf=-2, kneeF=-4,
                    wa=guard_wa)]
    P["fall"] = [st(footF=(8, 12), footB=(-7, 11), handF=(11, -2), handB=(-9, -1), tail=-4, scarf=-4, wa=guard_wa),
                 st(footF=(7, 12), footB=(-6, 12), handF=(11, 0), handB=(-10, 1), tail=-5, scarf=-5, wa=guard_wa)]
    P["crouch"] = [st(footF=(8, 4), footB=(-7, 4), handF=(8, 4), handB=(3, 6), bob=8, lean=3, kneeF=-7, kneeB=-7,
                      wa=20 if wpn else None),
                   st(footF=(8, 4), footB=(-7, 4), handF=(8, 5), handB=(3, 7), bob=9, lean=3, kneeF=-7, kneeB=-7,
                      wa=22 if wpn else None)]
    P["shield"] = [st(footF=(8, 12), footB=(-7, 12), handF=(7, 2), handB=(6, 4), lean=2, bob=3, kneeF=-6, kneeB=-6,
                      wa=-80 if wpn else None)]
    P["dodge"] = [st(footF=(5, 5), footB=(-1, 6), handF=(6, 3), handB=(3, 5), bob=7, kneeF=-8, kneeB=-8, rot=r,
                     wa=guard_wa) for r in (0, 120, 240)]
    P["hurt"] = [st(footF=(6, 9), footB=(-6, 11), handF=(8, -8), handB=(-4, -6), lean=-4, head_dx=-2, hurt=True, bob=-1,
                    tail=-3, scarf=-3, kneeF=-4, wa=-120),
                 st(footF=(7, 8), footB=(-7, 10), handF=(10, -6), handB=(-6, -8), lean=-6, head_dx=-3, hurt=True,
                    bob=-2, tail=-4, scarf=-4, kneeF=-5, wa=-150)]
    P["ledge"] = [st(footF=(3, 12), footB=(-3, 13), handF=(5, -15), handB=(0, -15), kneeF=-3, kneeB=3, tail=2, scarf=2,
                     wa=-100),
                  st(footF=(4, 12), footB=(-2, 13), handF=(5, -15), handB=(0, -15), kneeF=-4, kneeB=2, tail=3,
                     scarf=3, wa=-100)]
    P["taunt"] = taunt_poses(ch["taunt"], ch.get("weapon"))
    win = [st(footF=(7, 8), footB=(-6, 8), handF=(6, 4), handB=(-4, 4), bob=4, kneeF=-6, kneeB=-6, happy=True),
           st(footF=(5, 12), footB=(-4, 12), handF=(7, -16), handB=(-6, -15), bob=-6, happy=True, tail=-3, scarf=-3,
              wa=-80),
           st(footF=(5, 10), footB=(-4, 11), handF=(9, -17), handB=(-8, -15), bob=-9, happy=True, tail=-4, scarf=-4,
              effect="sparkle", sparks=[(18, -34), (-12, -30)], wa=-70),
           st(footF=(5, 12), footB=(-4, 12), handF=(6, -16), handB=(-5, -15), bob=-5, happy=True, tail=-2, scarf=-2,
              wa=-85),
           st(footF=(7, 9), footB=(-6, 9), handF=(7, -14), handB=(-6, -13), bob=3, happy=True, kneeF=-5, kneeB=-5,
              wa=-80),
           st(handF=(7, -15), handB=(-3, 5), happy=True, effect="sparkle", sparks=[(16, -36)], wa=-80),
           st(handF=(8, -13), handB=(-3, 5), happy=True, wa=-75),
           st(handF=(7, -15), handB=(-3, 5), happy=True, effect="sparkle", sparks=[(12, -38), (22, -30)], wa=-80)]
    P["win"] = win
    P.update(weapon_attacks() if wpn else fist_attacks())
    P["special"] = [st(footF=(8, 12), footB=(-6, 12), handF=(-5, 3), handB=(-6, 4), lean=-2, bob=1, wa=-150),
                    st(footF=(8, 12), footB=(-6, 12), handF=(8, 4), handB=(6, 5), orb=0 if wpn else 3, wa=0),
                    st(footF=(9, 12), footB=(-7, 12), handF=(14, 2), handB=(11, 3), lean=3, orb=0 if wpn else 5,
                       wa=0, big=True),
                    st(footF=(9, 12), footB=(-6, 12), handF=(15, 1), handB=(13, 2), lean=3, wa=0)]
    P["upspecial"] = [st(footF=(4, 12), footB=(-3, 13), handF=(5, -17), handB=(-4, 3), lean=2, bob=-2, kneeF=-3,
                         tail=4, scarf=4, wa=-90),
                      st(footF=(2, 14), footB=(-3, 13), handF=(6, -18), handB=(-5, 5), lean=2, bob=-3, tail=5, scarf=5,
                         effect="sparkle", sparks=[(12, -38), (8, -30)], wa=-85),
                      st(footF=(3, 13), footB=(-4, 12), handF=(4, -16), handB=(-6, 2), lean=1, bob=-3, tail=6, scarf=6,
                         wa=-95)]
    P["downspecial"] = [st(handF=(6, -10), handB=(-4, -10), bob=2, wa=-90),
                        st(handF=(8, 10), handB=(4, 10), bob=6, kneeF=-7, kneeB=-7, footF=(9, 10), footB=(-8, 10),
                           wa=90),
                        st(handF=(10, 12), handB=(5, 12), bob=7, kneeF=-7, kneeB=-7, footF=(9, 9), footB=(-8, 9),
                           wa=95, effect="sparkle", sparks=[(18, 20), (-8, 20)]),
                        st(handF=(8, 3), handB=(3, 5), bob=2, wa=-20)]
    P["charge"] = [st(handF=(6, 4), handB=(5, 5), bob=2, orb=3, footF=(9, 12), footB=(-7, 12), kneeF=-4, kneeB=-4,
                      wa=-150 if wpn else None),
                   st(handF=(5, 4), handB=(4, 5), bob=3, orb=5, footF=(9, 12), footB=(-7, 12), kneeF=-5, kneeB=-5,
                      wa=-160 if wpn else None, effect="sparkle", sparks=[(-8, -24), (16, -20)]),
                   st(handF=(15, 2), handB=(12, 3), lean=4, orb=0 if wpn else 7, footF=(12, 12), footB=(-10, 12),
                      wa=0, big=True),
                   st(handF=(16, 1), handB=(14, 2), lean=4, footF=(12, 12), footB=(-10, 12), wa=5)]
    P["throw"] = [st(handF=(-10, -8), lean=-3, wa=-150), st(handF=(15, -4), lean=3, footF=(9, 12), wa=-10),
                  st(handF=(10, 4), lean=2, wa=30)]
    P["ult"] = [st(handF=(8, 8), handB=(-6, 8), bob=4, kneeF=-6, kneeB=-6, footF=(9, 9), footB=(-8, 9), wa=60),
                st(handF=(10, -14), handB=(-9, -13), bob=-2, wa=-80, effect="sparkle",
                   sparks=[(20, -32), (-16, -30)]),
                st(handF=(11, -15), handB=(-10, -14), bob=-3, wa=-80, big=True, effect="sparkle",
                   sparks=[(22, -36), (-18, -34), (2, -44)]),
                st(handF=(18, -1), handB=(12, 1), lean=5, orb=0 if wpn else 6, wa=0, big=True,
                   footF=(13, 12), footB=(-11, 12))]
    return P


def make_character(cid, ch):
    poses = build_poses(ch)
    sheet = Image.new("RGBA", (FW * COLS, FH * len(ANIMS)), (0, 0, 0, 0))
    for row, (name, n) in enumerate(ANIMS):
        frames = poses[name]
        assert len(frames) >= n, (cid, name, len(frames), n)
        for col in range(n):
            sheet.paste(draw_character(ch, frames[col]), (col * FW, row * FH))
    sheet.save(os.path.join(OUT_DIR, f"char_{cid}.png"), optimize=True)
    sheet.crop((0, 0, FW * 6, FH)).save(os.path.join(OUT_DIR, f"idle_{cid}.png"))
    head = sheet.crop((HIP[0] - 30, HIP[1] - 70, HIP[0] + 32, HIP[1] - 8))
    head.save(os.path.join(OUT_DIR, f"portrait_{cid}.png"))


# ---------------------------------------------------------------- proyectiles (32x32, 4 cuadros)
def circ(d, c, r, col):
    d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=col)


def make_projectile(cid, ch):
    glow = rgba(ch["glow"])
    sheet = Image.new("RGBA", (32 * 4, 32), (0, 0, 0, 0))
    for i in range(4):
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        wob = [0, 1, 0, -1][i]
        if cid == "azul":
            d.polygon([(30, 16), (16, 10 + wob), (4, 16), (16, 22 - wob)], fill=glow)
            d.polygon([(28, 16), (16, 12), (16, 16)], fill=WHITE)
            d.line([(4, 16), (0, 16)], fill=shade(glow, 0.7), width=2)
        elif cid == "verde":
            pts = [(16 + math.cos(k / 9 * math.tau + i * 0.5) * (12 + (k * 7 + i) % 3),
                    16 + math.sin(k / 9 * math.tau + i * 0.5) * (12 + (k * 5 + i) % 3)) for k in range(9)]
            d.polygon(pts, fill=(140, 122, 104, 255))
            circ(d, (12, 12), 3, (184, 170, 154, 255))
            circ(d, (20, 20), 2.5, (100, 86, 72, 255))
            d.line([(10, 18), (16, 22)], fill=(96, 80, 66, 255), width=1)
        elif cid == "morado":
            circ(d, (16, 16), 12 + wob * 0.6, (60, 30, 92, 255))
            circ(d, (16, 16), 8, glow)
            circ(d, (16, 16), 4, WHITE)
            a = i * math.pi / 2
            for k in range(3):
                aa = a + k * math.tau / 3
                d.line([(16, 16), (16 + math.cos(aa) * 13, 16 + math.sin(aa) * 13)], fill=(230, 200, 255, 255), width=1)
        elif cid == "kaede":  # onda de corte (media luna)
            d.pieslice([2, 2, 30, 30], -70, 70, fill=glow)
            d.pieslice([-4 - wob, 4, 22 - wob, 28], -80, 80, fill=(0, 0, 0, 0))
            d.arc([2, 2, 30, 30], -70, 70, fill=WHITE, width=2)
        elif cid == "volta":  # rayo
            pts = [(2, 16), (10, 11 + wob), (14, 19), (22, 12 - wob), (30, 16)]
            d.line(pts, fill=glow, width=5)
            d.line(pts, fill=WHITE, width=2)
        elif cid == "nova":  # láser
            d.rounded_rectangle([2, 12, 30, 20], radius=4, fill=shade(glow, 0.8))
            d.rounded_rectangle([6, 14, 30, 18], radius=2, fill=WHITE)
        elif cid == "bruma":  # estrella mágica
            pts = []
            for k in range(10):
                r = 13 if k % 2 == 0 else 6
                a = k / 10 * math.tau + i * 0.3
                pts.append((16 + math.cos(a) * r, 16 + math.sin(a) * r))
            d.polygon(pts, fill=glow)
            circ(d, (16, 16), 4, WHITE)
        else:  # bola de fuego
            for k in range(3):
                circ(d, (10 - k * 4 - wob, 16), 6 - k * 1.5, shade(glow, 0.75 - k * 0.15))
            circ(d, (18, 16), 10 + wob, shade(glow, 0.9))
            circ(d, (18, 16), 7, (255, 230, 150, 255))
            circ(d, (20, 14), 3.5, WHITE)
        sheet.paste(finish_small(img), (i * 32, 0))
    sheet.save(os.path.join(OUT_DIR, f"proj_{cid}.png"))


def finish_small(img):
    a = np.array(img).astype(np.float32)
    alpha = a[..., 3] > 0
    out = a.copy()
    todo = ~alpha
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        n_alpha = _shift(alpha, dx, dy)
        n_rgb = _shift(a[..., :3], dx, dy)
        m = todo & n_alpha
        out[m, :3] = n_rgb[m] * 0.3 + 12
        out[m, 3] = 255
        todo &= ~m
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- objetos
def make_items():
    def save(img, name):
        finish_small(img).save(os.path.join(OUT_DIR, name))

    bat = Image.new("RGBA", (80, 24), (0, 0, 0, 0))  # mango a la izquierda (x=8, y=12)
    d = ImageDraw.Draw(bat)
    d.polygon([(4, 10), (28, 8), (74, 4), (78, 12), (74, 20), (28, 16), (4, 14)], fill=(214, 170, 110, 255))
    d.line([(28, 8), (74, 4)], fill=(244, 212, 160, 255), width=2)
    d.line([(30, 15), (74, 19)], fill=(170, 124, 76, 255), width=2)
    d.rectangle([2, 8, 16, 16], fill=(60, 40, 110, 255))
    for x in range(4, 16, 3):
        d.line([(x, 8), (x + 2, 16)], fill=(90, 70, 150, 255))
    d.rectangle([0, 7, 3, 17], fill=(100, 80, 160, 255))
    save(bat, "item_bat.png")

    bow = Image.new("RGBA", (40 * 3, 56), (0, 0, 0, 0))  # 3 cuadros: normal, medio, tenso
    for i in range(3):
        img = Image.new("RGBA", (40, 56), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        pts = [(8, 4), (14, 6), (20, 12), (24, 20), (26, 28), (24, 36), (20, 44), (14, 50), (8, 52)]
        for a, b in zip(pts, pts[1:]):
            d.line([a, b], fill=(150, 100, 50, 255), width=5)
            d.line([a, b], fill=(190, 136, 76, 255), width=2)
        d.rectangle([22, 24, 28, 32], fill=(90, 70, 50, 255))
        pull = [0, 8, 16][i]
        d.line([(8, 5), (8 - pull, 28), (8, 51)], fill=(235, 235, 235, 255), width=1)
        if i > 0:
            d.line([(8 - pull, 28), (38, 28)], fill=(170, 130, 80, 255), width=2)
            d.polygon([(38, 24), (38, 32), (34, 28)], fill=(200, 200, 215, 255))
        bow.paste(finish_small(img), (i * 40, 0))
    bow.save(os.path.join(OUT_DIR, "item_bow.png"))

    arrow = Image.new("RGBA", (48, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(arrow)
    d.line([(6, 6), (38, 6)], fill=(170, 130, 80, 255), width=2)
    d.polygon([(46, 6), (38, 1), (38, 11)], fill=(200, 200, 215, 255))
    d.polygon([(0, 1), (10, 6), (0, 11), (5, 6)], fill=(240, 240, 240, 255))
    save(arrow, "item_arrow.png")

    bomb = Image.new("RGBA", (40 * 2, 40), (0, 0, 0, 0))  # 2 cuadros (chispa de la mecha)
    for i in range(2):
        img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        circ(d, (19, 23), 14, (40, 44, 60, 255))
        circ(d, (14, 18), 4, (110, 120, 150, 255))
        d.rectangle([16, 6, 23, 11], fill=(90, 96, 120, 255))
        d.line([(20, 6), (24, 1)], fill=(200, 170, 120, 255), width=2)
        circ(d, (25, 1 + i), 3 + i, (255, 200, 60, 255))
        bomb.paste(finish_small(img), (i * 40, 0))
    bomb.save(os.path.join(OUT_DIR, "item_bomb.png"))

    sword = Image.new("RGBA", (80, 24), (0, 0, 0, 0))  # espada de energía; mango a la izquierda
    d = ImageDraw.Draw(sword)
    d.rounded_rectangle([20, 6, 78, 18], radius=6, fill=(120, 255, 180, 200))
    d.rounded_rectangle([22, 9, 76, 15], radius=3, fill=(230, 255, 240, 255))
    d.rectangle([2, 8, 18, 16], fill=(80, 84, 100, 255))
    d.rectangle([16, 4, 20, 20], fill=(200, 200, 215, 255))
    save(sword, "item_sword.png")

    heart = Image.new("RGBA", (36, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(heart)
    circ(d, (11, 11), 9, (236, 60, 90, 255))
    circ(d, (25, 11), 9, (236, 60, 90, 255))
    d.polygon([(3, 14), (33, 14), (18, 30)], fill=(236, 60, 90, 255))
    circ(d, (9, 8), 3, (255, 170, 190, 255))
    save(heart, "item_heart.png")

    star = Image.new("RGBA", (36, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(star)
    pts = []
    for k in range(10):
        r = 16 if k % 2 == 0 else 7
        a = k / 10 * math.tau - math.pi / 2
        pts.append((18 + math.cos(a) * r, 18 + math.sin(a) * r))
    d.polygon(pts, fill=(255, 220, 60, 255))
    d.rectangle([14, 14, 15, 19], fill=(60, 40, 20, 255))
    d.rectangle([20, 14, 21, 19], fill=(60, 40, 20, 255))
    save(star, "item_star.png")

    boom = Image.new("RGBA", (36, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(boom)
    d.polygon([(4, 30), (6, 8), (30, 4), (30, 11), (13, 13), (11, 31)], fill=(214, 150, 70, 255))
    d.line([(8, 28), (8, 9), (28, 6)], fill=(250, 200, 120, 255), width=2)
    d.polygon([(6, 8), (10, 8), (10, 12), (6, 12)], fill=(200, 60, 60, 255))
    save(boom, "item_boomerang.png")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    only = os.environ.get("ONLY")
    for cid, ch in CHARACTERS.items():
        if only and cid != only:
            continue
        make_character(cid, ch)
        make_projectile(cid, ch)
        print("personaje", cid)
    make_items()
    print("Sprites generados en", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
