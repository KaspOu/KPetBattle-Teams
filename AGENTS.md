# AGENTS.md — PetBattleTeams (KPetBattle-Teams)

Working guide for AI agents (and humans) modifying this addon. It documents the code as it
exists today — do not "fix" the architecture described here without being asked. See
`docs/ARCHITECTURE.md` for the full technical reference and `backlog.md` for the 2026-11-13
security/correctness audit (known defects are listed there, not silently patched here).

## 1. Technical context

- **Purpose.** Pet-battle team manager: build teams of 3 battle pets, switch the pet loadout
  between them, drag/drop pets, per-team notes and Pet Battle Scripts (PBS) integration,
  Rematch-compatible import/export, autoswitch by target NPC ID.
- **Target clients.** `## Interface: 120100, 120105, 120107` (retail 12.x / Midnight) and
  `50504` (Mists of Pandaria Classic); `## AllowLoadGameType: standard, mists`
  (`PetBattleTeams/PetBattleTeams.toc:1-2`). Version `12.1.503` (TOC line 11).
- **Environment.** WoW-embedded Lua 5.1 (LuaJIT on retail): no `os`/`io`/filesystem, no
  `require`, event-driven single-threaded, SavedVariables serialized by the client at logout.
  On retail 12.x the **secret-values system** applies: unit identity APIs return secret values
  in combat/tainted contexts — see `docs/WoWAddonDevGuide-master/12a_Secret_Safe_APIs.md`.
- **Embedded libraries** (vendored under `PetBattleTeams/libs/`, declared as externals in
  `.pkgmeta`): Ace3 subset (AceAddon/AceConfig/AceConfigDialog/AceConfigCmd/AceConfigRegistry/
  AceConsole/AceDB/AceGUI), LibStub, CallbackHandler-1.0, LibPetJournal-2.0 (KaspOu fork),
  LibPetBreedInfo-1.0, LibDropDownMenu (Hizuros), LibSharedMedia-3.0 and EmbedHandler-1.0
  (both loaded by the TOC but **not referenced by first-party code**).
- **Optional external addon.** `tdBattlePetScript` ("Pet Battle Scripts"): `ScriptEditor`
  integrates with `GetAddon("PetBattleScripts")` / its `Director` module / `GetClass("Script")`.
  Without it, script features degrade to a "addon required" popup.

## 2. Code organization

```
KPetBattle-Teams/
├── PetBattleTeams/            # the addon proper (folder name = addon name)
│   ├── PetBattleTeams.toc     # load order + metadata (source of truth for loading)
│   ├── PetBattleTeams.lua     # addon creation, slash handler, StaticPopups, L metatable
│   ├── i18n/                  # 9 localization files (en first, then 8 translations)
│   ├── modules/               # AceAddon modules + pure model files
│   │   ├── TeamManager.lua    # core: team data, loadout applying, autoswitch, persistence
│   │   ├── RematchImporter.lua / RematchExporter.lua / TeamModel.lua  # pure model layer
│   │   ├── ImportExport.lua   # runtime glue for import/export dialog
│   │   ├── TeamManagerUnitTests.lua   # in-game unit tests (shipped, never auto-run)
│   │   ├── Tooltip.lua / Cursor.lua / Config.lua / Tutorial.lua (dead)
│   │   └── GUI/               # UI builders + editors (GUI.lua, MainFrame, ScrollFrame, …)
│   ├── classes/               # mixin UI classes: TeamFrame, PetUnitFrame
│   └── libs/                  # vendored libraries (upstream code — avoid editing)
├── .context/                  # dev tooling (run.py, import_test.lua — currently broken)
├── .pkgmeta                   # BigWigs packager manifest (externals)
└── .release*.bat              # Windows release wrappers → ../packager/release.sh
```

### Module responsibilities and load order

`PetBattleTeams.toc` order is mandatory; several files capture module references at file load.
Critical dependencies:

1. `PetBattleTeams.lua` **first**: creates the AceAddon object `PetBattleTeams`, the
   `addon.L` localization metatable, slash handler and StaticPopups.
2. `i18n/*` next: each file calls `addon:RegisterLocale`; `Localization.en.lua` is the base.
3. `TeamManager.lua` before anything that calls `GetModule("TeamManager")` at file scope
   (ImportExport, GUI, Config, classes, …).
