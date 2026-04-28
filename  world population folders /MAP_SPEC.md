# Park Friends — World Map Specification

This document is the deterministic recipe for building the Park Friends overworld
from the asset folders in this directory. It is written for an AI agent (or human)
to **execute, not interpret**. Every tile placement is a row in a table; every
asset is referenced by a short ID that maps to one file.

---

## 0. Global conventions

- **Tile size:** 16 × 16 px (native grid for almost all assets in this folder).
- **Coordinate system:** origin `(0, 0)` is the **top-left** of each scene.
  `+x` is right, `+y` is down. All coordinates are in **tiles** (multiply by 16
  for pixels).
- **Bounding box notation:** `(x, y, w, h)` covers tiles `x..x+w-1`,
  `y..y+h-1` inclusive.
- **Asset path root:** all paths are relative to ` world population folders /`
  (the folder containing this file).
- **Architecture:** the world is split into **6 scenes** (SNES-style). The
  player transitions between scenes through edge triggers (the `WORLD_GRAPH`
  in §2). Each scene has its own coordinate space starting at (0, 0).

### Layer stack (paint bottom → top)

| Layer | Name | Contents |
|------|------|----------|
| L0 | Ground fill | Grass / dirt / stone / pavement / water autotile |
| L1 | Ground decoration | Flowers, pebbles, road stripes, manholes, cracks |
| L2 | Borders & fences | Tree wall, hedge, picket fence, sidewalk curb |
| L3 | Large objects | Houses, fountain, statue, vehicles, big trees |
| L4 | Small props | Benches, lamp posts, signs, mailboxes, balloons |
| L5 | Actors | Player, NPCs, creatures (these are dynamic, spawn points only) |
| L6 | Debug overlay | Region labels (do not render in shipping build) |

The agent must paint L0 across the entire scene first, then iterate L1…L5 in
order. Within a layer, iterate the placement table top-to-bottom.

---

## 1. Asset registry

Short IDs used throughout the spec. **Footprint** is in tiles (w × h).

### Ground / terrain (folder: `park-nature-terrain-and-tree-tiles/`)

| ID | File | Footprint | Notes |
|----|------|-----------|-------|
| `grass_fill` | `pixel-art-plain-bright-grass-fill-piece-70-16x16.png` | 1×1 | Default grass, use for L0 fill in suburb + park. |
| `grass_dark` | `pixel-art-solid-dark-green-grass-square-tile-16x16.png` | 1×1 | Tree-shadow / forest interior. |
| `dirt_fill` | `pixel-art-plain-brown-dirt-tile-16x16.png` | 1×1 | Construction lot fill, dirt path interiors. |
| `dirt_path_at` | `pixel-art-pebbled-brown-dirt-path-corner-and-edge-tileset-64x64.png` | 4×4 autotile | Yellow/brown dirt walking paths through the park & suburbs. |
| `stone_path_at` | `pixel-art-gray-stone-path-with-grass-border-corners-and-edges-tileset-64x64.png` | 4×4 autotile | Fountain plaza paving + statue plaza. |
| `stone_fill` | `pixel-art-gray-stone-ground-tile-16x16.png` | 1×1 | Plaza interior fill. |
| `water_fill` | `pixel-art-solid-blue-water-tile-16x16.png` | 1×1 | Pond interior. |
| `water_shore_at` | `pixel-art-blue-water-to-grass-shore-horizontal-edge-tileset-192x64.png` | 12×4 autotile | Pond shore against grass. |
| `pond_border_at` | `pixel-art-blue-pond-water-border-corners-and-edges-tileset-64x64.png` | 4×4 autotile | Compact pond shoreline alternative. |
| `tree_wall_at` | `pixel-art-dense-leaf-hedge-border-corner-and-edge-tileset-64x64.png` | 4×4 autotile | The dense tree-line border around suburb + park. |
| `hedge_at` | `pixel-art-leafy-hedge-border-corner-and-edge-tileset-64x64.png` | 4×4 autotile | Decorative hedges inside yards. |
| `flowers_set` | `pixel-art-basic-grass-biome-props-flowers-rocks-bushes-mushrooms-and-plants-tileset-144x80.png` | 9×5 sheet | Pick individual 1×1 flower tiles from this sheet. |
| `flower_red` | `pixel-art-tiny-flower-sprite-01-8x7.png` | 1×1 | Single flower prop. |
| `flower_yellow` | `pixel-art-tiny-flower-sprite-02-8x7.png` | 1×1 | Single flower prop. |
| `flower_blue` | `pixel-art-tiny-flower-sprite-03-8x7.png` | 1×1 | Single flower prop. |
| `rock_small_a` | `pixel-art-gray-rock-with-grass-sprite-01.png` | 1×1 | Decorative rock. |
| `rock_small_b` | `pixel-art-gray-rock-with-grass-sprite-04.png` | 1×1 | Decorative rock variant. |

### Trees (folder: `park-nature-terrain-and-tree-tiles/`)

| ID | File | Footprint |
|----|------|-----------|
| `tree_oak_big` | `Oak TREE.png` | ~3×4 (the named landmark oak) |
| `tree_round_lg` | `pixel-art-large-round-green-tree-sprite-48x48.png` | 3×3 |
| `tree_round_md` | `pixel-art-medium-round-green-tree-sprite-32x32.png` | 2×2 |
| `tree_round_sm` | `pixel-art-small-rounded-green-tree-sprite-16x16.png` | 1×1 |
| `tree_conical_md` | `pixel-art-tall-conical-green-tree-sprite-32x48.png` | 2×3 |
| `tree_conical_sm` | `pixel-art-small-conical-green-tree-sprite-16x32.png` | 1×2 |
| `tree_pine_border` | `pixel-art-small-border-tree-pine-sprite-32x48.png` | 2×3 |

### Suburban houses (folder: `suburban-house-exterior-tiles/`)

| ID | File | Footprint | Notes |
|----|------|-----------|-------|
| `house_a` | `pixel-art-complete-small-wooden-house-exterior-sprite-112x80.png` | 7×5 | Only complete house sprite available. **Reuse for all 9 suburban houses + secret lab** until variants exist (see §8 Missing Assets). |
| `fence_at` | `pixel-art-wood-post-and-rail-fence-corners-and-segments-tileset-64x64.png` | 4×4 autotile | Yard fences. |
| `fence_seg_01..11` | `pixel-art-wood-fence-piece-NN-tile-16x16.png` | 1×1 each | Individual fence pieces if autotile is impractical. |
| `house_door` | `pixel-art-wooden-house-arched-door-variants-spritesheet-16x64.png` | 1×4 sheet | Door overlay (front of house, optional — `house_a` already includes door). |

### Streets / city (folder: `city-street-pavement-tiles/`)

| ID | File | Footprint |
|----|------|-----------|
| `pavement` | `pixel-art-purple-blue-brick-street-pavement-tile-48x32.png` | 3×2 (tile this across roads & city ground) |

### Park creatures (folder: `parkland-creature-sprites/`)

