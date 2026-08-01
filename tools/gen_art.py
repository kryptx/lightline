#!/usr/bin/env python3
"""Generate all pixel-art assets for LIGHTLINE (Band 1 vertical slice).

Sprites are drawn at native pixel resolution; Godot renders them with
nearest-neighbor filtering. Sheets are horizontal strips of equal-size frames.
"""
import math
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets")

# ---------- palette ----------
OUTLINE = (16, 20, 36, 255)
SUIT = (66, 96, 122, 255)
SUIT_L = (96, 132, 160, 255)
SUIT_D = (44, 66, 88, 255)
BRASS = (198, 152, 64, 255)
BRASS_L = (236, 200, 116, 255)
BRASS_D = (140, 102, 42, 255)
GLASS = (150, 226, 236, 255)
GLASS_D = (84, 160, 180, 255)
FIN = (196, 98, 62, 255)
FIN_D = (142, 66, 42, 255)
TANK = (120, 130, 142, 255)
TANK_L = (168, 178, 190, 255)
ROCK = (46, 54, 76, 255)
ROCK_L = (74, 88, 114, 255)
ROCK_D = (32, 38, 56, 255)
KELP = (44, 116, 84, 255)
KELP_L = (70, 158, 110, 255)
KELP_D = (28, 82, 60, 255)
AMBER = (255, 214, 130, 255)
TEAL_GLOW = (120, 240, 220, 255)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            px(img, x, y, c)


def disc(img, cx, cy, r, c):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5:
                px(img, x, y, c)


def add_outline(img, color=OUTLINE):
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height and src[nx, ny][3] > 0:
                        dst[x, y] = color
                        break
    return out


def save(img, name):
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", name, img.size)


# ---------- diver ----------
def draw_diver_frame(kick_phase, bob, reel=False):
    """32x32 frame, diver facing right, horizontal swim pose."""
    f = new(32, 32)
    by = 14 + bob  # body top y

    # rear leg + fin (drawn first, darker)
    k1 = int(round(math.sin(kick_phase) * 3))
    lx = 9
    for i in range(6):  # thigh->foot going left
        px(f, lx - i, by + 4 + int(k1 * i / 5), SUIT_D)
        px(f, lx - i, by + 5 + int(k1 * i / 5), SUIT_D)
    fy = by + 4 + k1
    rect(f, lx - 10, fy, lx - 6, fy + 1, FIN_D)
    px(f, lx - 11, fy + (1 if k1 > 0 else 0), FIN_D)

    # front leg + fin
    k2 = int(round(math.sin(kick_phase + math.pi) * 3))
    for i in range(6):
        px(f, lx - i, by + 3 + int(k2 * i / 5), SUIT)
        px(f, lx - i, by + 4 + int(k2 * i / 5), SUIT)
    fy2 = by + 3 + k2
    rect(f, lx - 10, fy2, lx - 6, fy2 + 1, FIN)
    px(f, lx - 11, fy2 + (1 if k2 > 0 else 0), FIN)

    # air tank on back
    rect(f, 11, by - 4, 17, by - 2, TANK)
    rect(f, 11, by - 4, 17, by - 4, TANK_L)
    px(f, 18, by - 3, TANK_L)

    # torso
    rect(f, 8, by, 21, by + 5, SUIT)
    rect(f, 8, by, 21, by + 1, SUIT_L)
    rect(f, 8, by + 4, 21, by + 5, SUIT_D)
    # belt
    rect(f, 13, by, 14, by + 5, SUIT_D)
    px(f, 13, by + 2, BRASS)

    # arm along body (slight sway with kick)
    ay = by + 2 + (1 if math.sin(kick_phase) > 0.4 else 0)
    rect(f, 12, ay, 18, ay + 1, SUIT_L)
    px(f, 19, ay + 1, SUIT_L)  # hand

    # helmet
    hx, hy = 24, by + 1
    disc(f, hx, hy, 4, BRASS)
    px(f, hx - 3, hy - 3, BRASS_L)
    rect(f, hx - 2, hy - 4, hx + 1, hy - 4, BRASS_L)
    # glass porthole
    rect(f, hx, hy - 1, hx + 2, hy + 1, GLASS)
    px(f, hx + 2, hy + 1, GLASS_D)
    px(f, hx, hy - 1, (232, 250, 252, 255))
    # neck seal
    rect(f, 20, by + 1, 21, by + 3, BRASS_D)

    # tether ring on tank
    px(f, 14, by - 5, BRASS_L)
    px(f, 13, by - 5, BRASS_D)

    if reel:  # gripping the line overhead
        rect(f, 15, by - 8, 15, by - 5, SUIT_L)
        px(f, 16, by - 8, SUIT_L)

    return add_outline(f)