4. Model chain order: `RematchImporter.lua` → `RematchExporter.lua` → `TeamModel.lua` →
   `ImportExport.lua` (each captures `ns.<Model>` from the private table at file scope).
5. `classes/*.lua` before `modules/GUI/ScrollFrame.lua` (which reads
   `PetBattleTeams.PetBattleTeamsFrame` at file scope) and before anything constructing frames.

Module styles in use (follow the existing one when adding code):

- **AceAddon modules** (`PetBattleTeams:NewModule(...)`): TeamManager, GUI, Config (embeds
  AceConsole-3.0), Tooltip, Cursor, NoteEditor, ScriptEditor, ImportExport. Queried with
  `GetModule("Name")`.
- **Mixin classes** with `PetBattleTeams.Embed` (copy method table into instance):
  `PetBattleTeamsFrame` (classes/TeamFrame.lua) and `PetBattleTeamsUnitFrame`
  (classes/PetUnitFrame.lua).
- **Pure model files** sharing the addon's private vararg table (`local _, ns = ...`):
  RematchImporter, RematchExporter, TeamModel — no WoW API except through injected `api`.

### Namespaces and globals

- `PetBattleTeams` (AceAddon object) is the only addon namespace; modules hang off it.
- The private vararg table (`local _, addon = ...` / `local _, ns = ...`) carries `L`
  (localization) and the three model files. Do not create new globals.
- Existing **global frames**: `PetBattleTeamFrame` (MainFrame), `PetBattleTeamsTooltip`,
  `PetBattleTeamsImportExportFrame` (in `UISpecialFrames`), `CursorTeamFrame` (in
  `UISpecialFrames`), dynamically named Revive/Bandage buttons
  (`parent:GetName()..name` pattern).
- **Slash globals**: `SLASH_PETBATTLETEAMS1/2` (`/pbt`, `/PetBattleTeams`) +
  `SlashCmdList.PETBATTLETEAMS`. Note: `Config.lua:351` also registers `/pbt` through
  AceConfig (`SLASH_ACECONSOLE_PBT1`) — a known collision (backlog.md finding 6).
- **SavedVariables globals**: `PetBattleTeamsDB` (AceDB-3.0), `PetBattleTeamsSettings`
  (plain table, `ForceEnglish` key).
- Localization keys are the **English source strings**; `L[...]` falls back to the key itself.

## 3. WoW-specific rules

- **API per client version.** Code runs on both retail 12.x and MoP Classic. Guard
  12.x-only globals (`issecretvalue` at `TeamManager.lua:175` is the pattern:
  `if issecretvalue and issecretvalue(v) then … end`). Never assume an API exists on both
  clients without checking `docs/WoWAddonDevGuide-master/01_API_Reference.md`.
- **Secret values (12.x).** Do not do arithmetic, comparisons or string ops on values from
  unit-identity APIs during combat/tainted contexts. `UnitGUID`/`UnitName` need
  `issecretvalue` guards wherever they are operated on (`TeamManager.lua:418-429` lacks one —
  see backlog.md finding 13). Spell cooldowns: pass duration objects to cooldown frames, not
  raw `startTime`/`duration` (`ReviveButton.lua:14-16` violates this — backlog.md finding 4).
- **Combat lockdown.** Frames created from `secureactionbuttontemplate`
  (`ReviveButton.lua:41`, `PetBandageButton.lua:35`) are protected: `SetAttribute`,
  `Show`/`Hide`, `SetParent`, `SetPoint` on them must be guarded with `InCombatLockdown()` or
  deferred (pattern: `MainFrame.lua:99`, `GUI.lua:119`). Known violations are listed in
  backlog.md findings 2-3, 8 — do not replicate them in new code.
- **Event lifecycle.** Everything hangs off `ADDON_LOADED` and AceAddon `OnInitialize`
  callbacks (see `docs/ARCHITECTURE.md` §4). `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` are **not**
  used. The GUI is built lazily when the LoadOnDemand addon `Blizzard_Collections` loads
  (`GUI.lua:21-36`) — never assume `PetJournal` exists before that.
- **SavedVariables.** Opened through AceDB-3.0 in `OnInitialize` (after the client loaded the
  SV file; `## LoadSavedVariablesFirst: 1` is set in the TOC). Validate types when reading
  values that users can hand-edit (precedent: `TeamManager:ConvertDeprecated`,
  `TeamManager.lua:764-808`). Add defaults to the namespace defaults table
  (`TeamManager.lua:816-832`, `GUI.lua:58-73`, `Tooltip.lua:44-50`).
