#!/usr/bin/env python3
"""Synthesize the game's sound effects as 16-bit mono WAVs (22050 Hz)."""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
SR = 22050
rng = random.Random(4)


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples
        )
        w.writeframes(frames)
    print("wrote sfx/" + name, len(samples) / SR, "s")


def env(i, n, attack=0.01, release=0.4):
    t = i / n
    a = min(1.0, (i / SR) / max(attack, 1e-5))
    r = min(1.0, (1 - t) / max(release, 1e-5))
    return a * min(1.0, r)


def tone(dur, f0, f1=None, vol=0.6, release=0.5, harm=0.3):
    n = int(SR * dur)
    f1 = f1 if f1 is not None else f0
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) + harm * math.sin(phase * 2)
        out.append(s * vol * env(i, n, release=release))
    return out


def noise(dur, vol=0.5, release=0.6, lp=0.2):
    n = int(SR * dur)
    out = []
    last = 0.0
    for i in range(n):
        last += lp * (rng.uniform(-1, 1) - last)
        out.append(last * vol * env(i, n, release=release) * 3)
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return out


def cat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def delay(samples, sec):
    return [0.0] * int(SR * sec) + samples


write = write_wav

write("pickup.wav", tone(0.09, 640, 920, vol=0.4, release=0.5))
write("relic.wav", mix(tone(0.5, 523, vol=0.3, release=0.9),
                       delay(tone(0.45, 784, vol=0.25, release=0.9), 0.08),
                       delay(tone(0.4, 1047, vol=0.18, release=0.9), 0.16)))
write("hurt.wav", mix(noise(0.18, vol=0.5, lp=0.45), tone(0.18, 180, 90, vol=0.4)))
write("air.wav", cat(tone(0.06, 500, 700, vol=0.3), tone(0.06, 650, 900, vol=0.3),
                     tone(0.10, 800, 1100, vol=0.35)))
write("bank.wav", cat(tone(0.14, 440, vol=0.35), tone(0.14, 554, vol=0.35),
                      tone(0.30, 659, vol=0.4, release=0.8)))
write("death.wav", mix(tone(1.0, 220, 55, vol=0.45, release=0.9),
                       noise(1.0, vol=0.15, lp=0.1)))
write("warn.wav", tone(0.05, 880, vol=0.25, release=0.4))
write("ui.wav", tone(0.04, 520, 480, vol=0.25, release=0.4))
write("dash.wav", noise(0.22, vol=0.35, lp=0.6, release=0.8))
write("splash.wav", noise(0.5, vol=0.45, lp=0.35, release=0.9))
write("drop.wav", tone(0.12, 300, 180, vol=0.35, release=0.6))
write("upgrade.wav", cat(tone(0.09, 392, vol=0.3), tone(0.16, 587, vol=0.35, release=0.7)))

# underwater ambience loop (4 s): low drone + slow wobble
n = int(SR * 4)
amb = []
for i in range(n):
    t = i / SR
    # whole cycles per 4 s loop only (82.4 Hz used to click at every seam)
    s = 0.16 * math.sin(2 * math.pi * 55 * t) + 0.10 * math.sin(2 * math.pi * 82.5 * t + 0.6)
    s += 0.05 * math.sin(2 * math.pi * 110 * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 0.25 * t))
    amb.append(s)
write("ambience.wav", amb)
