# Sticky Fingers (Auto Looter)

Clean and configurable auto looter for **Project Zomboid Build 42**. Tag the items you care about, walk past a container, and they hop into your bag.

## Features

- **Right-click tagging** — right-click any item → *Sticky Fingers* →
  *Auto-loot X* to toggle it on/off.
- **Variant grouping** — items are tagged by their *inventory name* (the exact
  key the game stacks by), so tagging one variant collects everything that
  stacks with it (e.g. black + red *Digital Watch*, or every branded *Energy
  Drink*) — while a renamed depleted item like *Empty Cleaning Liquid Bottle*
  stays a separate entry and isn't looted just because the full one is tagged.
- **Per-item "max carried" + shopping list** — each tagged entry can have a max
  count (edited inline in the Tagged tab): once you're carrying that many, it
  stops looting more until you drop below it. Tick *Remove from list once max is
  reached* to make it a one-shot shopping-list entry that deletes itself when
  filled. New tags default to *no limit* (loot forever).
- **Source toggles** — independently enable/disable looting from **Ground,
  Containers, Vehicles, Corpses, Animals**.
- **Management window** — searchable list of *all* game items to tag ahead of
  time, plus a list of everything you've already tagged.
- **Master switch** — pause/resume all auto-looting without losing your
  settings (hotkey **K** by default).
- **Carry-weight limit** (optional) — off by default (grab regardless of
  weight). Enable it to stop auto-looting at your carry limit, with an
  adjustable cap from **50%–300%** of your *current* max weight — so as Strength
  raises your capacity, the limit scales with it. Items that wouldn't fit are
  skipped while lighter ones can still be grabbed.
- **Quality filters** (optional) — skip **non-fresh food** (stale / rotten /
  burnt), **broken items**, and/or **empty items** (used-up cans, drained
  cleaning-liquid/soda/fluid containers), even when their type is tagged. Handy
  because a depleted item keeps the same display name as its full version, so
  this is how you avoid re-looting your own empties.
- **Auto-loot unread skill books & recipe magazines** (optional) — walk past a
  bookshelf and grab **skill books** and **recipe-teaching** magazines/leaflets
  you haven't consumed yet. Plain fiction is deliberately left behind. Skill
  books are only taken if you can actually **read them at your current level** —
  it won't hoard Vol 3-5 while you're still level 0, nor books you've out-levelled.
  Recipe magazines are taken while they still teach something new. Won't grab a
  copy you're already carrying.
- **Ignore zones** — mark rectangular safe areas (e.g. your base) by picking two
  corners in the world; looting is suppressed while you stand inside one.
- **Exclude containers & vehicles** — right-click a specific container or a whole
  vehicle in the world → *Sticky Fingers* → *Exclude…* to protect a loot-dump
  crate or personal hauler from being looted back. Exclusions persist properly:
  containers by world position, and **vehicles via their own saved data**, so a
  personal vehicle stays ignored even after you drive far away and its chunk
  unloads/reloads. Manage them in the panel's **Excludes** tab (excluded
  vehicles appear there while they're loaded/nearby).
- **Respect walls** (on by default) — only loots containers you could actually
  walk to, so a crate on the far side of a wall is never grabbed. Your scan
  *range* then means "tiles of reachable path," not "through anything within X
  tiles." Turn it off in the panel for the old scan-through-walls behaviour.

## Controls

| Action | Default key |
| --- | --- |
| Open the Sticky Fingers panel | **L** |
| Toggle auto-looting (master switch) | **K** |

Both are rebindable under **Options → Key Bindings → [Sticky Fingers]**. You can
also open the panel from any item's right-click menu.

## Installing

Subscribe on the Steam Workshop, or install manually:

1. Copy `Contents\mods\StickyFingers` from this repo into your mods folder so you
   end up with:
   ```
   %UserProfile%\Zomboid\mods\StickyFingers\42\mod.info
   %UserProfile%\Zomboid\mods\StickyFingers\common\media\lua\...
   ```
2. Enable **Sticky Fingers (Auto Looter)** in the in-game **Mods** menu and start
   a save.

## Compatibility

- **Project Zomboid Build 42**, single-player.
- All settings are stored per-save, so different characters/worlds keep their own
  tags, zones and exclusions.

## Feedback

Found a bug or have an idea? Please open an issue with a short description of what
happened and what you expected.
