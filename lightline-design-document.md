# LIGHTLINE — Game Design Document

**Genre:** Descent roguelite with persistent progression
**Platform:** macOS (native Apple Silicon, Metal), keyboard/mouse + gamepad
**Target session length:** 10–20 minutes per dive
**Target total playtime:** 12–15 hours to credits, endless mode after
**Camera:** 2D side-on, hand-lit pixel art or flat-shaded vector

---

## 1. One-Paragraph Pitch

You are a salvage diver tethered to a derelict lighthouse that floats above an ocean trench no chart admits exists. Your tether is a glowing lifeline — it is your oxygen, your light, and your way home, and everything you pick up dims it. Each dive, you descend as far as your nerve and your gear allow, deciding at every moment whether to grab one more relic or turn back while the light still holds. Between dives you spend what you surfaced with on your body, your suit, and your lighthouse, opening deeper and stranger waters — and slowly piecing together what the diver before you found down there, and why she never came back up.

---

## 2. Design Pillars

1. **Every dive ends with a decision you made.** Death or safe return should always trace back to a choice the player owned ("I knew the light was low and I went for the chest anyway"), never to unreadable randomness.
2. **Progression on three clocks.** Something improves every *minute* (in-dive pickups), every *dive* (stats, gear, unlocks), and every *hour* (new depth bands, abilities, story). The player should never be more than ~10 minutes from a visible permanent gain.
3. **The light is the game.** One shared resource — the Lightline — drives tension, economy, and readability. If a mechanic doesn't touch the light, it needs a strong reason to exist.
4. **Curiosity pays.** Scanning creatures, reading logs, and poking into side caves grant permanent mechanical benefits, not just flavor. Exploration *is* a progression system.

---

## 3. The Core Loop

### 3.1 Moment-to-moment (seconds)

Swim, steer with momentum-based movement (floaty but precise — think *Dave the Diver* meets *Downwell*). The screen is dark beyond your light radius. You:

- **Collect** salvage, air pockets, and relics.
- **Avoid or manage** fauna — most creatures aren't fought, they're *handled*: lured with flares, dodged, outrun, or scanned from safety. Combat exists but is a last resort with a knife and later a spear-sling; it costs light.
- **Read the light.** The Lightline meter is drawn as your actual tether glow. Full = bright ring, near-empty = a sputtering halo. Oxygen, visibility, and carry weight all draw from it.

The central micro-tension: **picking things up dims your light.** A heavy relic might cut your remaining dive time by a third. Every pickup is a bet.

### 3.2 The dive (10–20 minutes)

