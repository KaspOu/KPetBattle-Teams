# Backlog — KPetBattle-Teams

## KPetBattle-Teams addon audit 2026-11-13

**Scope.** The working tree's pending changes (41 modified files, all verified byte-identical to
`HEAD` after stripping `\r` — pure CRLF line-ending churn) meant there were no semantic pending
changes, so the audit covered the entire addon: all first-party Lua under `PetBattleTeams/`
(25 files incl. the TOC), the 9 i18n files, `.pkgmeta`/`.release*.bat` (skimmed), and `.context/`
dev tooling. Depth: high. Two
read-only sub-audits ran in parallel (UI layer; support modules + i18n format sweep); every
`file:line` below was re-opened and re-traced before entering this report.

Entry points walked: slash commands (`/pbt`, `/pbto`), the import/export dialog (clipboard paste),
SavedVariables (`PetBattleTeamsDB`, `PetBattleTeamsSettings`), config options, unit-frame
dropdown menu / drag-and-drop / clicks, frame events (`ADDON_LOADED`,
`PLAYER_REGEN_DISABLED/ENABLED`, `PET_BATTLE_*`, `PLAYER_TARGET_CHANGED`, …), and addon-load
sequencing. There is no `loadstring`/`load`, no addon-message or network handler in first-party
code; the only code-execution sink is the external "Pet Battle Scripts" (tdBattlePetScript) addon.

### Findings (ranked, most severe first)

**HIGH — 1. Imported team strings carry PBS scripts past validation; they are pushed into Pet
Battle Scripts automatically at every pet-battle start.**
`modules/GUI/ScriptEditor.lua:59-61`, `:262-271`, `:251-258`, `:238-241` (validation only at
`:221-227`); `modules/TeamModel.lua:198-205` (import path), `:83-101` (SplitScript).
CONFIRMED up to the load; PBS execution semantics UNCERTAIN (source not on disk).
Traced scenario: an attacker shares a Rematch string whose notes contain
`-----BEGIN PET BATTLE SCRIPT----- … -----END PET BATTLE SCRIPT-----`; `ParseExtras` unescapes the
notes, `TeamModel.FromRecord` splits the block into `team.script` and stores it — the
`PBS_ValidateScript` gate exists only in `ScriptEditor:SaveEditor` (line 221-227) and is never
applied to imported or SavedVariables-sourced scripts. On `PET_BATTLE_OPENING_START`,
`AutoLoad_PBS_Script` (262-271) reads the selected team's script and calls
`PBS_Director:SetScript(PBSScript(code))` with no `pcall`, handing the untrusted Lua text to the
external addon, which compiles it (`ScriptClass:New({code=…})`, 238-241). Consequences: (a) a
script PBS rejects raises a Lua error in the event handler at every battle start with that team
selected; (b) a well-formed script from an untrusted string becomes the active battle script —
if PBS auto-run is enabled it executes in the client. What I could not verify: whether
`Director:SetScript` alone executes, or only on auto-run (tdBattlePetScript is not in this
workspace). The addon's own promise ("Invalid script (not saved)") is defeated by the import path.

**HIGH — 2. First Collections load during combat aborts GUI construction; the addon's UI is lost
for the session with the error repeating.**
`modules/GUI/GUI.lua:23-26` (no combat guard, contrast `:30-35` and `:77-79`), `:96-116`;
`modules/GUI/MainFrame.lua:198`; `modules/GUI/ReviveButton.lua:41`, `:44`, `:58`.
CONFIRMED (LoadOnDemand verified in `Blizzard_Collections*.toc`).
Traced scenario: `Blizzard_Collections` is `LoadOnDemand` and loads on the session's first
Collections open. If that happens in combat with `delayedInit` false (normal login out of combat),
`ADDON_LOADED` → `GUI:InitializeGUI()` → `CreateMainFrame` → `CreateReviveButton` executes
`button:SetAttribute("type","spell")` on a `secureactionbuttontemplate` frame → protected-function
error in combat (or, if the template were unresolved, the `CooldownFrame_Set` secret-value error
from finding M2 at line 58 — the build aborts either way). `self.mainFrame` is never assigned,
`UnregisterEvent("ADDON_LOADED")` (line 25) is skipped so every later `ADDON_LOADED` retries and
errors again, and the recovery branch (`GUI.lua:31-35`) requires `delayedInit`, which is false —
so no recovery runs after combat ends until some unrelated addon load succeeds.

