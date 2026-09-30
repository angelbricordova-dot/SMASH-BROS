"""
Generador de efectos de sonido simples (sin dependencias externas).
Uso: python3 tools/make_sounds.py
Crea archivos .wav en assets/sounds/. Puedes reemplazarlos por tus propios sonidos
(mismo nombre de archivo) o agregar más y registrarlos en scripts/game.gd (lista SFX).
"""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
RATE = 22050


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    k = min(1.0, 0.95 / peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32000)) for s in samples))


def osc(kind, phase):
    if kind == "square":
        return 1.0 if (phase % 1.0) < 0.5 else -1.0
    if kind == "saw":
        return 2.0 * (phase % 1.0) - 1.0
    if kind == "tri":
        p = phase % 1.0
        return 4 * p - 1 if p < 0.5 else 3 - 4 * p
    return math.sin(phase * math.tau)


def tone(f0, f1, dur, vol=0.5, kind="square", decay=3.0, noise=0.0, attack=0.005, seed=1, vibrato=0.0):
    n = int(RATE * dur)
    rnd = random.Random(seed)
    out, phase = [], 0.0
    lp = 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * t
        f *= 1 + vibrato * math.sin(i / RATE * 40)
        phase += f / RATE
        s = osc(kind, phase)
        if noise:
            lp += (rnd.uniform(-1, 1) - lp) * 0.5
            s = s * (1 - noise) + lp * noise * 1.6
        env = min(1.0, (i / RATE) / attack) * math.exp(-decay * t)
        out.append(s * vol * env)
    return out


def noise_burst(dur, vol=0.6, decay=4.0, smooth=0.3, seed=2):
    rnd = random.Random(seed)
    n = int(RATE * dur)
    out, lp = [], 0.0
    for i in range(n):
        lp += (rnd.uniform(-1, 1) - lp) * smooth
        out.append(lp * vol * math.exp(-decay * i / n))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(gap * RATE)
    return out


def delay(samples, secs, amount=0.35):
    out = [0.0] * int(secs * RATE)
    return mix(samples, out + [s * amount for s in samples])


NOTE = lambda n: 440.0 * 2 ** ((n - 69) / 12)  # noqa: E731

# --- combate
save("hit", mix(tone(180, 60, 0.18, 0.7, "saw", 5, 0.5), noise_burst(0.08, 0.5, 6)))
save("hit_strong", mix(tone(130, 40, 0.4, 0.9, "saw", 3.5, 0.6), noise_burst(0.25, 0.8, 4, 0.2)))
save("homerun", mix(tone(90, 30, 0.7, 1.0, "saw", 2.5, 0.5), noise_burst(0.5, 0.9, 3, 0.15),
                    seq([0.0] * int(0.05 * RATE), tone(1200, 2400, 0.4, 0.3, "sine", 2))))
save("swing", noise_burst(0.16, 0.5, 3, 0.08, seed=5))
save("jump", tone(260, 620, 0.14, 0.35, "square", 3))
save("double_jump", mix(tone(400, 900, 0.16, 0.3, "tri", 3), noise_burst(0.12, 0.25, 5, 0.15)))
save("land", noise_burst(0.07, 0.4, 7, 0.25, seed=9))
save("dash", noise_burst(0.14, 0.55, 5, 0.1, seed=11))
save("shoot", tone(900, 250, 0.22, 0.35, "square", 3))
save("shield", tone(520, 380, 0.12, 0.45, "square", 6, 0.2))
save("shield_crack", mix(tone(1400, 700, 0.1, 0.35, "square", 8), noise_burst(0.08, 0.4, 8, 0.6)))
save("shield_break", mix(tone(900, 90, 0.7, 0.6, "square", 2.5, 0.3), noise_burst(0.6, 0.6, 3, 0.7)))
save("parry", delay(mix(tone(NOTE(84), NOTE(84), 0.25, 0.4, "square", 4),
                        tone(NOTE(91), NOTE(91), 0.25, 0.3, "square", 4)), 0.07, 0.4))
save("ko", mix(tone(700, 60, 0.9, 0.6, "saw", 2.0, 0.25), noise_burst(0.9, 0.5, 2.5, 0.2)))
save("ult_ready", seq(*[tone(NOTE(n), NOTE(n), 0.08, 0.3, "square", 2) for n in (72, 76, 79, 84)]))
save("ult", mix(tone(80, 600, 1.0, 0.5, "saw", 1.2, 0.3, attack=0.2), tone(160, 1200, 1.0, 0.25, "square", 1.5),
                noise_burst(1.0, 0.3, 1.5, 0.1)))
