"""High-res tiling textures for the plaza floor (Roblox MaterialVariant-ready: color + normal + roughness).
 - plaza_tiles_*   : 2048px, 8x8 beveled terracotta/peach tiles (1 tile = 2 studs -> StudsPerTile 16)
 - plaza_cobble_*  : 2048px, cream cobblestones for paths (StudsPerTile 16)
 - plaza_mosaic_color : 4096px circular sun mosaic medallion for the fountain court (decal on a disc)
"""
import numpy as np, math
from PIL import Image, ImageFilter
OUT = "/workspace/roblox/steal-a-pinata/art/textures/plaza"
rng = np.random.default_rng(7)

def hexc(h): h = h.lstrip('#'); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], np.float32) / 255

def normal_from_height(h, strength=6.0):
    gy, gx = np.gradient(h)
    n = np.dstack([-gx * strength, gy * strength, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * .5 + .5) * 255).astype(np.uint8)

def smooth_noise(size, scale, seed):
    r = np.random.default_rng(seed); s = max(2, size // scale)
    small = Image.fromarray((r.random((s, s)) * 255).astype(np.uint8))
    return np.asarray(small.resize((size, size), Image.BICUBIC), np.float32) / 255

def save(arr, name):
    Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8) if arr.dtype != np.uint8 else arr).save(f"{OUT}/{name}.png")

def tiles(N=2048, n=8):
    cell = N // n; y, x = np.mgrid[0:N, 0:N]
    u = (x % cell) / cell; v = (y % cell) / cell
    ix, iy = x // cell, y // cell
    grout = .045; bev = .07
    d = np.minimum.reduce([u, 1 - u, v, 1 - v])           # distance to tile edge
    hgt = np.clip((d - grout) / bev, 0, 1); hgt = hgt * hgt * (3 - 2 * hgt)
    pal = [hexc(c) for c in ("#F2A877", "#EE9A68", "#F6B98A", "#E8905E", "#F4AE80")]
    pick = rng.integers(0, len(pal), (n, n)); tint = rng.uniform(-.035, .035, (n, n))
    base = np.zeros((N, N, 3), np.float32)
    for k, c in enumerate(pal): base[pick[iy, ix] == k] = c
    base += tint[iy, ix][..., None]
    cloud = smooth_noise(N, 48, 1)[..., None]; speck = rng.random((N, N, 1)).astype(np.float32)
    base *= .93 + .1 * cloud; base -= (speck > .985) * .06
    base *= (.82 + .18 * hgt)[..., None]                       # darker bevel edges
    gcol = hexc("#FBE3C6") * (.92 + .08 * cloud)
    col = np.where((hgt > 0)[..., None], base, gcol)
    h = hgt * .9 + cloud[..., 0] * .1 * hgt
    rough = np.where(hgt > 0, .55 + .1 * cloud[..., 0], .9)
    save(col, "plaza_tiles_color"); save(normal_from_height(h, 9), "plaza_tiles_normal"); save(rough, "plaza_tiles_roughness")
    save(np.dstack([h] * 3), "plaza_tiles_height")