**MEDIUM — 3. Hide-in-combat handler calls protected `Hide`/`SetParent`/`ClearAllPoints` on the
secure buttons at `PLAYER_REGEN_DISABLED`.**
`modules/GUI/MainFrame.lua:30-35` (guard at `:28`, event at `:221`;
templates `ReviveButton.lua:41`, `PetBandageButton.lua:35`; defaults `GUI.lua:60`, `:62`).
CONFIRMED (template resolution established behaviorally: the buttons are functional shipped
features, so the lowercase template name does resolve).
Traced scenario: user detaches the frame (`/pbt detach`, defaults are `attached=true`) and leaves
`hideInCombat=true` → entering combat runs the handler → first `self.bandageButton:Hide()` on a
protected frame errors, aborting the handler, so the error repeats on every combat entry and the
whole hide-in-combat feature (fade at lines 36-37) never executes.

**MEDIUM — 4. Revive button passes secret cooldown values into `CooldownFrame_Set` — the exact
pattern the 12.0.1+ migration guide documents as an error.**
`modules/GUI/ReviveButton.lua:14-16` (event path), `:38-39`, `:58` (creation path);
local client source `Wow/BlizzardInterfaceCode/.../Blizzard_FrameXMLUtil/Cooldown.lua:2`
(`start > 0` comparison); `docs/WoWAddonDevGuide-master/12_API_Migration_Guide.md:1802`
("`SetCooldownFromDurationObject` is now the ONLY way…"), `:1804-1806` (BROKEN example), `:1818-1826`
(`isEnabled` now non-secret). CONFIRMED against code + client source + guide; not reproduced
in-game.
Traced scenario: on retail 12.x, in combat, `SPELL_UPDATE_COOLDOWN` fires →
`C_Spell.GetSpellCooldown().startTime`/`duration` are secret → `CooldownFrame_Set` compares
`start > 0` (Cooldown.lua:2) → "attempt to compare (a secret value)" on every cooldown tick
during combat; the display stops updating. Fix per guide: branch on the non-secret
`isActive`/`isEnabled` and use `SetCooldownFromDurationObject`.

**MEDIUM — 5. `Cursor.lua` uses a stale empty-pet sentinel: dragging an empty slot calls
`PickupPet` with the sentinel and puts the cursor into SWAP state.**
`modules/Cursor.lua:18` (`"0x0000000000000000"`) vs `modules/TeamManager.lua:31`
(`"BattlePet-0-000000000000"`); defect at `Cursor.lua:127-137`; hook guard `:147` stale too.
CONFIRMED defect; client-side effect of `PickupPet("BattlePet-0-000000000000")` UNCERTAIN.
Traced scenario: empty slots are draggable (`PetUnitFrame.lua:327-330` gates only on `isEnabled`,
and `enabled[i]` defaults true) → `OnDragStart` → `Cursor:PickupPet` → `GetPetInfo` returns
`"BattlePet-0-000000000000"` (`TeamManager.lua:344`) → line 127 compares it against the stale
`"0x0000000000000000"` → always true → line 128 `C_PetJournal.PickupPet(sentinel)`, line 129
`operation = "SWAP"`, line 137 event fired. A subsequent click on another slot
(`PetUnitFrame.lua:100-105` → `UpdateTeamSwapPets`) rearranges pets with no cursor holding
anything; `PickupPetHook` (145-154) also fails its stale sentinel check and fires a spurious
`COPY` event. Whether the client silently no-ops or errors on the invalid id could not be
verified without a client.

