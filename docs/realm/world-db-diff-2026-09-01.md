# pfQuest vs. this realm's world database — 2026-09-01

Realm note. "The realm" below is the VMaNGOS server this fork of pfQuest is used with;
file and commit references outside `docs/` belong to that server's repository, not to this one.

**Verdict: pfQuest's shipped vanilla database is current for this realm.** Quest coverage is
exact, quest relations are within four rows, and the spawn data agrees to 75% on exact counts
with every divergence explained. Four small defects fell out, three in the addon and one in
the world DB.

## Method

The extractor route in the roadmap (`toolbox/extractor.lua` against the local DBs) was not
used: it needs Lua plus `luasql-mysql` on a Unix toolchain, and this machine has neither Lua
nor a WSL distribution installed. Instead the shipped `db/*.lua` files were parsed directly
and compared against the `mangos` database.

`db/*.lua` uses a tiny, regular subset of Lua — nested table constructors, integer and string
keys, positional values, numeric and quoted-string scalars — so a tokeniser for that subset is
exact. The scripts below were throwaway and are not kept; they are listed so the method is
reconstructable:

| Script | What it does |
| --- | --- |
| `pfq_parse.py` | Parses a pfQuest `db/*.lua` table literal into Python data |
| `pfq_quest_diff.py` | Field-by-field quest comparison against `quest_template` and the relation tables |
| `pfq_patch_probe.py` | Decides whether a field mismatch is staleness or patch-row selection |
| `pfq_spawn_diff.py` | Spawn-count comparison against `creature` and `gameobject` |

## Two traps that made the first pass wrong

Both are worth remembering, because each one produced a confident and completely false result.

**`quest_template` is keyed `(entry, patch)`.** A plain `COUNT(*)` gives 4727 where there are
only 4433 quests, and the surplus 294 rows are patch variants. An entry can be reused for
unrelated content between patches — 172 is "Ambushed In The Forest" at patch 0 and "Children's
Week" at patch 2 — so comparing against the wrong row invents mismatches wholesale. The
roadmap's "4433 vs 4727 gap" was this artefact and is withdrawn.

**`creature` has `id2` through `id5`.** They hold alternative entries for a randomised spawn
point. Counting only `id` reported Defias Looter, Sand Skitterer and Plaguebat as having zero
spawns and produced an alarming "309 lootable creature types never spawn, 47 quests blocked".
Counting all five columns gives them 84, 156 and 137 spawns. There is no such gap. Any future
query against `creature` must union all five columns.

## Quests

Filtered to `patch <= 10` to match `WowPatch = 10` in `mangosd.conf`.

| Check | Result |
| --- | --- |
| Quest entries | 4433 in pfQuest, 4433 in the world DB, **identical ID sets** |
| `end.U` — ender creature | 0 mismatches |
| `start.O` / `end.O` — quest-giving objects | 0 mismatches |
| `start.I` — quest-starting items | 0 mismatches |
| `start.U` — starter creature | **4 mismatches** |
| `lvl`, `min`, `class` | every one of the 4433 matches *some* patch row |
| `race` | 4432 of 4433 match some patch row |

The 62 `lvl` and 28 `min` "mismatches" against the highest patch row are entirely
patch-selection: pfQuest's extractor does not pick the same row this server does. `pfq_patch_probe.py`
confirms every value it ships exists in some patch row of the same quest. Nothing is stale.

`pre` (prerequisite chains) was not compared — worth adding if this is ever re-run.

### Defect 1 — pfQuest omits three quest starters

| Quest | Title | Realm's starter | pfQuest |
| --- | --- | --- | --- |
| 2985 | Call of Water (shaman) | Swart (3173) | no `start` block |
| 2986 | Call of Water (shaman) | Narm Skychaser (3066) | no `start` block |
| 5927 | Heeding the Call (tauren druid) | Innkeeper Gryshka (6929) | no `start` block |

Not a stale-data problem: pfQuest lists the *same two trainers* as starters for the sibling
quests "Call of Fire" (2983, 2984). It simply lost the Call of Water rows. In game the addon
will not show where to pick these three up. Upstream bug, worth reporting to shagu/pfQuest.

### Defect 2 — quest 7462 has no questgiver on this realm — **FIXED 2026-09-01**

Migration `sql/migrations/20260901104108_world.sql`, applied and verified; commit `8dc947c25`.

`The Treasure of the Shen'dralar` (7462, Dire Maul) has `PrevQuestId = 7461` and a gameobject
turn-in (179517), but **no row in `creature_questrelation`, `gameobject_questrelation`, or
`item_template.start_quest`.** Nothing offers it, and `NextQuestId` on 7461 is 0, so the chain
does not carry it either. It looks unobtainable here.

