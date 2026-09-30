"""
Música de Boulevard Smash: canciones de rock (y un par más tranquilas) con estructura de canción
de verdad —intro, estrofa, pre-estribillo, estribillo, puente, solo y final— para que no suenen
a un bucle corto y repetido.

Todo se sintetiza aquí mismo (no hace falta ningún programa de música):
  * Guitarras eléctricas: cuerdas "pulsadas" (Karplus-Strong) → distorsión → simulador de altavoz,
    grabadas dos veces (izquierda y derecha) como en los discos de rock.
  * Bajo, batería acústica (bombo, caja, platos, toms), piano eléctrico, sintetizadores.

    pip install numpy scipy soundfile
    python3 tools/make_music.py             (todas; tarda un par de minutos)
    python3 tools/make_music.py boulevard   (solo una)

Canciones (assets/music/<id>.ogg):
  boulevard  Rock del Boulevard   (punk-rock, 150 bpm)
  asfalto    Asfalto              (hard rock, 128 bpm)
  fuego      Fuego Cruzado        (metal, 176 bpm)
  neon       Noches de Neón       (synth-rock, 116 bpm)
  chaos      Caos Total           (punk rápido, 188 bpm) — modo Caos de Cartas
  training   Calentando           (funk, 102 bpm) — modo Entrenamiento
  menu       Boulevard de Noche   (lo-fi, 84 bpm) — menús
"""
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")


# =============================================================================================
#  Utilidades
# =============================================================================================
def mf(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, min(f, SR * 0.45) / (SR / 2), "low", output="sos"), x)


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f / (SR / 2), "high", output="sos"), x)


def bp(x, f0, f1, order=2):
    return signal.sosfilt(signal.butter(order, [f0 / (SR / 2), min(f1, SR * 0.45) / (SR / 2)], "band", output="sos"), x)


def peak(x, f, gain_db, q=1.0):
    """Ecualizador de campana (realza o baja una zona de frecuencias)."""
    a = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / SR
    al = np.sin(w) / (2 * q)
    b = [1 + al * a, -2 * np.cos(w), 1 - al * a]
    aa = [1 + al / a, -2 * np.cos(w), 1 - al / a]
    return signal.lfilter(b, aa, x)


def env(n, attack=0.002, decay=4.0, release=0.02):
    t = np.arange(n) / SR
    e = np.exp(-t * decay) * np.clip(t / max(attack, 1e-4), 0, 1)
    r = int(release * SR)
    if r and n > r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def reverb_ir(seconds=1.6, damp=6000, seed=1):
    r = np.random.default_rng(seed)
    n = int(SR * seconds)
    ir = r.standard_normal(n) * np.exp(-np.linspace(0, 7, n))
    ir = lp(ir, damp)
    ir[: int(0.012 * SR)] *= 0.2
    return ir / np.sqrt(np.sum(ir ** 2))


def convolve(x, ir):
    return signal.fftconvolve(x, ir)[: len(x)]


# =============================================================================================
#  Instrumentos
# =============================================================================================
class Rng:
    r = np.random.default_rng(11)


def ks(freq, dur, g=0.996, bright=0.6, seed=0):
    """Cuerda pulsada (Karplus-Strong), rápida: se calcula un periodo entero de golpe."""
    r = np.random.default_rng(int(seed))
    N = max(2, int(round(SR / freq)))
    n = int(SR * dur)
    y = np.zeros(n + N + 1)
    burst = r.uniform(-1, 1, N)
    # púa: la excitación más o menos brillante
    k = 0.15 + 0.8 * bright
    for _ in range(2):
        burst = k * burst + (1 - k) * np.concatenate([[burst[-1]], burst[:-1]])
    y[1:N + 1] = burst
    i = N + 1
    while i < len(y):
        j = min(i + N, len(y))
        y[i:j] = g * 0.5 * (y[i - N:j - N] + y[i - N - 1:j - N - 1])
        i = j
    return y[1:n + 1]


_gcache = {}