**MEDIUM — 6. `/pbt` is registered by two different handlers; which one wins is nondeterministic
per session.**
`PetBattleTeams.lua:21` + `:92` (addon subcommand handler) vs `modules/Config.lua:351`
(`RegisterOptionsTable("PetBattleTeams", …, {"pbt"})` → `libs/AceConfig-3.0/AceConfig-3.0.lua:49-54`
→ `AceConfigCmd-3.0/AceConfigCmd-3.0.lua:769` → `libs/AceConsole-3.0/AceConsole-3.0.lua:95`
(`_G["SLASH_"..name.."1"] = "/pbt"`, name `ACECONSOLE_PBT`)).
Dispatch: `Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:719-728` builds
`hash_SlashCmdList` by iterating `SlashCmdList` in `pairs` order, so whichever registration is
processed last owns `"/PBT"`. CONFIRMED collision; the winner is arbitrary.
Traced scenario: in some sessions `/pbt import`, `/pbt lock teams`, `/pbt reset ui` (help text
`PetBattleTeams.lua:75-88`) silently route to the AceConfig-Cmd handler, which treats the input
as an options path and prints usage instead — documented commands stop working intermittently.
Fix: drop the slash list from `Config.lua:351` (keep `/pbto`) or drop `SLASH_PETBATTLETEAMS1`.

**MEDIUM — 7. Deleting the LAST team from the roster while a different team is selected silently
changes the selection and re-applies a different team's loadout.**
`modules/TeamManager.lua:726-730` (branch `teamIndex == numTeams → SetSelected(teamIndex-1)`
has no `teamIndex == selectedTeam` guard); reachable because every team frame, including roster
rows, owns pet unit frames with the delete menu (`classes/TeamFrame.lua:65`, `:70`;
popup `classes/PetUnitFrame.lua:77`). CONFIRMED by trace.
Traced scenario: teams [A,B,C,D], selected B; right-click a pet slot on team D's roster row →
Delete → `table.remove` → `SetSelected(3)` fires (no lock/PVP-queue) → selection becomes C and
`SetSelected` → `ApplyTeam` (`TeamManager.lua:529`) rewrites the active pet loadout to team C —
an unintended team switch caused by deleting an unrelated team. Deleting a non-selected
middle team is unaffected (neither branch fires).

**LOW — 8. Options toggles show/hide the secure buttons with no combat guard.**
`modules/GUI/MainFrame.lua:66-72` (`reviveButton`/`bandageButton:SetShown`, lines 71-72),
`modules/GUI/GUI.lua:183-191` (`SetComponentPoints`, no `InCombatLockdown`, contrast
`MainFrame.lua:99` and `GUI.lua:119`), triggered from `modules/Config.lua:125-152`.
CONFIRMED. Toggling "Show control buttons" etc. in combat calls `Show`/`Hide` on protected frames
→ error mid-handler, option only partially applied.

**LOW — 9. `/pbt min` / `/pbt max` before the GUI is initialized nil-indexes.**
`modules/GUI/GUI.lua:198-209` (`self.menuButton:SetPoint` at 200 for `min`, at 204 for `max`;
`self.mainFrame` at 207), entered from `PetBattleTeams.lua:51-56`. CONFIRMED.
Scenario: slash typed before Collections was ever opened this session → `menuButton`/`mainFrame`
are nil (assigned only in `InitializeGUI`, `GUI.lua:98-101`) → "attempt to index a nil value".
Both branches die on `menuButton` first (200/204).

**LOW — 10. `Tooltip:SetUnit` crashes on teams whose `abilities` field is nil or has more than
3 entries (corrupted/legacy SavedVariables).**
`modules/Tooltip.lua:352` (`for i=1, #abilities do` → length of nil), `:356-360`
(`tooltip["AbilityName"..i]` nil → `abilityName:SetShown`); caller
`classes/PetUnitFrame.lua:143`; raw passthrough `modules/TeamManager.lua:341-344`.
CONFIRMED code path; trigger = hand-edited/legacy SV (in-scope input). The apply-stepper itself
anticipates nil abilities (`TeamManager.lua:45-46`), the tooltip does not — error on every hover
until SV fixed. (Whether any legacy release wrote abilities-less pet tables was not verified.)

