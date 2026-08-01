#!/usr/bin/env python3
"""Beta-stage art: the Gardens & the Throat, parasites, blooms, the Warden,
the Gardener keeper, gravity wells, and the finale set pieces."""
import math
import random

from gen_art import (new, px, rect, disc, add_outline, save,
                     OUTLINE, AMBER, TEAL_GLOW)

# Gardens palette (bioluminescent reef on dark rock)
REEF = (52, 40, 66, 255)
REEF_L = (80, 62, 96, 255)
REEF_D = (34, 26, 46, 255)
CORAL_A = (240, 110, 150, 255)
CORAL_B = (120, 230, 190, 255)
CORAL_C = (255, 190, 90, 255)

# Throat palette (black basalt, red veins)
BASALT = (30, 28, 34, 255)
BASALT_L = (52, 48, 56, 255)
BASALT_D = (16, 15, 20, 255)
VEIN = (150, 40, 44, 255)
VEIN_HOT = (230, 90, 70, 255)


def gen_gardens_tiles():
    rng = random.Random(41)
    tiles = new(32 * 4, 32)
    for t in range(4):
        f = new(32, 32)
        rect(f, 0, 0, 31, 31, REEF)
        for _ in range(22):
            f.putpixel((rng.randrange(32), rng.randrange(32)),
                       REEF_L if rng.random() < 0.5 else REEF_D)
        # organic pocks
        for _ in range(4):
            x, y = rng.randrange(4, 28), rng.randrange(4, 28)
            disc(f, x, y, rng.uniform(1.5, 2.6), REEF_D)
        if t == 1:  # living top edge: coral fuzz
            rect(f, 0, 0, 31, 1, REEF_L)
            for x in range(0, 32, 2):
                c = (CORAL_A, CORAL_B, CORAL_C)[rng.randrange(3)]
                h = rng.randrange(1, 4)
                for y in range(h):
                    px(f, x + rng.randrange(2), 2 + y, c)
        if t == 2:  # embedded glow polyps
            for _ in range(5):
                x, y = rng.randrange(3, 29), rng.randrange(3, 29)
                c = (CORAL_A, CORAL_B, CORAL_C)[rng.randrange(3)]
                disc(f, x, y, 1.6, c)
                px(f, x, y, (255, 255, 255, 220))
        if t == 3:  # root-laced variant
            for _ in range(3):
                x = rng.randrange(2, 30)
                y = 0
                while y < 31:
                    px(f, x, y, (96, 78, 60, 255))
                    px(f, x + 1, y, (70, 56, 44, 255))
                    x += rng.choice((-1, 0, 1))
                    x = max(1, min(30, x))
                    y += 1
        tiles.paste(f, (t * 32, 0))
    save(tiles, "gardens_tiles.png")