- **Inter-addon communication.** None over chat (`C_ChatInfo` is unused). Integration is
  LibStub-based (AceAddon `GetAddon`, CallbackHandler callbacks). If you add PBS features,
  keep the `ScriptEditor` contract: validate via `ScriptClass:SetCode` before storing.
- **Deprecated/legacy APIs.** `SetBackdrop` is used on `BackdropTemplate` frames (fine on both
  clients); `PetJournal_UpdatePetLoadOut` is called only behind an existence check
  (`TeamManager.lua:88-90`). Prefer `C_*` namespaces over deprecated globals for new code.

## 4. Instructions for AI agents

Before any modification:

1. Read the target file fully and its TOC neighbors — check what captures references at file
   scope before reordering anything.
2. Identify the module style in use (AceAddon module / mixin class / pure model) and follow it.
3. Grep for every caller of a function you change (the workspace tooling: `rtk grep` or plain
   `grep` from the workspace root; see the workspace `AGENTS.md` §9).
4. Check the WoW API against `docs/WoWAddonDevGuide-master/` for both target clients.
5. Respect combat/secure-frame rules and the secret-values rules above.

After any modification:

1. Run the Lua syntax gate (§5) on every file you touched.
2. Re-check module dependencies and load order (TOC).
3. Re-check event registrations and callbacks you touched.
4. Consider both clients (retail 12.x and MoP Classic) and combat paths.
5. List the in-game tests that remain to be done (no automated runtime tests exist).

Localization: any user-facing string change must update **all 9 files in `i18n/`** (keys are
English source strings; see the workspace `AGENTS.md` §10.6).

## 5. Commands and tools (all real — nothing else exists)

- **Lua syntax gate** (Lua 5.1 parser; run from the workspace root
  `/mnt/d/RProjects/_KaspOu`):

    ```bash
    python3 tools/validate_lua.py KPetBattle-Teams/PetBattleTeams   # this addon
    python3 tools/validate_lua.py --selftest                        # checker self-test
    ```

- **In-game unit tests**: `PetBattleTeams/modules/TeamManagerUnitTests.lua` is loaded by the
  TOC but never runs automatically. Manual run in-game:
  `/run PetBattleTeams.TeamManagerUnitTests:Run()` (the comment at line 53 shows a broken
  command — there is no global `TeamManagerUnitTests`). Warning: a run has live side effects
  (fires real callbacks, re-applies the loadout; backlog.md finding 16).
- **Dev harness**: `.context/run.py` (needs `pip install lupa`) is **broken** — it opens
  `tests/import_test.lua`, which does not exist (the file lives in `.context/`), and the
  fixture `export.txt` is missing (backlog.md finding 17). Not usable as-is.
- **Packaging**: `.release.bat` → `wsl bash ../packager/release.sh -d` (BigWigs WoW packager,
  manifest `.pkgmeta`), plus `.release.live.bat` and `.release.xcopylibs.bat`. Release scripts
  are state-changing — run them only when explicitly asked.
- **No lint, no build, no CI** in this repo. Lua files carry `-- luacheck: globals …`
  annotations, but there is no `.luacheckrc` and no lint command. Do not invent one.

## 6. Known landmines (do not replicate; see backlog.md for details)

- Two `EMPTY_PET` sentinels coexist: `TeamManager.lua:31` (`"BattlePet-0-000000000000"`) is the
  real one; `Cursor.lua:18` still has the legacy `"0x0000000000000000"` (backlog.md finding 5).
- `/pbt` is registered twice (backlog.md finding 6).
- Imported team strings can carry PBS scripts past validation (backlog.md finding 1).
- Dead artifacts: `modules/GUI/DescriptionEditor .lua` (empty file, space in the name, not in
  the TOC), `modules/Tutorial.lua` (not in the TOC, depends on unshipped `CustomTutorials-2.0`),
  `modules/GUI/LockTeamsButton.lua` (`GUI:CreateLockTeamsButton` is never called),
  `StaticPopupDialogs.PBT_IMPORT_TEAMS` (never shown, calls a nonexistent method).
- `TeamManager:GetIgnoreEmptyPets` is hardcoded `return true`
  (`TeamManager.lua:300-302`) — the DB key is ignored.
