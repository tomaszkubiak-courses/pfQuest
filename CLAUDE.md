# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

pfQuest is a World of Warcraft addon (Vanilla 1.12, TBC 2.4.3, WotLK 3.3.5a beta) written in Lua for the
1.12-era client API. It ships a full offline database of spawns, objects, items and quests, extracted from
MaNGOS server databases, and plots matches on the world- and minimap. Upstream is
`https://github.com/shagu/pfQuest`.

There is no test suite, linter or build step for the addon code itself — the client loads the `.lua` files
directly. Verification means loading the addon in a game client and using `/db` commands or `/reload`.

## Commands

```sh
make full            # build one release zip (all locales, vanilla) into release/
make full-tbc        # same for TBC; make enUS / enUS-tbc / ... for slim single-locale builds
make database        # run the SQL extractor (toolbox/), overwrites db/ with fresh output
```

`make` / `make all` builds every locale × expansion zip, but its first step is `make stripdb`, which runs
`toolbox/compressdb.sh` **in place on `db/*.lua` in the working tree** — it strips comments, whitespace and
newlines from the checked-in database files. Never run `make`, `make all` or `make stripdb` in a working copy
whose `db/` you want to keep readable; if it happens, `git checkout -- db/`.

The `locales` target calls `toolbox/find_locales.sh`, which does not exist in the tree.

### Database extraction (toolbox/)

`make database` runs `lua toolbox/extractor.lua`, which needs MariaDB with populated `vmangos`,
`cmangos-tbc` and `pfquest` (client DBC data, from `toolbox/client-data.sql`) schemas plus `luasql-mysql`.
It connects as `mangos`/`mangos` on `127.0.0.1`. `toolbox/README.md` is the setup procedure — importing the
core databases, translations, indexes, and the DBC→CSV conversion for `DBC/`.

Expansions are declared in `config.expansions` (`toolbox/extractor.lua:111`). Each entry names a `core`
(`vmangos` or `cmangos`); `config.cores` is the column-name glue table for cores whose schema differs from
CMaNGOS. A third `turtle` expansion entry exists behind `if false then` and writes to `output/custom/`.

## Architecture

### Load order

`*.toc` → `init/*.xml` → files. `init/data.xml` and `init/<locale>.xml` load the database tables; the slim
per-locale release targets in the Makefile rewrite the `.toc` to include only the needed XMLs. `init/addon.xml`
loads the addon code in dependency order: compat → overwrites → locales → config → slashcmd → database →
icons → map → quest → route → tracker → browser → journal → menu.

### The database (`db/`, `pfDB`)

`db/init.lua` declares `pfDB`; every other `db/*.lua` file is one giant table assignment. The layout is
`pfDB[<table>]["data"]` for the language-independent data and `pfDB[<table>][<locale>]` for names/texts, with
`-tbc` suffixed files carrying only the *diff* against vanilla.

`database.lua` (top ~200 lines) does the assembly at load time:
- `patchtable()` merges each `-tbc` / `-wotlk` diff into the base table (a value of `"_"` means delete).
- `pfDB[db]["loc"]` is set to the active client locale, falling back to `enUS`.
- A Hearthstone tooltip probe detects unlocalized servers and forces `loc` back to `enUS` for the tables
  whose names come from the server (`items`, `quests`, `objects`, `units`).
- `pfDatabase.Reload()` caches the `["data"]` tables into file-local upvalues (`units`, `quests`, …). Anything
  that swaps a `pfDB[...]["data"]` table must call it.

Record keys are terse: quests use `lvl`/`min`/`race`/`class`/`skill`/`pre`/`prechain`/`start`/`obj`/`end`,
where the start/obj/end sub-tables key by `U`(nit), `O`(bject), `I`(tem), `A`(reatrigger). Locale records use
`T`(itle), `O`(bjectives), `D`(escription). Unit/object coords are `{ x, y, zone, respawn }`.

### Node pipeline

`pfDatabase:Search*` (`SearchMobID`, `SearchObjectID`, `SearchItemID`, `SearchQuestID`, `SearchQuests`,
`SearchMetaRelation`, …) look up `pfDB`, build **meta** tables and hand them to `pfMap:AddNode(meta)`. The meta
object is the single currency between database, map, tooltip and tracker — its fields are documented in
`docs/meta.md`; `docs/config.md` documents every `pfQuest_config` key. Nodes are addressed by
`meta.addon` (`"PFQUEST"` for questlog-driven nodes, `"PFDB"` for browser/CLI results) plus `meta.title`, which
is what `pfMap:DeleteNode(addon, title)` and `/db clean` rely on.

`quest.lua` is the questlog driver: it watches quest events, diffs the questlog into `pfQuest.queue`, and
re-issues `SearchQuestID` per changed quest. `pfQuest_config["trackingmethod"]` (all / tracked / manual /
disabled) gates that. Completed quests land in `pfQuest_history`, which `pfDatabase:QuestFilter()` reads to
hide quests you have already done.

`map.lua` owns node frames, clustering, tooltips, minimap placement and the world map integration; `route.lua`
draws the arrow and the connecting lines; `tracker.lua` and `journal.lua` are the on-screen objective tracker
and quest journal; `browser.lua` is the database GUI; `slashcmd.lua` implements the `/db` CLI documented in
the README.

### Client compatibility

`compat/client.lua` builds `pfQuestCompat` from `GetBuildInfo()`'s build number (`11200` vanilla, `20400` TBC,
`30300` WotLK) and wraps every API that changed across expansions (`GetQuestLogTitle` arity, `QuestWatchFrame`
vs `WatchFrame`, questlog frame names, `GetPlayerFacing`, …). Use `pfQuestCompat.*` rather than the raw globals,
and gate expansion-specific behavior on `pfQuestCompat.client`. `compat/pfUI.lua` provides a minimal `pfUI.api`
stub so the code can use pfUI helpers whether or not pfUI is installed.

The target is the 1.12 Lua environment: no `#` length operator, no `%s+` guarantees, `table.getn`,
`string.gfind`, `mod`, and the implicit `this` / `event` / `arg1` globals inside event and script handlers.
Match that style; newer Lua idioms will break the vanilla client.

### `overwrites.lua`

Loaded before `database.lua` and used to patch `pfDB` for data the extractor gets wrong. Fixing the extractor
is the preferred solution — every entry here is meant as an intermediate fix and must carry a comment
explaining what is wrong, what the server actually does, and a concrete example. Realm-specific quest fixes
also live here, guarded by `pfQuestCompat.client` checks.

Notable convention introduced here: `pre` is a hard prerequisite (`QuestFilter` hides the quest until one
listed quest is in `pfQuest_history`), while `prechain` mirrors MaNGOS `prevChainQuests` — it only hides the
quest while the predecessor is still *in the questlog*.

### Saved variables

`pfQuest_config` (settings), `pfQuest_history` (completed quests), `pfQuest_colors`, `pfQuest_track` (active
meta tracking lists), `pfQuest_server` (server-scanned custom item names), `pfBrowser_fav`, and the
account-wide `pfQuest_questcache`. Adding one means editing all three `.toc` files.

### Localization

`locales.lua` holds the UI string table (`pfQuest_Loc`, indexed by the English string). Database translations
are separate and live in `db/<locale>/`.