def gen_throat_tiles():
    rng = random.Random(55)
    tiles = new(32 * 4, 32)
    for t in range(4):
        f = new(32, 32)
        rect(f, 0, 0, 31, 31, BASALT)
        # columnar basalt seams
        for x in range(0, 32, 8):
            for y in range(32):
                if rng.random() < 0.8:
                    px(f, x + (y // 11) % 2, y, BASALT_D)
        for _ in range(16):
            f.putpixel((rng.randrange(32), rng.randrange(32)),
                       BASALT_L if rng.random() < 0.5 else BASALT_D)
        if t == 1:  # top edge, faintly lit
            rect(f, 0, 0, 31, 0, BASALT_L)
            for x in range(0, 32, 3):
                px(f, x, 1, BASALT_L)
        if t == 2:  # red vein
            x, y = rng.randrange(6, 26), 0
            while y < 31:
                px(f, x, y, VEIN)
                if rng.random() < 0.3:
                    px(f, x + 1, y, VEIN_HOT)
                x += rng.choice((-1, 0, 0, 1))
                x = max(1, min(30, x))
                y += 1
        if t == 3:  # crushed scree
            for _ in range(10):
                x, y = rng.randrange(2, 30), rng.randrange(2, 30)
                px(f, x, y, BASALT_L)
                px(f, x + 1, y + 1, BASALT_D)
        tiles.paste(f, (t * 32, 0))
    save(tiles, "throat_tiles.png")


def gen_parasite():
    # wick louse: 10x10, 4 frames — a mote with cilia and a glowing belly
    sheet = new(10 * 4, 10)
    for i in range(4):
        f = new(10, 10)
        wob = math.sin(i / 4 * 2 * math.pi)
        disc(f, 5, 5, 2.6, (70, 60, 90, 255))
        # glowing belly — the stolen light
        g = 0.6 + 0.4 * wob
        px(f, 5, 6, (int(255 * g), int(214 * g), int(130 * g), 255))
        px(f, 4, 5, (110, 96, 140, 255))
        # cilia
        for a in range(0, 360, 45):
            r = 3.4 + (0.8 if (a // 45 + i) % 2 == 0 else 0)
            x = 5 + math.cos(math.radians(a)) * r
            y = 5 + math.sin(math.radians(a)) * r
            px(f, x, y, (140, 130, 170, 200))
        sheet.paste(f, (i * 10, 0))
    save(sheet, "parasite.png")


def gen_bloom():
    # carnivorous bloom, 26x26: frame 0 closed, frame 1 open (armed)
    sheet = new(26 * 2, 26)
    # closed: a fat bud
    f = new(26, 26)
    rect(f, 12, 16, 13, 24, (60, 110, 70, 255))
    disc(f, 13, 11, 6, (150, 60, 110, 255))
    disc(f, 13, 11, 4, (190, 80, 140, 255))
    for a in range(0, 360, 60):
        x = 13 + math.cos(math.radians(a)) * 5.5
        y = 11 + math.sin(math.radians(a)) * 5.5
        px(f, x, y, (110, 40, 80, 255))
    sheet.paste(add_outline(f), (0, 0))
    # open: petals wide, teeth ring, glowing throat
    f = new(26, 26)
    rect(f, 12, 18, 13, 25, (60, 110, 70, 255))
    for a in range(0, 360, 30):
        for r in (7, 9, 11):
            x = 13 + math.cos(math.radians(a)) * r
            y = 12 + math.sin(math.radians(a)) * r * 0.8
            px(f, x, y, (240, 110, 150, 255) if r > 8 else (190, 80, 140, 255))
    for a in range(0, 360, 45):  # teeth
        x = 13 + math.cos(math.radians(a)) * 5
        y = 12 + math.sin(math.radians(a)) * 4
        px(f, x, y, (235, 235, 240, 255))
    disc(f, 13, 12, 2.6, (255, 214, 130, 255))
    px(f, 13, 12, (255, 250, 230, 255))
    sheet.paste(add_outline(f), (26, 0))
    save(sheet, "bloom.png")


def gen_warden():
    # the Warden: 72x44, 3 frames (prowl a, prowl b, strike) — mostly
    # silhouette: a long deep-sea shape defined by its paired lamp-eyes
    sheet = new(72 * 3, 44)
    body = (22, 24, 32, 255)
    body_l = (34, 38, 48, 255)
    for i, state in enumerate(("a", "b", "strike")):
        f = new(72, 44)
        und = math.sin(i * 2.1) * 2
        # long tapering body
        for x in range(4, 64):
            t = (x - 4) / 60.0
            r = 9 * math.sin(math.pi * min(1.0, t * 1.25)) + 2
            yc = 22 + math.sin(t * 6.0 + i * 2.0) * 3 + und
            for dy in range(-int(r), int(r) + 1):
                c = body if abs(dy) > r - 3 else body_l
                px(f, x, yc + dy, c)
        # fin rays
        for x in range(16, 60, 7):
            px(f, x, 8 + (x // 7 + i) % 3, body_l)
			# (ray tips fade into the dark)
        # tail
        for j in range(6):
            px(f, 4 - j // 2, 22 + und + j - 3, body)
        # the eyes — two cold lamps
        ex = 60 if state != "strike" else 64
        for dy in (-4, 4):
            disc(f, ex, 22 + und + dy, 2.2, (255, 240, 200, 255))
            px(f, ex, 22 + und + dy, (150, 240, 220, 255))
			# eye glow halo baked faintly
        # strike: open jaw beneath the eyes
        if state == "strike":
            for x in range(58, 70):
                px(f, x, 28 + und, (10, 8, 12, 255))
                px(f, x, 29 + und, (10, 8, 12, 255))
            for x in range(59, 69, 2):
                px(f, x, 27 + und, (220, 224, 230, 255))
                px(f, x, 30 + und, (220, 224, 230, 255))
        sheet.paste(f, (i * 72, 0))
    save(sheet, "warden.png")


def gen_keeper_gardener():
    # 60x56, 3 frames: a hulking root-and-coral tender, bloom crown
    sheet = new(60 * 3, 56)
    bark = (86, 66, 50, 255)
    bark_l = (118, 92, 66, 255)
    bark_d = (56, 44, 36, 255)
    moss = (70, 158, 110, 255)
    for i, state in enumerate(("idle", "charge", "stunned")):
        f = new(60, 56)
        lean = 5 if state == "charge" else 0
        # trunk body
        for y in range(14, 50):
            w = 13 * math.sqrt(max(0.0, 1 - ((y - 34) / 21.0) ** 2)) + 3
            for dx in range(-int(w), int(w) + 1):
                c = bark
                if dx < -int(w) + 3:
                    c = bark_d
                if y < 20:
                    c = bark_l
                px(f, 30 + dx + lean, y, c)
        # moss patches
        rng = random.Random(7 + i)
        for _ in range(12):
            px(f, 30 + rng.randrange(-11, 12) + lean, rng.randrange(16, 48), moss)
        # root legs
        for dx in (-10, -2, 8):
            for j in range(7):
                px(f, 30 + dx + lean + (j % 2), 48 + j // 2, bark_d)
        # long tending arms
        ax = 48 + lean * 2
        for j in range(12):
            px(f, ax + j // 2, 26 + j, bark_l)
        for j in range(10):
            px(f, 12 + lean - j // 2, 28 + j, bark_d)
        # bloom crown
        for bx, c in ((20, CORAL_A), (30, CORAL_C), (40, CORAL_B)):
            disc(f, bx + lean, 10, 3.4, c)
            px(f, bx + lean, 10, (255, 255, 255, 230))
            px(f, bx + lean, 14, (60, 110, 70, 255))
        if state == "stunned":
            # the heart-polyp shows through the bark
            disc(f, 30, 30, 4, (255, 230, 150, 230))
            px(f, 30, 30, (150, 240, 220, 255))
            px(f, 12, 4, AMBER)
            px(f, 46, 2, AMBER)
        sheet.paste(add_outline(f), (i * 60, 0))
    save(sheet, "keeper_gardener.png")


def gen_gravity_well():
    # swirl texture for gravity wells, 96px, additive-friendly
    size = 96
    f = new(size, size)
    c = size / 2
    for arm in range(3):
        a0 = arm * (2 * math.pi / 3)
        for t in range(220):
            tt = t / 220.0
            r = 4 + tt * (c - 6)
            a = a0 + tt * 4.4
            x = c + math.cos(a) * r
            y = c + math.sin(a) * r * 0.9
            alpha = int(150 * (1 - tt))
            px(f, x, y, (150, 170, 230, alpha))
            if t % 3 == 0:
                px(f, x + 1, y, (90, 110, 190, alpha // 2))
    disc(f, c, c, 3, (20, 18, 40, 230))
    save(f, "gravity_well.png")


def gen_finale_props():
    # the Maw — a vast patient mouth, 128x64, mostly darkness and teeth
    f = new(128, 64)
    for x in range(4, 124):
        t = (x - 4) / 120.0
        depth = 26 * math.sin(math.pi * t)
        for y in range(int(30 - depth * 0.3), int(30 + depth)):
            px(f, x, y, (8, 5, 10, 255))
    for x in range(8, 122, 6):  # upper teeth
        t = (x - 4) / 120.0
        h = int(5 * math.sin(math.pi * t)) + 2
        for j in range(h):
            px(f, x, int(30 - 26 * math.sin(math.pi * t) * 0.3) + j + 2, (216, 210, 200, 255))
            px(f, x + 1, int(30 - 26 * math.sin(math.pi * t) * 0.3) + j + 2, (170, 160, 150, 255))
    for x in range(11, 119, 8):  # lower teeth
        t = (x - 4) / 120.0
        h = int(6 * math.sin(math.pi * t)) + 2
        base = int(30 + 26 * math.sin(math.pi * t))
        for j in range(h):
            px(f, x, base - j - 1, (216, 210, 200, 255))
    # a pair of distant eyes inside
    for ex in (52, 76):
        disc(f, ex, 34, 2, (255, 240, 200, 160))
        px(f, ex, 34, (150, 240, 220, 200))
    save(f, "maw.png")

    # the lamp anchor: rusted iron heart of the leash, 28x40
    f = new(28, 40)
    rect(f, 10, 6, 17, 30, (92, 82, 76, 255))
    rect(f, 10, 6, 11, 30, (120, 108, 100, 255))
    rect(f, 6, 28, 21, 34, (70, 62, 58, 255))
    rect(f, 4, 34, 23, 37, (54, 48, 46, 255))
    disc(f, 13.5, 8, 6, (92, 82, 76, 255))
    # the cold socket where the light goes
    rect(f, 11, 10, 16, 17, (26, 24, 30, 255))
    px(f, 13, 13, (80, 70, 60, 255))
    # rust veins
    rng = random.Random(3)
    for _ in range(14):
        px(f, rng.randrange(5, 23), rng.randrange(7, 37), (140, 76, 48, 255))
    save(add_outline(f), "lamp_anchor.png")

    # the finale gate: a dark iris in the floor, 96x24
    f = new(96, 24)
    for x in range(96):
        t = abs(x - 48) / 48.0
        h = int(9 * (1 - t * t))
        for y in range(12 - h, 12 + h):
            px(f, x, y, (10, 6, 14, 255))
    for a in range(0, 360, 24):  # iris ridges
        x = 48 + math.cos(math.radians(a)) * 40
        y = 12 + math.sin(math.radians(a)) * 8
        px(f, x, y, (60, 40, 70, 255))
    for x in range(20, 77, 14):
        px(f, x, 12, (150, 40, 44, 255))
    save(f, "finale_gate.png")

    # taut lightline segment for the finale chamber (bright, cuttable)
    f = new(6, 32)
    for y in range(32):
        px(f, 2, y, (255, 226, 160, 255))
        px(f, 3, y, (255, 244, 210, 255))
        if y % 5 == 0:
            px(f, 1, y, (255, 214, 130, 160))
            px(f, 4, y, (255, 214, 130, 160))
    save(f, "taut_line.png")


def main():
    gen_gardens_tiles()
    gen_throat_tiles()
    gen_parasite()
    gen_bloom()
    gen_warden()
    gen_keeper_gardener()
    gen_gravity_well()
    gen_finale_props()
    print("beta art done")


if __name__ == "__main__":
    main()