| ID | File | Spawn role |
|----|------|------------|
| `chicken_white` | `pixel-art-white-chicken-yellow-beak-4-direction-walk-idle-spritesheet-192x192.png` | Wandering park animal |
| `chicks` | `pixel-art-yellow-baby-chicks-5-frame-row-spritesheet-64x32.png` | Follower of chicken |
| `egg_nest` | `pixel-art-egg-and-nest-stages-empty-egg-hatched-spritesheet-64x16.png` | Static prop near `chicken_white` |

### Squirrel (folder: `squirrel-character-animation-frames/`)

| ID | File pattern | Spawn role |
|----|--------------|------------|
| `squirrel` | `idle/`, `run/`, `jump/`, `crouch/`, `hurt/` frame folders | Wandering park animal |

### NPCs

Player and NPC sprite sheets live in `girl-character-sprite-sheets/`,
`pride-character-npc-sprite-sheets/`, and `villain-npc-character-sprite-sheets/`.
**Sprites are placed by spawn point (single tile coord), not by footprint.** Each
spawn entry references the sheet filename and the variant.

### Interiors (referenced by indoor scenes only)

| ID | File | Scene |
|----|------|-------|
| `lab_tileset` | `secret-lab-interior-tiles/pixel-art-secret-lab-blue-gray-machinery-computer-wall-floor-tileset-x1-1184x736.png` | `secret_lab_interior` |
| `house_int_tileset` | `interior-room-sample-tiles/pixel-art-interior-sample-cabinets-potted-plant-wood-floor-stone-wall-tileset-160x80.png` | (future house interiors) |

---

## 2. World graph (scene transitions)

Six scenes. Edge triggers sit on a single tile-row or tile-column at the scene
boundary. When the player walks onto a trigger tile, fade and load the linked
scene at the matching `entry` coordinate so their relative position is preserved.

| From scene | Trigger edge (tiles) | → To scene | Entry coords |
|---|---|---|---|
| `suburb_north` | south edge, x=60..67, y=79 | `park` | x=44..51, y=1 |
| `suburb_north` | door of secret-lab building (x=11, y=7) | `secret_lab_interior` | x=20, y=26 |
| `park` | north edge, x=44..51, y=0 | `suburb_north` | x=60..67, y=78 |
| `park` | south edge, x=44..51, y=63 | `city_main` | x=60..67, y=1 |
| `city_main` | north edge, x=60..67, y=0 | `park` | x=44..51, y=62 |
| `city_main` | west edge, x=0, y=8..20 | `construction` | x=55, y=8..20 |
| `city_main` | south edge, x=0..127, y=47 | `parade` | x=0..127, y=1 |
| `construction` | east edge, x=55, y=8..20 | `city_main` | x=1, y=8..20 |
| `parade` | north edge, x=0..127, y=0 | `city_main` | x=0..127, y=46 |
| `secret_lab_interior` | door tile (x=20, y=27) | `suburb_north` | x=11, y=8 |

---

## 3. Scene: `suburb_north`

**Size:** 128 × 80 tiles. Contains the Green Shire Suburb, the Secret Lab
House (top-left), the seven main row-houses (top), the road, and two lower
suburban houses.

### 3.1 Layout zones

| Zone | Bounds (x,y,w,h) | Purpose |
|------|------------------|---------|
| Tree-wall border (N/E/W) | perimeter, 2 tiles thick except south edge | Map boundary |
| Secret lab plot | (4, 2, 16, 14) | Lab house + driveway + lawn, fenced off |
| Top row yards | (22, 2, 100, 18) | 7 houses + lawns |
| Road | (0, 26, 128, 5) | Horizontal asphalt road across full width |
| Sidewalk N | (0, 25, 128, 1) | Curb |
| Sidewalk S | (0, 31, 128, 1) | Curb |
| Lower-suburb yards | (4, 36, 60, 18) | 2 houses + lawn |
| Park-approach lawn | (0, 54, 128, 26) | Open grass with dirt path leading south |

### 3.2 Layer 0 — ground fill

| Range | Asset |
|-------|-------|
| Whole scene | `grass_fill` |
| Road `(0,26)–(127,30)` | `pavement` (tile the 3×2 across) |
| Sidewalks `(0,25)–(127,25)` and `(0,31)–(127,31)` | `stone_fill` |
| Dirt path from `(60,54)` to `(63,79)` (4 wide, all the way to south edge) | `dirt_path_at` autotile |
| Secret-lab driveway from house door at `(11,7)` west then south to road `(7,25)` | `stone_path_at` autotile, 2 tiles wide |

### 3.3 Layer 2 — borders

- Paint `tree_wall_at` autotile around the entire perimeter, **2 tiles thick**,
  EXCEPT a 4-tile-wide gap centered at `x=62..65, y=78..79` (south road exit).
- Hedge separator between secret-lab plot and main suburb: `hedge_at` running
  vertically at `x=20, y=2..16`.

### 3.4 Layer 3 — placements

Houses are 7×5. Spaced with 3-tile gaps between them.

| id | asset | x | y | w | h | layer |
|---|---|---|---|---|---|---|
| secret_lab | `house_a` | 8 | 4 | 7 | 5 | L3 |
| house_n_01 | `house_a` | 24 | 10 | 7 | 5 | L3 |
| house_n_02 | `house_a` | 34 | 10 | 7 | 5 | L3 |
| house_n_03 | `house_a` | 44 | 10 | 7 | 5 | L3 |
| house_n_04 | `house_a` | 54 | 10 | 7 | 5 | L3 |
| house_n_05 | `house_a` | 64 | 10 | 7 | 5 | L3 |
| house_n_06 | `house_a` | 74 | 10 | 7 | 5 | L3 |
| house_n_07 | `house_a` | 84 | 10 | 7 | 5 | L3 |
| house_s_01 | `house_a` | 8 | 40 | 7 | 5 | L3 |
| house_s_02 | `house_a` | 22 | 40 | 7 | 5 | L3 |

### 3.5 Layer 2 — fences (per house)

For every house, place a `fence_at` autotile rectangle around its yard:
`(house.x - 2, house.y + 5, house.w + 4, 4)` — i.e. fence wraps the front yard
below the house. Leave a 2-tile gap centered on the house door (door is at
`house.x + 3` in the 7-wide sprite) so the player can walk in.

### 3.6 Layer 3/4 — yard props

For each top-row house, place 2 trees and 2 flower clusters in the yard. Use
this rule to avoid the agent having to think:

```
For each house in top_row:
  tree_round_md at (house.x + 0,  house.y - 2)    # 2x2 tree top-left of house
  tree_round_md at (house.x + 5,  house.y - 2)    # 2x2 tree top-right
  flower_red    at (house.x + 1,  house.y + 6)
  flower_yellow at (house.x + 5,  house.y + 6)
```

Same rule applies to lower-suburb houses with `house.y + 6 → house.y + 6` etc.

### 3.7 Layer 4 — props

| id | asset | x | y |
|---|---|---|---|
| lamp_road_l | streetlamp (missing — see §8) | 12 | 24 |
| lamp_road_r | streetlamp (missing — see §8) | 110 | 24 |
| mailbox_n_01..07 | (missing — see §8) | per-house at `(house.x + 3, house.y + 5)` | |

