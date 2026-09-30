"""
Arma las hojas de animación del juego a partir de las imágenes de referencia de cada personaje.

    art/referencias/<id>.webp|png   la hoja que dibujaste / generaste (con poses sueltas)
    art/mascaras/<id>.png           qué píxeles son personaje (la crea tools/cut_sheets.py)

Salida (en assets/sprites/):
    char_<id>.png       31 filas de animación, cuadros de 160x144 (igual que antes: ver ANIMS)
    char_<id>_ult.png   (solo algunos) la versión transformada durante la ulti
    char_<id>.json      dónde está la mano y la cabeza en cada cuadro (para dibujar el pez,
                        el micrófono, la pistola, el gorro de panadero...)
    idle_<id>.png       la animación de espera (para los menús)
    portrait_<id>.png   el retrato (128x128)

Cómo funciona: cada "pose" es un rectángulo de la hoja de referencia. Cada animación es una
lista de cuadros; cada cuadro usa una pose con un pequeño ajuste opcional (girar, mover, voltear,
estirar). Así, con 10-30 poses salen las ~130 imágenes que necesita el juego.

    pip install pillow numpy scipy
    python3 tools/import_sheets.py            (todos)
    python3 tools/import_sheets.py lamont     (solo uno)
    python3 tools/import_sheets.py --debug    (además guarda art/debug_<id>.png para revisar)
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..")
REF = os.path.join(ROOT, "art", "referencias")
MASKS = os.path.join(ROOT, "art", "mascaras")
OUT = os.path.join(ROOT, "assets", "sprites")

# --- DEBE coincidir con scripts/fighter.gd ---
FW, FH = 160, 144
HIP_X, FEET_Y = 70, 138
ANIMS = [("idle", 6), ("walk", 8), ("run", 8), ("jump", 2), ("fall", 2), ("crouch", 2), ("shield", 1),
         ("dodge", 3), ("hurt", 2), ("ledge", 2), ("taunt", 6), ("win", 8), ("jab1", 3), ("jab2", 3),
         ("jab3", 4), ("ftilt", 4), ("utilt", 4), ("dtilt", 4), ("dash", 4), ("smash", 5), ("nair", 4),
         ("fair", 4), ("bair", 4), ("uair", 4), ("dair", 4), ("special", 4), ("upspecial", 3),
         ("downspecial", 4), ("charge", 4), ("throw", 3), ("ult", 4)]


def F(pose, **tf):
    """Un cuadro: pose + ajustes (rot=grados horario, dx, dy, sx, sy, flip, air=True centra en el aire)."""
    tf["pose"] = pose
    return tf


def cycle(poses, n, bob=2.0, **tf):
    """Ciclo (caminar/correr): reparte las poses en n cuadros con un pequeño rebote."""
    out = []
    for i in range(n):
        p = poses[i * len(poses) // n]
        out.append(F(p, dy=-abs(math.sin(i / n * math.tau)) * bob, **tf))
    return out


def breathe(pose, n=6, amt=0.018, **tf):
    return [F(pose, sy=1 + amt * math.sin(i / n * math.tau), sx=1 - amt * 0.6 * math.sin(i / n * math.tau), **tf)
            for i in range(n)]


def attack(windup, hit, n, recover=None, lean=0.0, reach=3.0, air=False, **tf):
    """Golpe: cuadro 0 = preparación, del 1 al n-2 = golpe, último = recuperación."""
    fr = [F(windup, rot=-lean * 0.5, dx=-2, air=air, **tf)]
    for i in range(n - 2):
        fr.append(F(hit, rot=lean, dx=reach * (i + 1) / max(1, n - 2), air=air, **tf))
    fr.append(F(recover or windup, air=air, **tf))
    return fr


def spin(pose, n, start=0.0, step=90.0, **tf):
    return [F(pose, rot=start + i * step, air=True, **tf) for i in range(n)]


# =============================================================================================
#  Personajes: rectángulos de cada pose (en píxeles de la hoja original) y animaciones
# =============================================================================================
CHARS = {}

# ----------------------------------------------------------------------------------- ILUNNA
CHARS["ilunna"] = {
    "height": 92, "portrait": (10, 13, 146, 150), "ult_form": "nojacket",
    "poses": {
        "idle": (17, 218, 137, 500), "walkA": (164, 86, 270, 349), "walkB": (284, 86, 395, 347),
        "stride": (413, 86, 552, 337), "run1": (188, 392, 343, 612), "run2": (391, 367, 552, 611),
        "crouch": (49, 644, 156, 818), "kick": (262, 637, 462, 829), "kick2": (219, 838, 405, 1022),
        "punch": (378, 840, 559, 1012, "all"),
    },
}
CHARS["ilunna"]["anims"] = {
    "idle": breathe("idle"),
    "walk": cycle(["walkA", "stride", "walkB", "stride"], 8, 2.0),
    "run": cycle(["run1", "run2"], 8, 4.0, rot=6),
    "jump": [F("run2", air=True, rot=-6), F("run2", air=True, rot=-12)],
    "fall": [F("run1", air=True, rot=8), F("run1", air=True, rot=12, dy=2)],
    "crouch": [F("crouch"), F("crouch", sy=0.97)],
    "shield": [F("crouch", sy=1.04)],
    "dodge": [F("crouch", air=True, rot=0), F("crouch", air=True, rot=120), F("crouch", air=True, rot=240)],
    "hurt": [F("stride", rot=-18, air=True, flip=True), F("run2", rot=-28, air=True, flip=True)],
    "ledge": [F("run2", rot=-70, air=True, dy=-10), F("run2", rot=-75, air=True, dy=-8)],
    "taunt": [F("idle"), F("stride"), F("run2"), F("run2", dy=-3), F("punch"), F("idle")],
    "win": [F("run2", dy=-4), F("run2"), F("punch"), F("punch", dy=-2), F("idle"), F("run2"), F("run2", dy=-4),
            F("idle")],
    "jab1": attack("stride", "run1", 3, reach=4),
    "jab2": attack("run1", "run2", 3, reach=4),
    "jab3": attack("crouch", "kick", 4, "stride"),
    "ftilt": attack("stride", "kick2", 4, lean=-4),
    "utilt": attack("crouch", "kick", 4, "stride", lean=-62),
    "dtilt": attack("crouch", "kick", 4, "crouch", lean=22),
    "dash": attack("run1", "kick2", 4, "run1", reach=6),
    "smash": attack("crouch", "punch", 5, "stride", reach=4),
    "nair": [F("crouch", air=True)] + spin("crouch", 2, 90, 90) + [F("crouch", air=True, rot=300)],
    "fair": attack("run1", "kick2", 4, air=True, lean=-12),
    "bair": attack("run1", "kick", 4, air=True, flip=True, lean=10),
    "uair": attack("crouch", "kick", 4, air=True, lean=-80),
    "dair": attack("crouch", "kick", 4, air=True, lean=72),
    "special": attack("stride", "kick2", 4, reach=4),
    "upspecial": spin("kick", 3, -60, -120),
    "downspecial": attack("crouch", "kick", 4, "crouch", lean=58),
    "charge": [F("crouch"), F("crouch", dx=1), F("punch"), F("punch", dx=3)],
    "throw": [F("run2"), F("run1", dx=4), F("stride")],
    "ult": [F("idle"), F("run2"), F("punch"), F("punch", dy=-3)],
}

# -------------------------------------------------------------------------------- ABNIELITO
CHARS["abnielito"] = {
    "height": 94, "portrait": (10, 31, 124, 150),
    "props": {"bus": ((445, 660, 548, 702), 1.9)},
    "poses": {
        "idle": (144, 77, 200, 203), "walk": (216, 83, 282, 203), "run": (292, 103, 370, 202),
        "jump": (385, 48, 449, 155), "crouch": (470, 122, 531, 203), "tumble": (664, 108, 758, 188),
        "jab": (15, 245, 114, 349), "knee": (148, 244, 220, 349), "kickA": (226, 238, 303, 349),
        "kickB": (303, 238, 385, 349), "lunge": (385, 238, 457, 349), "slide": (461, 276, 562, 337),
        "slide2": (559, 288, 730, 345, "all"), "nair": (29, 377, 122, 457), "fair": (168, 392, 277, 505),
        "bair": (306, 386, 394, 505), "hikick": (414, 376, 511, 476), "punch2": (14, 514, 108, 611),
        "punch3": (105, 520, 194, 611), "swirl": (221, 503, 319, 611, "all"), "flykick": (336, 525, 503, 610),
        "whip": (19, 621, 186, 708), "hop": (322, 613, 385, 683), "grab": (13, 738, 110, 845),
        "pummel": (160, 749, 222, 847), "fthrow": (278, 763, 384, 868), "uthrow": (540, 724, 614, 846),
        "breakdance": (647, 766, 747, 868), "ledge": (203, 872, 255, 967), "taunt1": (301, 895, 369, 1000),
        "confused": (398, 892, 452, 1001), "flex": (546, 911, 612, 1001), "ko": (667, 902, 734, 1022),
        "getup": (22, 937, 136, 999),
    },
}
CHARS["abnielito"]["anims"] = {
    "idle": breathe("idle"),
    "walk": cycle(["walk", "idle"], 8, 2.0),
    "run": cycle(["run"], 8, 4.0),
    "jump": [F("jump", air=True), F("jump", air=True, rot=-6)],
    "fall": [F("jump", air=True, rot=8), F("jump", air=True, rot=12)],
    "crouch": [F("crouch"), F("crouch", sy=0.97)],
    "shield": [F("idle")],
    "dodge": [F("crouch"), F("tumble", air=True), F("crouch")],
    "hurt": [F("tumble", air=True, rot=-10), F("tumble", air=True, rot=-30)],
    "ledge": [F("ledge", air=True, dy=6), F("ledge", air=True, dy=8)],
    "taunt": [F("taunt1"), F("confused"), F("confused", dy=-2), F("flex"), F("flex", dy=-2), F("taunt1")],
    "win": [F("ko"), F("flex"), F("ko", dy=-3), F("flex"), F("taunt1"), F("ko"), F("flex", dy=-3), F("ko")],
    "jab1": attack("idle", "jab", 3),
    "jab2": attack("jab", "punch2", 3),
    "jab3": attack("knee", "kickA", 4, "idle"),
    "ftilt": attack("knee", "kickB", 4, "idle"),
    "utilt": attack("crouch", "hikick", 4, "idle", lean=-20),
    "dtilt": attack("crouch", "breakdance", 4, "crouch"),
    "dash": attack("run", "slide2", 4, "slide", reach=6),
    "smash": attack("knee", "flykick", 5, "idle", reach=5),
    "nair": attack("jump", "nair", 4, air=True),
    "fair": attack("jump", "fair", 4, air=True),
    "bair": attack("jump", "bair", 4, air=True, flip=True),
    "uair": attack("jump", "swirl", 4, air=True, lean=-25),
    "dair": attack("jump", "fair", 4, air=True, lean=70),
    "special": attack("idle", "punch3", 4),
    "upspecial": [F("jump", air=True), F("swirl", air=True, rot=-20), F("swirl", air=True, rot=-30)],
    "downspecial": attack("crouch", "whip", 4, "crouch"),
    "charge": [F("pummel"), F("pummel", dy=-1), F("punch2"), F("punch2", dx=3)],
    "throw": [F("fthrow"), F("jab", dx=3), F("idle")],
    "ult": [F("taunt1"), F("confused"), F("punch3"), F("punch3", dx=3)],
}

# ---------------------------------------------------------------------------------- SCHIZOV
CHARS["schizov"] = {
    "height": 94, "sx": 1.08, "portrait": (8, 31, 131, 145),
    "poses": {
        "idle": (157, 19, 226, 152), "idle2": (226, 19, 277, 152), "idle3": (277, 19, 345, 155),
        "walkA": (377, 23, 432, 131), "walkB": (446, 23, 509, 131), "runA": (530, 31, 603, 131),
        "runB": (606, 33, 675, 131), "jump1": (200, 155, 256, 246), "jump0": (153, 170, 200, 273),
        "fall1": (255, 174, 307, 272), "fall2": (312, 160, 360, 262), "crouchA": (16, 203, 72, 277),
        "crouchB": (72, 201, 144, 298), "dodgeA": (515, 209, 587, 272), "dodgeB": (594, 209, 672, 273),
        "ledge": (561, 298, 612, 372), "jab": (4, 409, 72, 497), "kick": (135, 405, 248, 515),
        "captoss": (252, 387, 321, 515), "push": (313, 430, 398, 496), "hatup": (534, 370, 645, 497),
        "lowkick": (594, 423, 689, 482), "nair": (41, 527, 150, 599, "all"), "fair": (185, 539, 284, 618),
        "bair": (307, 536, 383, 652), "uair": (412, 520, 472, 628), "dair": (497, 523, 562, 652),
        "hathide": (564, 542, 611, 635), "dart": (11, 672, 75, 773), "blueprint": (193, 698, 354, 773, "all"),
        "capthrow": (400, 668, 470, 772), "deflect": (526, 679, 666, 788), "grab": (4, 795, 82, 877),
        "tauntA": (107, 781, 165, 877), "tauntB": (395, 795, 458, 876), "book": (480, 796, 560, 877),
        "ko": (566, 836, 668, 877), "angry": (13, 911, 81, 1014), "slap": (194, 913, 256, 1013),
        "cheer1": (313, 904, 366, 1013), "cheer2": (386, 904, 451, 1013), "cheer3": (466, 904, 533, 1013),
        "diploma": (584, 903, 650, 1024),
    },
}
CHARS["schizov"]["anims"] = {
    "idle": [F("idle"), F("idle", sy=1.012), F("idle", sy=1.02), F("idle", sy=1.02), F("idle", sy=1.012), F("idle")],
    "walk": cycle(["walkA", "walkB"], 8, 1.5),
    "run": cycle(["runA", "runB"], 8, 3.0),
    "jump": [F("jump0", air=True), F("jump1", air=True)],
    "fall": [F("fall1", air=True), F("fall2", air=True)],
    "crouch": [F("crouchA"), F("crouchB")],
    "shield": [F("crouchA", sy=1.05)],
    "dodge": [F("dodgeA"), F("dodgeB", air=True), F("dodgeA")],
    "hurt": [F("dodgeB", air=True, rot=-20), F("fall2", air=True, rot=-35, flip=True)],
    "ledge": [F("ledge", air=True, dy=4), F("ledge", air=True, dy=6)],
    "taunt": [F("tauntA"), F("book"), F("book", dy=-1), F("tauntB"), F("tauntB", dy=-1), F("tauntA")],
    "win": [F("cheer1"), F("cheer2"), F("cheer3"), F("cheer2", dy=-3), F("diploma"), F("cheer1", dy=-3),
            F("cheer3"), F("diploma")],
    "jab1": attack("idle", "jab", 3),
    "jab2": attack("jab", "slap", 3),
    "jab3": attack("crouchA", "kick", 4, "idle"),
    "ftilt": attack("idle3", "dart", 4, "idle"),
    "utilt": attack("crouchA", "uair", 4, "idle"),
    "dtilt": attack("crouchA", "lowkick", 4, "crouchA"),
    "dash": attack("runA", "push", 4, "runB", reach=6),
    "smash": attack("crouchB", "deflect", 5, "idle", reach=4),
    "nair": attack("jump1", "nair", 4, air=True),
    "fair": attack("jump1", "fair", 4, air=True),
    "bair": attack("jump1", "bair", 4, air=True, flip=True),
    "uair": attack("jump1", "uair", 4, air=True),
    "dair": attack("jump1", "hathide", 4, air=True, lean=10),
    "special": attack("idle", "capthrow", 4),
    "upspecial": [F("jump0", air=True), F("captoss", air=True), F("captoss", air=True, dy=-4)],
    "downspecial": attack("crouchA", "blueprint", 4, "crouchA", reach=8),
    "charge": [F("book"), F("book", dx=1), F("capthrow"), F("capthrow", dx=3)],
    "throw": [F("grab"), F("dart", dx=3), F("idle")],
    "ult": [F("angry"), F("angry", dy=-2), F("slap"), F("jab")],
}

# --------------------------------------------------------------------------------- PANADERO
CHARS["panadero"] = {
    "height": 96, "sx": 1.2, "portrait": (4, 21, 88, 112), "ult_form": "baker",
    "props": {"baguette": ((57, 657, 113, 678), 1.0), "loaf": ((205, 512, 226, 536), 1.0)},
    "poses": {
        "idle": (4, 120, 32, 191), "walkA": (41, 122, 72, 181), "walkB": (72, 122, 102, 181),
        "run": (102, 122, 132, 181), "crouchA": (135, 134, 164, 181), "crouchB": (164, 134, 193, 181),
        "jump": (196, 115, 223, 176), "dodge": (41, 202, 75, 260), "kick": (79, 211, 125, 261),
        "uppunch": (125, 211, 168, 261), "bend": (166, 218, 202, 271), "dtilt": (204, 222, 247, 261),
        "stand2": (2, 279, 30, 338), "bambo": (37, 287, 96, 343, "all"), "hunch": (95, 292, 126, 338),
        "nairspin": (1, 364, 33, 412), "fairkick": (45, 366, 94, 413), "utilt": (97, 358, 123, 414),
        "uair": (135, 349, 156, 411), "dair": (168, 366, 206, 414), "dair2": (213, 371, 255, 413),
        "armsup": (173, 426, 195, 492), "fair2": (60, 445, 109, 493), "bair": (130, 441, 156, 493),
        "fsmash": (4, 542, 83, 604, "all"), "usmash": (128, 540, 157, 605), "dsmash": (166, 554, 200, 604),
        "throwA": (2, 644, 52, 690), "reach": (133, 626, 158, 688), "dkick": (200, 646, 246, 687, "all"),
        "armup": (170, 707, 201, 763), "dive": (6, 727, 47, 764), "dive2": (95, 728, 153, 764),
        "grab": (2, 790, 49, 842), "pin": (62, 793, 134, 848, "all"), "bthrow": (147, 776, 180, 838),
        "yeast": (205, 801, 260, 843, "all"), "grab2": (4, 874, 38, 927), "lie": (53, 893, 125, 943),
        "sit": (153, 888, 193, 925), "flex": (209, 954, 248, 1014), "ko": (139, 958, 171, 1023),
    },
}
CHARS["panadero"]["anims"] = {
    "idle": breathe("idle", amt=0.025),
    "walk": cycle(["walkA", "idle", "walkB", "idle"], 8, 2.0),
    "run": cycle(["run", "walkB"], 8, 3.0, rot=5),
    "jump": [F("jump", air=True), F("jump", air=True, dy=-2)],
    "fall": [F("armsup", air=True, sy=0.9), F("armsup", air=True, sy=0.88)],
    "crouch": [F("crouchA"), F("crouchB")],
    "shield": [F("crouchA", sy=1.05)],
    "dodge": [F("crouchB"), F("dodge", air=True), F("crouchB")],
    "hurt": [F("bend", air=True, rot=-20, flip=True), F("hunch", air=True, rot=-35, flip=True)],
    "ledge": [F("reach", air=True, dy=4), F("reach", air=True, dy=6)],
    "taunt": [F("flex"), F("ko"), F("ko", dy=-2), F("flex"), F("flex", dy=-2), F("idle")],
    "win": [F("flex"), F("ko"), F("flex", dy=-3), F("ko"), F("armsup"), F("flex"), F("ko", dy=-3), F("flex")],
    "jab1": attack("idle", "grab", 3),
    "jab2": attack("grab", "throwA", 3),
    "jab3": attack("hunch", "bambo", 4, "idle"),
    "ftilt": attack("idle", "kick", 4),
    "utilt": attack("crouchA", "uppunch", 4, "idle"),
    "dtilt": attack("crouchA", "dtilt", 4, "crouchA"),
    "dash": attack("run", "dive2", 4, "run", reach=6),
    "smash": attack("hunch", "fsmash", 5, "idle", reach=4),
    "nair": attack("jump", "nairspin", 4, air=True),
    "fair": attack("jump", "fair2", 4, air=True),
    "bair": attack("jump", "fairkick", 4, air=True, flip=True),
    "uair": attack("jump", "uair", 4, air=True),
    "dair": attack("jump", "dair", 4, air=True, lean=20),
    "special": attack("idle", "throwA", 4),
    "upspecial": [F("crouchB"), F("usmash", air=True), F("armup", air=True)],
    "downspecial": attack("crouchA", "yeast", 4, "crouchA"),
    "charge": [F("crouchA"), F("crouchB"), F("pin"), F("pin", dx=3)],
    "throw": [F("grab"), F("throwA", dx=3), F("idle")],
    "ult": [F("flex"), F("armup"), F("throwA"), F("fsmash")],
}

# ----------------------------------------------------------------------------------- LAMONT
CHARS["lamont"] = {
    "height": 92, "portrait": (18, 29, 122, 139), "mask_thr": 0.5, "scale_ref": "taunt",
    "clean_gray": (78, 118),
    "poses": {
        # las 3 poses de pie de arriba están dibujadas más grandes en la hoja: se achican (último número)
        "front": (157, 16, 217, 153, "main", 0.68), "idle2": (248, 17, 302, 154, "main", 0.68),
        "idle": (314, 17, 370, 154, "main", 0.68),
        "run1": (373, 79, 428, 153), "run2": (434, 76, 485, 148), "run3": (494, 79, 551, 151),
        "crouchA": (571, 87, 617, 154), "crouchB": (651, 89, 702, 154), "leap": (735, 44, 791, 134),
        "sprint": (822, 82, 896, 154), "capfix": (948, 70, 1010, 164), "jab": (32, 172, 107, 252),
        "ftilt": (195, 172, 267, 248), "utilt": (334, 172, 390, 252), "dtilt": (442, 175, 510, 252),
        "dash": (523, 182, 673, 247, "all"), "dair": (560, 262, 640, 361), "nair": (37, 271, 106, 354, "all"),
        "fair": (172, 276, 257, 361), "bair": (326, 277, 387, 362), "uair": (444, 272, 509, 362),
        "fsmash": (664, 289, 789, 362, "all"), "usmash": (809, 262, 899, 362, "all"),
        "dsmash": (920, 273, 1001, 361), "shoot": (270, 382, 362, 455), "door": (481, 376, 626, 455, "all"),
        "brake": (694, 406, 842, 451, "all"), "grab": (33, 470, 96, 554), "pummel": (163, 475, 217, 554),
        "fthrow": (305, 484, 416, 554), "uthrow": (657, 461, 699, 554), "dthrow": (786, 511, 878, 562),
        "taunt": (932, 464, 983, 553),
    },
}
CHARS["lamont"]["anims"] = {
    "idle": breathe("idle"),
    "walk": cycle(["run1", "run2", "run3", "run2"], 8, 1.5),
    "run": cycle(["sprint", "run3", "sprint", "run1"], 8, 3.0),
    "jump": [F("leap", air=True), F("leap", air=True, rot=-6)],
    "fall": [F("leap", air=True, rot=10), F("leap", air=True, rot=14)],
    "crouch": [F("crouchA"), F("crouchB")],
    "shield": [F("crouchA", sy=1.04)],
    "dodge": [F("crouchB"), F("sprint", air=True, rot=-20), F("crouchB")],
    "hurt": [F("dthrow", air=True, rot=-15, flip=True), F("leap", air=True, rot=-40, flip=True)],
    "ledge": [F("uthrow", air=True, dy=6), F("uthrow", air=True, dy=8)],
    "taunt": [F("capfix"), F("taunt"), F("taunt", dy=-2), F("capfix"), F("capfix", dy=-2), F("idle")],
    "win": [F("taunt"), F("capfix"), F("taunt", dy=-3), F("front"), F("capfix"), F("taunt"), F("front", dy=-3),
            F("taunt")],
    "jab1": attack("idle", "jab", 3),
    "jab2": attack("jab", "pummel", 3),
    "jab3": attack("crouchA", "fair", 4, "idle"),
    "ftilt": attack("idle", "ftilt", 4),
    "utilt": attack("crouchA", "utilt", 4, "idle"),
    "dtilt": attack("crouchA", "dtilt", 4, "crouchA"),
    "dash": attack("sprint", "dash", 4, "run1", reach=6),
    "smash": attack("crouchB", "fsmash", 5, "idle", reach=4),
    "nair": attack("leap", "nair", 4, air=True),
    "fair": attack("leap", "fair", 4, air=True),
    "bair": attack("leap", "bair", 4, air=True, flip=True),
    "uair": attack("leap", "uair", 4, air=True),
    "dair": attack("leap", "dair", 4, air=True),
    "special": attack("idle", "shoot", 4, reach=2),
    "upspecial": [F("crouchA"), F("door", air=True), F("usmash", air=True)],
    "downspecial": attack("crouchA", "brake", 4, "crouchB", reach=6),
    "charge": [F("grab"), F("grab", dx=1), F("shoot"), F("shoot", dx=3)],
    "throw": [F("grab"), F("fthrow", dx=3), F("idle")],
    "ult": [F("capfix"), F("taunt"), F("shoot"), F("shoot", dx=2)],
}


# =============================================================================================
#  Motor
# =============================================================================================
def find(name):
    for ext in (".webp", ".png", ".jpg"):
        p = os.path.join(REF, name + ext)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(name)


class Sheet:
    def __init__(self, cid, cfg):
        self.cid = cid
        self.cfg = cfg
        self.rgb = np.asarray(Image.open(find(cid)).convert("RGB"))
        m = np.asarray(Image.open(os.path.join(MASKS, cid + ".png")).convert("L")).astype(np.float32) / 255.0
        self.mask = m > cfg.get("mask_thr", 0.5)
        self.cache = {}

    def extract(self, name):
        """Recorta una pose: devuelve RGBA (numpy float, premultiplicado no) a tamaño original."""
        spec = self.cfg["poses"][name]
        x0, y0, x1, y1 = spec[:4]
        keep = spec[4] if len(spec) > 4 else "main"
        m = self.mask[y0:y1, x0:x1].copy()
        lab, n = ndimage.label(ndimage.binary_dilation(m, iterations=self.cfg.get("dil", 1)))
        if n == 0:
            raise ValueError(f"{self.cid}:{name} sin píxeles")
        areas = ndimage.sum(m, lab, range(1, n + 1))
        big = areas.max()
        sel = np.zeros(n + 1, bool)
        for i, a in enumerate(areas, 1):
            sel[i] = a == big or (keep == "all" and a > 0.06 * big) or a > 0.35 * big
        m &= sel[lab]
        if "clean_gray" in self.cfg:
            # restos del fondo de cuadritos dentro de efectos transparentes: grises neutros de un tono
            lo, hi = self.cfg["clean_gray"]
            rgb0 = self.rgb[y0:y1, x0:x1].astype(np.int32)
            L = rgb0.mean(2)
            neutral = (rgb0.max(2) - rgb0.min(2)) < 12
            gray = neutral & (L > lo) & (L < hi)
            m &= ~ndimage.binary_opening(gray, iterations=1)
            m = ndimage.binary_opening(m, iterations=1)
        ys, xs = np.nonzero(m)
        m = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        rgb = self.rgb[y0 + ys.min():y0 + ys.max() + 1, x0 + xs.min():x0 + xs.max() + 1]
        return np.dstack([rgb.astype(np.float32), m.astype(np.float32) * 255.0])

    def scale(self):
        if "_scale" not in self.cfg:
            ref = self.cfg.get("scale_ref", "idle")
            img = self.extract(ref)
            self.cfg["_scale"] = self.cfg["height"] / img.shape[0]
        return self.cfg["_scale"]

    def pose(self, name, form=""):
        key = (name, form)
        if key in self.cache:
            return self.cache[key]
        a = self.extract(name)
        if form:
            a = recolor(a, form)
        spec = self.cfg["poses"][name]
        s = self.scale() * (spec[5] if len(spec) > 5 else 1.0)
        sx = s * self.cfg.get("sx", 1.0)
        w = max(1, round(a.shape[1] * sx))
        h = max(1, round(a.shape[0] * s))
        img = resize_rgba(a, w, h)
        # quita 1 píxel del borde (restos grises del fondo de cuadritos)
        img[..., 3] = ndimage.binary_erosion(img[..., 3] > 0, iterations=self.cfg.get("erode", 1)) * 255.0
        self.cache[key] = img
        return img


def resize_rgba(a, w, h):
    """Redimensiona con premultiplicado (sin halos) y deja el borde nítido."""
    alpha = a[..., 3:4] / 255.0
    pm = np.dstack([a[..., :3] * alpha, alpha[..., 0] * 255.0])
    im = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), "RGBA")
    up = w > a.shape[1] * 1.3
    im = im.resize((w, h), Image.LANCZOS if not up else Image.BICUBIC)
    if up:   # al agrandar mucho (Panadero), realza un poco los detalles
        rgb = im.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=70, threshold=2))
        im = Image.merge("RGBA", (*rgb.split(), im.split()[3]))
    b = np.asarray(im).astype(np.float32)
    al = b[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, b[..., :3] / np.maximum(al, 0.01), 0)
    return np.dstack([rgb, (b[..., 3] > 110).astype(np.float32) * 255.0])


def recolor(a, form):
    """Versión transformada de la ulti (se aplica a la pose original, antes de escalar)."""
    a = a.copy()
    H, W = a.shape[:2]
    rgb = a[..., :3]
    L = rgb.mean(2)
    mx, mn = rgb.max(2), rgb.min(2)
    solid = a[..., 3] > 0
    yy = np.arange(H)[:, None] * np.ones((1, W))
    if form == "nojacket":
        # la chaqueta negra (zona del torso y brazos) pasa a ser un jersey blanco
        # (la ropa negra: oscura y casi sin color; el pelo queda arriba y el pantalón abajo)
        band = (yy > H * 0.24) & (yy < H * 0.60)
        dark = solid & band & (L < 92) & ((mx - mn) < 38)
        k = np.clip((L - 12) / 80.0, 0, 1)[..., None]
        white = np.array([150, 152, 160]) + k * np.array([100, 98, 92])
        edge = L < 20
        rgb[dark & ~edge] = white[dark & ~edge]
    elif form == "baker":
        # la camisa celeste pasa a ser una chaquetilla de chef blanca
        blue = solid & (rgb[..., 2] > rgb[..., 0] + 12) & (L > 55) & (yy < H * 0.6)
        k = np.clip((L - 55) / 180.0, 0, 1)[..., None]
        white = np.array([196, 196, 200]) + k * np.array([59, 59, 55])
        rgb[blue] = white[blue]
    a[..., :3] = rgb
    return a


def rotate_rgba(img, deg):
    """Gira (grados en sentido horario) y devuelve la imagen y el desplazamiento del centro."""
    if abs(deg) < 0.01:
        return img
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    im = im.rotate(-deg, resample=Image.BICUBIC, expand=True)
    b = np.asarray(im).astype(np.float32)
    b[..., 3] = (b[..., 3] > 110) * 255.0
    return b


def trim(img):
    ys, xs = np.nonzero(img[..., 3] > 0)
    return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def outline(frame):
    """Contorno oscuro de 1 píxel alrededor del personaje (para que resalte en cualquier fondo)."""
    a = frame[..., 3] > 0
    ring = ndimage.binary_dilation(a, structure=np.ones((3, 3))) & ~a
    out = frame.copy()
    # el color del contorno sale de los vecinos, muy oscurecido
    src = frame[..., :3] * a[..., None]
    cnt = ndimage.uniform_filter(a.astype(np.float32), 3)
    avg = np.stack([ndimage.uniform_filter(src[..., c], 3) for c in range(3)], -1) / np.maximum(cnt, 1e-3)[..., None]
    out[ring, :3] = avg[ring] * 0.22 + 8
    out[ring, 3] = 235
    return out


def head_x(img):
    a = img[..., 3] > 0
    ys, xs = np.nonzero(a)
    top = ys.min()
    h = ys.max() - top + 1
    sel = ys < top + h * 0.28
    return float(xs[sel].mean())


def render(sheet, fr, form=""):
    """Dibuja un cuadro de 160x144. Devuelve (imagen, info de mano/cabeza)."""
    img = sheet.pose(fr["pose"], form)
    if fr.get("flip"):
        img = img[:, ::-1]
    sx, sy = fr.get("sx", 1.0), fr.get("sy", 1.0)
    if sx != 1.0 or sy != 1.0:
        img = resize_rgba(img, max(1, round(img.shape[1] * sx)), max(1, round(img.shape[0] * sy)))
    hx = head_x(img)
    h0 = img.shape[0]
    rot = fr.get("rot", 0.0)
    if rot:
        # posición de la cabeza tras girar (alrededor del centro)
        cx, cy = img.shape[1] / 2, img.shape[0] / 2
        img2 = trim(rotate_rgba(img, rot))
        r = math.radians(rot)
        ys, xs = np.nonzero(img[..., 3] > 0)
        px, py = hx - cx, ys.min() + 4 - cy
        img = img2
        head = (px * math.cos(r) - py * math.sin(r), px * math.sin(r) + py * math.cos(r))
    else:
        head = None
    H, W = img.shape[:2]
    target = sheet.cfg["height"]
    if fr.get("air"):
        # en el aire: el centro del cuerpo a media altura
        ox = HIP_X - (W / 2 if rot else hx)
        oy = FEET_Y - target * 0.55 - H / 2
    elif rot:
        ox = HIP_X - W / 2
        oy = FEET_Y - H
    else:
        ox = HIP_X - hx
        oy = FEET_Y - H
    ox += fr.get("dx", 0.0)
    oy += fr.get("dy", 0.0)
    ox, oy = int(round(ox)), int(round(oy))
    frame = np.zeros((FH, FW, 4), np.float32)
    x0, y0 = max(0, ox), max(0, oy)
    x1, y1 = min(FW, ox + W), min(FH, oy + H)
    if x1 > x0 and y1 > y0:
        frame[y0:y1, x0:x1] = img[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    # --- dónde está la cabeza y la mano (para dibujar objetos encima) ---
    if head is not None:
        top = (ox + W / 2 + head[0], oy + H / 2 + head[1])
    else:
        ys, xs = np.nonzero(img[..., 3] > 0)
        top = (ox + hx, oy + ys.min())
    a = frame[..., 3] > 0
    ys, xs = np.nonzero(a)
    info = {"head": [round(float(top[0]) - HIP_X, 1), round(float(top[1]) - FEET_Y, 1)], "hand": [16.0, -50.0, 0.0]}
    if len(ys):
        ty, by = ys.min(), ys.max()
        hh = by - ty + 1
        band = (ys > ty + hh * 0.2) & (ys < ty + hh * 0.62)
        if band.any():
            front = xs[band].max()
            near = band & (xs >= front - 5)
            hy = float(ys[near].mean())
            shoulder = (top[0], top[1] + hh * 0.3)
            ang = math.degrees(math.atan2(hy - shoulder[1], front - shoulder[0]))
            info["hand"] = [round(float(front) - 3 - HIP_X, 1), round(hy - FEET_Y, 1), round(ang, 1)]
    return frame, info


def draw_chef_hat(frame, info, scale):
    """Gorro de panadero sobre la cabeza (versión de la ulti de Panadero)."""
    im = Image.fromarray(np.clip(frame, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(im)
    hx = info["head"][0] + HIP_X
    hy = info["head"][1] + FEET_Y + 6
    w = 13 * scale
    d.rectangle([hx - w * 0.75, hy - 7 * scale, hx + w * 0.75, hy], fill=(236, 236, 240, 255), outline=(40, 40, 50, 255))
    for cx, cy, r in ((-0.6, -12, 0.62), (0.0, -16, 0.72), (0.6, -12, 0.62)):
        rr = r * w
        d.ellipse([hx + cx * w - rr, hy + cy * scale - rr, hx + cx * w + rr, hy + cy * scale + rr],
                  fill=(250, 250, 252, 255), outline=(40, 40, 50, 255))
    d.rectangle([hx - w * 0.72, hy - 8 * scale, hx + w * 0.72, hy - 1], fill=(244, 244, 248, 255))
    d.line([hx - w * 0.72, hy - 3 * scale, hx + w * 0.72, hy - 3 * scale], fill=(214, 170, 90, 255), width=2)
    return np.asarray(im).astype(np.float32)


def build(cid, debug=False):
    cfg = CHARS[cid]
    sheet = Sheet(cid, cfg)
    os.makedirs(OUT, exist_ok=True)
    forms = [""] + ([cfg["ult_form"]] if cfg.get("ult_form") else [])
    meta = {"hands": {}, "heads": {}}
    for form in forms:
        out = np.zeros((FH * len(ANIMS), FW * 8, 4), np.float32)
        for row, (name, n) in enumerate(ANIMS):
            frames = cfg["anims"][name]
            assert len(frames) >= n, (cid, name, len(frames), n)
            hands, heads = [], []
            for col in range(n):
                fr, info = render(sheet, frames[col], form)
                if form == "baker":
                    fr = draw_chef_hat(fr, info, cfg["height"] / 92.0)
                out[row * FH:(row + 1) * FH, col * FW:(col + 1) * FW] = outline(fr)
                hands.append(info["hand"])
                heads.append(info["head"])
            if form == "":
                meta["hands"][name] = hands
                meta["heads"][name] = heads
        img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
        suffix = "_ult" if form else ""
        img.save(os.path.join(OUT, f"char_{cid}{suffix}.png"), optimize=True)
        if form == "":
            img.crop((0, 0, FW * 6, FH)).save(os.path.join(OUT, f"idle_{cid}.png"))
            if debug:
                dbg = Image.new("RGBA", img.size, (60, 70, 90, 255))
                dbg.alpha_composite(img)
                d = ImageDraw.Draw(dbg)
                for row, (name, n) in enumerate(ANIMS):
                    d.text((2, row * FH + 2), name, fill=(255, 255, 0, 255))
                    for col in range(n):
                        hx, hy, _ = meta["hands"][name][col]
                        px, py = col * FW + HIP_X + hx, row * FH + FEET_Y + hy
                        d.ellipse([px - 2, py - 2, px + 2, py + 2], fill=(255, 0, 0, 255))
                        tx, ty = meta["heads"][name][col]
                        d.ellipse([col * FW + HIP_X + tx - 2, row * FH + FEET_Y + ty - 2,
                                   col * FW + HIP_X + tx + 2, row * FH + FEET_Y + ty + 2], fill=(0, 255, 0, 255))
                        d.line([col * FW, row * FH + FEET_Y, col * FW + FW, row * FH + FEET_Y], fill=(255, 255, 255, 60))
                dbg.save(os.path.join(ROOT, "art", f"debug_{cid}.png"))
    with open(os.path.join(OUT, f"char_{cid}.json"), "w") as f:
        json.dump(meta, f, separators=(",", ":"))
    # objetos sacados de la misma hoja (la guagua, la baguette...)
    for pname, (bx, k) in cfg.get("props", {}).items():
        cfg["poses"]["_" + pname] = bx
        img = sheet.pose("_" + pname)
        img = outline(np.pad(img, ((2, 2), (2, 2), (0, 0))))
        if k != 1.0:
            img = resize_rgba(img, round(img.shape[1] * k), round(img.shape[0] * k))
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, f"prop_{pname}.png"))
    # retrato
    x0, y0, x1, y1 = cfg["portrait"]
    por = Image.fromarray(sheet.rgb[y0:y1, x0:x1]).resize((128, 128), Image.LANCZOS)
    por.save(os.path.join(OUT, f"portrait_{cid}.png"))
    print("personaje", cid)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    debug = "--debug" in sys.argv
    for cid in args or list(CHARS):
        if not CHARS[cid]["poses"]:
            print("(sin poses todavía)", cid)
            continue
        build(cid, debug)


if __name__ == "__main__":
    main()
