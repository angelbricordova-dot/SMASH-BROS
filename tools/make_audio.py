"""
Generador de audio del juego: efectos de sonido (WAV). La música (OGG) la hace tools/make_music.py.

Uso:
    pip install numpy scipy soundfile
    python3 tools/make_audio.py            # todo
    python3 tools/make_audio.py sfx        # solo efectos
    python3 tools/make_audio.py music      # solo música

Los sonidos se sintetizan con capas de ruido filtrado, osciladores, cuerdas pulsadas
(Karplus-Strong) y reverberación, para que suenen más "reales" que los bips retro.
Puedes reemplazar cualquier archivo por tu propio sonido con el mismo nombre.
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
SFX_DIR = os.path.join(ROOT, "sounds")
MUSIC_DIR = os.path.join(ROOT, "music")
rng = np.random.default_rng(7)


# ======================================================================
#  Bloques básicos
# ======================================================================
def t_arr(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur, kind="white"):
    n = rng.standard_normal(int(SR * dur))
    if kind == "pink":
        b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
        n = signal.lfilter(b, a, n) * 4
    elif kind == "brown":
        n = np.cumsum(n)
        n = signal.lfilter([1, -1], [1, -0.995], n) * 0.1
    return n / (np.max(np.abs(n)) + 1e-9)


def filt(x, kind, freq, order=2):
    nyq = SR / 2
    if kind == "band":
        lo, hi = freq
        sos = signal.butter(order, [max(20, lo) / nyq, min(hi, nyq * 0.98) / nyq], btype="band", output="sos")
    else:
        sos = signal.butter(order, min(freq, nyq * 0.98) / nyq, btype="low" if kind == "low" else "high", output="sos")
    return signal.sosfilt(sos, x)


def sweep_filter(x, f0, f1, q=4.0, steps=40):
    """Filtro pasabanda que barre de f0 a f1 (para 'whooshes')."""
    out = np.zeros_like(x)
    n = len(x)
    seg = max(1, n // steps)
    for i in range(0, n, seg):
        k = i / n
        fc = f0 * (f1 / f0) ** k
        bw = fc / q
        chunk = x[max(0, i - 256):i + seg]
        y = filt(chunk, "band", (fc - bw, fc + bw))
        out[i:i + seg] = y[-len(out[i:i + seg]):]
    return out


def env_exp(dur, decay, attack=0.002):
    t = t_arr(dur)
    e = np.exp(-t * decay)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return e * a


def env_ad(dur, attack, release_curve=2.0):
    t = t_arr(dur)
    k = t / dur
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * (1 - k) ** release_curve


def env_swell(dur, peak=0.5, curve=2.0):
    k = np.linspace(0, 1, int(SR * dur))
    return np.where(k < peak, (k / peak) ** curve, ((1 - k) / (1 - peak)) ** curve)


def osc(freq, dur, kind="sine", phase=0.0):
    """freq puede ser número o arreglo (barrido)."""
    n = int(SR * dur)
    f = np.full(n, freq, dtype=float) if np.isscalar(freq) else np.asarray(freq, dtype=float)[:n]
    ph = np.cumsum(f) / SR + phase
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    if kind == "saw":
        return 2 * (ph % 1.0) - 1
    if kind == "square":
        return np.sign(np.sin(2 * np.pi * ph))
    if kind == "tri":
        return 2 * np.abs(2 * (ph % 1.0) - 1) - 1
    raise ValueError(kind)


def glide(f0, f1, dur, curve="exp"):
    k = np.linspace(0, 1, int(SR * dur))
    return f0 * (f1 / f0) ** k if curve == "exp" else f0 + (f1 - f0) * k


def partials(freqs, dur, decays, amps=None):
    out = np.zeros(int(SR * dur))
    amps = amps or [1.0] * len(freqs)
    for f, d, a in zip(freqs, decays, amps):
        out += a * osc(f, dur, "sine", rng.random()) * env_exp(dur, d)
    return out


def pluck(freq, dur, bright=0.5, decay=0.996):
    """Cuerda pulsada (Karplus-Strong)."""
    n = int(SR * dur)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    buf = filt(np.concatenate([buf] * 4), "low", 1000 + 8000 * bright)[-period:]
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % period]
        out[i] = v
        buf[i % period] = decay * 0.5 * (v + buf[(i + 1) % period])
    return out


def reverb(x, size=0.6, mix=0.25, damp=5000):
    ir_len = int(SR * size)
    ir = rng.standard_normal(ir_len) * np.exp(-np.linspace(0, 7, ir_len))
    ir = filt(ir, "low", damp)
    ir[0] = 0
    wet = signal.fftconvolve(x, ir)
    wet = np.pad(wet, (0, max(0, len(x) + ir_len - len(wet))))[: len(x) + ir_len]
    wet /= np.max(np.abs(wet)) + 1e-9
    dry = np.concatenate([x, np.zeros(ir_len)])
    return dry * (1 - mix) + wet * mix * np.max(np.abs(x))


def drive(x, amount=2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = np.zeros(n)
    for t in tracks:
        out[: len(t)] += t
    return out


def at(x, delay):
    return np.concatenate([np.zeros(int(SR * delay)), x])


def fade_out(x, dur=0.02):
    n = min(len(x), int(SR * dur))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def save_sfx(name, x, gain=0.9):
    os.makedirs(SFX_DIR, exist_ok=True)
    x = np.asarray(x, dtype=float)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    loud = np.nonzero(np.abs(x) > 0.003)[0]   # recortar el silencio final
    if len(loud):
        x = x[: loud[-1] + 1]
    x = fade_out(x)
    sf.write(os.path.join(SFX_DIR, name + ".wav"), x.astype(np.float32), SR, subtype="PCM_16")


# ======================================================================
#  Efectos de sonido
# ======================================================================
def thump(f0=140, f1=45, dur=0.18, decay=18):
    return osc(glide(f0, f1, dur), dur) * env_exp(dur, decay)


def click(dur=0.012, lo=2000, hi=8000):
    return filt(noise(dur), "band", (lo, hi)) * env_exp(dur, 300)


def whoosh(dur=0.22, f0=300, f1=2500, q=3.0, peak=0.45, kind="pink"):
    return sweep_filter(noise(dur, kind), f0, f1, q) * env_swell(dur, peak, 1.6)


def punch(weight=1.0):
    d = 0.12 + 0.18 * weight
    body = filt(noise(d, "pink"), "low", 1200 + 800 * weight) * env_exp(d, 30 - 10 * weight)
    x = mix(thump(130 - 30 * weight, 42, d, 22 - 8 * weight) * (1.0 + 0.5 * weight), body * 0.8,
            click(0.012) * 0.6)
    return reverb(drive(x, 1.5 + weight), 0.25 + 0.3 * weight, 0.15 + 0.1 * weight)


def glass(dur=0.8, n=26, base=2500):
    out = np.zeros(int(SR * dur))
    for _ in range(n):
        start = rng.uniform(0, dur * 0.4)
        f = rng.uniform(base, base * 3.2)
        d = rng.uniform(0.05, 0.3)
        tone = osc(f, d) * env_exp(d, rng.uniform(15, 40)) * rng.uniform(0.2, 0.6)
        s = int(start * SR)
        out[s:s + len(tone)] += tone[: len(out) - s]
    return out


def crackle(dur, density=60, lo=1500, hi=9000):
    out = np.zeros(int(SR * dur))
    for _ in range(int(density * dur)):
        s = int(rng.uniform(0, dur) * SR)
        c = click(rng.uniform(0.003, 0.012), lo, hi) * rng.uniform(0.2, 1.0)
        out[s:s + len(c)] += c[: len(out) - s]
    return out


def chime(notes, step=0.07, dur=0.9, decay=5.0):
    out = np.zeros(int(SR * (dur + step * len(notes))))
    for i, n in enumerate(notes):
        f = 440 * 2 ** ((n - 69) / 12)
        tone = partials([f, f * 2.01, f * 3.02], dur, [decay, decay * 1.6, decay * 2.4], [1, 0.4, 0.15])
        s = int(i * step * SR)
        out[s:s + len(tone)] += tone
    return reverb(out, 0.8, 0.3)


def make_sfx():
    S = save_sfx
    # --- golpes
    S("hit", punch(0.3))
    S("hit_strong", mix(punch(1.0), at(filt(noise(0.4), "band", (400, 2500)) * env_exp(0.4, 9) * 0.5, 0.01)))
    S("homerun", reverb(mix(
        partials([900, 1430, 2210], 0.5, [18, 22, 30], [1, 0.6, 0.4]) * 0.8, click(0.01, 1500, 10000),
        punch(1.0) * 0.9, at(chime([96, 100, 103], 0.05, 0.8), 0.12) * 0.4), 1.0, 0.25))
    S("swing", whoosh(0.18, 500, 2800, 3.5, 0.4))
    S("swing_heavy", whoosh(0.3, 250, 1500, 3.0, 0.5, "brown") + whoosh(0.3, 400, 2000, 3.0, 0.5) * 0.5)
    S("slash", mix(whoosh(0.2, 800, 5000, 3.5, 0.35), at(partials([2100, 3400, 5200, 6900], 0.6, [9, 11, 13, 16],
                                                                  [0.5, 0.4, 0.3, 0.2]), 0.05) * 0.5))
    S("charge", mix(osc(glide(120, 600, 1.0), 1.0, "saw") * 0.15, filt(noise(1.0), "band", (800, 4000)) * 0.3)
      * env_ad(1.0, 0.8, 0.3))
    # --- movimiento
    S("jump", mix(whoosh(0.16, 300, 1600, 2.5, 0.3), filt(noise(0.05), "band", (300, 1500)) * env_exp(0.05, 60) * 0.5))
    S("double_jump", mix(whoosh(0.25, 600, 4000, 3.0, 0.35), at(chime([88, 95], 0.04, 0.4, 9), 0.03) * 0.25))
    S("land", mix(thump(90, 40, 0.1, 30) * 0.8, filt(noise(0.08, "pink"), "low", 900) * env_exp(0.08, 40)))
    S("dash", mix(filt(noise(0.2), "band", (1200, 5000)) * env_swell(0.2, 0.15) * 0.6, whoosh(0.2, 200, 900)))
    S("roll", whoosh(0.3, 200, 1200, 2.0, 0.5))
    S("crouch", filt(noise(0.08, "pink"), "band", (400, 3000)) * env_swell(0.08, 0.3))
    S("helpless", osc(glide(700, 300, 0.3), 0.3, "sine") * env_exp(0.3, 8) * 0.4)
    # --- escudo / parry
    S("shield", mix(partials([1200, 1870, 2750], 0.35, [14, 18, 22], [0.6, 0.4, 0.3]),
                    filt(noise(0.05), "band", (2000, 7000)) * env_exp(0.05, 70) * 0.6))
    S("shield_up", (osc(220, 0.25) + osc(331, 0.25) * 0.6 + osc(441, 0.25) * 0.3) * env_ad(0.25, 0.03) * 0.5)
    S("shield_crack", mix(crackle(0.15, 200, 3000, 12000), glass(0.3, 10, 3000) * 0.7))
    S("shield_break", reverb(mix(glass(1.2, 60, 2000), thump(110, 35, 0.5, 6) * 0.8,
                                 filt(noise(0.6), "high", 2500) * env_exp(0.6, 6) * 0.6), 1.2, 0.3))
    S("parry", reverb(mix(click(0.008, 3000, 12000), partials([2480, 3720, 4980, 7450], 1.0,
                                                               [4, 5, 6, 8], [1, 0.7, 0.5, 0.3])), 1.2, 0.35))
    # --- KO y ulti
    ko = mix(osc(glide(90, 28, 1.5), 1.5) * env_exp(1.5, 2.2) * 1.2, filt(noise(1.2, "brown"), "low", 600)
             * env_exp(1.2, 3) * 0.8, crackle(0.8, 90, 2000, 9000) * 0.3, whoosh(0.5, 3000, 300, 2.5, 0.1) * 0.6)
    S("ko", reverb(drive(ko, 2.0), 1.6, 0.35))
    S("ult_ready", reverb(mix(chime([72, 76, 79, 84, 88], 0.06, 1.0, 3.5), whoosh(0.6, 400, 6000, 3, 0.8) * 0.3), 1.0, 0.3))
    riser = mix(sweep_filter(noise(1.2), 200, 8000, 5) * env_ad(1.2, 1.0, 0.3), osc(glide(55, 110, 1.2), 1.2, "saw")
                * 0.3 * env_ad(1.2, 0.9, 0.5))
    S("ult", reverb(mix(riser, at(punch(1.0), 1.05)), 1.4, 0.3))
    # --- habilidades
    fire_base = filt(noise(1.2, "brown"), "band", (80, 1500)) * (0.7 + 0.3 * np.sin(t_arr(1.2) * 30))
    S("fire", mix(fire_base[: int(SR * 0.5)] * env_ad(0.5, 0.02), crackle(0.5, 120, 1500, 7000) * 0.5))
    S("beam", reverb(mix(fire_base * env_ad(1.2, 0.05, 1.0), osc(glide(80, 60, 1.2), 1.2, "saw") * 0.25
                         * env_ad(1.2, 0.05, 1.0), crackle(1.2, 150) * 0.3), 1.0, 0.2))
    S("shoot", mix(whoosh(0.25, 2000, 600, 3.0, 0.1), osc(glide(900, 300, 0.2), 0.2, "sine") * env_exp(0.2, 12) * 0.4))
    S("freeze", reverb(mix(crackle(0.7, 160, 4000, 14000) * 0.7, partials([3100, 4400, 5900], 0.8, [4, 5, 6]) * 0.3,
                           whoosh(0.7, 800, 6000, 3, 0.3) * 0.5), 1.0, 0.3))
    S("shatter", reverb(mix(glass(0.9, 70, 2600), punch(0.5) * 0.6), 1.0, 0.3))
    S("quake", mix(filt(noise(1.6, "brown"), "low", 180) * env_ad(1.6, 0.02, 1.2) * 1.5,
                   osc(glide(60, 25, 1.6), 1.6) * env_exp(1.6, 2) * 1.2, crackle(1.4, 50, 300, 2500) * 0.6))
    S("teleport", reverb(mix(whoosh(0.35, 6000, 400, 4, 0.8), osc(glide(300, 1200, 0.35), 0.35) * env_ad(0.35, 0.3) * 0.3),
                         0.8, 0.3))
    S("shadow", reverb(mix(filt(noise(0.8, "brown"), "low", 500) * env_swell(0.8, 0.3),
                           (osc(55, 0.8, "saw") + osc(58.3, 0.8, "saw")) * 0.15 * env_swell(0.8, 0.3)), 1.2, 0.35))
    S("uppercut", mix(whoosh(0.3, 300, 3500, 3, 0.4), S_fire_short()))
    S("zap", mix(filt(osc(glide(120, 90, 0.35), 0.35, "square") * (1 + np.sign(np.sin(t_arr(0.35) * 900))), "high", 800)
                 * env_exp(0.35, 7) * 0.4, crackle(0.35, 400, 2000, 12000) * 0.8))
    S("thunder", reverb(mix(crackle(0.15, 600, 1000, 14000), click(0.02, 800, 12000),
                            filt(noise(2.0, "brown"), "low", 250) * env_exp(2.0, 2.2) * 1.3), 1.5, 0.3))
    S("laser", mix(osc(glide(2400, 500, 0.3), 0.3, "saw") * env_exp(0.3, 9) * 0.3,
                   filt(noise(0.3), "band", (3000, 9000)) * env_exp(0.3, 20) * 0.3))
    S("laser_big", reverb(mix(osc(glide(300, 120, 1.2), 1.2, "saw") * 0.35 * env_ad(1.2, 0.05, 0.8),
                              filt(noise(1.2), "band", (500, 4000)) * env_ad(1.2, 0.05, 0.8) * 0.5), 0.8, 0.25))
    S("explosion", reverb(drive(mix(thump(100, 30, 0.9, 4) * 1.5, filt(noise(1.0, "brown"), "low", 900) * env_exp(1.0, 4),
                                    crackle(0.8, 120, 800, 6000) * 0.5), 2.5), 1.4, 0.3))
    S("magic", reverb(mix(chime([79, 83, 86, 91], 0.045, 0.5, 7), whoosh(0.4, 1000, 7000, 4, 0.3) * 0.4), 0.9, 0.3))
    S("counter", reverb(mix(partials([1800, 2700, 4050], 0.6, [6, 8, 10]), click(0.01)), 0.8, 0.3))
    S("hover", filt(noise(0.5), "band", (200, 1200)) * env_swell(0.5, 0.2) * 0.8)
    # --- objetos
    S("bow_draw", filt(osc(glide(90, 140, 0.4), 0.4, "saw") * (0.6 + 0.4 * rng.random(int(SR * 0.4))), "band", (200, 2000))
      * env_ad(0.4, 0.3, 0.5) * 0.6)
    S("bow_shoot", mix(pluck(196, 0.5, 0.7, 0.994), whoosh(0.2, 1500, 400, 3, 0.1) * 0.5))
    S("arrow_hit", mix(thump(300, 120, 0.08, 40), partials([420, 930], 0.2, [25, 35]) * 0.4, click(0.01, 1000, 5000)))
    S("pickup", mix(click(0.008, 1000, 4000) * 0.5, chime([84, 91], 0.05, 0.35, 10) * 0.6))
    S("item_spawn", reverb(chime([79, 84, 88, 91, 96], 0.05, 0.6, 6), 1.0, 0.3))
    S("throw", whoosh(0.28, 300, 2200, 2.5, 0.35))
    S("heal", reverb(chime([72, 79, 84, 88, 91], 0.07, 0.8, 4), 1.2, 0.35))
    S("star", reverb(mix(chime([84, 88, 91, 96, 100, 103], 0.04, 0.6, 5)), 1.0, 0.3))
    S("fuse", filt(noise(0.6), "band", (2000, 8000)) * (0.5 + 0.5 * rng.random(int(SR * 0.6))) * 0.5)
    S("boomerang", mix(*[at(whoosh(0.12, 500, 2500, 3, 0.5) * 0.6, i * 0.1) for i in range(5)]))
    S("taunt", mix(whoosh(0.2, 400, 2400, 3, 0.4) * 0.6, at(chime([79, 86], 0.06, 0.4, 8) * 0.4, 0.1)))
    # --- interfaz
    S("menu_move", mix(click(0.006, 2000, 6000) * 0.5, osc(1320, 0.05) * env_exp(0.05, 70) * 0.4))
    S("select", mix(click(0.006, 2000, 6000) * 0.5, osc(1760, 0.07) * env_exp(0.07, 50) * 0.4))
    S("menu_confirm", reverb(chime([81, 88], 0.06, 0.4, 9), 0.6, 0.25))
    S("menu_back", reverb(chime([76, 69], 0.06, 0.35, 10), 0.5, 0.25))
    S("card_show", reverb(mix(whoosh(0.35, 400, 5000, 3, 0.6) * 0.5, at(chime([84, 91, 96], 0.05, 0.6, 5), 0.2)), 1, 0.3))
    S("card_pick", reverb(mix(punch(0.4) * 0.5, chime([72, 79, 84, 91], 0.04, 0.8, 4)), 1.0, 0.3))
    S("countdown", reverb(mix(thump(110, 55, 0.35, 8), click(0.01, 1500, 6000) * 0.4), 0.8, 0.25))
    S("start", reverb(mix(riser[: int(SR * 0.6)], chime([72, 79, 84], 0.03, 0.6, 4) * 0.5), 1.0, 0.3))
    stab = np.zeros(int(SR * 1.4))
    for n in (60, 64, 67, 72, 76):
        f = 440 * 2 ** ((n - 69) / 12)
        v = filt(osc(f, 1.4, "saw") + osc(f * 1.005, 1.4, "saw"), "low", 3000) * env_exp(1.4, 2.5)
        stab += v
    S("go", reverb(mix(punch(1.0) * 0.8, stab * 0.35), 1.4, 0.3))
    S("fanfare", make_fanfare())
    S("cheer", make_crowd(3.0))
    # --- Boulevard Smash: sonidos de los personajes nuevos
    # pistola de Lamont: chasquido + estampido + eco corto
    shot = mix(click(0.004, 2000, 12000), filt(noise(0.25), "band", (300, 6000)) * env_exp(0.25, 28) * 1.2,
               thump(180, 60, 0.12, 30) * 0.7)
    S("gunshot", reverb(drive(shot, 3.0), 0.6, 0.18))
    S("reload", mix(click(0.01, 1500, 6000), at(click(0.012, 800, 4000) * 0.8, 0.07),
                    at(partials([1900, 3100], 0.12, [40, 50]) * 0.4, 0.07)))
    # cachetada: palmada seca con cuerpo
    slap = mix(filt(noise(0.12), "band", (700, 5000)) * env_exp(0.12, 45) * 1.3, thump(220, 120, 0.06, 50) * 0.6)
    S("slap", reverb(slap, 0.4, 0.12))
    # pez: golpe mojado
    S("fish", mix(filt(noise(0.3, "pink"), "band", (150, 1800)) * env_exp(0.3, 16) * 1.2,
                  osc(glide(320, 120, 0.2), 0.2) * env_exp(0.2, 18) * 0.5,
                  at(crackle(0.2, 200, 1500, 6000) * 0.4, 0.02)))
    # micrófono: acople (pitido) que se cae + "golpe" en el micro
    t_ = t_arr(0.5)
    fb = osc(glide(2600, 2200, 0.5), 0.5) * env_ad(0.5, 0.05, 1.0) * (0.6 + 0.4 * np.sin(t_ * 40))
    S("mic", reverb(mix(fb * 0.35, thump(140, 60, 0.15, 18) * 0.8, filt(noise(0.1), "low", 1500) * env_exp(0.1, 30)),
                    0.8, 0.25))
    S("flour", mix(filt(noise(0.5, "pink"), "band", (400, 6000)) * env_swell(0.5, 0.15) * 0.9, whoosh(0.4, 600, 3000)))
    # revistas: páginas que aletean
    pages = mix(*[at(filt(noise(0.05), "band", (1500, 7000)) * env_exp(0.05, 60) * 0.7, i * 0.035) for i in range(9)])
    S("paper", mix(pages, whoosh(0.3, 800, 3000, 3, 0.3) * 0.5))
    # bocina de guagua (dos notas graves)
    horn = sum(osc(f, 0.7, "saw") for f in (233, 294, 350)) * env_ad(0.7, 0.02, 0.4) * 0.3
    S("bus_horn", reverb(filt(drive(horn, 2.0), "low", 2500), 0.8, 0.2))
    # mentira: "boing" gracioso
    S("lie", mix(osc(glide(300, 900, 0.25), 0.25) * env_exp(0.25, 6) * 0.5, at(chime([79, 74, 70], 0.06, 0.4, 8) * 0.4, 0.1)))
    # caja registradora (préstamo)
    S("cash", reverb(mix(click(0.01, 2000, 8000), at(partials([2637, 3520, 5274], 0.9, [3, 4, 5]) * 0.6, 0.05),
                         at(crackle(0.3, 300, 3000, 9000) * 0.4, 0.1)), 0.8, 0.25))
    S("cloth", mix(whoosh(0.4, 200, 1800, 2.0, 0.5), filt(noise(0.4, "pink"), "band", (300, 3000)) * env_swell(0.4, 0.3) * 0.5))
    S("powerup", reverb(mix(osc(glide(200, 800, 0.8), 0.8, "saw") * env_ad(0.8, 0.6, 0.5) * 0.25,
                            chime([72, 76, 79, 84, 88, 91], 0.07, 0.9, 4) * 0.6), 1.2, 0.3))
    S("bread", mix(thump(260, 140, 0.1, 30) * 0.8, filt(noise(0.1, "pink"), "band", (500, 3000)) * env_exp(0.1, 35)))
    S("angry", mix(osc(glide(140, 90, 0.6), 0.6, "saw") * env_ad(0.6, 0.05, 0.6) * 0.3,
                   filt(noise(0.6, "brown"), "low", 700) * env_swell(0.6, 0.2)))
    # golpe final: impacto enorme + cristal + cola larga
    fin = mix(punch(1.0) * 1.2, thump(80, 25, 1.2, 3) * 1.4, glass(0.8, 30, 3000) * 0.4,
              filt(noise(1.5, "brown"), "low", 500) * env_exp(1.5, 2.5) * 0.8)
    S("final_hit", reverb(drive(fin, 2.2), 2.0, 0.4))


def S_fire_short():
    x = filt(noise(0.35, "brown"), "band", (100, 2000)) * env_ad(0.35, 0.02)
    return mix(x, crackle(0.35, 150) * 0.4)


def make_crowd(dur):
    out = np.zeros(int(SR * dur))
    t = t_arr(dur)
    for _ in range(40):  # "voces": ruido con formantes de vocal
        f1, f2 = rng.uniform(400, 900), rng.uniform(900, 2400)
        v = filt(noise(dur), "band", (f1 * 0.8, f1 * 1.2)) + 0.6 * filt(noise(dur), "band", (f2 * 0.85, f2 * 1.15))
        swell = np.clip(np.sin(np.pi * t / dur * rng.uniform(0.8, 1.2) + rng.uniform(-0.3, 0.3)), 0, 1)
        out += v * swell * rng.uniform(0.3, 1.0)
    for _ in range(int(dur * 70)):  # aplausos
        s = int(rng.uniform(0, dur * 0.9) * SR)
        c = filt(noise(0.02), "band", (800, 5000)) * env_exp(0.02, 150) * rng.uniform(0.5, 1.5)
        out[s:s + len(c)] += c * 3
    return reverb(out * env_ad(dur, 0.4, 1.5), 1.2, 0.3)


def make_fanfare():
    bpm = 132
    beat = 60 / bpm
    seq = [(72, 0.5), (72, 0.25), (72, 0.25), (76, 0.5), (79, 0.5), (84, 1.5)]
    out = np.zeros(int(SR * 5))
    pos = 0.0
    for n, b in seq:
        dur = b * beat
        for off, amp in ((0, 1.0), (-12, 0.6), (4, 0.4), (7, 0.4)):
            f = 440 * 2 ** ((n + off - 69) / 12)
            v = (osc(f, dur + 0.4, "saw") + osc(f * 1.004, dur + 0.4, "saw")) * env_ad(dur + 0.4, 0.02, 1.5)
            v = filt(v, "low", 2600)
            s = int(pos * SR)
            out[s:s + len(v)] += v * amp
        pos += dur
    drums = mix(kick(0.4), at(kick(0.4), beat * 3), at(snare(0.3), beat * 1), at(snare(0.5) * 1.3, beat * 3))
    return reverb(mix(out * 0.25, drums * 0.7)[: int(SR * 3.4)], 1.4, 0.3)


# ======================================================================
#  Piezas de batería (las usa la fanfarria). La música está en tools/make_music.py
# ======================================================================
def note_f(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def kick(dur=0.35):
    return mix(osc(glide(160, 42, dur), dur) * env_exp(dur, 9) * 1.2, click(0.006, 1000, 5000) * 0.3)


def snare(dur=0.25):
    return mix(filt(noise(dur), "band", (1500, 8000)) * env_exp(dur, 16) * 0.8, osc(190, dur) * env_exp(dur, 25) * 0.5)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "sfx"):
        make_sfx()
        print("Efectos generados en", os.path.abspath(SFX_DIR))
    if what in ("all", "music"):
        import make_music as music_rock    # la música de Boulevard Smash está en tools/make_music.py
        music_rock.main(list(music_rock.SONGS))
