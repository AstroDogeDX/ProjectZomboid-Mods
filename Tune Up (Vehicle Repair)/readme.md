# Tune Up (Vehicle Repair)

Repair vehicle parts **without spare parts or materials** in **Project Zomboid Build 42** — trade time (and a little sweat) instead.

An emergency, field-expedient spot repair. It *supplements* the vanilla material-based repair system rather than replacing it: a scavenged part is still faster and can take a part beyond your skill cap, but when all you have is time and a wrench, you can nurse a part back to life.

## Features

- **Tune Up on every part** — a new option sits alongside Repair / Install /
  Uninstall in the vehicle mechanics menu, on any part with a condition to
  restore (engines, brakes, suspension, tyres, bodywork, windows, batteries and
  more).
- **Skill-gated** — the most you can restore a part to is capped by your
  **Mechanics skill**: `skill × 10%` by default, so level 5 tops out at 50% and
  level 10 can fully restore. Below the minimum skill you can't tune up at all.
- **Time, not parts** — each 1% takes **in-game minutes**, starting around 10 and
  dropping as your skill rises (about `10 − skill × 0.9`), down to 1 minute per
  percent at level 10. Use the game's fast-forward time controls to pass the
  hours.
- **Interruptible** — work happens 1% at a time. Cancel, walk away, or run out of
  tools and it stops cleanly at a whole percent, keeping the progress you've
  earned.
- **Still hands-on** — you must be able to **reach** the part: stand at the
  correct side of the vehicle, and remove any part in front first (take the wheel
  off to get at the brakes), exactly like installs and uninstalls.
- **It costs you** — tuning up drains **fatigue** and **boredom**, so long
  sessions leave you needing rest. A skilled mechanic (Expert level and up) tires
  less and even finds the work *relaxing*, relieving boredom instead of causing
  it.
- **Requires a wrench** in your inventory (toggleable).

## Configuration

Everything is tunable under **Sandbox Options → Tune Up**, including:

| Option | Default | Effect |
| --- | --- | --- |
| Max repair % per Mechanics level | 10 | Skill × this = the highest % you can reach |
| Minimum Mechanics level | 1 | Below this, tune-ups are unavailable |
| Base minutes per 1% | 10 | Time to restore 1% before the skill bonus |
| Minutes saved per level | 0.9 | How much faster each Mechanics level makes you |
| Minimum minutes per 1% | 1 | Floor so high skill is never instant |
| Require a wrench | On | Whether a wrench is needed |
| Respect reach | On | Enforce standing at the part + removing covers |
| Grant Mechanics XP | On | Small XP per percent restored |
| Fatigue / Boredom per 1% | — | How tiring / dull the work is |
| Expert level & ease factor | 7 / 0.5 | When the work becomes easier and relaxing |

## Installing

Subscribe on the Steam Workshop, or install manually:

1. Copy `Contents\mods\TuneUp` from this repo into your mods folder so you end up
   with:
   ```
   %UserProfile%\Zomboid\mods\TuneUp\42\mod.info
   %UserProfile%\Zomboid\mods\TuneUp\common\media\lua\...
   ```
2. Enable **Tune Up (Vehicle Repair)** in the in-game **Mods** menu and start a
   save.

## Compatibility

- **Project Zomboid Build 42**, single-player.
- Integrates cleanly with the vanilla mechanics menu and coexists with other
  mechanics-menu mods.

## Feedback

Found a bug or have a balance suggestion? Please open an issue — this mod is meant
to be a fun, fair alternative to material repairs, and tuning the numbers is half
the fun.