def guitar_chord(root, dur, kind="power", mute=False, seed=0):
    """Acorde de guitara SIN distorsión (la distorsión se aplica a toda la pista)."""
    key = (root, round(dur, 3), kind, mute, seed % 3)
    if key in _gcache:
        return _gcache[key]
    ints = {"power": [0, 7, 12], "power3": [0, 7, 12, 16], "min": [0, 7, 12, 15], "single": [0],
            "oct": [0, 12], "sus": [0, 7, 12, 17]}[kind]
    n = int(SR * dur)
    out = np.zeros(n + int(0.03 * SR))
    for k, iv in enumerate(ints):
        g = 0.975 if mute else 0.9975
        s = ks(mf(root + iv), dur, g=g, bright=0.25 if mute else 0.75, seed=seed * 7 + k)
        if mute:
            s *= env(len(s), 0.001, 16.0)
        d = int((0.004 + 0.003 * k) * SR) * (0 if mute else 1)   # rasgueo
        out[d:d + len(s)] += s * (1.0 - 0.1 * k)
    out = out[:n]
    rel = min(n, int(0.02 * SR))
    out[-rel:] *= np.linspace(1, 0, rel)
    _gcache[key] = out
    return out


def amp(x, gain=14.0, tone=4800.0, tight=110.0):
    """Amplificador de guitarra: filtro, saturación y simulador de caja (altavoz 4x12)."""
    x = hp(x, tight)
    x = peak(x, 800, 4.0, 0.8)
    y = np.tanh(x * gain) + 0.15 * np.tanh(x * gain * 2.2)
    y = hp(y, 80)
    y = lp(y, tone, 4)
    y = peak(y, 110, 3.0, 0.9)
    y = peak(y, 2600, 3.5, 1.3)
    y = peak(y, 400, -3.0, 1.0)
    return y


def bass_note(midi, dur, seed=0, pick=True):
    s = ks(mf(midi), dur, g=0.998, bright=0.5 if pick else 0.3, seed=seed + 100)
    s += 0.5 * np.sin(2 * np.pi * mf(midi) * np.arange(len(s)) / SR) * env(len(s), 0.004, 2.5)
    s *= env(len(s), 0.002, 1.2, 0.03)
    return np.tanh(lp(s, 1600) * 1.6)


def saw(freq, dur, voices=3, detune=0.007, vib=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(voices):
        f = freq * (1 + detune * (v - (voices - 1) / 2))
        ph = np.cumsum(np.full(n, f) * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3 - 0.3, 0, 1))) / SR
        out += 2 * (ph % 1.0) - 1
    return out / voices


def lead_note(midi, dur, bend=0.0):
    """Guitarra solista: cuerda + sostenido con vibrato (sale por el amplificador)."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = mf(midi) * (1 + bend * np.clip(1 - t * 12, 0, 1))
    ph = np.cumsum(f * (1 + 0.008 * np.sin(2 * np.pi * 6.0 * t) * np.clip(t * 4 - 0.4, 0, 1))) / SR
    body = (2 * (ph % 1.0) - 1) * 0.6 + np.sign(np.sin(2 * np.pi * ph)) * 0.25
    pl = ks(mf(midi), dur, g=0.999, bright=0.9, seed=midi)
    x = (body * env(n, 0.01, 0.4, 0.05) * 0.6 + pl) * env(n, 0.002, 0.2, 0.04)
    return x


def epiano(midi, dur, vel=1.0):
    """Piano eléctrico (tipo Rhodes) por FM."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = mf(midi)
    idx = 1.8 * np.exp(-t * 6) * vel
    x = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
    x += 0.3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 20)
    return x * env(n, 0.003, 1.8, 0.08) * (1 + 0.2 * np.sin(2 * np.pi * 4.2 * t)) * vel


def pad(midis, dur):
    x = sum(saw(mf(m), dur, 4, 0.01) for m in midis) / len(midis)
    x = lp(x, 1400)
    n = len(x)
    return x * np.clip(np.arange(n) / (0.4 * SR), 0, 1) * np.clip((n - np.arange(n)) / (0.3 * SR), 0, 1)


# --- batería ---
def _metal(n, seed=0):
    t = np.arange(n) / SR
    freqs = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]
    x = sum(np.sign(np.sin(2 * np.pi * f * 1.83 * t + seed)) for f in freqs)
    return x / 6


def kick(vel=1.0):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 45 + 95 * np.exp(-t * 32)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.5)
    click = hp(Rng.r.standard_normal(n), 2500) * np.exp(-t * 180) * 0.35
    return np.tanh((x + click) * 1.6) * vel


def snare(vel=1.0):
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    tone = (np.sin(2 * np.pi * 185 * t) + 0.6 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t * 22)
    nz = bp(Rng.r.standard_normal(n), 1200, 9000) * np.exp(-t * 13)
    return np.tanh((tone * 0.7 + nz * 1.1) * 1.3) * vel


