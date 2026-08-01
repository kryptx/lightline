#!/usr/bin/env python3
"""Beta audio pass: per-band music loops, hub & finale themes, ending stings,
and the new hazard SFX. All loops are built from whole-number cycle counts so
they seam cleanly."""
import math
import random

from gen_sfx import SR, write_wav, env, tone, noise, mix, cat, delay

rng = random.Random(17)
TAU = 2 * math.pi


def hz(cycles_per_loop, loop_s):
    """Snap a frequency to a whole number of cycles per loop so it seams."""
    return cycles_per_loop / loop_s


def build_loop(loop_s, voices, vol=1.0):
    """voices: [(freq, amp, lfo_rate_cycles, lfo_depth)] — all lfo rates are
    whole cycles per loop, so the loop is mathematically seamless."""
    n = int(SR * loop_s)
    out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for f, amp, lfo_c, lfo_d in voices:
            lfo = 1.0 + lfo_d * math.sin(TAU * lfo_c * t / loop_s)
            s += amp * lfo * math.sin(TAU * f * t)
        out.append(s * vol)
    return out


LOOP = 8.0

# Band 1 — the Shallows: soft major-ish calm (existing ambience.wav stays as
# a fallback; this is the proper music bed)
write_wav("music_band1.wav", build_loop(LOOP, [
    (hz(440, LOOP), 0.10, 1, 0.35),   # 55 Hz
    (hz(660, LOOP), 0.07, 2, 0.3),    # 82.5
    (hz(1320, LOOP), 0.05, 3, 0.4),   # 165
    (hz(1980, LOOP), 0.025, 5, 0.5),  # 247.5
], 0.9))

# Band 2 — the Middens: minor drift, a little motion in the water
write_wav("music_band2.wav", build_loop(LOOP, [
    (hz(392, LOOP), 0.10, 1, 0.3),    # 49 Hz
    (hz(588, LOOP), 0.06, 2, 0.35),
    (hz(932, LOOP), 0.05, 3, 0.4),    # minor third color
    (hz(1568, LOOP), 0.02, 7, 0.6),
], 0.9))

# Band 3 — the Cathedral: hollow fifths, choir shimmer
write_wav("music_band3.wav", build_loop(LOOP, [
    (hz(349, LOOP), 0.10, 1, 0.25),
    (hz(524, LOOP), 0.07, 2, 0.3),
    (hz(1866, LOOP), 0.030, 3, 0.55),  # 233 shimmer
    (hz(1976, LOOP), 0.022, 5, 0.55),  # 247 beats against it
], 0.9))

# Band 4 — the Gardens: luminous, faintly pretty, faintly wrong
write_wav("music_band4.wav", build_loop(LOOP, [
    (hz(330, LOOP), 0.09, 1, 0.3),
    (hz(494, LOOP), 0.06, 2, 0.35),
    (hz(830, LOOP), 0.05, 3, 0.45),
    (hz(2490, LOOP), 0.020, 9, 0.65),  # glittering top
    (hz(2794, LOOP), 0.014, 11, 0.65),
], 0.9))

# Band 5 — the Throat: sub-bass dread, slow pulse
write_wav("music_band5.wav", build_loop(LOOP, [
    (hz(233, LOOP), 0.13, 1, 0.4),    # ~29 Hz felt more than heard
    (hz(311, LOOP), 0.09, 2, 0.5),
    (hz(466, LOOP), 0.05, 2, 0.5),
    (hz(699, LOOP), 0.03, 4, 0.7),    # tritone unease
], 1.0))

# Hub — the lighthouse: warm, slow, above the waterline
write_wav("music_hub.wav", build_loop(LOOP, [
    (hz(524, LOOP), 0.08, 1, 0.3),    # 65.5
    (hz(786, LOOP), 0.06, 1, 0.25),
    (hz(1048, LOOP), 0.05, 2, 0.3),
    (hz(1572, LOOP), 0.03, 3, 0.35),
    (hz(2620, LOOP), 0.015, 2, 0.4),
], 0.9))

# Finale — the floor of the Throat: near-silence with a vast slow breath
write_wav("music_finale.wav", build_loop(12.0, [
    (hz(180, 12.0), 0.12, 1, 0.6),    # 15 Hz breath (subsonic wobble)
    (hz(276, 12.0), 0.08, 1, 0.4),    # 23 Hz
    (hz(553, 12.0), 0.04, 2, 0.5),
    (hz(1246, 12.0), 0.015, 3, 0.7),
], 1.0))