### 3.8 Layer 5 — spawn points

| id | sheet | variant | x | y |
|---|---|---|---|---|
| player_spawn | `girl-character-sprite-sheets/pixel-art-blonde-girl-blue-dress-character-8-direction-idle-walk-sit-sleep-spritesheet-576x384.png` | default | 62 | 60 |
| npc_pride_01 | `pride-character-npc-sprite-sheets/...variant-01...png` | 01 | 30 | 22 |
| npc_pride_02 | `pride-character-npc-sprite-sheets/...variant-03...png` | 03 | 70 | 22 |

### 3.9 Creek (water feature crossing this scene)

The creek originates at a tree-line spring in the suburb's NE corner, runs SW
through the lower lawn, and exits the south edge into the `park` scene where it
feeds the pond. **2 tiles wide** throughout. Paint as `water_fill` interior +
`water_shore_at` autotile around the perimeter.

Path waypoints (centerline):

| Segment | From (x,y) | To (x,y) | Shape |
|---------|------------|----------|-------|
| C-1 | (110, 22) | (110, 38) | straight south |
| C-2 | (110, 38) | (78, 56) | diagonal SW |
| C-3 | (78, 56) | (50, 60) | gentle west curve |
| C-4 | (50, 60) | (50, 79) | straight south to scene edge |

The creek exits at `x=49..50, y=79` and re-enters the `park` scene at
`x=49..50, y=0`. (Note: this is offset 5 tiles east of the path transition at
x=60..67 — they run parallel through the south edge.)

### 3.10 Bridges

Where the creek crosses the dirt path, place a wooden footbridge (asset
missing — §9 `bridge_wood`).

| id | x | y | w | h | notes |
|----|---|---|---|---|-------|
| bridge_01 | 49 | 70 | 4 | 2 | Path crosses creek; bridge spans both creek tiles + 1-tile path overlap each side |

### 3.11 Driveways

Each row-house gets a 1-tile-wide paved driveway from its front-yard gate to
the north sidewalk (y=25). Use `pavement` (3×2 tiles, but render single
column) or `stone_path_at` autotile, 1 tile wide.

| House | Driveway from | Driveway to |
|-------|---------------|-------------|
| secret_lab | (11, 12) | (11, 25), then west to road shoulder at (4, 25) — curving driveway |
| house_n_01 | (27, 16) | (27, 25) |
| house_n_02 | (37, 16) | (37, 25) |
| house_n_03 | (47, 16) | (47, 25) |
| house_n_04 | (57, 16) | (57, 25) |
| house_n_05 | (67, 16) | (67, 25) |
| house_n_06 | (77, 16) | (77, 25) |
| house_n_07 | (87, 16) | (87, 25) |
| house_s_01 | (11, 46) | (11, 32) (driveway runs north up to the south sidewalk) |
| house_s_02 | (25, 46) | (25, 32) |

### 3.12 Secret-lab plot details

| id | asset | x | y | w | h | notes |
|----|-------|---|---|---|---|-------|
| lab_shed | `house_a` (placeholder; small outbuilding ideally — §9 `shed_small`) | 16 | 6 | 3 | 3 | Small shed beside lab |
| lab_gate | (missing — §9 `gate_wooden`) | 7 | 24 | 2 | 1 | Wooden gate at driveway exit onto road |
| lab_bush_01 | `flowers_set` (bush tile) | 6 | 12 | 1 | 1 | |
| lab_bush_02 | `flowers_set` (bush tile) | 14 | 12 | 1 | 1 | |
| lab_tree_01 | `tree_round_md` | 4 | 4 | 2 | 2 | Inside lab fence |
| lab_tree_02 | `tree_round_md` | 17 | 4 | 2 | 2 | |

The lab plot is enclosed by a `fence_at` autotile rectangle at
`(4, 2, 16, 14)` with the gate cell at (7, 16) cut out (player can pass).

### 3.13 Streetlamps + road props

| id | asset | x | y | notes |
|----|-------|---|---|-------|
| lamp_road_n_01 | (missing — §9 `streetlamp_iron`) | 12 | 24 | North sidewalk |
| lamp_road_n_02 | `streetlamp_iron` | 32 | 24 | |
| lamp_road_n_03 | `streetlamp_iron` | 52 | 24 | |
| lamp_road_n_04 | `streetlamp_iron` | 72 | 24 | |
| lamp_road_n_05 | `streetlamp_iron` | 92 | 24 | |
| lamp_road_n_06 | `streetlamp_iron` | 112 | 24 | |
| lamp_road_s_01 | `streetlamp_iron` | 12 | 32 | South sidewalk |
| lamp_road_s_02 | `streetlamp_iron` | 32 | 32 | |
| lamp_road_s_03 | `streetlamp_iron` | 52 | 32 | |
| lamp_road_s_04 | `streetlamp_iron` | 72 | 32 | |
| lamp_road_s_05 | `streetlamp_iron` | 92 | 32 | |
| lamp_road_s_06 | `streetlamp_iron` | 112 | 32 | |
| car_road_01 | (missing — §9 `car_static`) | 40 | 27 | Parked / passing car on road |
| mailbox_n_01..07 | (missing — §9 `mailbox`) | (house.x + 3, house.y + 5) for each top-row house | | |
| bench_lawn | (missing — §9 `bench_park`) | 70 | 60 | Bench in lower lawn near path |

### 3.14 Roof-color variant tags

Tag each placed house with the roof color it should eventually swap to (no-op
today; spec stays correct when variants arrive):

| house_id | desired variant |
|----------|------------------|
| secret_lab | dark_purple |
| house_n_01 | blue |
| house_n_02 | brown |
| house_n_03 | green |
| house_n_04 | red_brown |
| house_n_05 | dark_red |
| house_n_06 | charcoal |
| house_n_07 | tan_small |
| house_s_01 | brown |
| house_s_02 | tan |

### 3.15 Lower-suburb extra house

Add a 3rd small house in the lower suburb (visible in the screenshot, smaller
than the others — could be a cottage):

| id | asset | x | y | w | h |
|----|-------|---|---|---|---|
| house_s_03 | `house_a` (variant `cottage`) | 4 | 50 | 5 | 4 |

---

## 4. Scene: `park`

**Size:** 96 × 64 tiles. Holds the Pond, the Fountain plaza, the Statue, and
the Oak Tree landmark.

### 4.1 Layout zones

| Zone | Bounds | Purpose |
|------|--------|---------|
| Tree-wall border | perimeter 2-thick, gaps at N (x=44..51) and S (x=44..51) | Map boundary |
| Pond | (8, 14, 22, 16) | Body of water, kidney-shape via autotile |
| Fountain plaza | (38, 18, 14, 14) | Stone-paved, fountain in center |
| Statue plaza | (66, 38, 10, 10) | Stone-paved, statue centered |
| Oak landmark | (4, 46, 4, 6) | Single big oak, grass around |
| Path network | see §4.3 | Connects all four landmarks + N/S exits |

### 4.2 Layer 0 — ground fill

