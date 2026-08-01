# LIGHTLINE — vertical slice

A descent roguelite: you are a salvage diver tethered to a derelict lighthouse.
The tether is your oxygen, your light, and your way home — and everything you
pick up dims it. See `lightline-design-document.md` for the full design.

This is the MVP vertical slice from §10 of the design doc: **Band 1 (The
Shallows) + the lighthouse hub with stats-only progression + banking/death
rules + the corpse run.**

## Run it

Requires [Godot 4.x](https://godotengine.org) (`brew install --cask godot`).

```sh
godot --path .          # or open the folder in the Godot editor and press ▶
```

## Controls

| Action | Input |
|---|---|
| Swim | WASD / arrows (gamepad: left stick) |
| Dash-kick (costs light) | Shift (RB) |
| Reel in & surface | hold Space (A) |
| Drop heaviest item | G (D-pad down) |

## The loop

- The **Lightline bar** is oxygen, visibility, and carry budget in one meter.
- Every pickup adds weight; weight drains the light faster. Relics are heavy.
- **Push or bank**: hold Space to reel home at any time — the HUD shows the
  estimated *return budget* in seconds of light. Surface to bank everything.
- **Die** and you lose the cargo but keep a small stipend; your cargo net
  stays where you fell for exactly one dive — go get it back.
- Spend salvage at the lighthouse on the five body stats (Lungs, Beam, Grip,
  Fins, Nerve). Relics are the rare banked-only currency for future gear.

Saves live in `~/Library/Application Support/Lightline/`.

## Development

- `tools/gen_art.py`, `tools/gen_sfx.py` — regenerate all pixel art / SFX
  (Python 3 + Pillow).
- `godot --headless --path . -s tests/test_logic.gd` — economy/progression
  logic tests.
- Debug flags (after `--`): `--fresh` (wipe save), `--autodive` (autopilot
  plays the loop), `--greedy` (autopilot never turns back), `--timescale=N`,
  `--shot=path.png --shot-delay=S` (dive screenshot), `--shot-hub=path.png`
  (hub screenshot).