pfQuest has it right: it lists Shen'dralar Ancient (14358) as the starter, which is also the
NPC that starts *and* ends the prerequisite 7461. The fix is a one-row insert:

```sql
INSERT INTO creature_questrelation (id, quest, patch) VALUES (14358, 7462, 1);
```

Justification for touching only this one: **173 quests here have no questgiver of any kind**, so
a missing relation is not by itself a fault — most of that set is removed or unused content.
pfQuest names a starter for **exactly one** of those 173, and it is 7462. `Player::GetNextQuest`
(`src/game/Objects/Player.cpp:12804`) confirms the chain cannot supply it: it only returns a
follow-up the questgiver already holds in its relation map. Starterless count is now 172.

### Defect 3 — quest 7487 race restriction — **WITHDRAWN, not a bug**

`Attunement to the Core` (7487) has `RequiredRaces = 178` (Orc, Undead, Tauren, Troll) because
**it is the Horde half of a faction pair**: 7848 is the Alliance copy with the same title and
`RequiredRaces = 77`. 178 and 77 are the two standard faction masks in this database, carried
by 215 and 217 quests respectively. The world DB is right and pfQuest is the one dropping the
restriction. Nothing to fix.

Worth noting the same query showed 7487 also has no questgiver — it is one of the 172, and
pfQuest does not name a starter for it either.

## Spawns

`creature` and `gameobject`, continent maps (0, 1), `patch_min <= 10 <= patch_max`, unioning
`id` through `id5`.

| | Creatures | Gameobjects |
| --- | --- | --- |
| pfQuest entries with at least one location | 6713 | 6261 |
| Realm entries spawned | 7689 | 7950 |
| Exact spawn-count agreement | 75.3% | 80.0% |
| pfQuest lists more than the realm spawns | 20.6% | 16.8% |
| pfQuest lists fewer | 4.1% | 3.2% |
| pfQuest located but realm never spawns | 63 entries / 261 locations | 5 entries / 7 locations |

Total locations: pfQuest 71159, realm 66069 continent spawns — within 7%.

Every category of divergence is explained:

- **pfQuest blank where the realm spawns something — 1039 entries, 97.6% instance-only.**
  The vanilla addon does not map dungeon interiors, so instance creatures carry an empty
  `coords` list by design.
- **pfQuest located but never spawned — 63 entries.** Summon- and event-derived positions the
  extractor computes from the summoner's location. All ten quests that name one are of that
  kind: the warlock "The Binding" demons (5676, 5677, 6268), Shy-Rotam (10737), Darrowshire
  Spirit (11064), Number Two (15554).
- **The 5 gameobject entries are not in `gameobject_template` at all** (300000, 3000491 and
  similar) — pfQuest artefacts, not realm gaps.
- **Count differences** come from pfQuest rounding coordinates to 0.1% of a zone, which merges
  spawns standing close together.

## Template coverage

| | pfQuest only | World DB only |
| --- | --- | --- |
| Creatures | 4 (420, 15547, 21000, 21010) | 0 |
| Items | 5 (20470, 20472, 20474, 20482, 20483) | 0 |
| Gameobjects | 141, mostly TBC-range ids (181488+, 182013+) | 3 |

The three world-DB-only gameobjects are traps — Naxx Teleporter trap (129), Ghost Saber Trap
(12653), The Toxic Fogger (19586) — which pfQuest excludes deliberately. The pfQuest-only
entries do not exist on this realm and the addon renders them as `[?]`, which is its
documented behaviour.

## Loot — `items.lua` and `refloot.lua`

Compared by reproducing exactly what `toolbox/extractor.lua` does, so a difference means the
two databases disagree rather than the two tools reading the schema differently. Script:
`pfq_loot_diff.py`, with `pfq_loot_cause.py` for the follow-up.

| Block | Owners with data | Exact | Source set differs | Value differs |
| --- | --- | --- | --- | --- |
| `items.U` creature drops | 3161 | **95.22%** | 86 | 65 |
| `items.O` object loot | 2565 | **98.28%** | 42 | 2 |
| `items.R` reference loot | 5135 | **99.81%** | 10 | 0 |
| `items.V` vendors | 1931 | **99.95%** | 1 | 0 |
| `refloot.U` creatures | 584 | **98.97%** | 6 | 0 |
| `refloot.O` objects | 22 | 18 of 22 | 4 | 0 |