- Whole scene: `grass_fill`.
- Pond interior `(10, 16) .. (27, 27)`: `water_fill`. Then run `water_shore_at`
  autotile around the pond perimeter (1 tile inset from the bounding box).
- Fountain plaza interior: `stone_fill`. `stone_path_at` autotile on the
  perimeter.
- Statue plaza interior: `stone_fill`. `stone_path_at` autotile on the perimeter.

### 4.3 Layer 0 — dirt paths (1-tile wide unless noted)

Path graph (paint `dirt_path_at` autotile, 2 tiles wide):

```
N entry (44..47, 0)
   ↓ vertical to (44..47, 17)
   ↓ branches:
       west to pond approach: (28..47, 18..19)
       east to fountain: (47..52, 18..19)
       south to statue + south exit
   continues to (44..47, 38)
       east branch (47..68, 38..39) → statue plaza
       south branch to (44..47, 63) — S exit
   west branch from (8..44, 50..51) → oak tree
```

### 4.4 Layer 3 — placements

| id | asset | x | y | w | h |
|---|---|---|---|---|---|
| oak_landmark | `tree_oak_big` | 4 | 46 | 4 | 6 |
| fountain | (missing — see §8 `fountain_sprite`) | 43 | 23 | 4 | 4 |
| statue | (missing — see §8 `statue_sprite`) | 70 | 42 | 2 | 3 |

### 4.5 Layer 3 — tree clusters (decorative)

Scatter trees inside the park to fill empty grass. Rule: do **not** place trees
on path tiles, plaza tiles, or pond tiles. Place these specific instances:

| id | asset | x | y |
|---|---|---|---|
| tree_p_01 | `tree_round_lg` | 12 | 4 |
| tree_p_02 | `tree_round_lg` | 60 | 6 |
| tree_p_03 | `tree_round_md` | 80 | 10 |
| tree_p_04 | `tree_conical_md` | 34 | 32 |
| tree_p_05 | `tree_round_md` | 56 | 50 |
| tree_p_06 | `tree_round_md` | 82 | 52 |
| tree_p_07 | `tree_conical_sm` | 18 | 38 |
| tree_p_08 | `tree_round_md` | 28 | 56 |

### 4.6 Layer 4 — props

| id | asset | x | y | notes |
|---|---|---|---|---|
| bench_01 | bench (missing — §8) | 40 | 32 | Near fountain south |
| bench_02 | bench (missing — §8) | 20 | 30 | Pond east shore |
| bench_03 | bench (missing — §8) | 66 | 50 | Statue plaza south |
| flower_cluster_01 | `flower_red` | 50 | 12 | |
| flower_cluster_02 | `flower_yellow` | 52 | 12 | |
| flower_cluster_03 | `flower_blue` | 36 | 50 | |
| rock_01 | `rock_small_a` | 8 | 24 | Pond NW shore |
| rock_02 | `rock_small_b` | 30 | 18 | Pond NE shore |

### 4.7 Layer 5 — creatures + NPC spawns

| id | asset | x | y |
|---|---|---|---|
| chicken_01 | `chicken_white` | 58 | 30 |
| chicks_01 | `chicks` | 59 | 31 |
| squirrel_01 | `squirrel` (idle) | 6 | 50 |
| npc_park_01 | pride NPC variant 02 | 44 | 30 |

### 4.8 Creek + bridges (matches `suburb_north` §3.9)

Creek enters the park scene from the north edge at `x=49..50, y=0`, runs
south, curves SW into the pond, and "ends" by merging with the pond water at
the pond's NE corner.

| Segment | From | To | Shape |
|---------|------|-----|-------|
| C-5 | (49, 0) | (49, 12) | straight south |
| C-6 | (49, 12) | (30, 18) | diagonal SW into pond's NE shore |

Where the main N-S dirt path (x=44..47) crosses the creek, place:

| id | asset | x | y | w | h |
|----|-------|---|---|---|---|
| bridge_park_01 | `bridge_wood` (§9) | 47 | 8 | 4 | 2 |

### 4.9 Pond detail

| id | asset | x | y | w | h | notes |
|----|-------|---|---|---|---|-------|
| pier_dock | (missing — §9 `pier_dock`) | 26 | 18 | 4 | 3 | Wooden pier extending east into pond |
| cattail_01 | (missing — §9 `cattails`) | 9 | 22 | 1 | 1 | South shore reeds |
| cattail_02 | `cattails` | 11 | 28 | 1 | 1 | |
| cattail_03 | `cattails` | 26 | 26 | 1 | 1 | |
| pond_rock_01 | `rock_small_a` | 8 | 16 | 1 | 1 | Already listed in §4.6, reaffirmed |
| pond_rock_02 | `rock_small_b` | 28 | 14 | 1 | 1 | NE shore |
| pond_rock_03 | `rock_small_a` | 14 | 30 | 1 | 1 | South shore |

### 4.10 Fountain plaza detail (octagonal)

To approximate the octagonal plaza in the screenshot, **clip the four corners
of the 14×14 plaza by 2 tiles each** — i.e. tiles in the corners
`(38..39, 18..19)`, `(50..51, 18..19)`, `(38..39, 30..31)`, `(50..51, 30..31)`
revert to grass (paint `grass_fill` over the stone fill in those 2×2 corner
blocks). Re-run `stone_path_at` autotile around the new octagonal perimeter.

Plaza furnishings:

| id | asset | x | y | notes |
|----|-------|---|---|-------|
| lamp_fountain_NW | `streetlamp_iron` (§9) | 40 | 20 | NW corner of octagonal plaza |
| lamp_fountain_NE | `streetlamp_iron` | 49 | 20 | NE |
| lamp_fountain_SW | `streetlamp_iron` | 40 | 29 | SW |
| lamp_fountain_SE | `streetlamp_iron` | 49 | 29 | SE |
| bench_fountain_N | `bench_park` (§9) | 44 | 20 | Bench facing fountain from north |
| bench_fountain_S | `bench_park` | 44 | 30 | South |
| bench_fountain_E | `bench_park` | 50 | 24 | East |
| bench_fountain_W | `bench_park` | 38 | 24 | West |
| flower_plaza_01 | `flower_red` | 41 | 21 | |
| flower_plaza_02 | `flower_yellow` | 48 | 21 | |
| flower_plaza_03 | `flower_blue` | 41 | 29 | |
| flower_plaza_04 | `flower_red` | 48 | 29 | |

### 4.11 Statue plaza detail

| id | asset | x | y | notes |
|----|-------|---|---|-------|
| flower_statue_01 | `flower_red` | 69 | 44 | Around statue base |
| flower_statue_02 | `flower_yellow` | 71 | 44 | |
| flower_statue_03 | `flower_blue` | 69 | 41 | |
| flower_statue_04 | `flower_red` | 71 | 41 | |
| bench_statue | `bench_park` | 70 | 47 | Bench facing statue from south |

### 4.12 Bushes / shrubs scattered across the park