save("beam", mix(tone(110, 90, 1.0, 0.6, "saw", 1.0, 0.5, vibrato=0.05), noise_burst(1.0, 0.6, 1.2, 0.4)))
save("freeze", mix(tone(2000, 3000, 0.5, 0.3, "sine", 3, vibrato=0.08), tone(1500, 900, 0.5, 0.2, "tri", 3)))
save("shatter", mix(noise_burst(0.5, 0.8, 4, 0.8), tone(3000, 1200, 0.3, 0.3, "square", 6)))
save("quake", mix(tone(60, 30, 1.2, 1.0, "saw", 2.0, 0.7), noise_burst(1.2, 0.9, 2, 0.05)))
save("teleport", mix(tone(300, 1800, 0.25, 0.35, "sine", 2, vibrato=0.1), noise_burst(0.25, 0.25, 3, 0.3)))
save("shadow", mix(tone(200, 60, 0.6, 0.5, "saw", 2, 0.4, vibrato=0.15), noise_burst(0.6, 0.3, 2, 0.05)))
save("fire", mix(noise_burst(0.4, 0.7, 3, 0.35), tone(200, 120, 0.4, 0.3, "saw", 3, 0.5)))
save("uppercut", mix(tone(300, 900, 0.25, 0.4, "saw", 3, 0.3), noise_burst(0.2, 0.4, 4, 0.3)))
save("bow_draw", tone(180, 260, 0.35, 0.25, "tri", 1, 0.3))
save("bow_shoot", mix(tone(700, 200, 0.15, 0.4, "square", 6), noise_burst(0.1, 0.3, 6, 0.4)))
save("arrow_hit", mix(tone(400, 150, 0.1, 0.5, "square", 8), noise_burst(0.06, 0.4, 8, 0.6)))
save("pickup", seq(tone(NOTE(79), NOTE(79), 0.06, 0.35, "square", 2), tone(NOTE(86), NOTE(86), 0.1, 0.35, "square", 3)))
save("item_spawn", seq(*[tone(NOTE(n), NOTE(n), 0.05, 0.25, "tri", 2) for n in (67, 71, 74, 79)]))
save("throw", noise_burst(0.2, 0.5, 3, 0.1, seed=17))
save("taunt", seq(tone(NOTE(76), NOTE(76), 0.08, 0.3, "square", 2), tone(NOTE(72), NOTE(72), 0.12, 0.3, "square", 3)))
save("crouch", noise_burst(0.05, 0.2, 8, 0.2, seed=23))
save("helpless", tone(500, 300, 0.2, 0.2, "tri", 4))
# --- interfaz
save("select", tone(520, 780, 0.1, 0.35, "square", 4))
save("menu_move", tone(NOTE(79), NOTE(79), 0.05, 0.25, "square", 5))
save("menu_confirm", seq(tone(NOTE(76), NOTE(76), 0.06, 0.3, "square", 3), tone(NOTE(83), NOTE(83), 0.12, 0.3, "square", 3)))
save("menu_back", seq(tone(NOTE(76), NOTE(76), 0.06, 0.3, "square", 3), tone(NOTE(69), NOTE(69), 0.1, 0.3, "square", 3)))
save("start", tone(300, 900, 0.4, 0.4, "square", 2))
save("go", mix(seq(*[tone(NOTE(n), NOTE(n), 0.07, 0.3, "square", 1) for n in (72, 76, 79)]),
               seq([0.0] * int(0.21 * RATE), tone(NOTE(84), NOTE(84), 0.5, 0.35, "square", 2))))
# ovación (ruido filtrado con "aplausos")
rnd = random.Random(99)
claps = [0.0] * int(2.2 * RATE)
for _ in range(160):
    pos = rnd.randint(0, len(claps) - 2000)
    for i, s in enumerate(noise_burst(0.03, rnd.uniform(0.2, 0.5), 9, 0.9, seed=rnd.randint(0, 9999))):
        claps[pos + i] += s
crowd = noise_burst(2.2, 0.5, 1.2, 0.03, seed=7)
save("cheer", mix(claps, crowd))
fan = []
for n, d in [(72, 0.12), (76, 0.12), (79, 0.12), (84, 0.36), (79, 0.12), (84, 0.6)]:
    fan += mix(tone(NOTE(n), NOTE(n), d, 0.3, "square", 1), tone(NOTE(n - 12), NOTE(n - 12), d, 0.2, "tri", 1))
save("fanfare", fan)
print("Sonidos generados en", os.path.abspath(OUT))
