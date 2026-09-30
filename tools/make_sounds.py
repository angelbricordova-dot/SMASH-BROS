"""
Generador de efectos de sonido simples (sin dependencias externas).
Uso: python3 tools/make_sounds.py
Crea archivos .wav en assets/sounds/. Puedes reemplazarlos por tus propios sonidos
(mismo nombre de archivo) o agregar más y registrarlos en scripts/game.gd.
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
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


def tone(f0, f1, dur, vol=0.5, wave_type="square", decay=3.0, noise=0.0):
    n = int(RATE * dur)
    rnd = random.Random(1)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += f / RATE
        if wave_type == "square":
            s = 1.0 if (phase % 1.0) < 0.5 else -1.0
        elif wave_type == "saw":
            s = 2.0 * (phase % 1.0) - 1.0
        else:
            s = math.sin(phase * math.tau)
        s = s * (1 - noise) + rnd.uniform(-1, 1) * noise
        out.append(s * vol * math.exp(-decay * t))
    return out


save("hit", tone(180, 60, 0.18, 0.7, "saw", 5, 0.5))
save("hit_strong", tone(120, 40, 0.35, 0.9, "saw", 4, 0.6))
save("jump", tone(260, 620, 0.14, 0.35, "square", 3))
save("shoot", tone(900, 250, 0.22, 0.35, "square", 3))
save("shield", tone(520, 380, 0.12, 0.45, "square", 6, 0.2))
save("ko", tone(700, 60, 0.8, 0.6, "saw", 2.0, 0.25))
save("select", tone(520, 780, 0.1, 0.35, "square", 4))
save("start", tone(300, 900, 0.4, 0.4, "square", 2))
print("Sonidos generados en", os.path.abspath(OUT))
