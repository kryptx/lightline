#!/usr/bin/env python3
"""Alpha-stage art: Middens & Cathedral tiles, new fauna, Keepers, props."""
import math
import random

from gen_art import (new, px, rect, disc, add_outline, save,
                     OUTLINE, ROCK, ROCK_L, ROCK_D, AMBER, TEAL_GLOW)

# Middens palette (drowned town)
BRICK = (64, 72, 58, 255)
BRICK_L = (92, 102, 80, 255)
BRICK_D = (44, 50, 40, 255)
MOSS = (58, 110, 74, 255)
RUST = (122, 76, 48, 255)
PIPE = (74, 82, 92, 255)
PIPE_L = (108, 118, 128, 255)

# Cathedral palette (pale drowned stone)
BONE = (108, 104, 118, 255)
BONE_L = (146, 140, 152, 255)
BONE_D = (74, 70, 86, 255)
GLASS_TEAL = (78, 190, 176, 255)
GLASS_ROSE = (190, 110, 140, 255)

PALE = (196, 200, 208, 255)
PALE_D = (140, 144, 158, 255)


def gen_town_tiles():
    rng = random.Random(21)
    tiles = new(32 * 4, 32)
    for t in range(4):
        f = new(32, 32)
        rect(f, 0, 0, 31, 31, BRICK)
        # brick courses
        for by in range(0, 32, 6):
            for bx in range(0, 32, 8):
                off = 4 if (by // 6) % 2 else 0
                x0 = (bx + off) % 32
                rect(f, x0, by, min(31, x0 + 6), by, BRICK_D)
                px(f, x0, by + 3, BRICK_D)
        for _ in range(20):
            f.putpixel((rng.randrange(32), rng.randrange(32)),
                       BRICK_L if rng.random() < 0.5 else BRICK_D)
        if t == 1:  # mossy top edge
            rect(f, 0, 0, 31, 1, MOSS)
            for x in range(0, 32, 2):
                px(f, x + rng.randrange(2), 2 + rng.randrange(2), MOSS)
        if t == 2:  # boarded window
            rect(f, 8, 8, 23, 23, (26, 30, 38, 255))
            rect(f, 8, 8, 23, 9, BRICK_D)
            for i in range(3):
                rect(f, 9, 12 + i * 5, 22, 12 + i * 5, RUST)
        if t == 3:  # embedded pipe run
            rect(f, 0, 12, 31, 19, PIPE)
            rect(f, 0, 12, 31, 13, PIPE_L)
            rect(f, 0, 18, 31, 19, (48, 54, 62, 255))
            for x in (6, 22):
                rect(f, x, 11, x + 2, 20, PIPE_L)
            for _ in range(6):
                px(f, rng.randrange(32), rng.randrange(12, 20), RUST)
        tiles.paste(f, (t * 32, 0))
    save(tiles, "town_tiles.png")


def gen_cathedral_tiles():
    rng = random.Random(33)
    tiles = new(32 * 4, 32)
    for t in range(4):
        f = new(32, 32)
        rect(f, 0, 0, 31, 31, BONE)
        # large ashlar blocks
        for by in range(0, 32, 10):
            rect(f, 0, by, 31, by, BONE_D)
        for bx in range(0, 32, 16):
            for by in range(0, 32, 10):
                off = 8 if (by // 10) % 2 else 0
                px(f, (bx + off) % 32, by + 4, BONE_D)
                px(f, (bx + off) % 32, by + 5, BONE_D)
        for _ in range(16):
            f.putpixel((rng.randrange(32), rng.randrange(32)),
                       BONE_L if rng.random() < 0.5 else BONE_D)
        if t == 1:  # top-lit edge
            rect(f, 0, 0, 31, 1, BONE_L)
        if t == 2:  # carved relief
            disc(f, 16, 16, 7, BONE_D)
            disc(f, 16, 16, 5, BONE)
            for a in range(0, 360, 45):
                x = 16 + math.cos(math.radians(a)) * 6
                y = 16 + math.sin(math.radians(a)) * 6
                px(f, x, y, BONE_L)
            px(f, 16, 16, BONE_L)
        if t == 3:  # shattered mosaic, faint glow
            for _ in range(14):
                x, y = rng.randrange(2, 30), rng.randrange(2, 30)
                c = GLASS_TEAL if rng.random() < 0.6 else GLASS_ROSE
                px(f, x, y, c)
                if rng.random() < 0.5:
                    px(f, x + 1, y, tuple(v // 2 for v in c[:3]) + (255,))
        tiles.paste(f, (t * 32, 0))
    save(tiles, "cathedral_tiles.png")


def gen_lanternjaw():
    # 30x20, 4 frames: jaw fish, mostly darkness, glowing lure on a stalk
    sheet = new(30 * 4, 20)
    body = (38, 40, 54, 255)
    body_l = (58, 62, 80, 255)
    teeth = (216, 220, 228, 255)
    for i in range(4):
        f = new(30, 20)
        wob = math.sin(i / 4 * 2 * math.pi)
        # body
        for x in range(6, 22):
            r = 5 - abs(x - 14) * 0.45
            for dy in range(-int(r), int(r) + 1):
                px(f, x, 11 + dy, body)
        for x in range(9, 20):
            px(f, x, 8, body_l)
        # tail
        for j in range(4):
            px(f, 5 - j, 11 + int(wob * (j + 1) / 2), body)
            px(f, 5 - j, 12 + int(wob * (j + 1) / 2), body)
        # gaping jaw + teeth
        jaw_open = 2 + (1 if i % 2 else 0)
        for x in range(21, 26):
            px(f, x, 9 - (x - 21) // 2, body_l)
            px(f, x, 13 + jaw_open - (25 - x) // 2, body)
        for x in range(22, 26, 2):
            px(f, x, 10, teeth)
            px(f, x + 1, 12 + jaw_open, teeth)
        # dead little eye
        px(f, 19, 9, (120, 130, 150, 255))
        # lure stalk arcs forward over the head
        stalk = [(18, 6), (20, 4), (22, 3), (24, 3)]
        for sx, sy in stalk:
            px(f, sx, sy + (1 if wob > 0 else 0), body_l)
        # the false light
        glow = 0.7 + 0.3 * wob
        lx, ly = 26, 4 + (1 if wob > 0 else 0)
        disc(f, lx, ly, 2.6, (255, 214, 130, int(120 * glow)))
        disc(f, lx, ly, 1.4, (255, 236, 190, 255))
        sheet.paste(add_outline(f), (i * 30, 0))
    save(sheet, "lanternjaw.png")


def gen_eel():
    # 28x14, 3 frames: lurk (head at pipe), coil (telegraph), strike
    sheet = new(28 * 3, 14)
    body = (78, 96, 68, 255)
    body_l = (110, 132, 92, 255)
    for i, state in enumerate(("lurk", "coil", "strike")):
        f = new(28, 14)
        if state == "lurk":
            disc(f, 5, 7, 4, body)
            px(f, 7, 5, (230, 220, 140, 255))
            px(f, 8, 5, OUTLINE)
        elif state == "coil":
            disc(f, 6, 7, 5, body)
            disc(f, 4, 7, 3, body_l)
            px(f, 9, 4, (230, 220, 140, 255))
            px(f, 10, 4, OUTLINE)
            # open mouth sliver
            px(f, 10, 8, (220, 224, 230, 255))
        else:
            for x in range(2, 24):
                y = 7 + int(math.sin(x * 0.5) * 1.5)
                px(f, x, y, body)
                px(f, x, y + 1, body_l if x % 3 else body)
            # head + jaws at tip
            disc(f, 24, 7, 3, body)
            px(f, 26, 5, (220, 224, 230, 255))
            px(f, 26, 9, (220, 224, 230, 255))
            px(f, 24, 5, (230, 220, 140, 255))
        sheet.paste(add_outline(f), (i * 28, 0))
    save(sheet, "eel.png")


def gen_choir():
    # 20x30, 4 frames: pale robed blind singer, drifting; mouth open
    sheet = new(20 * 4, 30)
    for i in range(4):
        f = new(20, 30)
        sway = math.sin(i / 4 * 2 * math.pi)
        cx = 10 + int(sway)
        # robe: tapering body of pale skin
        for y in range(8, 27):
            w = 3 + (y - 8) * 0.28
            wobble = int(math.sin(y * 0.7 + i) * 1)
            for dx in range(-int(w), int(w) + 1):
                px(f, cx + dx + (wobble if y > 18 else 0), y, PALE if abs(dx) < w - 1 else PALE_D)
        # ragged hem
        for dx in range(-4, 5, 2):
            px(f, cx + dx, 27 + (i + dx) % 2, PALE_D)
        # head: eyeless, mouth open in song
        disc(f, cx, 5, 4, PALE)
        px(f, cx - 2, 4, PALE_D)  # sunken sockets
        px(f, cx + 2, 4, PALE_D)
        mouth_h = 2 + (1 if i % 2 else 0)
        rect(f, cx - 1, 7, cx + 1, 7 + mouth_h, (40, 30, 44, 255))
        # thin arms folded
        px(f, cx - 4, 12, PALE_D)
        px(f, cx + 4, 12, PALE_D)
        sheet.paste(add_outline(f, (30, 26, 40, 255)), (i * 20, 0))
    save(sheet, "choir.png")


def gen_keeper_dredge():
    # 64x40, 3 frames: armored crab — idle, charge, stunned (eye stalk out)
    sheet = new(64 * 3, 40)
    shell = (86, 58, 48, 255)
    shell_l = (124, 88, 66, 255)
    shell_d = (58, 38, 34, 255)
    for i, state in enumerate(("idle", "charge", "stunned")):
        f = new(64, 40)
        cy = 22
        # legs
        n_legs = 4
        for l in range(n_legs):
            lx = 12 + l * 12
            spread = 2 if state == "charge" else 0
            for s in range(6):
                px(f, lx - 3 - spread + s // 2, cy + 8 + s, shell_d)
                px(f, lx + 40 - lx // 2, cy, shell_d)  # harmless filler pixel inside body
        # massive shell dome
        for y in range(6, 30):
            w = 26 * math.sqrt(max(0.0, 1 - ((y - 18) / 13.0) ** 2))
            for dx in range(-int(w), int(w) + 1):
                c = shell
                if y < 12:
                    c = shell_l
                elif y > 25:
                    c = shell_d
                px(f, 32 + dx, y, c)
        # plate ridges
        for rx in (-16, -6, 4, 14):
            for y in range(9, 27):
                px(f, 32 + rx + (y % 2), y, shell_d)
        # barnacles
        rng = random.Random(5 + i)
        for _ in range(10):
            px(f, 32 + rng.randrange(-20, 20), rng.randrange(8, 26), (160, 150, 130, 255))
        # claws front
        claw_x = 56 if state != "charge" else 60
        disc(f, claw_x, 26, 5, shell_l)
        px(f, claw_x + 3, 23, shell_d)
        disc(f, 8, 27, 4, shell_l)
        if state == "stunned":
            # eye stalk out — the weakpoint
            for y in range(2, 10):
                px(f, 44, y, (196, 170, 120, 255))
            disc(f, 44, 2, 3, (255, 230, 150, 255))
            disc(f, 44, 2, 1.4, (150, 240, 220, 255))
            # little daze stars
            px(f, 20, 2, AMBER)
            px(f, 26, 0, AMBER)
        else:
            # eye tucked under lip
            px(f, 44, 27, (255, 230, 150, 255))
        sheet.paste(add_outline(f), (i * 64, 0))
    save(sheet, "keeper_dredge.png")


def gen_keeper_bell():
    # 56x60, 3 frames: hulk carrying the parish bell on its back
    sheet = new(56 * 3, 60)
    hide = (72, 80, 96, 255)
    hide_l = (100, 110, 128, 255)
    hide_d = (48, 54, 68, 255)
    bell = (150, 118, 54, 255)
    bell_l = (198, 164, 88, 255)
    for i, state in enumerate(("idle", "charge", "stunned")):
        f = new(56, 60)
        lean = 4 if state == "charge" else 0
        # the bell (on its hunched back)
        bx = 20 - lean
        for y in range(4, 24):
            w = 5 + (y - 4) * 0.55
            for dx in range(-int(w), int(w) + 1):
                px(f, bx + dx, y, bell if abs(dx) < w - 1 else (110, 84, 40, 255))
        rect(f, bx - 12, 24, bx + 12, 26, bell_l)
        px(f, bx, 27, (60, 46, 26, 255))  # clapper
        rect(f, bx - 3, 2, bx + 3, 4, hide_d)  # yoke strap
        # hunched body
        for y in range(20, 50):
            w = 12 * math.sqrt(max(0.0, 1 - ((y - 36) / 17.0) ** 2)) + 4
            for dx in range(-int(w), int(w) + 1):
                c = hide
                if dx < -int(w) + 3:
                    c = hide_d
                if y < 26:
                    c = hide_l
                px(f, 30 + dx + lean, y, c)
        # arms: knuckle-walking
        ax = 44 + lean * 2
        rect(f, ax, 34, ax + 4, 54, hide_l)
        rect(f, ax, 52, ax + 6, 55, hide_d)
        rect(f, 14 + lean, 40, 18 + lean, 54, hide_d)
        # head low, lantern-blind cowl
        hx = 44 + lean
        disc(f, hx, 28, 5, hide_l)
        if state == "stunned":
            px(f, hx + 2, 27, (255, 230, 150, 255))  # exposed eye
            px(f, hx + 3, 27, (150, 240, 220, 255))
            px(f, 10, 6, AMBER)
            px(f, 16, 2, AMBER)
        else:
            rect(f, hx + 1, 26, hx + 4, 29, hide_d)  # shut plate
        sheet.paste(add_outline(f), (i * 56, 0))
    save(sheet, "keeper_bell.png")


def gen_keeper_cantor():
    # 40x60, 3 frames: the tall blind singer of the deep nave
    sheet = new(40 * 3, 60)
    for i, state in enumerate(("idle", "charge", "stunned")):
        f = new(40, 60)
        cx = 20
        sway = 2 if state == "charge" else 0
        # towering robe
        for y in range(12, 56):
            w = 4 + (y - 12) * 0.3
            wobble = int(math.sin(y * 0.35 + i * 2) * 1.5) if state != "stunned" else 0
            for dx in range(-int(w), int(w) + 1):
                c = PALE if abs(dx) < w - 1.5 else PALE_D
                if y > 48:
                    c = PALE_D
                px(f, cx + dx + wobble + sway, y, c)
        # long arms spread when charging
        if state == "charge":
            for j in range(10):
                px(f, cx - 8 - j, 22 + j // 2, PALE_D)
                px(f, cx + 8 + j, 22 + j // 2, PALE_D)
        # head: tall, eyeless, huge open mouth
        disc(f, cx + sway, 8, 5, PALE)
        px(f, cx - 2 + sway, 6, PALE_D)
        px(f, cx + 2 + sway, 6, PALE_D)
        mouth = 4 if state != "stunned" else 1
        rect(f, cx - 1 + sway, 10, cx + 1 + sway, 10 + mouth, (40, 30, 44, 255))
        if state == "stunned":
            # the tally-lamp it swallowed shows through its throat
            disc(f, cx, 20, 3, (255, 230, 150, 220))
            px(f, cx, 20, (150, 240, 220, 255))
            px(f, 8, 4, AMBER)
            px(f, 30, 2, AMBER)
        # song ripple hint (baked): tiny rings by the mouth
        if state == "idle":
            for r in (7, 10):
                for a in range(-30, 31, 15):
                    x = cx + math.cos(math.radians(a)) * r + 6
                    y = 8 + math.sin(math.radians(a)) * r
                    px(f, x, y, (170, 200, 210, 90))
        sheet.paste(add_outline(f, (30, 26, 40, 255)), (i * 40, 0))
    save(sheet, "keeper_cantor.png")


def gen_props():
    # anemone (Keeper 1 stunner), 2 frames 22x18
    sheet = new(22 * 2, 18)
    for i in range(2):
        f = new(22, 18)
        rect(f, 7, 13, 14, 16, (110, 70, 90, 255))
        for t in range(9):
            x = 4 + t * 1.6
            h = 6 + ((t + i) % 3) * 2
            for y in range(int(h)):
                px(f, x, 13 - y, (216, 120, 190, 255) if y < h - 2 else (255, 190, 230, 255))
        sheet.paste(add_outline(f), (i * 22, 0))
    save(sheet, "anemone.png")

    # valve wheel, 2 frames 16x16
    sheet = new(16 * 2, 16)
    for i in range(2):
        f = new(16, 16)
        disc(f, 8, 8, 6, RUST)
        disc(f, 8, 8, 4.5, (150, 96, 60, 255))
        ang0 = 0 if i == 0 else 22
        for a in range(ang0, 360 + ang0, 45):
            x = 8 + math.cos(math.radians(a)) * 6
            y = 8 + math.sin(math.radians(a)) * 6
            px(f, x, y, (188, 128, 80, 255))
        disc(f, 8, 8, 1.5, (188, 128, 80, 255))
        sheet.paste(add_outline(f), (i * 16, 0))
    save(sheet, "valve.png")

    # organ pipes (Keeper 3 stunner), 26x48
    f = new(26, 48)
    for j, (w, h) in enumerate(((5, 40), (5, 46), (5, 34))):
        x0 = 2 + j * 8
        rect(f, x0, 47 - h, x0 + w, 47, (140, 136, 150, 255))
        rect(f, x0, 47 - h, x0 + 1, 47, (176, 172, 186, 255))
        rect(f, x0, 47 - h, x0 + w, 47 - h + 2, (96, 92, 108, 255))
        px(f, x0 + 2, 47 - h + 4, (30, 26, 40, 255))
    save(add_outline(f), "organ_pipe.png")

    # arena gate: stone slab 96x20
    f = new(96, 20)
    rect(f, 0, 4, 95, 15, BONE_D)
    rect(f, 0, 4, 95, 6, BONE)
    for x in range(0, 96, 12):
        rect(f, x, 4, x, 15, (52, 48, 62, 255))
    for x in range(6, 96, 24):
        disc(f, x, 10, 2, (150, 240, 220, 140))
    save(add_outline(f), "gate.png")

    # refill beacon, 2 frames 20x30
    sheet = new(20 * 2, 30)
    for i in range(2):
        f = new(20, 30)
        rect(f, 8, 12, 11, 28, (70, 76, 90, 255))
        rect(f, 6, 27, 13, 29, (52, 56, 68, 255))
        rect(f, 5, 4, 14, 12, (198, 152, 64, 255))
        glow = (255, 236, 190, 255) if i == 0 else (255, 214, 130, 255)
        rect(f, 7, 6, 12, 10, glow)
        px(f, 9, 2, (198, 152, 64, 255))
        sheet.paste(add_outline(f), (i * 20, 0))
    save(sheet, "beacon.png")

    # pressure core, 4 frames 18x18
    sheet = new(18 * 4, 18)
    for i in range(4):
        f = new(18, 18)
        g = 0.6 + 0.4 * math.sin(i / 4 * 2 * math.pi)
        disc(f, 9, 9, 7, (60, 70, 90, 255))
        disc(f, 9, 9, 5.5, (90, 105, 130, 255))
        disc(f, 9, 9, 3.5, (int(150 * g + 80), int(220 * g), int(200 * g), 255))
        px(f, 7, 7, (255, 255, 255, 230))
        for a in range(0, 360, 60):
            x = 9 + math.cos(math.radians(a + i * 15)) * 6.5
            y = 9 + math.sin(math.radians(a + i * 15)) * 6.5
            px(f, x, y, (150, 240, 220, 160))
        sheet.paste(add_outline(f), (i * 18, 0))
    save(sheet, "core.png")

    # Marlowe's log device, 2 frames 14x12
    sheet = new(14 * 2, 12)
    for i in range(2):
        f = new(14, 12)
        rect(f, 2, 3, 11, 10, (70, 76, 90, 255))
        rect(f, 2, 3, 11, 4, (108, 118, 128, 255))
        rect(f, 4, 6, 6, 8, (40, 44, 54, 255))
        rect(f, 8, 6, 10, 8, (40, 44, 54, 255))
        px(f, 12, 2, (150, 240, 220, 255) if i == 0 else (60, 90, 84, 255))
        sheet.paste(add_outline(f), (i * 14, 0))
    save(sheet, "log_device.png")

    # anchor deployable, 16x22
    f = new(16, 22)
    rect(f, 7, 2, 8, 15, (120, 130, 142, 255))
    disc(f, 7.5, 3, 2.5, (120, 130, 142, 255))
    disc(f, 7.5, 3, 1.2, (30, 34, 44, 255))
    for dx in (-5, 5):
        for j in range(5):
            px(f, 7 + dx + (j if dx < 0 else -j), 19 - j, (150, 160, 172, 255))
    rect(f, 5, 14, 10, 16, (150, 160, 172, 255))
    save(add_outline(f), "anchor_item.png")

    # flare, 3 frames 10x12
    sheet = new(10 * 3, 12)
    for i in range(3):
        f = new(10, 12)
        rect(f, 4, 5, 5, 10, (170, 60, 50, 255))
        flick = i % 3
        disc(f, 4.5, 3 - flick * 0.5, 2 + flick * 0.4, (255, 214, 130, 220))
        px(f, 4, 2 - flick, (255, 250, 230, 255))
        sheet.paste(f, (i * 10, 0))
    save(sheet, "flare.png")

    # darkness pocket blob (multiplied over scene), 160px radial
    size = 160
    f = new(size, size)
    c = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            if d < 1:
                a = int(235 * (1 - d) ** 0.7)
                f.putpixel((x, y), (4, 2, 8, a))
    save(f, "darkness.png")

    # ability icons 14x14
    f = new(14, 14)  # sonar: arcs
    for r in (2, 4.5, 6.5):
        for a in range(-50, 51, 12):
            x = 3 + math.cos(math.radians(a)) * r
            y = 7 + math.sin(math.radians(a)) * r
            px(f, x, y, TEAL_GLOW)
    px(f, 3, 7, (255, 255, 255, 255))
    save(add_outline(f), "icon_sonar.png")

    f = new(14, 14)  # flare
    rect(f, 6, 6, 7, 12, (170, 60, 50, 255))
    disc(f, 6.5, 4, 2.4, (255, 214, 130, 255))
    px(f, 6, 3, (255, 250, 230, 255))
    save(add_outline(f), "icon_flare.png")

    f = new(14, 14)  # anchor
    rect(f, 6, 2, 7, 10, (150, 160, 172, 255))
    disc(f, 6.5, 2.5, 1.8, (150, 160, 172, 255))
    for dx in (-4, 4):
        for j in range(3):
            px(f, 6 + dx + (j if dx < 0 else -j), 12 - j, (150, 160, 172, 255))
    save(add_outline(f), "icon_anchor.png")


def main():
    gen_town_tiles()
    gen_cathedral_tiles()
    gen_lanternjaw()
    gen_eel()
    gen_choir()
    gen_keeper_dredge()
    gen_keeper_bell()
    gen_keeper_cantor()
    gen_props()
    print("alpha art done")


if __name__ == "__main__":
    main()
