My file tools are hitting an error right now, so I'll give you the whole handoff document right here — copy everything below the line and paste it to Claude Code as your first message (or save it as HANDOFF.md in your project folder, which is even better since Claude Code can read it there).

PARK FRIENDS — Project Handoff Brief for Claude Code
Context
I'm building an EarthBound-style RPG called Park Friends. The project already exists in a folder on this computer — first task: explore my project folder, read the code and assets, and identify the language/engine, tile size, resolution, map format, and how tilesets/sprites load, before changing anything.
My two problems:
	1	The game doesn't look right — likely mixed art styles from asset packs, no unified palette, missing edge/transition tiles, wrong projection.
	2	I want AI-generated sprites/tiles instead of packs, generated as code/pixel-data → PNG, not via image-generation models (they can't hold a grid, palette, or frame consistency).
Everything below is the plan. Match new work to this doc AND to conventions already in my project.

PART 1 — Design pillars (what makes it "EarthBound")
	•	Setting inversion: JRPG grammar in mundane suburbia. Weapons = bats/yo-yos; healing = food; save via phone call; money via ATM. Every JRPG trope gets a mundane absurd translation, consistently.
	•	Humor register: deadpan, melancholy-adjacent absurdism — one comedic voice across all items, enemies, NPC lines.
	•	Rolling HP odometer: HP scrolls down over real time; you can heal or win before it hits 0.
	•	Visible overworld enemies (no random encounters): chase when you're weak, flee when strong, swirl transition, instant auto-win vs far-weaker enemies.
	•	Psychedelic animated battle backgrounds (per-scanline distortion + palette cycling).
	•	Oblique-projection maps, one continuous world.
	•	Inventory friction as design: tiny per-character inventories, key items take slots.
	•	Defeat = respawn at last save with half money, not game over.
	•	Scope: vertical slice first — one area (the park), one dungeon, one boss, full battle loop. Load-bearing systems (rolling HP, dialogue/scripting, one complete battle) before anything else.

PART 2 — Technical architecture (raw code, no engine)
2.1 Platform layer
	•	Fixed-timestep loop: 60Hz logic, accumulator pattern, delta clamping.
	•	Input edge detection (pressed/released/held), rebinding table.
	•	Audio: ring-buffer mixer feeding the OS callback.
	•	Memory: frame arena + entity pools + permanent asset arena. No per-frame heap allocation.
	•	Load ALL assets at boot (SNES-scale = a few MB). Zero streaming, zero load screens.
	•	Fixed-point positions (8.8 pixel+subpixel) → deterministic, replay-testable.
2.2 Core decision: indexed-color software rendering
Render everything to an 8-bit palette-index framebuffer; convert to RGB once per frame:
uint8_t  fb[224][256];      // the whole game renders here
uint32_t palette[256];      // index -> ARGB
uint32_t out[224][256];     // converted once per frame

for (int i = 0; i < 256*224; i++)
    ((uint32_t*)out)[i] = palette[((uint8_t*)fb)[i]];
Why: 57,344 pixels = sub-millisecond full redraws (never render-bound), and all signature effects become palette-array writes:
// full-screen fade: lerp the palette, touch zero pixels
for (int i = 0; i < 256; i++)
    palette[i] = lerp_color(black, master_palette[i], fade_t);

// palette cycling (water shimmer, bg animation): rotate a sub-range
uint32_t tmp = palette[cycle_start];
memmove(&palette[cycle_start], &palette[cycle_start+1], (cycle_len-1)*4);
palette[cycle_start + cycle_len - 1] = tmp;
Flash = white palette for 2 frames. Dark cave = dimmed palette. "Corrupted" area = planned palette swap.
2.3 Present: one texture, integer scale
Upload the 256×224 buffer as one texture per frame, one quad, nearest-neighbor only, integer scaling only:
scale = min(win_w / 256, win_h / 224);        // integer only
dst_w = 256 * scale; dst_h = 224 * scale;      // center + letterbox
Non-integer scale or bilinear filtering = instant "cheap emulator" look. Non-negotiable.
2.4 Tilemap renderer — full redraw, visible range only
int tx0 = cam_x >> 4, ty0 = cam_y >> 4;            // 16px tiles
int fine_x = cam_x & 15, fine_y = cam_y & 15;

for (int ty = 0; ty <= 14; ty++)                    // 224/16 = 14 (+1)
for (int tx = 0; tx <= 16; tx++) {                  // 256/16 = 16 (+1)
    uint16_t tile = layer[ty0+ty][tx0+tx];
    blit_tile(tile, tx*16 - fine_x, ty*16 - fine_y);
}
Blit with color-key transparency:
for (int y = y0; y < y1; y++)
for (int x = x0; x < x1; x++) {
    uint8_t p = src[y*16 + x];
    if (p) fb[dy+y][dx+x] = p;    // index 0 = transparent
}
~1000 blits/frame across 3–4 layers = trivial; no dirty rects or caching. Draw order: background tiles → below-entity tiles → Y-sorted entities (sort by feet-Y, insertion sort) → overhang layer AFTER entities (awnings, tree canopies) → fx → UI.
2.5 Battle backgrounds — HDMA emulation (the crown jewel)
for (int y = 0; y < 224; y++) {
    int off_h = (int)(A1 * sinf(w1 * y + f1 * t));                     // horizontal wave
    int off_i = (int)(A2 * sinf(w2 * y + f2 * t)) * ((y&1)? 1 : -1);   // interlaced "wobbly jelly"
    int off_v = (int)(A3 * sinf(w3 * t));                              // vertical scroll/compress

    int src_y = (y + scroll_y + off_v) & (BG_H - 1);                   // power-of-2 wrap
    for (int x = 0; x < 256; x++)
        fb[y][x] = bg[src_y][(x + off_h + off_i + scroll_x) & (BG_W - 1)];
}
	•	Params per axis: amplitude, frequency, phase-speed. Interlaced variant = the signature liquid shimmer.
	•	Layer two backgrounds with independent distortion; fake transparency via precomputed 256×256 blend LUT or checkerboard dither.
	•	Run palette cycling on the bg range simultaneously. Store backgrounds as small power-of-two patterns (wrap = bitmask).
	•	Distortion intensity telegraphs threat: gentle blue weaves = trash mobs, fast strobing red = bosses.
	•	Swirl transition: per-row sine, amplitude ramps up frame over frame, palette fades green/red/blue by encounter difficulty.
2.6 State machine
Explicit stack: TITLE → OVERWORLD (base) with MENU / DIALOGUE / BATTLE / CUTSCENE / SHOP pushed on top. Each state: enter/exit/update/draw/input. Only top state gets input; define per-state whether lower states draw (menu over dimmed overworld: yes) or update (no). Transitions owned by the machine so nothing half-runs during fades.
2.7 Entities & world
	•	Fixed entity pool, generational handles (index+generation), no inter-entity pointers.
	•	Tile collision: solid flags, AABB sweep, resolve X and Y separately for wall-slide.
	•	Trigger volumes with enter-latch: doors (target map+pos+facing), cutscenes, map edges.
	•	Party snake: ring buffer of leader's past positions sampled every N px; followers read at fixed offsets; flush on teleport.
	•	Overworld enemies: idle → notice (radius/LOS) → chase-or-flee by level vs party average; relative facing at contact decides front/back/surprise.
	•	Camera: follow leader, pixel snap, clamp to map bounds.
2.8 Scripting & flags (the soul)
	•	Global flag bitset + int variables. Every quest step, chest, changed NPC line = flags. Enforce a naming convention + registry file.
	•	Script interpreter (small DSL/bytecode). Ops: show text, yes/no, jump/label, set/check flag, give/take item (handle full inventory!), give money, start battle, warp, move entity along path (blocking), face, sound/music, shake/flash, wait, open shop, heal, call/return.
	•	Coroutine semantics: scripts span frames; save program counter + op progress in a script context struct.
	•	Text control codes: {PLAYER}, {FAVORITE_THING}, pauses, per-char blip, page breaks. Player-named characters means string templating from day one. All text through a string-table with IDs.
2.9 Data-driven everything
Enemies, items, PSI, shops, encounters, dialogue in data files, compiled with build-time reference validation (every ID/label/warp/jump must resolve — fail the build, not the runtime).
	•	Enemy record: HP, PP, off/def/speed/guts, exp, money, drop+rate, weighted action list + AI hooks (low-HP heal/call-help), elemental resistance tiers, sprites, battle text, overworld behavior.
	•	Item record: type, slot, per-character equip whitelist, stat effects, battle/field usability, price.
	•	Stats: HP/PP/Offense/Defense/Speed/Guts/Vitality/IQ/Luck; per-character EXP tables; random growth-weighted level-ups.
2.10 Battle system
	•	Phases: swirl → "X and cohorts attacked!" → command input → speed-sorted resolution (with random factor) → outro.
	•	Commands: Bash/Goods/Auto Fight/PSI/Defend/Run.
	•	Damage ≈ 2×Offense − Defense ± spread; miss from speed differential; SMAAAASH!! crits from Guts (ignore defense, big graphic + sound); Guts 1-HP survive chance.
	•	PSI tiers (α/β/γ/Ω), per-enemy resistance multipliers, multi-target scaling.
	•	Status: poison, paralysis, sleep, crying, feeling strange (reversed commands), mushroomization (persists overworld), homesickness (cured by calling mom).
	•	Shields: physical/PSI, absorb vs reflect, per-hit decrement.
	•	Rolling HP: displayed HP scrolls toward target at fixed/tiered rate; death checks displayed value; scroll FREEZES the moment the last enemy dies; heals may set both instantly. Render digits as vertical 0–9 strips with sub-digit y-offset (odometer wheels).
	•	Auto-win check BEFORE the swirl. Run = speed-based, guaranteed after N failures. Rewards: EXP split among conscious members, money to bank, drop rolls.
2.11 Audio
N-channel mixer, per-channel volume/pan; loop points mid-track (intro → loop); battle crossfade/duck; text blip tied to typewriter reveal (skip spaces); SFX priority/voice stealing.
2.12 Saves
Serialize: flags, variables, party stats/EXP/inventory/equipment/PSI, money+bank, map+pos+facing, play time. Versioned binary (magic+version, migration), CRC32, two-slot mirroring, atomic write (temp → flush → rename).
2.13 Debug tools — build EARLY
Noclip/free camera, flag inspector/setter, warp menu, battle tester (fight any encounter ID), give-item console, frame-time overlay, script single-step. Seeded PRNG (separate gameplay/cosmetic streams); input-replay regression harness.
2.14 Build order
	1	Platform + framebuffer + input + fixed loop
	2	Tilemap render + collision + party movement w/ follower buffer
	3	Map format + doors + camera
	4	Text box + font + script interpreter + flags
	5	Menus + inventory + party data
	6	Battle end-to-end (1 enemy) → rolling HP → PSI/status
	7	Battle backgrounds + transitions + audio
	8	Saves
	9	Debug tools (threaded through from step 2)
	10	Content tooling, then content
The two genuinely hard parts: script coroutine semantics and rolling HP × battle-end timing.

PART 3 — Aesthetic bible
3.1 Projection (the most identifying rule)
Oblique projection. Ground seen from ~45° above but NO perspective convergence, NO horizontal foreshortening. Building fronts drawn dead-on at full height; roofs/tops as 45° parallelograms sheered in one consistent diagonal direction per map (EB sheers up-right). Roads/fences run only horizontal or that one diagonal. Characters drawn plain front/back/side — the clash is the charm. Diagonals stair-step cleanly within 16px tiles.
3.2 Color
	•	High-key, saturated, pastel-leaning — default mood is "sunny Saturday morning." Flat fills, minimal gradients, sparse dithering.
	•	Per-area palette chord (4–6 dominant hues) enforced on every tile in that area — region should be identifiable from a 32×32 crop.
	•	Emotion via palette: creepy = drained saturation, dream = pink, night = blue+neon, horror = red-on-black. Plan "corrupted" palette-swap variants up front (free in indexed color).
	•	Master palette ~128–192 colors total.
3.3 Tile rules
	•	Selective outlines: trees/signs/building silhouettes get dark brown/navy outlines; ground fields get NONE.
	•	One hard-edged shadow tone per material; legibility over physics. Small dark ellipse drop-shadows under characters/objects.
	•	Embrace repetition: same grass tile ×200, variant tiles at 5–10%, 4–8 detail pixels per tile max. Cleanliness IS the style.
3.4 Character sprites ("clay figure" rule)
	•	~16×24. Big round head (~40%), dot eyes, no mouths. Personality = silhouette + color blocking.
	•	Black outlines on characters (unlike scenery). 2-frame walk cycles + idle — the stiff toddle is the charm; don't smooth it. 8 directions for party, 4 for NPCs.
	•	NPC variety = one base body + head/hat/clothes swaps + palette swaps — the authentic method AND the efficiency plan.
3.5 Enemy art — deliberately a DIFFERENT style
Large (32–100px), front-facing, completely static portraits, soft rounded airbrush-style shading (claymation/clip-art register). Mundane-object surrealism + deadpan names. No animation: feedback = screen shake, palette flash, sprite flicker/invert on hit, vertical mosaic dissolve on death.
3.6 Battle composition
No floor, no party sprites — enemies float on the distortion background; party = name/HP/PP cards at bottom. Card nudges up when acting, shakes when hit. SMAAAASH = big graphic + shake. PSI = full-screen geometric palette overlays (rings, starbursts, floods).
3.7 UI & typography
	•	Font: rounded, friendly, slightly wide bitmap sans — gentle, NOT crunchy 8-bit. Dark text on light windows.
	•	Window flavors (Plain/Mint/Strawberry/Banana/Peanut): 9-slice border, flat pastel fill, player-selectable — one palette table each.
	•	Windows pop in bluntly — no easing, no sliding, no transparency. Bouncing cursor, soft blips, per-char text tick.
3.8 Motion: the deadpan principle
Constant-speed pixel-snapped movement, no easing. Cutscenes = walk, face, text, tiny emote popups ("!"). Big beats via palette shift + music change + flash. 95% deadpan, 5% fireworks.
3.9 Tone
Draw the suburbs like a tourist map of somewhere magical; let ~3% be quietly wrong with zero visual fanfare. Never make spooky tiles overtly spooky — menace and whimsy share the same sunny flatness.

PART 4 — AI asset generation strategy
Do NOT use image-generation models for tiles/sprites — they fail at grid discipline (uneven fake "pixels," anti-aliasing), cross-generation consistency, seamless tiling, and frame coherence.
Instead: generate pixel art as code — arrays of palette indices rendered to exact PNGs by script. Guarantees on-grid pixels, one shared palette, and walk frames that are literally the same drawing with legs moved. Iterate under art direction ("greener grass, bigger head").
The real production math (not 2,048 unique tiles):
	•	~40 base tiles per area: grass + variants, path + 8 edge pieces, fence ×4, tree ×4, building wall/roof/door/window pieces, props (bench, lamppost, flowerbed, trash can)
	•	× palette swaps (night park, autumn park, corrupted park = free)
	•	× programmatic assembly (script combines building pieces into whole buildings)
	•	Characters: 1 base body (~12 sprites: 4 dir × 2 walk + idle) → 20 characters via head/hair/hat/color swaps. Consistent by construction.

PART 5 — First tasks, in order
	1	Explore the Park Friends folder. Identify language/engine, tile size, resolution, map format, asset loading, current asset inventory. Report before editing.
	2	Diagnose the look against Part 3: mixed pack styles? no unified palette? missing edge/transition tiles? non-integer scaling or bilinear filtering? wrong/mixed projection? missing overhang layer, Y-sorting, drop shadows?
	3	Propose a fix plan mapping Part 2 onto what exists — adapt rather than rewrite, but flag anything at odds with the indexed-palette / integer-scale / data-driven approach.
	4	Generate the first asset batch (Part 4) as code-rendered PNGs in my engine's format, and wire the park tileset into a test map so I can see it running.
	5	Set up debug tools early (warp, flag inspector, battle tester) per 2.13.
	6	Ask me about the Park Friends story and who the 20 characters are before designing sprites — design needs identity.

That's the complete brief. One tip for using it: save it as HANDOFF.md inside your Park Friends folder before you start Claude Code, then your first message can just be "Read HANDOFF.md and start with Part 5, task 1." It'll have the full context sitting right in the project. Good luck — this is going to be a fun one to build.
