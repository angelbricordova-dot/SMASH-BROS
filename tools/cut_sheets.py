"""Quita el fondo de cuadritos de las hojas de referencia (art/referencias/) y guarda una máscara
por hoja en art/mascaras/<id>.png (blanco = personaje).

Dos métodos:
  * "cuadricula": detecta el patrón de cuadritos gris claro/gris oscuro (rápido, sin IA).
  * "ia": para hojas donde el fondo se parece al personaje (Lamont: cuadritos casi negros y
    pelo/gorra/pantalón negros) usa la IA de recorte BiRefNet (librería `rembg`). Es lenta
    (~1 minuto por trozo) y usa unos 8 GB de memoria.

Solo hace falta si cambias las imágenes de referencia:
    pip install pillow numpy scipy            (y para "ia": pip install rembg onnxruntime)
    python3 tools/cut_sheets.py [nombre...]
Luego:  python3 tools/import_sheets.py     (arma las hojas de animación del juego)
"""
import os, sys
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
REF = os.path.join(ROOT, "art", "referencias")
OUT = os.path.join(ROOT, "art", "mascaras")
# hoja -> tamaño de mosaico (≈ 2.5 veces la altura de un personaje en esa hoja)
SHEETS = {"ilunna": 320, "abnielito": 256, "schizov": 256, "lamont": 192, "panadero": 128}
METHOD = {"lamont": "ia"}   # el resto: "cuadricula"


def find(name):
    for ext in (".webp", ".png", ".jpg"):
        p = os.path.join(REF, name + ext)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(name)


# ----------------------------------------------------------------------------- método "cuadricula"
def _levels(a):
    """Los dos grises del fondo de cuadritos, medidos en el borde de la imagen."""
    rgb = a.astype(float)
    border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3), rgb[:, :4].reshape(-1, 3),
                             rgb[:, -4:].reshape(-1, 3)])
    lum = border.mean(1)[(border.max(1) - border.min(1)) < 16]
    thr = (np.percentile(lum, 90) + np.percentile(lum, 10)) / 2
    return np.median(lum[lum > thr]), np.median(lum[lum <= thr])


def _flood_bg(a, hi, lo):
    """Grises neutros conectados con el borde (se come las camisetas grises si el contorno tiene huecos)."""
    from scipy import ndimage
    rgb = a.astype(int)
    L = rgb.mean(axis=2)
    neutral = (rgb.max(axis=2) - rgb.min(axis=2)) < 18
    cand = neutral & (L > lo - 28) & (L < hi + 30)
    lab, _ = ndimage.label(cand)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(edge))


def _cells_fg(a, hi, lo, tol=13, cell=14):
    """Fondo = cuadritos pequeños (una zona gris grande no es un cuadrito: es ropa)."""
    from scipy import ndimage
    rgb = a.astype(float)
    L = rgb.mean(2)
    neutral = (rgb.max(2) - rgb.min(2)) < 14
    res = np.zeros(L.shape, bool)
    for lev in (hi, lo):
        m = neutral & (abs(L - lev) < tol)
        lab, n = ndimage.label(m)
        ok = np.zeros(n + 1, bool)
        for i, s in enumerate(ndimage.find_objects(lab), 1):
            ok[i] = (s[0].stop - s[0].start) <= cell and (s[1].stop - s[1].start) <= cell
        res |= ok[lab]
    blend = neutral & (L > lo - 6) & (L < hi + 6)
    cand = res | (blend & ndimage.binary_dilation(res, iterations=2))
    lab, _ = ndimage.label(cand)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    fg = ndimage.binary_opening(~bg, iterations=1)
    fg2 = _closefill(fg, 3)
    return fg2 & ~((fg2 & ~fg) & bg & ~ndimage.binary_fill_holes(fg))


def _closefill(m, r):
    from scipy import ndimage
    st = ndimage.generate_binary_structure(2, 1)
    p = r + 2
    mp = ndimage.binary_closing(np.pad(m, p), structure=st, iterations=r)
    return ndimage.binary_fill_holes(mp)[p:-p, p:-p]