| id | asset | x | y |
|----|-------|---|---|
| bush_01 | `flowers_set` (bush sub-tile) | 6 | 8 |
| bush_02 | `flowers_set` | 18 | 6 |
| bush_03 | `flowers_set` | 56 | 8 |
| bush_04 | `flowers_set` | 88 | 14 |
| bush_05 | `flowers_set` | 12 | 54 |
| bush_06 | `flowers_set` | 78 | 56 |
| bush_07 | `flowers_set` | 32 | 60 |

---

## 5. Scene: `city_main`

**Size:** 128 × 48 tiles. Three-row downtown grid with cafe, store, hospital,
police, and the Development Corp building.

### 5.1 Layer 0

- Whole scene: `pavement` tiled (3×2 repeat).
- Sidewalks: 1-tile-thick `stone_fill` along every block edge.

### 5.2 Layout (block grid)

The city is a 3-row × 4-column block grid. Each block is 28w × 12h tiles with
4-tile streets between them.

| Block | Bounds (x,y,w,h) | Function | Asset (placeholder) |
|-------|------------------|----------|---------------------|
| B-NW | (4, 4, 28, 12) | Cafe | (missing — §8 `bldg_cafe`) |
| B-NM | (36, 4, 28, 12) | General store | (missing — §8 `bldg_store`) |
| B-NE | (68, 4, 28, 12) | Hospital | (missing — §8 `bldg_hospital`) |
| B-MW | (4, 20, 28, 12) | Apartments row | (missing — §8 `bldg_apartment`) |
| B-MM | (36, 20, 28, 12) | Apartments row | (missing — §8 `bldg_apartment`) |
| B-ME | (68, 20, 28, 12) | Police HQ | (missing — §8 `bldg_police`) |
| B-SE | (100, 20, 24, 12) | Development Corp | (missing — §8 `bldg_devcorp`) |

### 5.3 Streets

- Vertical streets at x = 32..35, 64..67, 96..99 (full height).
- Horizontal street at y = 16..19 (full width).
- Lane stripes: paint a 1-tile-wide white-stripe overlay (missing asset — §8) at
  the midline of each street.

### 5.4 Spawn points

| id | sheet | x | y |
|---|---|---|---|
| npc_cop_01 | `villain-npc-character-sprite-sheets/pixel-art-blue-police-officer-cop-npc-...png` | 80 | 28 |
| npc_cop_sergeant | `...blue-police-sergeant-npc...png` | 84 | 28 |
| npc_villain_01 | `...blue-uniform-character-4b-villain-npc...png` | 110 | 24 |

### 5.5 Crosswalks

Place a 4w × 2h zebra-stripe overlay (asset missing — §9 `crosswalk_stripes`)
at every intersection, both N-S and E-W crossings:

| id | x | y | orientation |
|----|---|---|-------------|
| xw_NW_h | 30 | 16 | horizontal across NW intersection |
| xw_NW_v | 32 | 14 | vertical |
| xw_NM_h | 62 | 16 | horizontal |
| xw_NM_v | 64 | 14 | vertical |
| xw_NE_h | 94 | 16 | horizontal |
| xw_NE_v | 96 | 14 | vertical |

### 5.6 Sidewalk lamp posts

Lamp post on every block corner. Each block is 28×12 starting from the corners
listed in §5.2. Lamp positions (sit on the sidewalk just inside each corner):

| id | x | y |
|----|---|---|
| lamp_city_01 | 4 | 4 |
| lamp_city_02 | 31 | 4 |
| lamp_city_03 | 36 | 4 |
| lamp_city_04 | 63 | 4 |
| lamp_city_05 | 68 | 4 |
| lamp_city_06 | 95 | 4 |
| lamp_city_07 | 4 | 31 |
| lamp_city_08 | 31 | 31 |
| lamp_city_09 | 36 | 31 |
| lamp_city_10 | 63 | 31 |
| lamp_city_11 | 68 | 31 |
| lamp_city_12 | 95 | 31 |
| lamp_city_13 | 100 | 31 |
| lamp_city_14 | 123 | 31 |

### 5.7 Sidewalk trees, hydrants, trash cans

| id | asset | x | y |
|----|-------|---|---|
| sw_tree_01 | `tree_round_sm` | 18 | 16 |
| sw_tree_02 | `tree_round_sm` | 50 | 16 |
| sw_tree_03 | `tree_round_sm` | 82 | 16 |
| sw_tree_04 | `tree_round_sm` | 110 | 32 |
| hydrant_01 | (missing — §9 `fire_hydrant`) | 6 | 17 |
| hydrant_02 | `fire_hydrant` | 70 | 17 |
| trash_01 | (missing — §9 `trash_can`) | 32 | 17 |
| trash_02 | `trash_can` | 96 | 17 |

### 5.8 Vehicles

| id | asset | x | y | notes |
|----|-------|---|---|-------|
| car_city_01 | `car_static` (§9) | 20 | 17 | Parked, north street |
| car_city_02 | `car_static` | 78 | 17 | Parked, north street |
| car_city_03 | `car_static` | 50 | 17 | Moving E |
| police_car | (missing — §9 `police_car`) | 76 | 32 | Parked outside police HQ |

---

## 6. Scene: `construction`

**Size:** 56 × 32 tiles. Walled-off dirt lot west of the city.

### 6.1 Layers

- L0 fill: `dirt_fill` everywhere.
- L2 border: chain-link fence (missing — §8 `fence_chainlink`) around the
  perimeter except a 4-wide gate on the east edge connecting to `city_main`.
- L3 vehicles (all missing — §8): excavator at (8, 6), bulldozer at (28, 8),
  dump truck at (16, 18).
- L3 piles: dirt mound (`dirt_fill` cluster + rocks) at (40, 14, 6, 6).
- L4 props: traffic cones, barrels (missing — §8).

### 6.2 Construction props (per the screenshot)

| id | asset | x | y | w | h | notes |
|----|-------|---|---|---|---|-------|
| excavator | (missing — §9 `vehicle_excavator`) | 6 | 4 | 5 | 4 | Yellow, top-left |
| bulldozer | (missing — §9 `vehicle_bulldozer`) | 26 | 6 | 4 | 3 | Blue |
| dump_truck | (missing — §9 `vehicle_truck`) | 14 | 18 | 4 | 3 | Yellow/orange |
| shipping_container | (missing — §9 `shipping_container`) | 2 | 22 | 5 | 3 | Red, west wall |
| crate_stack_01 | (missing — §9 `crate_stack`) | 36 | 4 | 2 | 2 | |
| crate_stack_02 | `crate_stack` | 38 | 22 | 2 | 2 | |
| pipe_stack_01 | (missing — §9 `pipe_stack`) | 8 | 26 | 4 | 2 | Steel pipes |
| pallet_01 | (missing — §9 `pallet_wood`) | 22 | 22 | 2 | 1 | |
| pallet_02 | `pallet_wood` | 24 | 22 | 2 | 1 | |
| scaffold_01 | (missing — §9 `scaffold`) | 44 | 4 | 4 | 5 | East wall scaffold |
| trailer_office | (missing — §9 `site_office_trailer`) | 44 | 24 | 6 | 4 | SE corner site office |
| cone_01..06 | (missing — §9 `traffic_cone`) | 12,14,18,30,32,40 | 14 (all) | 1 | 1 | Cones lining work zone |
| barrel_01..02 | (missing — §9 `barrel_orange`) | 4,6 | 14 | 1 | 1 | |