**LOW — 11. `delayedInit` is never reset, permanently disabling target autoswitch after a
combat-login init.**
`modules/GUI/GUI.lua:77-79` (set true, never set false anywhere in the file),
consumer `:38-42`, recovery `:30-35` (initializes GUI but leaves the flag true). CONFIRMED logic.
Scenario: log in during combat → after combat the GUI initializes, but `PLAYER_TARGET_CHANGED`
keeps skipping `DetectTarget()` for the rest of the session.

**LOW — 12. "Lock teams" does not cover rename, delete, note or NPC edits.**
`modules/TeamManager.lua:359-367` (`SetTeamName`), `:384-390` (`SetTeamNote`),
`:401-409` (`SetTeamNpcID`), `:720-737` (`DeleteTeam`) have no lock check, while pet-content
paths do (`:466`, `:540-541`, `:611`, `:742`, import overwrite `TeamModel.lua:381-382`) and the
help text promises "preventing changes to those teams" (`PetBattleTeams.lua:82`). Menu entries
call these unguarded (`classes/PetUnitFrame.lua:30-33` rename, `:36-41` note, `:45-49` NPC edit,
`:77` delete). CONFIRMED structural gap; intent uncertain (maybe loadout-only by design), but the
import-overwrite lock proves name/content protection is intended elsewhere.

**LOW — 13. `SetNpcFromTarget` lacks the `issecretvalue` guard its sibling has — errors on 12.x
when invoked in combat.**
`modules/TeamManager.lua:421-426` (`guid:match` / `UnitName` concat), contrast `:173-177`
(`DetectTarget` guards guid with `issecretvalue`); UI callers `classes/PetUnitFrame.lua:51-54`
and `classes/TeamFrame.lua:197`, both unguarded; UI stays visible in combat when the frame is
attached (hide only runs when detached, `modules/GUI/MainFrame.lua:28`).
CONFIRMED defect against `12a_Secret_Safe_APIs.md` (UnitName/UnitGUID "sometimes" secret;
"InCombatLockdown() is NOT a sufficient guard"). Scenario: combat on retail 12.x with the
Collections journal open → right-click the NPC button → `UnitGUID("target")` is secret →
`guid:match` raises a secret-value error, action aborted. (Assumption not client-verified:
Collections can be opened in combat.)

**LOW — 14. `RematchExporter.ToBase32` infinite-loops on non-finite input — client freeze.**
`modules/RematchExporter.lua:19-28` (`num = inf` → `inf % 32` = NaN → `math.floor(inf/32)` = inf
→ loop never ends), reachable via `modules/TeamModel.lua:111-118` (`tonumber(digits)` overflows
to `inf` at ≥309 decimal digits) from the NPC-ID popup storing the RAW editbox text
(`PetBattleTeams.lua:188-194`) or hand-edited SV. CONFIRMED logic chain.
Scenario: paste a ≥309-digit number as a team's NPC ID, then export (`/pbt export`) or import a
conflicting string (identity check serializes the existing team) → `ToBase32(inf)` → hard client
hang. No attacker path beyond tricking the user into pasting; self-DoS.

**LOW — 15. SavedVariables values are consumed without type validation (load-time crash paths).**

- `PetBattleTeamsSettings` non-table: guard `if PetBattleTeamsSettings and
PetBattleTeamsSettings.ForceEnglish` at `i18n/localization.{de,es,fr,it,ko,pt,ru,zh}.lua:4` and
  get at `modules/Config.lua:339`. CORRECTED during verification: a _string_ value survives
  (string metatable makes `.ForceEnglish` legal → nil), but a _number/boolean_ value errors on
  index during file load → the whole addon stops loading at the first translation file.
