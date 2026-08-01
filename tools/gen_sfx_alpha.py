#!/usr/bin/env python3
"""Alpha-stage SFX: abilities, scanning, keepers, band 2/3 fauna."""
import math
import random

from gen_sfx import SR, write_wav, env, tone, noise, mix, cat, delay

rng = random.Random(9)

# sonar: clean descending ping with a soft echo
ping = tone(0.35, 1400, 900, vol=0.35, release=0.85, harm=0.1)
write_wav("sonar.wav", mix(ping, delay([s * 0.4 for s in ping], 0.22)))

# flare ignite: strike + fizz
write_wav("flare.wav", cat(noise(0.05, vol=0.5, lp=0.8),
                           noise(0.5, vol=0.22, lp=0.55, release=0.95)))

# scanning progress tick + completion chime
write_wav("scan_tick.wav", tone(0.04, 980, vol=0.15, release=0.4))
write_wav("scan_done.wav", mix(tone(0.4, 740, vol=0.3, release=0.9),
                               delay(tone(0.35, 1108, vol=0.22, release=0.9), 0.09)))

# keeper roar: layered low growl
def growl(dur, f0, f1):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) + 0.6 * math.sin(phase * 0.5) + 0.3 * math.sin(phase * 3.03)
        s += rng.uniform(-0.4, 0.4) * (1 - t)
        out.append(s * 0.35 * env(i, n, attack=0.02, release=0.5))
    return out

write_wav("roar.wav", growl(0.9, 110, 60))
write_wav("stun.wav", mix(tone(0.5, 220, 180, vol=0.4, release=0.9),
                          noise(0.12, vol=0.4, lp=0.7)))

# the parish bell
n = int(SR * 1.6)
bell = []
for i in range(n):
    t = i / SR
    s = (0.5 * math.sin(2 * math.pi * 164 * t) +
         0.3 * math.sin(2 * math.pi * 246.9 * t) +
         0.18 * math.sin(2 * math.pi * 329.6 * t) +
         0.12 * math.sin(2 * math.pi * 411.1 * t))
    bell.append(s * 0.5 * math.exp(-2.2 * t) * min(1.0, i / 40.0))
write_wav("bell.wav", bell)

# pressure core pickup: triumphant rising triad
write_wav("core.wav", cat(tone(0.16, 392, vol=0.3), tone(0.16, 494, vol=0.32),
                          tone(0.16, 587, vol=0.34), tone(0.5, 784, vol=0.4, release=0.85)))

# log pickup: radio click + warm chime
write_wav("log.wav", cat(noise(0.03, vol=0.35, lp=0.9),
                         mix(tone(0.5, 587, vol=0.22, release=0.9),
                             delay(tone(0.4, 880, vol=0.15, release=0.9), 0.1))))

# hull strain creak
n = int(SR * 0.9)
creak = []
f = 90.0
phase = 0.0
for i in range(n):
    t = i / n
    f += rng.uniform(-6, 8) * (0.5 + t)
    phase += 2 * math.pi * f / SR
    s = math.sin(phase) * (0.6 + 0.4 * math.sin(2 * math.pi * 13 * t))
    creak.append(s * 0.3 * env(i, n, attack=0.05, release=0.4))
write_wav("creak.wav", creak)

# eel snap
write_wav("eel.wav", cat(tone(0.05, 300, 500, vol=0.25),
                         mix(noise(0.09, vol=0.5, lp=0.8), tone(0.09, 180, 90, vol=0.35))))

# choir: eerie vocal swell (minor second shimmer)
n = int(SR * 1.4)
choir = []
for i in range(n):
    t = i / SR
    vib = 1 + 0.006 * math.sin(2 * math.pi * 5.2 * t)
    s = (0.4 * math.sin(2 * math.pi * 233 * t * vib) +
         0.3 * math.sin(2 * math.pi * 246.9 * t) +
         0.2 * math.sin(2 * math.pi * 466 * t * vib) +
         0.12 * math.sin(2 * math.pi * 349 * t))
    choir.append(s * 0.3 * env(i, n, attack=0.35, release=0.45))
write_wav("choir.wav", choir)

# stone gate grinding open
n = int(SR * 1.1)
gate = []
last = 0.0
for i in range(n):
    t = i / n
    last += 0.25 * (rng.uniform(-1, 1) - last)
    s = last * 2.2 + 0.25 * math.sin(2 * math.pi * (55 + 20 * t) * i / SR)
    gate.append(s * 0.4 * env(i, n, attack=0.08, release=0.25))
write_wav("gate.wav", gate)

# douse / relight the lamp
write_wav("douse.wav", cat(noise(0.12, vol=0.3, lp=0.5), tone(0.15, 440, 180, vol=0.15)))
write_wav("relight.wav", cat(noise(0.05, vol=0.25, lp=0.8), tone(0.2, 300, 640, vol=0.2)))

# anchor deposit clunk
write_wav("deposit.wav", mix(tone(0.2, 140, 90, vol=0.45, release=0.7),
                             delay(tone(0.15, 520, vol=0.15, release=0.6), 0.06)))
