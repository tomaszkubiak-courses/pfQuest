# pfQuest hides quests behind quest-chain links — 2026-09-06

Realm note. "The realm" below is the VMaNGOS server this fork of pfQuest is used with;
`ObjectMgr` and `Player` references are that server's C++ sources, not this addon's.

## Symptom

A level 14 character stood in front of Bingles Blastenheimer in Loch Modan with an exclamation
mark over his head, and pfQuest showed no node for the quest anywhere on the map — not at the
questgiver, not in the zone. The quest is 2038, "Bingles' Missing Supplies".

## Root cause

`pfDatabase:QuestFilter` (`database.lua`) hides a quest when it carries a `pre` list and none of
the quests in that list has been completed:

```lua
if quests[id]["pre"] then
  local one_complete = nil
  for _, prequest in pairs(quests[id]["pre"]) do
    if pfQuest_history[prequest] then one_complete = true end
  end
  if not one_complete then return end
end
```

`db/quests.lua` gives 2038 `["pre"] = { 2039 }` ("Find Bingles"). The level fields are not the
problem: `min` is 12 and `lvl` is 15, both of which pass for a level 14 character.

The `pre` list is built by the database extractor from three sources
(`toolbox/extractor.lua`):

1. `PrevQuestId`
2. `SELECT entry FROM quest_template WHERE NextQuestId = <entry> AND ExclusiveGroup < 0`
3. `SELECT entry FROM quest_template WHERE NextQuestInChain = <entry>`

Rule 3 is wrong. A MaNGOS-derived core does not treat a chain link as a prerequisite:

- `ObjectMgr::LoadQuests` puts `NextQuestInChain` into the follow-up's `prevChainQuests`, and
  `PrevQuestId` / `NextQuestId` into its `prevQuests`.
- `Player::SatisfyQuestPreviousQuest` reads `prevQuests` — that is the real prerequisite check.
- `Player::SatisfyQuestPrevChain` reads `prevChainQuests` and refuses the quest **only while the
  predecessor is still in the quest log** (`IsCurrentQuest`). It never asks for it to have been
  completed.

For 2038 the world DB has `PrevQuestId = 0` and no `NextQuestId` pointing at it; 2039 reaches it
only through `NextQuestInChain`. So the server offers 2038 to any level 12+ character who has
never heard of 2039, while pfQuest hides it forever.

Rule 2 is also narrower than the core, which links *every* `NextQuestId`, not just those whose
source sits in a negative exclusive group. That error runs the other way — it can show a quest a
little early — and was left alone.

## Scale on this realm

Compared pfQuest's shipped `pre` lists against the world DB, selecting the same
`max(patch) <= WowPatch` row the core loads. Of 4433 quests, **193** carry a `pre` the core does
not enforce:

- **117** from the chain rule — e.g. 11 Riverpaw Gnoll Bounty, 429 Wild Hearts, 844 Plainstrider
  Menace, 870 The Forgotten Pools, 1524 Call of Fire, 2038 Bingles' Missing Supplies.
- **76** with no link of any kind in this world DB — almost all Ahn'Qiraj war effort turn-ins
  (8492+ gated on 8795, 8532+ on 8792, the 8811-8855 commendation series), plus 934 Crown of the
  Earth, 1288 Vimes's Report, 3503 Meeting with the Master, 7668 The Darkreaver Menace. These come
  from a different snapshot of the source database, not from rule 3.

pfQuest's vanilla data is itself generated from a VMaNGOS world database, which is why the quest
ID sets match exactly (4433 = 4433, checked again here) — the divergence is in the extraction
rules and in the age of the snapshot, not in the content.

## Fix applied locally

Two changes, in this repository and in the copy the client actually loads (the addon directory
under the client's `Interface/AddOns`).

**`overwrites.lua`** — for the 117 chain cases, `pre` is dropped and the chain predecessor moved
to a new `prechain` field; for the 76 unlinked cases `pre` is dropped outright. Guarded on
`pfQuestCompat.client <= 11200` so a TBC or WotLK client is untouched. That file is upstream's
documented place for extractor gaps and is loaded after the database.

**`database.lua`** — `QuestFilter` gained the matching clause, placed right after the `pre` block:

```lua
-- hide quests whose chain predecessor is still in the quest log. A quest chain link is not a
-- prerequisite: the server refuses the follow-up only while the previous quest is still being
-- worked on, and never asks for it to have been completed.
if quests[id]["prechain"] then
  for _, prequest in pairs(quests[id]["prechain"]) do
    if pfQuest.questlog[prequest] then return end
  end
end
```

This reproduces `SatisfyQuestPrevChain` exactly.

Verified by replaying the overwrite against the shipped data and the world DB: 0 quests remain
gated by a `pre` the core does not enforce, all 2206 quests with a real prerequisite keep theirs,
every `prechain` entry is backed by a `NextQuestInChain` row, and no overwritten quest has a real
prerequisite. Not yet confirmed in game.

## Upstream report

Not filed — there is nowhere to file it. `github.com/shagu/pfQuest` is archived with issues
disabled, `gitlab.com/shagu/pfQuest` returns 404 to an anonymous request, and `git.shagu.org` does
not answer from this machine. If a live tracker turns up, the report is the two sections above:
rule 3 in the extractor should write a separate field, and `QuestFilter` should treat it as
"hide while the predecessor is in the questlog".

## Method

Scripts were written to a scratch directory and are not kept. The comparison needs two dumps from
the world DB — `entry, MinLevel, QuestLevel, PrevQuestId, ExclusiveGroup, RequiredRaces` and
`entry, NextQuestId, NextQuestInChain`, both joined against
`(SELECT entry, MAX(patch) FROM quest_template WHERE patch <= 10 GROUP BY entry)` — plus a
line-oriented parse of `db/quests.lua`, which is regular enough that a regex over
`^  \[(\d+)\] = \{` blocks is sufficient. Read `world-db-diff-2026-09-01.md` first; it
carries the schema traps.