- `TeamManager:ConvertDeprecated` (`modules/TeamManager.lua:797-798`): `petID:match` on a
  boolean/table petID (any non-string petID that `:781` didn't convert) → index error at
  `OnInitialize`; `"0x…"` without the `0x0000` prefix → `format("BattlePet-0-%s", nil)` → format
  error.
- `SetLocked` assert (`modules/GUI/MainFrame.lua:61` via `modules/GUI/GUI.lua:105`): corrupted
  `db.global.locked = "1"` → assert aborts `InitializeGUI` mid-way, frame left unpositioned.
  All CONFIRMED as reachable given a hand-edited/corrupted SV file (explicitly in-scope input);
  not reachable from normal gameplay. Fix: normalize once at `PetBattleTeams.lua:5`.

**LOW — 16. Unit tests are shipped in the release TOC, their documented command is broken, and a
manual run has live side effects.**
`PetBattleTeams.toc:78` (file loaded in production), `modules/TeamManagerUnitTests.lua:53`
(`--/run TeamManagerUnitTests:Run()` — no such global; `NewAddon` creates none, zero references
to the name anywhere else). CONFIRMED never auto-executes (file load only registers tables).
If run correctly, `Setup`'s function-copy loop (`:30-34`) binds the real module's closures, so
`SetSelected` fires the REAL `TeamManager.callbacks` (`modules/TeamManager.lua:527-528`) and the
copied `ApplyTeam` arms an OnUpdate whose file-local stepper (`:40-116`) drives real
`C_PetJournal.SetPetLoadOutInfo`/`SummonPetByGUID` — reverting manual loadout edits and
potentially dismissing the active pet. Premise not client-verified: a freshly created frame ticks
by default.

**LOW — 17. Dev test tooling cannot run at all (no injection found).**
`.context/run.py:11` opens `tests/import_test.lua`, but no `tests/` directory exists (the file
lives in `.context/`); on this machine it fails earlier at `.context/run.py:5` (`lupa` not
installed); docstrings are stale by two renames (`run.py:1`, `import_test.lua:3`,
`.context/import_export.md:206`). Whole file read: no `subprocess`/`os.system`/`io.popen`, all
paths literal — no command injection. CONFIRMED.

**LOW — 18. Dead `PBT_IMPORT_TEAMS` dialog calls a method that does not exist.**
`PetBattleTeams.lua:214-228` (`self.data:ImportTeams()` at `:220`) — no `StaticPopup_Show` of
this dialog anywhere and no `ImportTeams` function in first-party code (grep: 0 hits). CONFIRMED
unreachable today; if ever shown, guaranteed error.

**LOW — 19. `Tutorial.lua` is dead code with an unshipped dependency.**
`modules/Tutorial.lua:3` (`LibStub("CustomTutorials-2.0")` — library not shipped, 0 references
outside this file), file not listed in `PetBattleTeams.toc` → never executes; if someone adds it
to the TOC it hard-errors at load. CONFIRMED.

**LOW — 20. Stale slash-help text.**
`PetBattleTeams.lua:86` says reset teams gives "no confirmation", but `/pbt reset teams` shows the
`PBT_RESET_TEAMS` confirmation popup (`PetBattleTeams.lua:246` via
`modules/TeamManager.lua:246-247`). CONFIRMED; documentation defect only.

### Findings with unverified premises (reported as uncertain per depth=high)

**UNCERTAIN — U1 (functional if true): `LoadSavedVariablesFirst` may be unsupported on the MoP
Classic 5.5 client → "Force English" silently dead there.** `PetBattleTeams.toc:27`; the bundled
guide (`04_Addon_Structure.md:271-273`) dates the directive to 11.1.5+. Could not verify 5.5
client support. No crash either way.

**UNCERTAIN — U2 (MEDIUM if restricted): in-combat team switching via click/scroll may error in
a loop.** `classes/PetUnitFrame.lua:129` and `modules/GUI/MainFrame.lua:134` →
`SetSelected` → `ApplyTeam` (`modules/TeamManager.lua:118-124`) → OnUpdate →
`C_PetJournal.SetPetLoadOutInfo` (`:51`/`:60`) with no `InCombatLockdown()` guard — while the
autoswitch path guards it (`:167`). Whether `SetPetLoadOutInfo` is combat-restricted could not be
determined from local docs/source; if it is, clicking a team in combat produces repeated OnUpdate
errors.

**UNCERTAIN — U3 (LOW): `xp / maxXp` unguarded division.** `classes/PetUnitFrame.lua:306`
(`SetWidth(((xp / maxXp) * …)+1)`; the sibling health branch divides by `max(maxHealth,1)`).
If a pet ever reports `maxXp == 0` (client behavior unverified), NaN corrupts the bar layout.
Only when `showXpInHealthBar` is enabled (default false).

### Cleared (checked and disproved)

- **Injection/code execution inside this addon**: no `loadstring`/`load`/`dofile`/`RunCode`
  anywhere in first-party code; the only script sink is external PBS (finding 1).
- **Remote input**: no `CHAT_MSG_ADDON`/`C_ChatInfo`/socket handlers → no network attack surface;
  inputs are paste, SavedVariables, and local UI only.
- **Format strings**: my own sweep of all shared keys across the 8 translation files vs English
  (831 translations compared directive-by-directive) — 0 mismatches; all 13 first-party
  `string.format(L[...])` sites pass untrusted data as arguments only; the 5 `StaticPopup` `%s`
  texts are identical in structure across all 9 locale files (checked individually).
- **Import parser nil-safety**: `RematchImporter.Parse/ParseTeamLine/ParseTag/ParseExtras/
ParseGroupHeader` — every pattern chain either matches or returns nil+reason; invalid lines
  become `error` entries; `tonumber` failures become warnings; no nil index reachable.
- **Import cannot inject pets/loadout**: `BuildPet` requires `SpeciesExists` and picks only
  owned pet IDs via `FindPetID`; unknown species/tags → empty slot + warning
  (`TeamModel.lua:144-169`).
- **Merge idempotence/identity**: identity comparisons serialize both sides through the same
  code; attacker name can't break the comparison (`RematchExporter.lua:45` strips `:`/newlines).
- **ApplyTeam vs auto-save hook**: `hooksecurefunc(C_PetJournal, "SetPetLoadOutInfo",
UpdateCurrentTeam)` cannot clobber an in-progress import because `IsWorking()`
  (`TeamManager.lua:200-202`, step < 5) short-circuits it during application (`:742`).
- **MoveTeam selection bookkeeping** (`TeamManager.lua:559-604`): all four
  source/destination/selected orderings hand-executed — correct.
- **`SetSelected` bounds/lock guards** (`:521-530`) and every `GetSelected()==0` consumer:
  nil/type-guarded (sub-audit + my reads).
- **StaticPopup arity**: popups pass `(displayName, nil, teamIndex)` against one-`%s` dialogs;
  `GetTeamName` never returns nil (`TeamManager.lua:369-383`).
- **Secret values, autoswitch**: `DetectTarget` guards `UnitGUID` with `issecretvalue`
  (`TeamManager.lua:175-177`) and early-returns on combat/pet battle (`:167`).
- **TeamManagerUnitTests never auto-runs** (zero external references, grep exit 1); only loads
  definitions.
- **run.py: no command injection** (full file read — literal paths, no shell).
- **AceDB `New("PetBattleTeamsDB", {}, true)`**: third arg selects the Default profile (verified
  in `AceDB-3.0.lua`); only `.global` is used, namespaces isolated — no profile-order hazard.
- **Config option tables**: all three `show*` toggles verified typed with matching get/set
  (`Config.lua:125-152`); sub-audit programmatically checked all 32 entries for `order`/`type`.
- **`L` fallback metatable** (`PetBattleTeams.lua:263-275`): missing keys fall back to the
  English key — missing translations cannot nil-crash a format call.

### Hardening (correct today, fragile — explicitly not vulnerabilities)

- `TeamManager:DetectTarget` `UnitName("target")` (`:185`, used at `:188`) is guarded only by
  `InCombatLockdown`, but the secret-values guide says combat checks are insufficient in tainted
  contexts — add `issecretvalue` like the guid at `:175`.
- `ScriptEditor:ShowEditor` (`modules/GUI/ScriptEditor.lua:182-183`): `assert(type(teamIndex) ==
"number")` precedes the nil check, making the graceful return dead code — swap their order.
- `GetIgnoreEmptyPets` is hardcoded `return true` (`modules/TeamManager.lua:300-302`) with the
  DB default (`ignoreEmptyPets = false`) and the OnUpdate branch (`:49-56`) effectively dead; no
  Config entry exposes it (grep) — behaviour is deliberate (comment) but the dead DB key misleads.
- TOC lists `i18n\Localization.<lang>.lua` while disk files are `localization.<lang>.lua`
  (`PetBattleTeams.toc:63-71`) — harmless on Windows/macOS (case-insensitive); breaks only on a
  case-sensitive filesystem, which no supported WoW platform uses.
- `secureactionbuttontemplate` is lowercase in both button factories
  (`ReviveButton.lua:41`, `PetBandageButton.lua:35`) — works in shipped builds; the casing was
  never confirmed against docs.
- `Tooltip:SetUnit`'s `petID == 0` guard (`modules/Tooltip.lua:253`) is dead (petIDs are strings
  post-migration) — harmless leftover.

