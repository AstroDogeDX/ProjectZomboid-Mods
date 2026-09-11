# Sticky Fingers (Auto Looter)

Clean and configurable auto looter for **Project Zomboid Build 42**. Tag the
items you care about, walk past a container, and they hop into your bag.

> **Status:** v1 scaffold — feature-complete for single-player, but several
> engine calls need one in-game verification pass (see
> [Verification checklist](#verification-checklist)). It is written to compile
> and load; the checklist items are method-name confirmations, not redesigns.

## Features

- **Right-click tagging** — right-click any item → *Sticky Fingers* →
  *Auto-loot X* to toggle it on/off.
- **Variant grouping** — items are tagged by *display name*, the same key the
  vanilla inventory uses to group stacks. Tagging one variant collects them all
  (e.g. black + red *Digital Watch*, or every branded *Energy Drink*).
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
  you haven't consumed yet. Plain fiction is deliberately left behind. Uses the
  game's own "already read" test, so out-levelled skill books and already-known
  recipes are ignored, and it won't grab a copy you're already carrying.
- **Ignore zones** — mark rectangular safe areas (e.g. your base) by picking two
  corners in the world; looting is suppressed while you stand inside one.
- **Exclude containers & vehicles** — right-click a specific container or a whole
  vehicle in the world → *Sticky Fingers* → *Exclude…* to protect a loot-dump
  crate or personal hauler from being looted back. Manage the list (and re-enable
  them) in the panel's **Excludes** tab.
- **Respect walls** (on by default) — only loots containers you could actually
  walk to. Reachability is flood-filled outward from you one walkable step at a
  time (using the same `canReachTo` test the vanilla loot window uses), so a
  crate on the far side of a wall is never grabbed. Your scan *range* then means
  "tiles of reachable path," not "through anything within X tiles." Turn it off
  in the panel for the old scan-through-walls behaviour.

## Controls

| Action | Default key |
| --- | --- |
| Open the Sticky Fingers panel | **L** |
| Toggle auto-looting (master switch) | **K** |

Both are rebindable under **Options → Key Bindings → [Sticky Fingers]**. You can
also open the panel from any item's right-click menu.

## Installing (local test)

Build 42 mods live in your Zomboid mods folder:

```
%UserProfile%\Zomboid\mods\
```

Copy the mod folder there so you end up with:

```
%UserProfile%\Zomboid\mods\StickyFingers\42\mod.info
%UserProfile%\Zomboid\mods\StickyFingers\common\media\lua\...
```

i.e. copy `Contents\mods\StickyFingers` from this repo into `Zomboid\mods\`.
Then enable **Sticky Fingers (Auto Looter)** in the in-game Mods menu and start
a save.

> Tip for iteration: make a directory symlink instead of copying, so edits here
> show up in-game after a Lua reload/restart:
> ```powershell
> New-Item -ItemType SymbolicLink `
>   -Path "$env:UserProfile\Zomboid\mods\StickyFingers" `
>   -Target "$PWD\Contents\mods\StickyFingers"
> ```

## Project layout

```
Contents/mods/StickyFingers/
  42/
    mod.info                     Build 42 manifest (poster.png goes here too)
  common/media/lua/
    shared/
      StickyFingers_Shared.lua   namespace, defaults, ModData persistence
    client/
      StickyFingers_Tags.lua     tag set, keyed by display name
      StickyFingers_Zones.lua    rectangle storage + point-in-zone tests
      StickyFingers_Excludes.lua per-container / per-vehicle exclusions
      StickyFingers_Filters.lua  quality filters (non-fresh food, broken)
      StickyFingers_Books.lua    unread-literature detection + dedupe
      StickyFingers_ContextMenu.lua       inventory right-click tagging
      StickyFingers_WorldContextMenu.lua  world right-click exclusions
      StickyFingers_Looter.lua   proximity scan + instant grab (the engine)
      StickyFingers_ZoneTool.lua two-corner world selector overlay
      ui/
        StickyFingers_MainWindow.lua  master switch + tab host
        StickyFingers_Panels.lua      Tagged / Search / Zones / Excludes / Settings tabs
        StickyFingers_Keybinds.lua    hotkeys + Options key bindings
workshop.txt                     Steam Workshop metadata (id=0 until published)
```

### Design notes

- **Single-player first.** All state lives in `ModData` under the key
  `StickyFingers` and persists with the save. The code is split `shared / client
  / server` and every write routes through `SF.save()`, so a future multiplayer
  port only has to add server-authoritative transfers + `ModData.transmit()`
  rather than restructure anything.
- **Instant grab.** Matching items are moved directly into your inventory on
  each ~400ms proximity scan (capped at 20 grabs/scan to avoid hitches). No
  timed action and no weight gate — by design.

## Verification checklist

I can't run Project Zomboid from here, so a handful of Java-bound method names
are called from memory of the B41/B42 API. Each is wrapped defensively (a bad
call warns once to the console and is skipped rather than breaking the loop).
Load the mod, open the debug console, and confirm these behave — adjust the
flagged line if a name differs in your build:

- [x] **Ground** — `getWorldObjects()` + `transmitRemoveItemFromSquare()`.
      *Confirmed working in-game.*
- [x] **Containers** — `getObjects()` + `getContainerCount()`/
      `getContainerByIndex()` (matches vanilla; catches multi-container objects).
      *Confirmed working in-game.*
- [x] **Corpses & Animals** — both are `IsoDeadBody` entries in
      `IsoGridSquare:getStaticMovingObjects()`; `so:isAnimal()` separates the two
      source toggles. Fixed to match vanilla `ISInventoryPage.lua`.
- [x] **Vehicles** — per-square `IsoGridSquare:getVehicleContainer()` +
      `getPartByIndex():getItemContainer()`, gated by `canAccessContainer()`
      (matches vanilla `ISInventoryPage.lua`). Replaced the crashing
      `getCell():getVehicles()` approach.
- [ ] **Zone picker** — `ISCoordConversion.ToWorld/ToScreen` argument order and
      return values (world tile under the cursor). *Zones confirmed working; the
      corner-picker overlay projection is the unverified part.*

See the `ENGINE-API CAUTION` comment blocks in the Lua files for the exact
lines.

## Roadmap / not yet done

- `poster.png` (256×256) for the mod menu — drop one in `42/`.
- Optional: pickup sound, weight-aware mode, per-source range, "loot only when
  standing still".
- Multiplayer (server-authoritative transfers + tag/zone sync).