### Two more traps, both of which faked a large gap

**`mincountOrRef < 0` means the `item` column is not an item.** It holds a
`reference_loot_template` id — that is the whole reference-loot mechanism, and the extractor's
own refloot pass proves it by querying `creature_loot_template WHERE mincountOrRef < 0 AND
item = <reference entry>`. Treating those rows as item drops manufactured **28344 phantom
(item, creature) pairs across 581 "items"**, which read as a catastrophic pfQuest gap. The
extractor never hits this because it iterates `item_template` and can only emit real items.
Both filters are now in `build_expected()`.

**Lua's `round` is half-up, Python's is half-to-even.** `extractor.lua` computes
`math.floor(x * 10^n + 0.5) / 10^n`. Using Python's `round` reported 237 spurious last-digit
chance mismatches (12.47 vs 12.46). `_lua_round` reproduces the Lua behaviour.

### Defect 4 — pfQuest is missing quest-item drop sources

180 `(item, creature)` rows across **82 items** that this realm has and pfQuest does not.
**Every single one is a quest drop** (`ChanceOrQuestChance < 0`) — a single coherent cause,
not scatter.

- **16 items where pfQuest lists no creature source at all**: 895, 896, 2477, 4610, 5220,
  5389, 5681, 6927, 7271, 7333, 7679, 7680, 11222, 11507, 20018, 20021. Worgen Skull and
  Worgen Fang are `{}` in `items.lua` while the realm drops them from six Nightbane worgen.
- **66 items where pfQuest lists some sources but not all**: Gnoll Paw (725) has 12 of the
  realm's 15, Tough Wolf Meat (750) 4 of 6, Rot Blossom, Skeleton Finger, Fel Moss, Hillsbrad
  Human Skull and so on.

**68 quests require one of these 82 items.** For those, the addon will either point at fewer
mobs than actually drop the item, or at none.

The reverse direction is negligible: 9 rows over 4 items that pfQuest has and the realm lacks.

### Everything else in the loot data is noise

- **65 `items.U` chance values differ** — these are the extractor's container quirk. Its item
  loop rebinds `entry` to each *container* of the item being scanned and rewrites that
  container's chances scaled by the container's own drop rate; whichever outer iteration runs
  last wins. The tell is exact halving (0.18 vs 0.36, 0.21 vs 0.42) and it affects only
  displayed percentages, never which mob to kill.
- **`items.O`**: 18 object sources missing over 13 items; 79 extra over 32 items, of which 8
  distinct object ids are ≥ 200000 (300000, 300203, 300400-300405) and exist in no
  `gameobject_template` here — pfQuest artefacts, the same family as the five phantom
  gameobject entries found earlier.
- **`items.R`**: 10 items where pfQuest names reference 100 and this realm names reference 1.
  Reference-id renumbering between the two databases.
- **`items.V`**: one item, 6217, with a vendor (5138) pfQuest has and the realm does not.
- **`refloot`**: 6 references missing creatures 10390, 10391, 1063; the four object
  differences are the 3004xx phantoms again.

## Left open

- `pre` / prerequisite chains not compared.
- Coordinate *positions* not compared, only counts. Doing so needs the client's WorldMapArea
  transform to convert world coordinates to zone percentages.
- Locale directories (9 languages) not compared against the `locales_*` tables.
- `areatrigger.lua` (432 entries) and `quests-itemreq.lua` (180) not compared.
- `zones.lua`, `minimap.lua`, `meta.lua` are client-derived and have no DB counterpart.
- Nothing has been reported upstream: the three missing quest starters, nor the 82 items with
  missing quest-drop sources.

## Considered and deliberately not applied

`items.U` has 9 rows over 4 items that pfQuest lists and this realm does not — "A Letter to
Yvette" (2839) drops from 3 creatures here and 8 in pfQuest, plus Ring of Forlorn Spirits from
Baron Bloodbane, Dwarven Hatchet from Crimson Hammersmith, and a display-only item. `items.O`
has a further 79 rows over 32 items in the same direction.

These were **not** added. The asymmetry with 7462 is the point: there the realm has nothing at
all and the quest is provably unreachable, which is a broken state. Here the realm simply has a
*narrower* loot list, and VMaNGOS does a great deal of Blizzlike loot correction upstream — a
shorter list is at least as likely to be the corrected one as the stale one. Adding rows on
pfQuest's word alone would be inventing content, and pfQuest is demonstrably the weaker source
in this file (it is missing 180 quest-drop rows of its own, and lists 8 gameobject ids that
exist in no `gameobject_template` here).