def hat(open_=False, vel=1.0):
    n = int((0.35 if open_ else 0.07) * SR)
    t = np.arange(n) / SR
    x = hp(_metal(n) + 0.5 * Rng.r.standard_normal(n), 7000) * np.exp(-t * (9 if open_ else 55))
    return x * 0.5 * vel


def crash(vel=1.0):
    n = int(2.4 * SR)
    t = np.arange(n) / SR
    x = hp(_metal(n, 1.3) * 0.6 + Rng.r.standard_normal(n), 4500) * np.exp(-t * 1.8)
    return x * 0.45 * vel


def ride(vel=1.0):
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    x = hp(_metal(n, 2.1), 5000) * np.exp(-t * 6) + np.sin(2 * np.pi * 2800 * t) * np.exp(-t * 9) * 0.3
    return x * 0.35 * vel


def tom(pitch=110, vel=1.0):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = pitch * (1 + 0.5 * np.exp(-t * 20))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7) + bp(Rng.r.standard_normal(n), 200, 3000) * np.exp(-t * 30) * 0.3
    return np.tanh(x * 1.3) * vel


def clap(vel=1.0):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for d in (0.0, 0.011, 0.023):
        s = int(d * SR)
        x[s:] += bp(Rng.r.standard_normal(n - s), 900, 5000) * np.exp(-t[: n - s] * 35)
    return x * 0.7 * vel


DRUMS = {}


def drum(name, vel=1.0):
    k = (name, round(vel, 2))
    if k not in DRUMS:
        DRUMS[k] = {"k": lambda: kick(vel), "s": lambda: snare(vel), "h": lambda: hat(False, vel),
                    "o": lambda: hat(True, vel), "c": lambda: crash(vel), "r": lambda: ride(vel),
                    "t1": lambda: tom(150, vel), "t2": lambda: tom(115, vel), "t3": lambda: tom(85, vel),
                    "cl": lambda: clap(vel)}[name]()
    return DRUMS[k]


# =============================================================================================
#  Canción
# =============================================================================================
BUSES = ("drums", "bass", "gtrL", "gtrR", "clean", "lead", "keys", "pad", "fx")


