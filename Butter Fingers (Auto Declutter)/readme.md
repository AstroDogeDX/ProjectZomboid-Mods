# Butter Fingers (Auto Declutter)

The anti-hoarding counterpart to **Sticky Fingers**, for **Project Zomboid Build 42**. Where Sticky Fingers grabs the loot you want, Butter Fingers quietly gets rid of the junk you don't — dropping it on the floor or dumping it into a nearby bin.

## Features

- **Auto-declutter** — a throttled scan of your inventory drops items that match
  your rules. Master on/off switch (default on).
- **Drop the junk you tag** — right-click any item → *Butter Fingers* →
  *Auto-drop X*. A management panel lists your settings and drop list.
- **Predefined categories** (each toggleable):
  - **Empty containers** — drained bottles, empty cans, used-up cleaning liquid.
    Bottles and canteens you want to keep are protected by favouriting them —
    which happens automatically when you deliberately pick one up.
  - **Broken items** — the literally-broken/unusable ones (a *dull* or *worn*
    item is still useful and is **not** dropped).
  - **Read books & known recipes** — skill books you've finished and recipe
    magazines you already know.
- **Use the native "unwanted" mark** — flag an item *unwanted* (B42's built-in
  grey-out) and Butter Fingers treats it as "please drop this."
- **Your favourites are always safe** — favourited items are never dropped,
  honouring B42's favourite flag.
- **Smart protect** — manually pick up an item of a droppable *kind* (an
  emptyable container, a breakable weapon/tool, or a book/recipe) and it's
  automatically favourited, so it won't be thrown back out later — grab a full
  canteen and it stays safe even once it's empty. (Auto-looted items don't
  trigger this — only your deliberate pickups.)
- **Dump containers** — choose where junk goes: the floor, or into a designated
  container in reach. Right-click a container → *Butter Fingers* → *Set as dump
  container*, and **trash cans / bins qualify automatically**. Optionally run in
  **container-only** mode, where nothing is dropped on the floor at all — junk is
  only ever binned, and kept on you if no bin is in reach.
- **Only when over-encumbered** (optional) — leave you alone until you're
  actually too heavy, then shed the junk.
- **Plays nice with Sticky Fingers** — it will never drop something Sticky
  Fingers is set to loot, so the two can't fight.

## Controls

| Action | Default key |
| --- | --- |
| Open the Butter Fingers panel | **J** |
| Toggle auto-declutter | **H** |
| Declutter now | **U** |

All rebindable under **Options → Key Bindings → [Butter Fingers]**. You can also
open the panel from any item's right-click menu.

## Installing

Subscribe on the Steam Workshop, or install manually:

1. Copy `Contents\mods\ButterFingers` into your mods folder so you end up with:
   ```
   %UserProfile%\Zomboid\mods\ButterFingers\42\mod.info
   %UserProfile%\Zomboid\mods\ButterFingers\common\media\lua\...
   ```
2. Enable **Butter Fingers (Auto Declutter)** in the in-game **Mods** menu and
   start a save.

## Compatibility

- **Project Zomboid Build 42**, single-player.
- Pairs naturally with [Sticky Fingers (Auto Looter)](../Sticky%20Fingers%20%28Auto%20Looter%29).
- Settings are stored per-save.

## Feedback

Bug reports and ideas welcome — please open an issue. Auto-dropping is powerful,
so if anything ever gets dropped that you meant to keep, tell me exactly what and
I'll tighten the rule.