1. **Kit up** at the lighthouse — choose loadout (2 ability slots, 1 consumable set, suit config).
2. **Descend** through procedurally assembled chunks within hand-authored depth bands.
3. **Push or bank.** At any moment the player can pull the tether and surface, keeping everything. Descending further multiplies rewards but the return trip costs light too — the deeper you are, the more expensive turning back becomes. This is the loop's beating heart.
4. **Surface (or don't).** Survive: bank everything. Die: lose the cargo net, keep all *knowledge* (scans, logs, map reveals) and a small guaranteed stipend of salvage — so even a disastrous dive advances something.
5. **Corpse-run hook:** your dropped cargo net stays where you died for exactly one dive, marked on the map. Retrieving it is a tense, focused objective that gives failed runs a purpose and pulls the player straight into "one more dive."

### 3.3 The meta loop (hours)

Spend at the lighthouse across four progression tracks (Section 4), unlock the next **depth band** (biome) via suit pressure ratings, and receive the next **story beat** the first time you touch a new maximum depth. The credits roll after the fifth band's finale; an endless "Abyssal Tide" mode with weekly modifiers continues beyond.

---

## 4. Progression Systems (the reason to come back)

Four interlocking tracks, deliberately on different cadences so *something* is always about to pop.

### 4.1 Body — stats (every 1–2 dives)

Spent with **Salvage**, the common currency. Five stats, each with 10 visible ranks and a named capstone perk at ranks 5 and 10:

| Stat | Effect | Rank-10 capstone |
|---|---|---|
| **Lungs** | Max Lightline (dive length) | *Second Wind* — once per dive, refill 25% when you'd hit zero |
| **Beam** | Light radius & pickup detection range | *Daybreak* — briefly reveal the whole screen on descent into a new chunk |
| **Grip** | Carry weight before light-drain penalty | *Deep Pockets* — first relic each dive weighs nothing |
| **Fins** | Swim speed & current resistance | *Slipstream* — dashing through fish schools costs no light |
| **Nerve** | Slows panic (screen-narrowing when creatures stalk you) | *Cold Blood* — predators must be 40% closer before triggering panic |

Early ranks are cheap (one decent dive each); costs curve so the last ranks land around hour 10–12. Stats are respec-able for a small fee to encourage experimentation.

### 4.2 Suit & tools — gear (every 3–5 dives)

Spent with **Relics**, the rare banked-only currency — this is what dying actually costs you.

- **Suit tiers I–V** gate the five depth bands via pressure rating. Each tier is a major purchase and the game's chapter structure.
- **Abilities** (equip 2): Dash-kick, Sonar Pulse (pings pickups/threats through walls), Flare (light + lure), Anchor (place a mid-dive checkpoint/stash), Grapnel, Decoy Lantern, Ink Veil. Each ability has 3 upgrade ranks that change how it plays, not just numbers (e.g., Sonar rank 3 marks fragile walls).
- **Consumable crafting:** glowjars, patch kits, bait, one-use "riser balloons" that float a heavy relic to the surface without you.

### 4.3 Knowledge — the curiosity engine (constantly)

- **Bestiary:** scanning a creature (hold-to-scan from within light range — risky by design) permanently reveals its behavior *and* grants a passive: scan the Lanternjaw and its lure light no longer fools you; fully scan a species and it appears on your minimap.
- **Charts:** each depth band's layout chunks get permanently annotated as you see them; shortcut doors (*Hollow Knight*-style one-way drops that open into two-way passages) persist forever, physically shortening future dives.
- **Logs:** 40 scattered recordings from Marlowe, the previous diver. Finding them is the narrative delivery system (Section 6) and each also teaches a real technique or secret ("she mentions killing her light near the Choir — try it").

Knowledge survives death completely. This is the system that makes even a 90-second failed dive feel like progress.

### 4.4 The Lighthouse — hub progression (every 1–2 hours)

Rebuilding the lighthouse is the long-arc visual scoreboard: repair the workshop (unlocks crafting), the archive (bestiary UI + log playback), the great lamp (starting-depth elevator — skip cleared bands), the radio (endless-mode modifiers), the garden (small per-dive buff you choose while "tending" — a calm ritual between dives). Watching the ruin become a home is the emotional progress bar.

---

## 5. World Structure & 10-Hour Pacing

Five hand-themed depth bands; within each, dives assemble from ~30 authored chunks with seeded variation, so layouts stay fresh but learnable.

| Band | Theme & new mechanic | New threats | Hours (cumulative) |
|---|---|---|---|
| **1. The Shallows** | Kelp, wrecks; tutorializes light economy | Passive fish, urchin hazards | 0–1.5 |
| **2. The Middens** | Sunken town; currents that push/pull | Lanternjaw (fake-light predator), eels in pipes | 1.5–3.5 |
| **3. The Cathedral** | Drowned cathedral; **darkness pockets** your beam can't pierce — sound cues matter | The Choir (blind, sound-hunting) — forces slow play & light-off stealth | 3.5–6 |
| **4. The Gardens** | Bioluminescent reef; **light parasites** that eat your Lightline | Swarm behaviors; environmental puzzles using flares | 6–8.5 |
| **5. The Throat** | The trench proper; gravity wells, crushing timers | The Warden (stalker boss present in every Band-5 dive) | 8.5–11 |
| **Finale** | The floor of the Throat: fixed, authored final dive with a genuine choice ending | — | 11–12 |
| **Abyssal Tide** | Endless mode, weekly modifiers, leaderboard depth | remix of all | 12+ |

Each band ends with a **Keeper** — a set-piece boss that is 70% environment puzzle, 30% combat, and drops the pressure core needed for the next suit tier. Mid-band, one guaranteed **Vault** dive (a fixed challenge room) offers a large relic payout for players who want a skill test.

**Why this holds for 10+ hours:** each band introduces one mechanic that recontextualizes the light (currents move it, darkness defeats it, parasites eat it, gravity bends it), so the core verb keeps changing meaning; meanwhile the four progression tracks guarantee that even a routine dive advances two or three visible meters.

---

## 6. Narrative (the pull between sessions)

Minimal, environmental, and rationed. Marlowe — the lighthouse's previous keeper — descended years ago. Her logs are found out of order; the archive lets you replay and sequence them. The mystery has three layers revealed roughly at hours 3, 7, and 11:

1. She wasn't salvaging. She was *feeding* something.
2. The lighthouse's lamp isn't for ships. It's a leash.
3. Your Lightline runs to the lamp — and the thing in the Throat can see it too.

The final dive offers a choice (relight the lamp / cut the line / go down with it) with three short endings. No dialogue trees, no cutscenes over 60 seconds. Story is a reward, never a gate.

---

## 7. Difficulty, Fairness & Retention Guardrails

- **Assist options:** Lightline drain −25/−50%, panic off, aim assist. No content locked behind difficulty.
- **Pity systems:** three deaths in one band without banking a relic quietly raises relic spawn rates until the next bank; the corpse-run net always contains at least its original value.
- **No FOMO pressure:** weekly Abyssal Tide modifiers rotate but past cosmetic rewards return on a cycle.
- **Session bookends:** the game explicitly celebrates surfacing — banking animation, ledger of what you gained, and a one-line "next time" hint (nearest unpurchased upgrade, undiscovered log direction). Every session ends by planting the seed of the next one.
- **Readable death:** kill-screen replays the last 5 seconds with the fatal choice highlighted ("cargo weight exceeded return budget at 340m").

---

## 8. Controls (macOS)

| Action | Keyboard/Mouse | Gamepad |
|---|---|---|
| Swim | WASD (mouse steers gaze/beam) | Left stick (right stick beam) |
| Dash-kick | Shift | RT |
| Interact / Scan (hold) | E | X |
| Ability 1 / 2 | Q / R | LB / RB |
| Drop heaviest item | G | D-pad down |
| Pull tether (begin surfacing) | Hold Space | Hold A |

Full remapping; native support for DualSense/Xbox controllers over Bluetooth (standard on macOS).

---

## 9. Technical Plan (macOS-first)

- **Engine:** Godot 4.x — free, lightweight, first-class macOS export with Metal via the Forward+ renderer; ships a universal binary (Apple Silicon + Intel). Unity is the fallback if console ports become a goal.
- **Performance target:** 120 fps on M1 MacBook Air at native resolution; the 2D art style makes this trivial and keeps the download under 500 MB.
- **Platform niceties:** proper .app bundle, notarized & hardened runtime (required for Gatekeeper), Cmd+Q/Cmd+M respected, windowed and fullscreen (borderless), save files in `~/Library/Application Support/Lightline/`, iCloud Drive–friendly single-folder saves, Steam Cloud if shipping via Steam.
- **Audio is a mechanic** (Band 3 depends on it): spatial 2D audio, with a visual sound-ring accessibility mode for deaf/HoH players.

---

## 10. Scope & Build Order (MVP-first)

**Vertical slice (prove the loop):** Band 1 + lighthouse with stats-only progression + banking/death rules + corpse run. If "push or bank" isn't tense here, nothing else matters — iterate until it is.

**Alpha:** Bands 1–3, abilities, bestiary passives, first Keeper bosses, logs 1–15.
**Beta:** Bands 4–5, finale, endings, assist options, full audio pass.
**Post-launch:** Abyssal Tide weekly modifiers, leaderboards, one free "Sixth Band" tease.

**Cut list if scope bites** (in order): endless-mode modifiers → Band 4's parasite mechanic (fold swarms into Band 5) → third ending → ability upgrade rank 3s. Never cut: the corpse run, the banking decision, knowledge-survives-death.

---

## 11. Why a Player Comes Back (summary)

- **Minute scale:** every pickup is a bet against the light — constant micro-decisions.
- **Dive scale:** push-or-bank plus the corpse run make every ending (good or bad) generate the next dive's goal.
- **Session scale:** four progression tracks on staggered cadences mean the "next unlock" is always visible on the kit-up screen.
- **Arc scale:** each depth band changes what light *means*, suit tiers structure chapters, and a rationed three-layer mystery pulls toward the floor of the Throat.
- **After credits:** endless mode turns mastery into depth-chasing.

The player isn't grinding numbers; they're funding an expedition, learning an ecosystem, rebuilding a home, and solving a disappearance — four reasons to descend, one light to spend.