### Coverage

- **Audited**: every first-party file (`PetBattleTeams.lua`, `modules/TeamManager.lua`,
  `modules/TeamModel.lua`, `modules/ImportExport.lua`, `modules/RematchImporter.lua`,
  `modules/RematchExporter.lua`, `modules/Config.lua`, `modules/Cursor.lua`,
  `modules/Tooltip.lua`, `modules/TeamManagerUnitTests.lua`, `modules/GUI/*` incl.
  `ScriptEditor.lua`/`NoteEditor.lua`, `classes/TeamFrame.lua`, `classes/PetUnitFrame.lua` — full
  files for the core chain, whole-file or cited-block reads elsewhere), the TOC and load
  sequencing, all 9 i18n files (format parity + guards), `.pkgmeta` and `.release*.bat` (static,
  no untrusted input — packaging excluded from behaviour by design), `.context/` tooling, plus
  local Blizzard client source (cooldown wrapper, slash dispatch, LoadOnDemand TOCs) and the
  workspace API docs (secret values, 12.0.1 cooldown hotfix).
- **Delegation + verification**: two read-only sub-audits produced candidates; I re-opened every
  cited line. Corrections applied during verification: `MainFrame.lua:204` (not 207) for the
  `/pbt max` nil-index; `TeamManager.lua:344` (not 343) for `return EMPTY_PET`;
  `Cooldown.lua:2` (not :3); `run.py:11` (not :13) for the file-open; the
  ForceEnglish trigger corrected (string SV does not crash — number/boolean does);
  `AceConfigCmd` lives under `libs/AceConfig-3.0/AceConfigCmd-3.0/`.
