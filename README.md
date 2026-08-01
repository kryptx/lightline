# LIGHTLINE — alpha

A descent roguelite: you are a salvage diver tethered to a derelict lighthouse.
The tether is your oxygen, your light, and your way home — and everything you
pick up dims it. See `lightline-design-document.md` for the full design.

This build is the **alpha** from §10 of the design doc: Bands 1–3 (the
Shallows, the Middens, the Cathedral), the ability system, bestiary scan
passives, the first Keeper bosses gating suit tiers, and Marlowe's logs 1–15 —
on top of the vertical slice's banking/death rules and corpse run.

## Run it

Requires [Godot 4.x](https://godotengine.org) (`brew install --cask godot`).

```sh
godot --path .          # or open the folder in the Godot editor and press ▶
```

## Controls

| Action | Input |
|---|---|
| Swim | WASD / arrows (gamepad: left stick) |
| Dash-kick (costs light) | Shift (RT) |
| Reel in & surface | hold Space (A) |
| Drop heaviest item | G (D-pad down) |
| Scan creature / use valve | hold / press E (X) |
| Douse or relight the lamp | F (Y) |
| Abilities | Q / R (LB / RB) |

## The loop

- The **Lightline bar** is oxygen, visibility, and carry budget in one meter.
- Every pickup adds weight; weight drains the light faster. Relics are heavy.
- **Push or bank**: hold Space to reel home at any time — the HUD shows the
  estimated *return budget* in seconds of light. Surface to bank everything.
- **Die** and you lose the cargo but keep a small stipend; your cargo net
  stays where you fell for exactly one dive — go get it back.
- Spend salvage at the lighthouse on the five body stats (Lungs, Beam, Grip,
  Fins, Nerve). Relics buy **abilities** (Sonar Pulse, Flare, Anchor — three
  ranks each) and **suit tiers**.
- Each band's floor is held by a **Keeper** — 70% environment puzzle, 30%
  combat. Lure its charge into the arena's props (anemone beds, valve-fired
  vents, organ pipes), then dash the exposed weakpoint. Its pressure core
  rates your suit for the next band down.
- **Scanning** (hold E in your own light) permanently logs a creature and
  grants a passive. Knowledge — scans, logs, charts — survives death.
- **The Middens** (band 2): currents, pipe eels, and the Lanternjaw's false
  light. **The Cathedral** (band 3): darkness pockets your beam can't pierce
  and the blind, sound-hunting Choir — move like silt settles, or kill your
  light entirely (F).
- 15 of **Marlowe's logs** are scattered across the bands; each teaches a
  real technique, and together they say what she was actually doing down
  there. Replay them in the Archive tab.

Saves live in `~/Library/Application Support/Lightline/`.

## Development

- `tools/gen_art.py` + `tools/gen_art_alpha.py`, `tools/gen_sfx.py` +
  `tools/gen_sfx_alpha.py` — regenerate all pixel art / SFX (Python 3 + Pillow).
- `godot --headless --path . -s tests/test_logic.gd` — economy/progression
  logic tests.
- Debug flags (after `--`): `--fresh` (wipe save), `--autodive` (autopilot
  plays the loop), `--greedy` (autopilot never turns back), `--timescale=N`,
  `--shot=path.png --shot-delay=S` (dive screenshot), `--shot-hub=path.png`
  (hub screenshot), `--suit=N`, `--relics=N`, `--stat=lungs:10`,
  `--ability=sonar:3`, `--scan-all`, `--spawn-depth=M`, `--test-keeper=N`
  (autopilot fights Keeper N).