### 6.3 Construction NPC spawns

| id | sheet | x | y |
|----|-------|---|---|
| npc_worker_01 | (missing — §9 `worker_npc_sheet`; placeholder: any villain NPC sheet) | 20 | 12 |
| npc_foreman | `villain-npc-character-sprite-sheets/pixel-art-orange-haired-girl-npc-...png` | 46 | 26 |

---

## 7. Scene: `parade`

**Size:** 128 × 20 tiles. A wide horizontal strip running the full width south of the city.

### 7.1 Layers

- L0 fill: rainbow/pink parade road tile (**missing — §8 `parade_road_tile`**;
  use `pavement` as placeholder).
- L0 sidewalks: `stone_fill` rows at y=0..1 (north) and y=18..19 (south).
- L4 props (missing — §8): rainbow flags every 8 tiles along both sidewalks,
  balloons in clusters at x=20, 50, 80, 110.
- L5 spawns: scatter 6 NPCs from `pride-character-npc-sprite-sheets/` along the
  road centerline at y=10, x=12, 28, 48, 66, 88, 108.

### 7.2 Tents (far-left of parade)

| id | asset | x | y | w | h |
|----|-------|---|---|---|---|
| tent_white_01 | (missing — §9 `tent_white`) | 2 | 4 | 5 | 5 |
| tent_white_02 | `tent_white` | 10 | 4 | 4 | 4 |

### 7.3 Rainbow archway

| id | asset | x | y | w | h |
|----|-------|---|---|---|---|
| arch_rainbow | (missing — §9 `rainbow_arch`) | 60 | 4 | 8 | 8 |

### 7.4 Flags (every 8 tiles along both sidewalks)

| id | asset | x | y |
|----|-------|---|---|
| flag_n_01..16 | `parade_flag` (§9) | 4, 12, 20, 28, ..., 124 (step 8) | 1 |
| flag_s_01..16 | `parade_flag` | 4, 12, 20, 28, ..., 124 (step 8) | 18 |

### 7.5 Balloon clusters

| id | asset | x | y |
|----|-------|---|---|
| balloons_01 | `parade_balloons` (§9) | 20 | 8 |
| balloons_02 | `parade_balloons` | 50 | 8 |
| balloons_03 | `parade_balloons` | 80 | 8 |
| balloons_04 | `parade_balloons` | 110 | 8 |

### 7.6 Confetti / glitter overlay

Apply a sparse 1-tile decorative overlay (asset missing — §9 `confetti_overlay`)
at random positions across the road band y=2..17 — agent should place
~24 instances at deterministic positions: every 6th tile on x, alternating y=4
and y=14.

---

## 8. Scene: `secret_lab_interior`

**Size:** 40 × 28 tiles.

### 8.1 Layers

- L0 floor: gray machinery floor pulled from `lab_tileset` (use the floor
  region of `pixel-art-secret-lab-blue-gray-machinery-computer-wall-floor-tileset-x1-1184x736.png`;
  the agent should slice 16×16 tiles from the floor band of that sheet).
- L2 walls: north/east/west walls 2 tiles thick from same tileset's wall band.
- L3 machinery: place 4 console banks against the north wall at x=4, 12, 22, 30
  (each 4w × 3h).
- L3 door: tile (20, 27) at south wall — this is the exit trigger.
- L5 spawns: villain wizard at (20, 8) using
  `villain-npc-character-sprite-sheets/pixel-art-blue-robed-wizard-with-staff-npc-...png`.

---

## 9. Missing assets (flag list)

These are referenced above but **do not exist** in the current asset folders.
The agent should leave a 1×1 magenta debug tile (or the
`pixel-art-solid-mint-green-placeholder-tile-16x16.png`) at the placement, and
the asset should be sourced before final render.

| Slot | Used in | Notes |
|------|---------|-------|
| `fountain_sprite` | park | 4×4 ornamental fountain with water effect |
| `statue_sprite` | park | 2×3 humanoid statue on pedestal |
| `bench_park` | park | 2×1 wooden bench |
| `lamp_post` | suburb, city, park | 1×3 lamp |
| `mailbox` | suburb | 1×1 |
| `bldg_cafe` | city | ~10×6, awning + sign |
| `bldg_store` | city | ~10×6, "STORE" sign |
| `bldg_hospital` | city | ~10×6, "H" sign |
| `bldg_police` | city | ~10×6, blue "POLICE" sign |
| `bldg_apartment` | city | ~10×6 brownstone variants |
| `bldg_devcorp` | city | ~8×6, dark glass |
| `road_stripe_white` | city | 1×1 stripe overlay |
| `fence_chainlink` | construction | perimeter autotile |
| `vehicle_excavator` | construction | ~5×4 |
| `vehicle_bulldozer` | construction | ~4×3 |
| `vehicle_truck` | construction | ~4×3 |
| `traffic_cone` | construction | 1×1 |
| `parade_road_tile` | parade | 1×1 rainbow/pink ground |
| `parade_flag` | parade | 1×2 flag on pole |
| `parade_balloons` | parade | 2×3 balloon cluster |
| `bridge_wood` | suburb, park | 4×2 wooden footbridge |
| `pier_dock` | park | 4×3 wooden pier extending into water |
| `cattails` | park | 1×1 reed/cattail prop |
| `gate_wooden` | suburb | 2×1 fence gate sprite |
| `shed_small` | suburb | 3×3 outbuilding |
| `streetlamp_iron` | suburb, park, city | 1×3 iron lamp post |
| `car_static` | suburb, city | 4×2 parked car |
| `police_car` | city | 4×2 police cruiser |
| `fire_hydrant` | city | 1×1 |
| `trash_can` | city | 1×1 |
| `crosswalk_stripes` | city | 4×2 zebra-stripe overlay |
| `shipping_container` | construction | 5×3 red metal container |
| `crate_stack` | construction | 2×2 wood crate stack |
| `pipe_stack` | construction | 4×2 steel pipe pile |
| `pallet_wood` | construction | 2×1 wood pallet |
| `scaffold` | construction | 4×5 scaffolding rig |
| `site_office_trailer` | construction | 6×4 worker trailer |
| `barrel_orange` | construction | 1×1 |
| `worker_npc_sheet` | construction | 8-direction sprite sheet |
| `tent_white` | parade | 4×4 to 5×5 festival tent |
| `rainbow_arch` | parade | 8×8 archway |
| `confetti_overlay` | parade | 1×1 sparse decorative |
| `mailbox` | suburb | 1×1 |

---

## 10. Build order (instructions to the agent)

For **each scene** in this order — `suburb_north`, `park`, `city_main`,
`construction`, `parade`, `secret_lab_interior` — perform:

1. Allocate a tile grid of the scene's declared size; fill every cell with
   the L0 default for that scene.
