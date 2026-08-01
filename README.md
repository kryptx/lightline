# LIGHTLINE — beta

A descent roguelite: you are a salvage diver tethered to a derelict lighthouse.
The tether is your oxygen, your light, and your way home — and everything you
pick up dims it. See `lightline-design-document.md` for the full design.

This build is the **beta** from §10 of the design doc: all five bands (the
Shallows, the Middens, the Cathedral, the Gardens, the Throat), four Keeper
bosses gating five suit tiers, the Warden stalking every Throat dive, the
authored finale with its three endings, assist options, and a full audio pass
(per-band music, hub and finale themes, ending stings) — on top of the
abilities, bestiary passives, 24 of Marlowe's logs, banking/death rules, and
the corpse run.

## Run it

Requires [Godot 4.x](https://godotengine.org) (`brew install --cask godot`).

```sh
godot --headless --import --path .   # first run only: import assets (also after pulling new assets)
godot --path .                       # or open the folder in the Godot editor and press ▶
```

The import step populates the untracked `.godot/` cache; without it a fresh
checkout will fail to load textures and sounds. Opening the project in the
Godot editor does the same thing automatically.

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
  light entirely (F). **The Gardens** (band 4): wick lice that drink the line
  (dash them off, or burn a flare) and carnivorous blooms that open for
  flares. **The Throat** (band 5): gravity wells, crushing timers — and the
  Warden, which cannot be fought, only evaded, and which sees your lit lamp
  from very far away.
- 24 of **Marlowe's logs** are scattered across the bands; each teaches a
  real technique, and together they say what she was actually doing down
  there. Replay them in the Archive tab.
- With Suit V fitted, an iris waits in the floor of the Throat. Below it: a
  fixed, authored final descent and a **genuine choice** with three endings.
  The hub remembers which one you made — and the floor will let you choose
  differently.
- **Assists** (Settings tab): Lightline drain −25/−50%, panic off, gentle
  fauna. No content is locked behind difficulty. The Choir's song always
  draws visible rings — sound is never the only cue.

Saves live in `~/Library/Application Support/Lightline/`.

## Development

- `tools/gen_art*.py`, `tools/gen_sfx*.py` — regenerate all pixel art, SFX,
  and music loops (Python 3 + Pillow).
- `godot --headless --path . -s tests/test_logic.gd` — economy/progression
  logic tests.
- Debug flags (after `--`): `--fresh` (wipe save), `--autodive` (autopilot
  plays the loop), `--greedy` (autopilot never turns back), `--timescale=N`,
  `--shot=path.png --shot-delay=S` (dive screenshot), `--shot-hub=path.png`
  (hub screenshot), `--suit=N`, `--relics=N`, `--stat=lungs:10`,
  `--ability=sonar:3`, `--scan-all`, `--spawn-depth=M`, `--test-keeper=N`
  (autopilot fights Keeper N), `--test-finale=relight|cut|descend` (autopilot
  plays the finale to that ending).