# ---------- ending stings ----------
def sting_relight():
    # the lamp takes the light back: warm rising resolution
    return cat(tone(0.5, 262, vol=0.25, release=0.9),
               mix(tone(0.6, 330, vol=0.22, release=0.9),
                   delay(tone(0.5, 392, vol=0.2, release=0.9), 0.12)),
               mix(tone(1.6, 524, vol=0.3, release=0.95),
                   delay(tone(1.4, 660, vol=0.18, release=0.95), 0.1),
                   delay(tone(1.2, 786, vol=0.12, release=0.95), 0.2)))

def sting_cut():
    # the line parts: one bright snap, then everything settles colder
    snap = mix(noise(0.06, vol=0.6, lp=0.9), tone(0.06, 1200, 300, vol=0.4))
    return cat(snap, [0.0] * int(SR * 0.3),
               mix(tone(2.0, 220, vol=0.22, release=0.95),
                   delay(tone(1.8, 165, vol=0.18, release=0.95), 0.3),
                   delay(tone(1.6, 110, vol=0.15, release=0.95), 0.6)))

def sting_descend():
    # going down with it: a swallowing glissando into sub-bass
    n = int(SR * 3.0)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = 300 * math.pow(0.08, t)  # 300 Hz -> 24 Hz
        phase += TAU * f / SR
        s = math.sin(phase) + 0.4 * math.sin(phase * 0.5)
        out.append(s * 0.4 * env(i, n, attack=0.05, release=0.35))
    return out

write_wav("ending_relight.wav", sting_relight())
write_wav("ending_cut.wav", sting_cut())
write_wav("ending_descend.wav", sting_descend())

# ---------- hazard SFX ----------
# parasite attaches: tiny wet click + sip
write_wav("parasite_on.wav", cat(noise(0.03, vol=0.3, lp=0.8),
                                 tone(0.16, 1400, 900, vol=0.12, release=0.7)))
# parasites shaken off: flutter of cilia
write_wav("parasite_off.wav", mix(noise(0.2, vol=0.25, lp=0.7, release=0.8),
                                  tone(0.2, 700, 1100, vol=0.1)))
# crush cycle: groan of stone, then the clench
write_wav("crush_warn.wav", mix(tone(1.0, 70, 55, vol=0.3, release=0.7),
                                noise(1.0, vol=0.12, lp=0.15)))
write_wav("crush_hit.wav", mix(noise(0.3, vol=0.6, lp=0.5),
                               tone(0.35, 120, 40, vol=0.5, release=0.8)))
# gravity well hum (2 s seamless loop)
write_wav("well_hum.wav", build_loop(2.0, [
    (hz(72, 2.0), 0.20, 1, 0.3),   # 36 Hz
    (hz(108, 2.0), 0.10, 2, 0.4),
    (hz(216, 2.0), 0.05, 3, 0.5),
], 1.0))
# the Warden: a heartbeat that isn't yours, and its strike
beat = mix(tone(0.09, 55, 40, vol=0.7, release=0.5),
           tone(0.06, 80, 60, vol=0.3, release=0.5))
write_wav("warden_heart.wav", cat(beat, [0.0] * int(SR * 0.18), beat,
                                  [0.0] * int(SR * 0.9)))
write_wav("warden_hit.wav", mix(noise(0.5, vol=0.6, lp=0.4),
                                tone(0.6, 90, 30, vol=0.6, release=0.7),
                                delay(tone(0.3, 1800, 600, vol=0.2), 0.05)))
# bloom snapping open
write_wav("bloom.wav", cat(tone(0.05, 200, 500, vol=0.3),
                           mix(noise(0.12, vol=0.3, lp=0.7),
                               tone(0.14, 640, 880, vol=0.2, release=0.7))))
# credits pad (10 s, gentle)
write_wav("music_credits.wav", build_loop(10.0, [
    (hz(655, 10.0), 0.08, 1, 0.3),
    (hz(983, 10.0), 0.06, 1, 0.25),
    (hz(1310, 10.0), 0.045, 2, 0.35),
    (hz(1966, 10.0), 0.025, 3, 0.4),
], 0.9))