2. Apply L0 overrides from the scene's "Layer 0" subsection (paths, plazas,
   water, road).
3. For every autotile (`*_at`), resolve edge tiles using the bitmask reference
   PNGs in `park-nature-terrain-and-tree-tiles/`
   (`pixel-art-autotile-bitmask-reference-diagram-blue-white-set-1-480x256.png`
   and `set-2`). The bitmask is computed from neighbors that share the same
   autotile ID.
4. Paint L1 decorations (sparse — only what is explicitly listed).
5. Paint L2 borders (tree-wall, hedges, fences). Borders use autotiles —
   resolve corner pieces from the bitmask reference.
6. Place L3 large objects from the scene's placement table, in the order
   listed. Each placement blits the asset at `(x*16, y*16)` with the asset's
   native pixel size.
7. Place L4 props.
8. Register L5 spawn points in the scene's actor manifest (do not blit; the
   game runtime instantiates them at runtime).
9. Save scene as `scenes/<scene_name>.tmx` (or your engine's equivalent),
   plus an actor-manifest JSON listing L5 spawns.

When the agent finishes a scene, render a thumbnail and stop. Do not begin the
next scene until the current one is approved. Scenes are independent; a defect
in one does not block the others.

---

## 11. Open decisions

These are not blockers — the spec is buildable as-is — but worth flagging:

- **House variants:** only `house_a` exists. All 9 placed houses currently use
  the same sprite. When variant sprites arrive, swap by `id` (the placement
  table is keyed so this is a search-and-replace, not a re-layout).
- **Indoor scenes for each suburban house:** not in scope yet. Add as
  `house_int_01..09` scenes later, using `house_int_tileset`.
- **Day/night lighting:** not in scope for layout; lighting is a runtime layer
  applied over the final render.

---

## 12. Feature audit — every visible item on the map image

This is the checklist. Each row is a thing visible in the source screenshot,
the scene + section it lives in, and a status flag. The agent (and you) can
walk this list top-to-bottom to confirm nothing was dropped.

Status legend:
- **PLACED** — coords + asset binding both present in the spec.
- **PLACEHOLDER** — coords present, asset is missing (§9). Renders as a debug
  tile until art arrives.
- **PARTIAL** — partially modeled (e.g. shape simplified, count reduced).

### Suburb (top-left + top of image)

| # | Visible feature | Scene | Spec section | Status |
|---|-----------------|-------|--------------|--------|
| 1 | Dense tree-wall border (N/E/W) | suburb_north | §3.3 | PLACED |
| 2 | "SECRET LAB HOUSE" main building | suburb_north | §3.4 (secret_lab) | PLACED (variant tag `dark_purple`) |
| 3 | Lab outbuilding / shed | suburb_north | §3.12 (lab_shed) | PLACEHOLDER |
| 4 | Curving stone driveway from lab to road | suburb_north | §3.11 | PLACED |
| 5 | Lab plot wooden fence | suburb_north | §3.12 | PLACED |
| 6 | Lab driveway gate | suburb_north | §3.12 (lab_gate) | PLACEHOLDER |
| 7 | Trees inside lab plot | suburb_north | §3.12 | PLACED |
| 8 | Bushes inside lab plot | suburb_north | §3.12 | PLACED |
| 9 | Top-row house: blue roof | suburb_north | §3.4, §3.14 (n_01) | PLACED + variant tag |
| 10 | Top-row house: brown roof | suburb_north | §3.4, §3.14 (n_02) | PLACED + variant tag |
| 11 | Top-row house: green roof | suburb_north | §3.4, §3.14 (n_03) | PLACED + variant tag |
| 12 | Top-row house: red-brown roof | suburb_north | §3.4, §3.14 (n_04) | PLACED + variant tag |
| 13 | Top-row house: dark-red roof | suburb_north | §3.4, §3.14 (n_05) | PLACED + variant tag |
| 14 | Top-row house: charcoal roof | suburb_north | §3.4, §3.14 (n_06) | PLACED + variant tag |
| 15 | Top-row house: small tan | suburb_north | §3.4, §3.14 (n_07) | PLACED + variant tag |
| 16 | Per-house white picket fence | suburb_north | §3.5 | PLACED |
| 17 | Per-house front-yard trees (×2) | suburb_north | §3.6 | PLACED |
| 18 | Per-house front-yard flowers | suburb_north | §3.6 | PLACED |
| 19 | Per-house mailbox at gate | suburb_north | §3.13 (mailbox_n_*) | PLACEHOLDER |
| 20 | Per-house driveway to road | suburb_north | §3.11 | PLACED |
| 21 | Asphalt road full-width with center stripe | suburb_north | §3.2 | PLACED (stripe asset placeholder) |
| 22 | "ROAD" label | n/a | debug-only | n/a |
| 23 | North + south sidewalk curbs | suburb_north | §3.2 | PLACED |
| 24 | Streetlamps along road (12 total) | suburb_north | §3.13 | PLACEHOLDER |
| 25 | Car on road | suburb_north | §3.13 (car_road_01) | PLACEHOLDER |
| 26 | Lower-suburb house #1 (brown) | suburb_north | §3.4 (s_01) | PLACED |
| 27 | Lower-suburb house #2 (tan) | suburb_north | §3.4 (s_02) | PLACED |
| 28 | Lower-suburb house #3 (small cottage) | suburb_north | §3.15 (s_03) | PLACED |
| 29 | Lower-suburb fences | suburb_north | §3.5 (rule applies) | PLACED |
| 30 | Bench in lower lawn | suburb_north | §3.13 (bench_lawn) | PLACEHOLDER |
| 31 | Dirt path leading south to park | suburb_north | §3.2 | PLACED |
| 32 | Creek flowing through lower suburb | suburb_north | §3.9 | PLACED |
| 33 | Footbridge over creek | suburb_north | §3.10 (bridge_01) | PLACEHOLDER |
| 34 | Scattered trees in lawn areas | suburb_north | (use rule §3.6 + park's §4.5 analogy — call out 6 extras) | PARTIAL — see §3.6 rule |
| 35 | Flowers + bushes in lawn | suburb_north | (covered under per-house rule) | PARTIAL |

### Park (middle of image)

| # | Visible feature | Scene | Spec section | Status |
|---|-----------------|-------|--------------|--------|
| 36 | Tree-wall border around park | park | §4.1 | PLACED |
| 37 | "POND" label | n/a | debug-only | n/a |
| 38 | Kidney-shaped pond | park | §4.1, §4.2 | PARTIAL (rectangle approximation; shore autotile softens) |
| 39 | Pond shore stones | park | §4.6, §4.9 (rocks 01-03) | PLACED |
| 40 | Pond cattails / reeds | park | §4.9 | PLACEHOLDER |
| 41 | Wooden pier extending into pond | park | §4.9 (pier_dock) | PLACEHOLDER |
| 42 | Creek flowing out of pond | park | §4.8 | PLACED |
| 43 | Bridge over creek (park side) | park | §4.8 (bridge_park_01) | PLACEHOLDER |
| 44 | "FOUNTAIN" label | n/a | debug-only | n/a |
| 45 | Octagonal stone fountain plaza | park | §4.10 (corner-clip) | PLACED |
| 46 | Central fountain w/ water spurt | park | §4.4 (fountain) | PLACEHOLDER |
| 47 | Fountain plaza lamps (×4 corners) | park | §4.10 | PLACEHOLDER |
| 48 | Fountain plaza benches (×4) | park | §4.10 | PLACEHOLDER |
| 49 | Fountain plaza flower beds | park | §4.10 | PLACED |
| 50 | "STATUE" label | n/a | debug-only | n/a |
| 51 | Statue plaza (small stone) | park | §4.1 | PLACED |
| 52 | Humanoid statue on pedestal | park | §4.4 (statue) | PLACEHOLDER |
| 53 | Flowers at statue base | park | §4.11 | PLACED |
| 54 | Bench facing statue | park | §4.11 | PLACEHOLDER |
| 55 | "OAK TREE" label | n/a | debug-only | n/a |
| 56 | Big oak landmark tree | park | §4.4 (oak_landmark) | PLACED (real `Oak TREE.png`) |
| 57 | Yellow dirt path network | park | §4.3 | PLACED |
| 58 | Scattered park trees (8) | park | §4.5 | PLACED |
| 59 | Scattered park bushes (7) | park | §4.12 | PLACED |
| 60 | Park benches (3 generic) | park | §4.6 | PLACEHOLDER |
| 61 | Wandering chicken + chicks | park | §4.7 | PLACED |
| 62 | Squirrel | park | §4.7 | PLACED |

### City (bottom-center to bottom-right)

| # | Visible feature | Scene | Spec section | Status |
|---|-----------------|-------|--------------|--------|
| 63 | "CITY AREA" label | n/a | debug-only | n/a |
| 64 | Pavement everywhere | city_main | §5.1 | PLACED |
| 65 | Block sidewalks | city_main | §5.1 | PLACED |
| 66 | Cafe (red awning) | city_main | §5.2 (B-NW) | PLACEHOLDER |
| 67 | General Store ("STORE" sign) | city_main | §5.2 (B-NM) | PLACEHOLDER |
| 68 | Hospital ("H" sign) | city_main | §5.2 (B-NE) | PLACEHOLDER |
| 69 | Apartments / brownstones (rows) | city_main | §5.2 (B-MW, B-MM) | PLACEHOLDER |
| 70 | Police HQ | city_main | §5.2 (B-ME) | PLACEHOLDER |
| 71 | Development Corp building | city_main | §5.2 (B-SE) | PLACEHOLDER |
| 72 | N-S streets (×3) | city_main | §5.3 | PLACED |
| 73 | E-W street | city_main | §5.3 | PLACED |
| 74 | Lane stripes | city_main | §5.3 | PLACEHOLDER (`road_stripe_white`) |
| 75 | Pedestrian crosswalks | city_main | §5.5 | PLACEHOLDER |
| 76 | Block-corner streetlamps (×14) | city_main | §5.6 | PLACEHOLDER |
| 77 | Sidewalk trees | city_main | §5.7 | PLACED |
| 78 | Fire hydrants | city_main | §5.7 | PLACEHOLDER |
| 79 | Trash cans | city_main | §5.7 | PLACEHOLDER |
| 80 | Parked cars (×3) | city_main | §5.8 | PLACEHOLDER |
| 81 | Police car at HQ | city_main | §5.8 | PLACEHOLDER |
| 82 | Police officer NPC | city_main | §5.4 | PLACED |
| 83 | Police sergeant NPC | city_main | §5.4 | PLACED |
| 84 | Villain NPC | city_main | §5.4 | PLACED |

### Construction (bottom-left)

| # | Visible feature | Scene | Spec section | Status |
|---|-----------------|-------|--------------|--------|
| 85 | "CONSTRUCTION AREA" label | n/a | debug-only | n/a |
| 86 | Brown dirt fill | construction | §6.1 | PLACED |
| 87 | Chain-link perimeter fence | construction | §6.1 | PLACEHOLDER |
| 88 | Yellow excavator | construction | §6.2 | PLACEHOLDER |
| 89 | Blue bulldozer | construction | §6.2 | PLACEHOLDER |
| 90 | Yellow dump truck | construction | §6.2 | PLACEHOLDER |
| 91 | Red shipping container | construction | §6.2 | PLACEHOLDER |
| 92 | Crate stacks | construction | §6.2 | PLACEHOLDER |
| 93 | Steel pipe stack | construction | §6.2 | PLACEHOLDER |
| 94 | Wooden pallets | construction | §6.2 | PLACEHOLDER |
| 95 | Scaffolding | construction | §6.2 | PLACEHOLDER |
| 96 | Site-office trailer | construction | §6.2 | PLACEHOLDER |
| 97 | Traffic cones | construction | §6.2 | PLACEHOLDER |
| 98 | Orange barrels | construction | §6.2 | PLACEHOLDER |
| 99 | Dirt mound | construction | §6.1 | PLACED |
| 100 | Worker NPC | construction | §6.3 | PLACEHOLDER (sheet missing) |
| 101 | Foreman NPC | construction | §6.3 | PLACED |

### Parade (very bottom strip)

| # | Visible feature | Scene | Spec section | Status |
|---|-----------------|-------|--------------|--------|
| 102 | "PRIDE PARADE AREAS" label | n/a | debug-only | n/a |
| 103 | Pink/purple/rainbow road surface | parade | §7.1 | PLACEHOLDER |
| 104 | North + south sidewalks | parade | §7.1 | PLACED |
| 105 | White festival tents (×2) | parade | §7.2 | PLACEHOLDER |
| 106 | Rainbow archway | parade | §7.3 | PLACEHOLDER |
| 107 | Rainbow flags lining sidewalks (×32) | parade | §7.4 | PLACEHOLDER |
| 108 | Balloon clusters (×4) | parade | §7.5 | PLACEHOLDER |
| 109 | Confetti / glitter overlay | parade | §7.6 | PLACEHOLDER |
| 110 | Pride NPCs marching (×6) | parade | §7.1 | PLACED |

### Indoor (not on map image — added for completeness)

| # | Feature | Scene | Spec section | Status |
|---|---------|-------|--------------|--------|
| 111 | Lab floor | secret_lab_interior | §8.1 | PLACED (sliced from tileset) |
| 112 | Lab walls | secret_lab_interior | §8.1 | PLACED |
| 113 | Console banks (×4) | secret_lab_interior | §8.1 | PLACED |
| 114 | Exit door | secret_lab_interior | §8.1 | PLACED |
| 115 | Wizard NPC | secret_lab_interior | §8.1 | PLACED |

### Audit summary

- **Total features catalogued:** 115.
- **PLACED with real assets:** 51.
- **PLACED with placeholder/debug tile (asset missing — §9):** 56.
- **PARTIAL approximations:** 4.
- **Labels (not rendered, debug only):** 6 (counted but not built).

If a feature you can see in the screenshot does not appear in this audit
table, it has been missed — flag it and the spec will be patched. The audit
is the single source of truth for "did we cover it?".