def cut_checker(name):
    from scipy import ndimage
    a = np.asarray(Image.open(find(name)).convert("RGB"))
    hi, lo = _levels(a)
    fg1 = ndimage.binary_opening(~_flood_bg(a, hi, lo), iterations=1)
    fg = _cells_fg(a, hi, lo) & _closefill(fg1, 4)
    fg = ndimage.binary_opening(fg, iterations=1)
    # rellena huecos cerrados que no tienen patrón de cuadritos (camisetas grises)
    L = a.astype(float).mean(2)
    fg0 = fg.copy()
    lab, n = ndimage.label(_closefill(fg, 8) & ~fg)
    for i in range(1, n + 1):
        m = lab == i
        ring = ndimage.binary_dilation(m, iterations=2) & ~m
        enc = fg0[ring].mean()
        if m.sum() < 6 and enc > 0.6:
            fg |= m
            continue
        if enc < 0.8:
            continue
        fh = (abs(L[m] - hi) < 12).mean()
        fl = (abs(L[m] - lo) < 12).mean()
        if not (fh > 0.2 and fl > 0.2):
            fg |= m
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((fg * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))
    print(name, "listo (cuadricula)")


# ----------------------------------------------------------------------------- método "ia"
def _tiles(W, H, tile):
    step = tile // 2
    xs = sorted(set(list(range(0, max(1, W - tile) + 1, step)) + [max(0, W - tile)]))
    ys = sorted(set(list(range(0, max(1, H - tile) + 1, step)) + [max(0, H - tile)]))
    return xs, ys


def cut_row(name, tile, y, out_npy):
    """Procesa una fila de mosaicos (en un proceso aparte: la IA gasta mucha memoria)."""
    import onnxruntime as ort
    from rembg import new_session, remove
    opts = ort.SessionOptions()
    opts.enable_cpu_mem_arena = False
    opts.enable_mem_pattern = False
    session = new_session("birefnet-general", sess_opts=opts)
    im = Image.open(find(name)).convert("RGB")
    W, H = im.size
    xs, _ = _tiles(W, H, tile)
    acc = np.zeros((H, W), np.float32)
    for x in xs:
        box = (x, y, min(W, x + tile), min(H, y + tile))
        c = im.crop(box)
        up = 1024 / max(c.size)
        c2 = c.resize((round(c.width * up), round(c.height * up)), Image.LANCZOS)
        a = remove(c2, session=session, only_mask=True)
        a = np.asarray(a.resize(c.size, Image.BILINEAR)).astype(np.float32) / 255.0
        # ignora los bordes del mosaico (ahí la IA ve personajes cortados)
        m = 0 if tile >= min(W, H) else tile // 8
        w = np.ones_like(a)
        if m:
            if box[0] > 0: w[:, :m] = 0
            if box[1] > 0: w[:m, :] = 0
            if box[2] < W: w[:, -m:] = 0
            if box[3] < H: w[-m:, :] = 0
        sub = acc[box[1]:box[3], box[0]:box[2]]
        np.maximum(sub, a * w, out=sub)
    np.save(out_npy, acc)


def cut(name, tile):
    import subprocess, tempfile
    W, H = Image.open(find(name)).size
    _, ys = _tiles(W, H, tile)
    acc = np.zeros((H, W), np.float32)
    tmp = tempfile.mkdtemp()
    for y in ys:
        f = os.path.join(tmp, "row%d.npy" % y)
        subprocess.run([sys.executable, __file__, "--row", name, str(tile), str(y), f], check=True)
        np.maximum(acc, np.load(f), out=acc)
        print(name, "fila", y, "/", H, flush=True)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((acc * 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--row":
        cut_row(sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5])
        return
    names = sys.argv[1:] or list(SHEETS)
    for n in names:
        if METHOD.get(n, "cuadricula") == "ia":
            cut(n, SHEETS[n])
        else:
            cut_checker(n)


if __name__ == "__main__":
    main()