def cobble(N=2048, n=12):
    cell = N / n; pts = []
    for j in range(n):
        for i in range(n):
            pts.append(((i + .5 + rng.uniform(-.3, .3)) * cell, (j + .5 + rng.uniform(-.3, .3)) * cell))
    pts = np.array(pts)
    # tile seamlessly: replicate points around
    P = np.concatenate([pts + np.array([dx, dy]) * N for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    d1 = np.full((N, N), 1e9, np.float32); d2 = np.full((N, N), 1e9, np.float32); idx = np.zeros((N, N), np.int32)
    for k, (px, py) in enumerate(P):
        if not (-cell * 2 < px < N + cell * 2 and -cell * 2 < py < N + cell * 2): continue
        x0, x1 = int(max(0, px - cell * 2)), int(min(N, px + cell * 2)); y0, y1 = int(max(0, py - cell * 2)), int(min(N, py + cell * 2))
        dd = np.sqrt((x[y0:y1, x0:x1] - px) ** 2 + (y[y0:y1, x0:x1] - py) ** 2)
        sub1 = d1[y0:y1, x0:x1]; sub2 = d2[y0:y1, x0:x1]; si = idx[y0:y1, x0:x1]
        closer = dd < sub1
        sub2[:] = np.where(closer, sub1, np.minimum(sub2, dd)); si[:] = np.where(closer, k % len(pts), si); sub1[:] = np.where(closer, dd, sub1)
    edge = (d2 - d1) / cell
    hgt = np.clip((edge - .05) / .22, 0, 1); hgt = np.sqrt(hgt)
    pal = [hexc(c) for c in ("#FFF1DC", "#F6E2C4", "#EFD7B6", "#FBE9CF", "#E9CDAA")]
    pick = rng.integers(0, len(pal), len(pts)); tint = rng.uniform(-.03, .03, len(pts))
    base = np.stack([pal[p] for p in pick])[idx] + tint[idx][..., None]
    cloud = smooth_noise(N, 40, 3)[..., None]
    base *= (.9 + .1 * cloud) * (.8 + .2 * hgt[..., None])
    col = np.where((hgt > 0)[..., None], base, hexc("#C9A27E") * .9)
    save(col, "plaza_cobble_color"); save(normal_from_height(hgt, 10), "plaza_cobble_normal"); save(np.where(hgt > 0, .6, .95), "plaza_cobble_roughness")

def mosaic(N=4096):
    """Polar mosaic: rings of small tiles, alternating fiesta colours, 16-ray sun. Transparent outside r=1."""
    y, x = (np.mgrid[0:N, 0:N].astype(np.float32) + .5) / N * 2 - 1
    r = np.sqrt(x * x + y * y); a = (np.arctan2(y, x) / (2 * np.pi)) % 1
    C = {k: hexc(v) for k, v in dict(pink="#FF3E9A", yel="#FFD23F", tur="#16C6D9", cream="#FFF3E0", lime="#7ED957",
                                      grape="#8E44EC", mango="#FF9A1F", terra="#E07A4F", white="#FFFFFF").items()}
    col = np.zeros((N, N, 3), np.float32) + C["cream"]
    ringw = .028; ring = np.floor(r / ringw).astype(int)
    nseg = np.maximum(8, (2 * np.pi * (ring + .5) * ringw / ringw * 1.0).astype(int))   # ~square tiles
    seg = np.floor(a * nseg).astype(int)
    fr = (r / ringw) % 1; fa = (a * nseg) % 1
    grout = (np.minimum.reduce([fr, 1 - fr, fa, 1 - fa]) < .08)
    rays = (np.floor(a * 16).astype(int) % 2 == 0)
    tw = rng.uniform(-.04, .04, 50000)
    # bands from centre outwards
    band = ring
    col[:] = C["cream"]
    m = band < 6; col[m & rays] = C["yel"]; col[m & ~rays] = C["mango"]
    m = (band >= 6) & (band < 8); col[m] = C["pink"]
    m = (band >= 8) & (band < 22); sun = (np.abs(((a * 16) % 1) - .5) * 2) < (1 - (band - 8) / 14)   # triangular rays
    col[m] = np.where(sun[m][..., None], np.where((np.floor(a * 16).astype(int) % 2 == 0)[m][..., None], C["yel"], C["mango"]), C["cream"])
    m = (band >= 22) & (band < 24); col[m] = C["tur"]
    m = (band >= 24) & (band < 30); chk = ((seg + band) % 2 == 0); col[m & chk] = C["white"]; col[m & ~chk] = C["tur"]
    m = (band >= 30) & (band < 32); col[m] = C["pink"]
    m = (band >= 32) & (band < 34); col[m] = C["yel"]
    col += tw[(seg * 31 + band * 7) % 50000][..., None]
    cloud = smooth_noise(N, 64, 5)[..., None]; col *= .94 + .08 * cloud
    edge = np.minimum.reduce([fr, 1 - fr, fa, 1 - fa])
    sh = np.clip(edge / .2, 0, 1)[..., None]; col *= .86 + .14 * sh
    col = np.where(grout[..., None], C["cream"] * .92, col)
    alpha = (r < 34 * ringw).astype(np.float32)
    rgba = np.dstack([col, alpha])
    save(rgba, "plaza_mosaic_color")
    hgt = np.where(grout, 0, np.clip(edge / .12, 0, 1))
    save(normal_from_height(hgt.astype(np.float32), 5), "plaza_mosaic_normal")

if __name__ == "__main__":
    tiles(); cobble(); mosaic(); print("ok")