def gen_diver():
    swim = new(32 * 6, 32)
    for i in range(6):
        fr = draw_diver_frame(kick_phase=i / 6 * 2 * math.pi, bob=(1 if i in (2, 3) else 0))
        swim.paste(fr, (i * 32, 0))
    save(swim, "diver_swim.png")

    idle = new(32 * 4, 32)
    for i in range(4):
        fr = draw_diver_frame(kick_phase=math.sin(i / 4 * 2 * math.pi) * 0.5, bob=(0, 1, 1, 0)[i])
        idle.paste(fr, (i * 32, 0))
    save(idle, "diver_idle.png")

    reel = new(32 * 4, 32)
    for i in range(4):
        fr = draw_diver_frame(kick_phase=i / 4 * 2 * math.pi, bob=(0, 1, 0, 1)[i], reel=True)
        reel.paste(fr, (i * 32, 0))
    save(reel, "diver_reel.png")


# ---------- fish ----------
def draw_fish(body, belly, tail_phase, w=16, h=10):
    f = new(w, h)
    cy = h // 2
    # body ellipse
    for x in range(3, 13):
        r = 3 - abs(x - 8) * 0.45
        for dy in range(-int(r), int(r) + 1):
            px(f, x, cy + dy, body)
    # belly
    for x in range(5, 11):
        px(f, x, cy + 1, belly)
    # tail
    t = int(round(math.sin(tail_phase) * 2))
    for i in range(3):
        px(f, 2 - i, cy + t * (i + 1) // 3, body)
        px(f, 2 - i, cy + 1 + t * (i + 1) // 3, body)
    # eye
    px(f, 11, cy - 1, (240, 244, 250, 255))
    px(f, 12, cy - 1, OUTLINE)
    # top fin
    px(f, 7, cy - 3, body)
    px(f, 8, cy - 3, body)
    return add_outline(f)


def gen_fish():
    for name, body, belly in (
        ("fish_teal", (72, 170, 168, 255), (170, 224, 214, 255)),
        ("fish_rose", (188, 110, 128, 255), (232, 186, 192, 255)),
    ):
        sheet = new(16 * 4, 10)
        for i in range(4):
            sheet.paste(draw_fish(body, belly, i / 4 * 2 * math.pi), (i * 16, 0))
        save(sheet, name + ".png")


# ---------- urchin ----------
def gen_urchin():
    sheet = new(18 * 2, 18)
    for i, spread in enumerate((6.5, 7.5)):
        f = new(18, 18)
        cx = cy = 9
        for a in range(0, 360, 20):
            r = spread + (1 if (a // 20) % 2 == i % 2 else 0)
            x = cx + math.cos(math.radians(a)) * r
            y = cy + math.sin(math.radians(a)) * r
            steps = int(r)
            for s in range(steps):
                t = s / steps
                px(f, cx + (x - cx) * t, cy + (y - cy) * t, (60, 40, 78, 255) if t > 0.5 else (40, 28, 54, 255))
        disc(f, cx, cy, 4, (74, 50, 96, 255))
        disc(f, cx - 1, cy - 1, 2, (104, 74, 128, 255))
        px(f, cx, cy, (196, 120, 210, 255))
        sheet.paste(add_outline(f), (i * 18, 0))
    save(sheet, "urchin.png")


# ---------- pickups ----------
def gen_salvage():
    # three variants: gear, coin cluster, bottle — 14x14 each
    sheet = new(14 * 3, 14)
    g = new(14, 14)
    disc(g, 7, 7, 4, TANK)
    disc(g, 7, 7, 2, TANK_L)
    px(g, 7, 7, ROCK_D)
    for a in range(0, 360, 45):
        px(g, 7 + math.cos(math.radians(a)) * 5.5, 7 + math.sin(math.radians(a)) * 5.5, TANK)
    sheet.paste(add_outline(g), (0, 0))

    c = new(14, 14)
    for cx, cy in ((5, 9), (9, 9), (7, 6)):
        disc(c, cx, cy, 2.6, BRASS)
        px(c, cx - 1, cy - 1, BRASS_L)
    sheet.paste(add_outline(c), (14, 0))

    b = new(14, 14)
    rect(b, 5, 5, 8, 12, (96, 168, 152, 255))
    rect(b, 6, 2, 7, 4, (96, 168, 152, 255))
    rect(b, 6, 1, 7, 1, BRASS_D)
    px(b, 5, 6, (170, 224, 214, 255))
    sheet.paste(add_outline(b), (28, 0))
    save(sheet, "salvage.png")


def gen_relic():
    # glowing idol, 4-frame pulse, 16x22
    sheet = new(16 * 4, 22)
    for i in range(4):
        f = new(16, 22)
        glow = 0.6 + 0.4 * math.sin(i / 4 * 2 * math.pi)
        # halo
        for r, alpha in ((7, 40), (6, 70)):
            disc(f, 8, 9, r, (120, 240, 220, int(alpha * glow)))
        # idol body
        rect(f, 6, 6, 10, 16, (70, 96, 110, 255))
        rect(f, 5, 16, 11, 19, (54, 76, 90, 255))
        disc(f, 8, 5, 3, (70, 96, 110, 255))
        # carved face
        px(f, 7, 4, TEAL_GLOW)
        px(f, 9, 4, TEAL_GLOW)
        rect(f, 7, 10, 9, 10, TEAL_GLOW)
        px(f, 8, 12, (int(120 * glow + 60), int(240 * glow), int(220 * glow), 255))
        sheet.paste(add_outline(f), (i * 16, 0))
    save(sheet, "relic.png")


def gen_air_pocket():
    sheet = new(20 * 3, 20)
    for i in range(3):
        f = new(20, 20)
        wob = math.sin(i / 3 * 2 * math.pi)
        disc(f, 10 + wob, 10, 6, (150, 210, 240, 110))
        disc(f, 10 + wob, 10, 5, (190, 235, 250, 90))
        px(f, 8 + wob, 7, (255, 255, 255, 220))
        px(f, 7 + wob, 8, (255, 255, 255, 160))
        disc(f, 15, 5 - i, 1.4, (200, 235, 250, 120))
        disc(f, 4, 14 + i, 1.1, (200, 235, 250, 100))
        sheet.paste(f, (i * 20, 0))
    save(sheet, "air_pocket.png")


def gen_net():
    f = new(22, 18)
    # bundle of cargo under a rope net
    disc(f, 11, 11, 7, (92, 74, 52, 255))
    disc(f, 8, 10, 4, (116, 96, 66, 255))
    disc(f, 14, 12, 4, (104, 84, 58, 255))
    for x in range(4, 19, 3):
        for y in range(5, 17):
            if (x + y) % 3 == 0:
                px(f, x, y, (176, 148, 96, 255))
    for y in range(5, 17, 3):
        for x in range(4, 19):
            if (x * 7 + y) % 4 == 0:
                px(f, x, y, (176, 148, 96, 255))
    # float marker
    rect(f, 10, 1, 12, 3, (216, 90, 74, 255))
    px(f, 11, 0, (255, 214, 130, 255))
    save(add_outline(f), "net.png")


# ---------- kelp ----------
def gen_kelp():
    sheet = new(18 * 4, 48)
    for i in range(4):
        f = new(18, 48)
        phase = i / 4 * 2 * math.pi
        for y in range(47, 2, -1):
            t = (47 - y) / 45.0
            sway = math.sin(phase + t * 2.2) * 3 * t
            x = 9 + sway
            px(f, x, y, KELP)
            px(f, x - 1, y, KELP_D)
            if y % 5 == 0 and y > 8:
                # leaf pair
                for l in range(1, 4):
                    px(f, x + l, y - l // 2, KELP_L)
                    px(f, x - 1 - l, y - 1 - l // 2, KELP)
        sheet.paste(f, (i * 18, 0))
    save(sheet, "kelp.png")


# ---------- rock tiles ----------
def gen_rocks():
    rng = random.Random(7)
    tiles = new(32 * 4, 32)
    for t in range(4):
        f = new(32, 32)
        rect(f, 0, 0, 31, 31, ROCK)
        # speckle
        for _ in range(26):
            x, y = rng.randrange(32), rng.randrange(32)
            f.putpixel((x, y), ROCK_D if rng.random() < 0.6 else ROCK_L)
        # cracks
        for _ in range(2):
            x, y = rng.randrange(4, 28), rng.randrange(4, 28)
            for s in range(rng.randrange(4, 9)):
                px(f, x, y, ROCK_D)
                x += rng.choice((-1, 0, 1))
                y += rng.choice((0, 1))
        if t == 1:  # top-lit edge tile
            rect(f, 0, 0, 31, 1, ROCK_L)
            for x in range(0, 32, 3):
                px(f, x, 2, ROCK_L)
            # a little sediment
            for x in range(0, 32, 2):
                px(f, x + rng.randrange(2), 0, (108, 122, 148, 255))
        if t == 3:  # sandy floor variant
            rect(f, 0, 0, 31, 2, (120, 108, 84, 255))
            rect(f, 0, 3, 31, 4, (96, 86, 68, 255))
        tiles.paste(f, (t * 32, 0))
    save(tiles, "rock_tiles.png")


# ---------- light & fx ----------
def gen_halo():
    size = 256
    f = new(size, size)
    c = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            if d < 1:
                a = int(255 * (1 - d) ** 1.6)
                f.putpixel((x, y), (255, 236, 200, a))
    save(f, "halo.png")


def gen_vignette():
    w, h = 480, 270
    f = new(w, h)
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - cx) / cx, (y - cy) / cy)
            a = max(0.0, d - 0.55) / 0.45
            f.putpixel((x, y), (10, 4, 8, int(min(1.0, a) ** 2 * 235)))
    save(f, "vignette.png")


def gen_water_gradient():
    w, h = 16, 1024
    f = new(w, h)
    top = (22, 52, 84)
    bot = (2, 5, 12)
    for y in range(h):
        t = (y / h) ** 0.7
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            f.putpixel((x, y), c)
    save(f, "water_gradient.png")


def gen_bubble():
    sheet = new(8 * 3, 8)
    for i, r in enumerate((1.6, 2.4, 3.0)):
        f = new(8, 8)
        disc(f, 4, 4, r, (196, 232, 248, 140))
        px(f, 3, 3, (255, 255, 255, 200))
        sheet.paste(f, (i * 8, 0))
    save(sheet, "bubble.png")


def gen_surface_glimmer():
    w, h = 64, 10
    f = new(w, h)
    rng = random.Random(3)
    for x in range(w):
        f.putpixel((x, 0), (210, 235, 250, 200))
        f.putpixel((x, 1), (150, 205, 235, 150))
        if rng.random() < 0.5:
            f.putpixel((x, 2), (120, 180, 220, 90))
    save(f, "surface.png")


# ---------- HUD icons ----------
def gen_icons():
    # lightline lantern icon 12x12
    f = new(12, 12)
    rect(f, 4, 2, 7, 3, BRASS)
    rect(f, 3, 4, 8, 8, AMBER)
    rect(f, 4, 9, 7, 10, BRASS_D)
    px(f, 5, 5, (255, 250, 220, 255))
    save(add_outline(f), "icon_light.png")

    f = new(12, 12)  # weight icon
    rect(f, 3, 5, 8, 10, TANK)
    rect(f, 5, 2, 6, 4, TANK_L)
    save(add_outline(f), "icon_weight.png")

    f = new(12, 12)  # depth arrow
    for i in range(5):
        px(f, 5 - i + 1, 3 + i, GLASS)
        px(f, 6 + i - 1, 3 + i, GLASS)
    rect(f, 5, 8, 6, 9, GLASS_D)
    save(add_outline(f), "icon_depth.png")

    # net marker arrow
    f = new(14, 14)
    for i in range(6):
        px(f, 7 - i + 1, 4 + i, (255, 170, 120, 255))
        px(f, 7 + i - 1, 4 + i, (255, 170, 120, 255))
    save(add_outline(f), "icon_net_marker.png")


# ---------- lighthouse hub background ----------
def gen_lighthouse_bg():
    w, h = 320, 180
    f = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(f)
    rng = random.Random(11)
    # dusk sky gradient
    sky_top = (24, 18, 52)
    sky_mid = (86, 44, 74)
    sky_low = (198, 110, 72)
    horizon = 108
    for y in range(horizon):
        t = y / horizon
        if t < 0.6:
            tt = t / 0.6
            c = tuple(int(sky_top[i] + (sky_mid[i] - sky_top[i]) * tt) for i in range(3))
        else:
            tt = (t - 0.6) / 0.4
            c = tuple(int(sky_mid[i] + (sky_low[i] - sky_mid[i]) * tt) for i in range(3))
        d.line([(0, y), (w, y)], fill=c + (255,))
    # stars
    for _ in range(60):
        x, y = rng.randrange(w), rng.randrange(horizon - 30)
        b = rng.randrange(120, 220)
        f.putpixel((x, y), (b, b, min(255, b + 20), 255))
    # cloud bands
    for cy, ln, col in ((30, 40, (54, 36, 72)), (52, 70, (74, 42, 78)), (78, 90, (120, 60, 80))):
        for i in range(3):
            x0 = rng.randrange(w)
            d.line([(x0, cy + i * 3), (x0 + ln, cy + i * 3)], fill=col + (255,))
    # sea
    sea_top = (52, 46, 84)
    sea_bot = (10, 14, 34)
    for y in range(horizon, h):
        t = (y - horizon) / (h - horizon)
        c = tuple(int(sea_top[i] + (sea_bot[i] - sea_top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c + (255,))
    # shimmer
    for _ in range(90):
        x, y = rng.randrange(w), rng.randrange(horizon + 2, h - 4)
        ln = rng.randrange(2, 7)
        c = (150, 120, 130) if y < horizon + 26 else (60, 70, 110)
        d.line([(x, y), (x + ln, y)], fill=c + (160,))

    # rock island
    def rock_blob(cx, cy, rx, ry, col):
        for yy in range(int(cy - ry), int(cy + ry) + 1):
            for xx in range(int(cx - rx), int(cx + rx) + 1):
                if ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1:
                    if 0 <= xx < w and 0 <= yy < h:
                        f.putpixel((xx, yy), col + (255,))

    rock_blob(160, 122, 55, 18, (30, 30, 48))
    rock_blob(130, 118, 25, 10, (38, 38, 58))
    rock_blob(190, 120, 28, 11, (26, 26, 42))

    # lighthouse tower (derelict)
    base_x, base_y = 160, 112
    tower_h = 62
    for i, y in enumerate(range(base_y - tower_h, base_y)):
        t = i / tower_h
        half = int(7 + 4 * t)
        col = (172, 168, 170) if (y // 8) % 2 == 0 else (150, 118, 118)
        d.line([(base_x - half, y), (base_x + half, y)], fill=col + (255,))
        # shade right side
        d.line([(base_x + half - 2, y), (base_x + half, y)], fill=(96, 84, 96, 255))
    # damage: missing chunks
    for _ in range(14):
        x = base_x + rng.randrange(-8, 9)
        y = base_y - rng.randrange(6, tower_h - 6)
        f.putpixel((x, y), (60, 52, 64, 255))
    # gallery + lamp room
    d.rectangle([base_x - 9, base_y - tower_h - 10, base_x + 9, base_y - tower_h], fill=(52, 48, 58, 255))
    d.rectangle([base_x - 6, base_y - tower_h - 8, base_x + 6, base_y - tower_h - 2], fill=(255, 220, 140, 255))
    d.rectangle([base_x - 10, base_y - tower_h - 12, base_x + 10, base_y - tower_h - 10], fill=(40, 36, 46, 255))
    # roof
    for i in range(6):
        d.line([(base_x - 8 + i, base_y - tower_h - 12 - i), (base_x + 8 - i, base_y - tower_h - 12 - i)],
               fill=(70, 40, 46, 255))
    # lamp glow
    gx, gy = base_x, base_y - tower_h - 5
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for r, a in ((26, 26), (18, 44), (11, 70), (6, 110)):
        gd = ImageDraw.Draw(glow)
        gd.ellipse([gx - r, gy - r // 2, gx + r, gy + r // 2], fill=(255, 220, 150, a))
    f = Image.alpha_composite(f, glow)
    d = ImageDraw.Draw(f)
    # light beam sweeping right
    beam = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(beam)
    bd.polygon([(gx + 4, gy - 2), (w, gy - 26), (w, gy + 14)], fill=(255, 226, 160, 34))
    f = Image.alpha_composite(f, beam)
    d = ImageDraw.Draw(f)

    # the lightline: glowing tether running from lamp down into the sea
    lx = base_x - 22
    for y in range(gy, h):
        sway = math.sin(y * 0.12) * (1 + (y - gy) * 0.03)
        c = (255, 226, 160, 220) if y < 120 else (150, 230, 210, 190)
        f.putpixel((min(w - 1, max(0, int(lx + sway))), y), c)
    # dock + boat silhouette
    d.rectangle([96, 124, 128, 126], fill=(24, 22, 36, 255))
    for x in range(98, 126, 6):
        d.line([(x, 126), (x, 132)], fill=(24, 22, 36, 255))

    f = f.resize((1280, 720), Image.NEAREST)
    save(f, "lighthouse_bg.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    gen_diver()
    gen_fish()
    gen_urchin()
    gen_salvage()
    gen_relic()
    gen_air_pocket()
    gen_net()
    gen_kelp()
    gen_rocks()
    gen_halo()
    gen_vignette()
    gen_water_gradient()
    gen_bubble()
    gen_surface_glimmer()
    gen_icons()
    gen_lighthouse_bg()
    print("done")


if __name__ == "__main__":
    main()