class Song:
    def __init__(self, bpm, swing=0.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.swing = swing
        self.cursor = 0       # en compases
        self.events = {b: [] for b in BUSES}
        self.rng = np.random.default_rng(5)

    def t(self, bar, step16=0.0):
        """Segundos desde el inicio (con swing en las semicorcheas pares)."""
        sw = self.swing * self.beat / 4 if int(step16) % 2 == 1 else 0.0
        return (bar * 16 + step16) * self.beat / 4 + sw

    def add(self, bus, x, time, gain=1.0):
        human = self.rng.normal(0, 0.003) if bus != "drums" else self.rng.normal(0, 0.002)
        self.events[bus].append((max(0.0, time + human), x, gain))

    def render(self):
        total = self.t(self.cursor)
        L = int(SR * (total + 3.0))
        buses = {}
        for b, evs in self.events.items():
            y = np.zeros(L)
            for time, x, g in evs:
                s = int(time * SR)
                e = min(L, s + len(x))
                y[s:e] += x[: e - s] * g
            buses[b] = y
        return buses, total


# --- partes que se repiten (patrones de un compás) ---
GTR = {
    "mute8": [(i * 2, 2, True) for i in range(8)],
    "mute16": [(i, 1, True) for i in range(16)],
    "open8": [(i * 2, 2, False) for i in range(8)],
    "whole": [(0, 16, False)],
    "half": [(0, 8, False), (8, 8, False)],
    "push": [(0, 3, False), (3, 3, False), (6, 2, False), (8, 3, False), (11, 3, False), (14, 2, False)],
    "gallop": [(s, 1, True) for b in range(4) for s in (b * 4, b * 4 + 2, b * 4 + 3)],
    "chug": [(0, 2, True), (2, 2, True), (4, 1, True), (5, 1, True), (6, 2, False), (8, 2, True), (10, 2, True),
             (12, 1, True), (13, 1, True), (14, 2, False)],
    "stabs": [(0, 2, False), (6, 2, False), (10, 2, False), (14, 2, False)],
}
DR = {  # k=bombo s=caja h=charles cerrado o=abierto r=ride
    "rock": {"k": "x.......x.x.....", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."},
    "rock2": {"k": "x.....x.x.x.....", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.xo"},
    "ride": {"k": "x.......x.x.....", "s": "....x.......x...", "r": "x.x.x.x.x.x.x.x."},
    "half": {"k": "x.........x.....", "s": "........x.......", "h": "x.x.x.x.x.x.x.x."},
    "punk": {"k": "x.x.x.x.x.x.x.x.", "s": "..x...x...x...x.", "h": "x.x.x.x.x.x.x.x."},
    "double": {"k": "xxxxxxxxxxxxxxxx", "s": "....x.......x...", "r": "x...x...x...x..."},
    "four": {"k": "x...x...x...x...", "s": "....x.......x...", "h": "..x...x...x...x.", "cl": "....x.......x..."},
    "funk": {"k": "x..x..x...x..x..", "s": "....x..x.x..x...", "h": "xxxxxxxxxxxxxxxx"},
    "boombap": {"k": "x.......x.x.....", "s": "....x.......x...", "h": "x.x.x.x.x.x.x.x."},
    "build": {"k": "x...x...x...x...", "s": "..x...x...x.xxxx", "h": "x.x.x.x.x.x.x.x."},
    "intro": {"k": "x...............", "h": "x.x.x.x.x.x.x.x."},
}


def drums(song, bar, pat, fill=False, crash_=False, vel=1.0):
    p = DR[pat]
    for inst, s in p.items():
        for i, c in enumerate(s):
            if c == ".":
                continue
            if fill and i >= 8 and inst in ("s", "k"):
                continue
            name = "o" if c == "o" else inst
            v = vel * (1.0 if i % 4 == 0 else 0.78) * (0.85 + 0.15 * song.rng.random())
            if inst in ("h", "r") and i % 4 != 0:
                v *= 0.75
            song.add("drums", drum(name, round(v, 1)), song.t(bar, i))
    if crash_:
        song.add("drums", drum("c", round(vel, 1)), song.t(bar, 0))
        song.add("drums", drum("k", round(vel, 1)), song.t(bar, 0))
    if fill:  # redoble de toms en la segunda mitad
        seq = ["s", "s", "t1", "t1", "t2", "t2", "t3", "t3"]
        for i, name in enumerate(seq):
            song.add("drums", drum(name, 0.9 if name[0] == "t" else 0.8), song.t(bar, 8 + i))


def guitar(song, bar, root, pattern, kind="power", vel=1.0, double=True):
    for (st, ln, mute) in GTR[pattern]:
        dur = ln * song.beat / 4 * (0.92 if mute else 0.98)
        for side, bus in ((0, "gtrL"), (1, "gtrR")):
            if side == 1 and not double:
                break
            x = guitar_chord(root, dur, kind, mute, seed=side + (bar % 3) * 2)
            song.add(bus, x, song.t(bar, st), vel * (0.8 if mute else 1.0))


def bass(song, bar, root, pattern="8ths", vel=1.0):
    r = root - 12 if root >= 40 else root
    steps = {"8ths": [(i * 2, 2) for i in range(8)], "root": [(0, 8), (8, 8)], "gallop": GTR["gallop"],
             "16ths": [(i, 1) for i in range(16)], "funk": [(0, 3), (3, 1), (6, 2), (10, 2), (12, 1), (14, 2)],
             "lofi": [(0, 6), (6, 2), (10, 4), (14, 2)]}[pattern]
    for it in steps:
        st, ln = it[0], it[1]
        note = r + (12 if pattern == "funk" and st in (3, 12) else 0)
        song.add("bass", bass_note(note, ln * song.beat / 4 * 0.95, seed=st), song.t(bar, st), vel)


def melody(song, bar0, notes, bus="lead", vel=1.0):
    """notes: lista de (midi o None, duración en semicorcheas[, bend])."""
    pos = 0.0
    for it in notes:
        m, ln = it[0], it[1]
        if m is not None:
            dur = ln * song.beat / 4 * 0.97
            x = lead_note(m, dur, it[2] if len(it) > 2 else 0.0) if bus == "lead" else epiano(m, dur + 0.3)
            song.add(bus, x, song.t(bar0, pos), vel)
        pos += ln


def solo(song, bar0, bars, root, rng, density=0.6):
    """Solo improvisado sobre la escala pentatónica menor."""
    scale = [0, 3, 5, 7, 10]
    notes = []
    pos = 0
    idx = 7
    total = bars * 16
    while pos < total:
        ln = rng.choice([1, 2, 2, 2, 4, 4, 6, 8], p=[0.12, 0.25, 0.15, 0.13, 0.15, 0.1, 0.05, 0.05])
        ln = min(ln, total - pos)
        if rng.random() < density:
            idx = int(np.clip(idx + rng.choice([-2, -1, -1, 1, 1, 2, 3]), 0, 14))
            m = root + 12 * (idx // 5) + scale[idx % 5]
            notes.append((m, ln, 0.06 if rng.random() < 0.2 else 0.0))
        else:
            notes.append((None, ln))
        pos += ln
    melody(song, bar0, notes)


def section(song, bars, chords, gtr=None, drum_pat="rock", bass_pat="8ths", kind="power", vel=1.0,
            crash_every=0, fill_last=True, first_crash=True, lead=None, keys=None, pad_=False, gvel=1.0):
    """Añade `bars` compases con la progresión `chords` (una nota raíz por compás, se repite)."""
    b0 = song.cursor
    for i in range(bars):
        bar = b0 + i
        root = chords[i % len(chords)]
        if drum_pat:
            fill = fill_last and (i % 4 == 3) and i == bars - 1 or (fill_last and i % 8 == 7)
            cr = (first_crash and i == 0) or (crash_every and i % crash_every == 0)
            drums(song, bar, drum_pat, fill=fill, crash_=cr, vel=vel)
        if gtr:
            guitar(song, bar, root, gtr, kind, gvel)
        if bass_pat:
            bass(song, bar, root, bass_pat)
        if keys:
            for m in keys(root):
                song.add("keys", epiano(m, 16 * song.beat / 4 * 0.9, 0.7), song.t(bar, 0))
        if pad_:
            song.add("pad", pad([root + 24, root + 31, root + 36], 16 * song.beat / 4), song.t(bar, 0))
    if lead is not None:
        melody(song, b0, lead)
    song.cursor += bars
    return b0


def mixdown(song, gains, reverb_amt=0.18, dist=14.0, tone=4800.0):
    buses, total = song.render()
    room = reverb_ir(1.2, 7000, 3)
    hall = reverb_ir(2.4, 5000, 4)
    gL = amp(buses["gtrL"], dist, tone) if np.any(buses["gtrL"]) else buses["gtrL"]
    gR = amp(buses["gtrR"], dist, tone * 0.95) if np.any(buses["gtrR"]) else buses["gtrR"]
    lead = amp(buses["lead"], dist * 0.8, 5200) if np.any(buses["lead"]) else buses["lead"]
    drums_ = buses["drums"]
    drums_ = drums_ + convolve(drums_, room) * 0.25
    lead = lead + convolve(lead, hall) * 0.3
    keys = buses["keys"] + convolve(buses["keys"], hall) * 0.3
    padb = buses["pad"]
    clean = buses["clean"] + convolve(buses["clean"], room) * 0.3
    fx = buses["fx"]

    def g(k):
        return gains.get(k, 1.0)

    center = (drums_ * g("drums") + buses["bass"] * g("bass") + lead * g("lead") + keys * g("keys")
              + padb * g("pad") + fx * g("fx"))
    left = center + gL * g("gtr") + clean * g("clean") * 0.8 + np.roll(padb, int(0.011 * SR)) * g("pad") * 0.3
    right = center + gR * g("gtr") + clean * g("clean") * 0.6
    st = np.stack([left, right], axis=1)
    st += np.stack([convolve(left, hall), convolve(right, hall)], axis=1) * reverb_amt * 0.5
    # cola del final encima del principio → el bucle no tiene cortes
    n = int(total * SR)
    out = st[:n].copy()
    tail = st[n:]
    out[: len(tail)] += tail
    # "mastering": compresión suave + limitador
    out = out / (np.percentile(np.abs(out), 99.7) + 1e-9)
    out = np.tanh(out * 1.1) * 0.84
    return out.astype(np.float32)


def write(name, data):
    os.makedirs(OUT, exist_ok=True)
    with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", SR, 2, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 4096):
            f.write(data[i:i + 4096])
    print("  %s.ogg  %.0f s" % (name, len(data) / SR))


# =============================================================================================
#  Las canciones
# =============================================================================================
E, F, Fs, G, A, B, C, D = 40, 41, 42, 43, 45, 47, 48, 50   # raíces de acordes (cuerdas graves)


def song_boulevard():
    s = Song(150)
    rng = np.random.default_rng(1)
    riff = [(64, 2), (67, 2), (69, 2), (67, 2), (64, 4), (62, 2), (64, 2)]
    # intro: guitarra sola y luego entra la banda
    section(s, 2, [E, E], "chug", drum_pat=None, bass_pat=None, gvel=0.9)
    section(s, 2, [E, D], "chug", drum_pat="build", bass_pat="8ths", first_crash=False)
    # estrofa
    for _ in range(2):
        section(s, 4, [E, E, C, D], "mute8", "rock", "8ths")
    # pre-estribillo
    section(s, 4, [A, A, C, D], "half", "build", "root", crash_every=2)
    # estribillo con melodía
    chorus = [(71, 4), (71, 2), (69, 2), (67, 4), (64, 4), (69, 4), (67, 2), (64, 2), (62, 8),
              (71, 4), (74, 4), (71, 2), (69, 2), (67, 4), (64, 6), (67, 2), (64, 8)]
    section(s, 8, [G, D, E, C], "open8", "rock2", "8ths", crash_every=4, lead=chorus + chorus[:0])
    # estrofa 2 con riff de guitarra solista
    section(s, 8, [E, E, C, D], "mute8", "rock", "8ths", lead=(riff + [(None, 16)]) * 4)
    section(s, 8, [G, D, E, C], "open8", "rock2", "8ths", crash_every=4, lead=chorus)
    # puente a medio tiempo y solo
    section(s, 4, [C, D, E, E], "whole", "half", "root", pad_=True)
    b = section(s, 8, [E, C, G, D], "push", "ride", "8ths", crash_every=4)
    solo(s, b, 8, 64, rng, 0.75)
    # estribillo final y cierre
    section(s, 8, [G, D, E, C], "open8", "rock2", "8ths", crash_every=2, lead=chorus)
    section(s, 4, [E, E, D, D], "push", "rock", "8ths", crash_every=4)
    return mixdown(s, {"drums": 1.0, "bass": 0.9, "gtr": 0.55, "lead": 0.35})


def song_asfalto():
    s = Song(128)
    rng = np.random.default_rng(2)
    section(s, 4, [A, A, G, A], "chug", "intro", None, first_crash=False)
    for _ in range(2):
        section(s, 4, [A, A, G, D], "chug", "rock", "8ths")
    section(s, 4, [F, G, A, A], "half", "build", "root", crash_every=2)
    hook = [(76, 6), (74, 2), (72, 4), (69, 4), (72, 4), (74, 4), (76, 8), (79, 6), (76, 2), (74, 4), (72, 4),
            (74, 8), (None, 8)]
    section(s, 8, [F, G, A, A], "open8", "rock2", "8ths", crash_every=4, lead=hook)
    section(s, 8, [A, A, G, D], "chug", "rock", "8ths")
    b = section(s, 8, [D, C, A, A], "push", "ride", "8ths", crash_every=4)
    solo(s, b, 8, 69, rng, 0.7)
    section(s, 8, [F, G, A, A], "open8", "rock2", "8ths", crash_every=2, lead=hook)
    section(s, 4, [A, G, F, E], "whole", "half", "root", crash_every=1)
    return mixdown(s, {"drums": 1.0, "bass": 0.95, "gtr": 0.6, "lead": 0.32}, dist=18.0)


def song_fuego():
    s = Song(176)
    rng = np.random.default_rng(3)
    D2 = 38
    section(s, 4, [D2, D2, F, E], "gallop", "double", "gallop", crash_every=2)
    for _ in range(2):
        section(s, 4, [D2, D2, C - 12 + 12, 46], "gallop", "double", "gallop")
    section(s, 8, [D2, 46, F, C], "half", "half", "root", crash_every=2,
            lead=[(74, 8), (77, 8), (76, 8), (72, 8), (74, 8), (81, 8), (79, 8), (77, 8)] * 2)
    section(s, 8, [D2, D2, F, E], "mute16", "double", "16ths")
    b = section(s, 8, [D2, 46, C, A], "gallop", "double", "gallop", crash_every=4)
    solo(s, b, 8, 62, rng, 0.85)
    section(s, 8, [D2, 46, F, C], "half", "half", "root", crash_every=2,
            lead=[(74, 8), (77, 8), (76, 8), (72, 8), (74, 8), (81, 8), (79, 8), (77, 8)] * 2)
    section(s, 8, [46, C, D2, D2], "whole", "half", "root", crash_every=4, pad_=True)
    for _ in range(2):
        section(s, 4, [D2, D2, F, E], "gallop", "double", "gallop", crash_every=4)
    b = section(s, 8, [D2, 46, C, A], "mute16", "double", "16ths", crash_every=4)
    solo(s, b, 8, 62, rng, 0.9)
    section(s, 4, [D2, D2, D2, D2], "chug", "double", "gallop", crash_every=1)
    return mixdown(s, {"drums": 1.0, "bass": 0.9, "gtr": 0.62, "lead": 0.3}, dist=26.0, tone=4300)


def song_neon():
    s = Song(116)
    Fs2 = 42

    def arp(song, bar0, bars, roots):
        for i in range(bars):
            r = roots[i % len(roots)] + 24
            for st in range(16):
                m = r + [0, 7, 12, 16, 19, 12, 7, 4][st % 8] + (0 if (i % 2 == 0) else -1 if st % 8 == 3 else 0)
                x = lp(saw(mf(m), song.beat / 4 * 0.8, 2, 0.004), 3000) * env(int(SR * song.beat / 4 * 0.8), 0.002, 8)
                song.add("fx", x, song.t(bar0 + i, st), 0.35)

    b = section(s, 4, [Fs2, D, A, E], None, "intro", None, pad_=True, first_crash=False)
    arp(s, b, 4, [Fs2, D, A, E])
    for _ in range(2):
        b = section(s, 4, [Fs2, D, A, E], "mute8", "four", "8ths", pad_=True)
        arp(s, b, 4, [Fs2, D, A, E])
    hook = [(73, 4), (76, 4), (78, 8), (76, 4), (73, 4), (71, 8), (69, 4), (71, 4), (73, 8), (None, 8)]
    b = section(s, 8, [D, E, Fs2, Fs2], "open8", "rock", "8ths", crash_every=4, lead=hook * 2, pad_=True)
    arp(s, b, 8, [D, E, Fs2, Fs2])
    b = section(s, 8, [B - 12, D, A, E], "half", "half", "root", pad_=True)
    arp(s, b, 8, [B - 12, D, A, E])
    b = section(s, 8, [D, E, Fs2, Fs2], "open8", "rock", "8ths", crash_every=4, lead=hook * 2, pad_=True)
    arp(s, b, 8, [D, E, Fs2, Fs2])
    b = section(s, 8, [Fs2, D, A, E], None, "four", "8ths", pad_=True, first_crash=True)
    arp(s, b, 8, [Fs2, D, A, E])
    solo(s, b, 8, 66, np.random.default_rng(8), 0.6)
    b = section(s, 8, [D, E, Fs2, Fs2], "open8", "rock2", "8ths", crash_every=2, lead=hook * 2, pad_=True)
    arp(s, b, 8, [D, E, Fs2, Fs2])
    return mixdown(s, {"drums": 1.0, "bass": 0.85, "gtr": 0.4, "lead": 0.3, "pad": 0.35, "fx": 1.0}, dist=10.0)


def song_chaos():
    s = Song(188)
    rng = np.random.default_rng(4)
    section(s, 4, [E, E, G, A], "open8", "punk", "8ths", crash_every=2)
    for _ in range(3):
        section(s, 4, [E, C, G, D], "mute8", "punk", "8ths")
        section(s, 4, [A, C, D, E], "open8", "punk", "8ths", crash_every=2,
                lead=[(76, 4), (79, 4), (81, 8), (79, 4), (76, 4), (74, 8), (76, 16)])
    b = section(s, 8, [E, D, C, D], "push", "rock2", "8ths", crash_every=4)
    solo(s, b, 8, 64, rng, 0.9)
    section(s, 8, [C, D, E, E], "half", "half", "root", crash_every=4)
    for _ in range(2):
        section(s, 4, [G, D, E, C], "open8", "punk", "8ths", crash_every=2,
                lead=[(79, 4), (78, 4), (76, 8), (74, 4), (76, 4), (71, 8), (74, 4), (76, 12)])
    b = section(s, 8, [E, C, G, D], "mute8", "double", "8ths", crash_every=4)
    solo(s, b, 8, 76, rng, 0.95)
    section(s, 8, [E, C, G, D], "open8", "punk", "8ths", crash_every=2)
    return mixdown(s, {"drums": 1.0, "bass": 0.9, "gtr": 0.6, "lead": 0.3}, dist=20.0)


def song_training():
    s = Song(102, swing=0.12)
    E2 = 40

    def scratch(song, bar, root, dense=True):
        steps = [0, 2, 3, 6, 8, 10, 11, 14] if dense else [0, 6, 10, 14]
        for st in steps:
            mute = st in (2, 3, 11)
            x = guitar_chord(root + 12, song.beat / 4 * (0.6 if mute else 1.2), "min", mute, seed=st)
            song.add("clean", hp(x, 300), song.t(bar, st), 0.45 if mute else 0.6)

    for part in range(5):
        for i in range(8):
            bar = s.cursor + i
            root = [E2, E2, A, A, E2, E2, B, A][i] if part != 3 else [C, C, D, D, E2, E2, B, B][i]
            drums(s, bar, "funk", fill=(i == 7), crash_=(i == 0), vel=0.9)
            bass(s, bar, root, "funk")
            scratch(s, bar, root, part != 1)
            if part >= 1:
                for m in [root + 24 + 7, root + 24 + 10, root + 24 + 14]:
                    s.add("keys", epiano(m, s.beat * 1.5, 0.6), s.t(bar, 0))
        if part in (2, 4):
            melody(s, s.cursor, [(76, 2), (79, 2), (81, 4), (79, 2), (76, 6), (None, 16), (74, 2), (76, 2), (79, 4),
                                 (76, 8), (None, 16), (71, 4), (74, 4), (76, 8), (None, 32)], bus="keys")
        s.cursor += 8
    return mixdown(s, {"drums": 0.9, "bass": 1.0, "clean": 1.0, "keys": 0.6}, reverb_amt=0.12)


def song_menu():
    s = Song(84, swing=0.18)
    prog = [53, 52, 50, 48]    # Fa, Mi, Re, Do (acordes de séptima: suena "lo-fi")
    ints = {53: [0, 4, 7, 11, 14], 52: [0, 3, 7, 10, 14], 50: [0, 3, 7, 10, 14], 48: [0, 4, 7, 11, 14]}
    for part in range(4):
        for i in range(8):
            bar = s.cursor + i
            root = prog[i % 4]
            if part > 0:
                drums(s, bar, "boombap", fill=False, crash_=False, vel=0.7)
            bass(s, bar, root - 12, "lofi", 0.8)
            for k, iv in enumerate(ints[root]):
                s.add("keys", epiano(root + 12 + iv, s.beat * 3.6, 0.55), s.t(bar, 0) + k * 0.018)
                if i % 2 == 1:
                    s.add("keys", epiano(root + 12 + iv, s.beat * 1.6, 0.35), s.t(bar, 10) + k * 0.012)
        if part in (1, 3):
            mel = [(72, 3), (74, 1), (76, 4), (79, 6), (77, 2), (76, 8), (74, 4), (72, 4), (69, 8), (None, 8),
                   (72, 3), (74, 1), (76, 4), (74, 4), (72, 4), (71, 8), (72, 16), (None, 8)]
            melody(s, s.cursor, mel, bus="keys", vel=0.8)
        s.cursor += 8
    # crepitar del vinilo
    L = int(s.t(s.cursor) * SR)
    r = np.random.default_rng(9)
    vinyl = lp(r.standard_normal(L), 3000) * 0.012
    pops = np.zeros(L)
    pops[r.integers(0, L, L // 3000)] = r.uniform(0.2, 0.6, L // 3000)
    vinyl += lp(pops, 5000)
    s.add("fx", vinyl, 0.0)
    return mixdown(s, {"drums": 0.75, "bass": 0.9, "keys": 0.7, "fx": 0.5}, reverb_amt=0.25)


SONGS = {"boulevard": song_boulevard, "asfalto": song_asfalto, "fuego": song_fuego, "neon": song_neon,
         "chaos": song_chaos, "training": song_training, "menu": song_menu}


def main(names=None):
    names = names or [a for a in sys.argv[1:] if a in SONGS] or list(SONGS)
    for n in names:
        write(n, SONGS[n]())
    print("Música en", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