- **Not audited (gaps)**: vendored libraries under `PetBattleTeams/libs/` (Ace3 family,
  LibDropDownMenu, LibPetJournal, LibPetBreedInfo, LibSharedMedia, EmbedHandler, CallbackHandler,
  LibStub — upstream code; only the call paths my traces touched were read); tdBattlePetScript
  (PBS) internals — not present on disk, which is why finding 1's execution step stays uncertain;
  MoP Classic 5.5 API availability — no client source in the workspace (`Frame:GetBoundsRect` at
  `Tooltip.lua:164` is the most doubtful, per sub-audit); no in-client execution of anything —
  no finding was reproduced in a running game; `.release/` mirrors and git history not reviewed;
  PNG/BLP assets and `.vscode`/`.editorconfig` config files.

**Summary.** 24 findings: 2 high, 5 medium, 14 low, 3 uncertain — overall risk **moderate**: no
injection, secrets leak, or code-execution bug inside this addon itself, but one security-relevant
flow (imported PBS scripts bypassing validation and auto-loading at battle start, finding 1) and
several retail-12.x combat/secret-value crashes (findings 2-4) make it not comfortable to ship
unchanged. Top three to fix first: (1) validate imported/stored PBS scripts and wrap the
`PBS_SetScript` push in `pcall` (finding 1); (2) add combat guards to `GUI:InitializeGUI`'s
`ADDON_LOADED` branch and the `PLAYER_REGEN_DISABLED` hide path (findings 2-3); (3) fix the stale
`EMPTY_PET` sentinel in `Cursor.lua:18` and remove the duplicate `/pbt` registration (findings
5-6). No code was changed by this audit.
