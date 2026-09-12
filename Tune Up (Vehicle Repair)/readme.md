# Tune Up (Vehicle Repair)

A Project Zomboid **Build 42** mod that lets you repair vehicle parts **without spare parts or materials** — you trade time (and a little sweat) instead.

An emergency, field-expedient spot repair. It *supplements* the vanilla material-based repair system rather than replacing it: a scavenged part is still faster and can exceed your skill cap, but when you have nothing but time and a wrench, you can nurse a part back to life.

## How it works

- A **Tune Up** option appears on each part in the vehicle mechanics menu, alongside Repair / Install / Uninstall.
- Repairs happen **1% at a time** and are fully interruptible — cancel, walk away, or run out of tools and it stops cleanly at a whole percent.
- The most you can restore a part to is capped by your **Mechanics skill**: `skill × 10%` by default (level 5 → 50%, level 10 → 100%). Below the minimum skill you can't tune up at all.
- Each 1% takes **in-game minutes**, starting at 10 and dropping with skill (about `10 − skill × 0.9`), down to 1 minute per percent at level 10. Use the in-game fast-forward controls to pass the time.
- You must be able to **reach** the part — stand at the correct side of the vehicle, and remove any part in front (e.g. take the wheel off to reach the brakes), the same as installs and uninstalls.
- Tuning up costs **fatigue** and **boredom**, so long sessions leave you needing rest. A skilled mechanic (Expert level and up) tires less and actually finds the work *relaxing* — it relieves boredom instead of causing it.
- Requires a **wrench** in your inventory (toggleable).

Everything above is configurable via **Sandbox Options → Tune Up**.

## Compatibility

- Single-player, Build 42.
- Integrates by post-hooking `ISVehicleMechanics:doPartContextMenu`, so it coexists with other mechanics-menu mods.
- The one world-mutating function (`TU.applyRepair`) is isolated for a clean future multiplayer port.
