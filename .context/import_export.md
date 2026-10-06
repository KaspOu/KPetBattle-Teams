# Import/Export Guide - PetBattleTeams

PetBattleTeams supports importing and exporting teams using the ReMatch team string format. The format is designed to be compatible with standard ReMatch team strings for normal teams.

> **Note:** PetBattleTeams keeps its own team model; Rematch strings are only read (import) and written (export). Information the addon cannot use (tiers "any ability", special tags, `P:` preferences...) is stored with the team and re-exported unchanged while still valid. See "Round-Trip Compatibility".

## Quick Start

### Exporting Teams

1. Type `/pbexport` in chat to export all teams, or right-click a team and choose **Export Team** to export only that team
2. A dialog will appear containing your teams in ReMatch-compatible team-string format
3. Copy the text to share your teams or keep it as a backup

### Importing Teams

1. Type `/pbimport` in chat, or right-click any team and choose **Import Teams**
2. Paste one or more ReMatch-compatible team strings into the dialog (one team per line)
3. Click Import

**Features:**
- Multiple teams can be imported at once
- ReMatch group headers are recognized and ignored
- Imported teams are added to the PetBattleTeams team list

## Team String Format

### Basic Format

```
Team Name:npcIDs:petTag1:petTag2:petTag3:[P:preferences:][N:notes]
```

**Example:**
```
My Team:36VF:12102OQ:0110219:ZL:N:This is my team\nWith a note
```

- **P: preferences** (optional) — ReMatch leveling preferences; stored and re-exported, not used by PetBattleTeams
- **N: notes** (optional) — Team notes

## Components

### Team Name

The first field is the team name. Colons and line breaks are sanitized during export to prevent breaking the team-string format.

**Unnamed teams.** A PetBattleTeams team without a name is displayed as "Team: N". ReMatch always needs a name, so such a team is exported as `Team N` (N = its position). On import, a team named `Team N` (or the localized "Team: N" label) is imported **without a name**, and identified by its content, so re-importing it does not create duplicates. A team you explicitly name "Team 3" is therefore also imported unnamed.

### NPC IDs

NPC IDs are encoded using base 32. Multiple targets are represented by comma-separated IDs:

```
npcID,npcID,npcID
```

**Example:** `36VF,1A2B,4K9`

When imported, these IDs are converted back to numeric NPC IDs.

### Pet Tags

Each team contains three pet tags in the format:
```
petTag1:petTag2:petTag3
```

#### Pet Tag Structure

A normal pet tag contains: **AAA + breed + speciesID**

- **First 3 characters** — Ability selection:
  - `0` = any ability
  - `1` = first ability
  - `2` = second ability
- **Next character** — Breed
- **Remaining characters** — Species ID (base 32)

PetBattleTeams uses these values to identify the requested pet species and breed and to select an owned pet when importing.

#### Special and Empty Pet Tags

ReMatch supports special pet tags:
```
ZI, ZU, ZL, ZR, ZN...
```

PetBattleTeams recognizes each of them (`ZL` leveling, `ZI` ignored, `ZR` random, `ZN` unnotable, `ZU` unknown, `Q` queue). The slot is left empty in PetBattleTeams (with a warning in the import report) and the original tag is written back on export while the slot stays empty.

### Notes

Notes use the ReMatch format:
```
N:notes
```

#### Line Breaks

Line breaks are encoded as `\n`:

**Example:**
```
N:Line one\nLine two\nLine three
```

When imported, these sequences are converted back into normal line breaks. Normal team notes are preserved when importing and exporting.

#### Pet Battle Scripts

PetBattleTeams can store a pet battle script inside the team notes using the following markers:

```
-----BEGIN PET BATTLE SCRIPT-----
script content
-----END PET BATTLE SCRIPT-----
```

**Example:**
```
N:Strategy notes\n\n-----BEGIN PET BATTLE SCRIPT-----\n...\n-----END PET BATTLE SCRIPT-----
```

**Features:**
- During import: PetBattleTeams separates the script from normal notes and stores them independently
- During export: The script is placed back into the notes using the same markers
- This is an additional PetBattleTeams convention; ReMatch treats the entire N: field as notes

### ReMatch Preferences

ReMatch can append a preferences section:
```
P:minHP:allowMM:expectedDD:maxHP:minXP:maxXP:
```

**Examples:**
```
P:1000::::::
P::1:::::
P:::::20:25:
```

> **Note:** PetBattleTeams does not use ReMatch's leveling preferences. The P: section is stored with the team and written back unchanged on export.

### Groups

ReMatch can export group headers such as:
```
__ Group Name:sort:icon:color:showTab:... __
```

**Important:** PetBattleTeams does not currently import the ReMatch group structure. Group headers are ignored during import, while the teams themselves are still imported.

## Pet Selection

When importing a team, PetBattleTeams searches the player's collection for an available pet matching the requested species and breed.

If multiple matching pets exist, PetBattleTeams uses its own selection logic based primarily on:

- Pet level
- Breed match
- Rarity

**Note:** The exact pet selected by PetBattleTeams may differ from the pet selected by ReMatch. The export format identifies the requested pet through its species/breed information; it does not preserve the unique BattlePet GUID of the player's individual pet.

## Round-Trip Compatibility

An **Export → Import → Export** round trip returns the same string for everything PetBattleTeams can store, and keeps the following ReMatch-only information **opaquely** for as long as the team is not edited in a way that invalidates it:

- `0` = "any ability" (never turned into `1`)
- The requested breed of a tag (e.g. `0005V8` stays `5` even if your best pet is breed 4)
- Special tags (ZL, ZI, ZR, ZN, ZU, Q...) on slots that stay empty
- `P:` preferences
- The raw NPC list and the exact layout of the notes

When you edit a team in PetBattleTeams, the affected value is recomputed from the team itself, and only that value: change one ability and the other two slots keep their `0`; change the pet and the tag is rebuilt from the new pet; change the notes or script and the `N:` part is rebuilt; change the NPC ID and it is re-encoded.

What does **not** survive:

- ReMatch groups (headers are read, reported as ignored, teams are imported)
- The exact BattlePet GUID (a pet is found again by species, level, breed and rarity)
- Special tags on a slot once a pet has been placed in it (a pet replaces the tag; if the slot is emptied again, the original tag returns)
- Only the first `BEGIN/END` script block is stored as the script. Text that follows it is merged into the note (it is kept, but placed before the script if the note is edited)
- Only the first NPC ID is used for automatic team switching
- `P:` preferences are stored and exported but PetBattleTeams does not use them

ReMatch has no placeholders, variables or nested strings: a team line is `name:npcs:tag:tag:tag:[P:...][N:...]`, nothing else. Characters like `%`, `{}`, `$`, `[]` and Unicode are kept literally.

## Identity, Duplicates and Re-import

A team is identified by its name, compared case-insensitively, as in ReMatch.

- Importing a string identical to an existing team does nothing ("unchanged"), so importing the same text twice never creates duplicates
- If a team with the same name exists and differs, it is **skipped** and reported, unless **"Overwrite existing teams that have the same name"** is checked: the team is then updated in place (locked teams are never overwritten)
- Two identical lines in the same text produce one team

## Import Report

Each import prints a summary in chat (`imported / updated / unchanged / skipped / ignored / error(s)`), then the notable lines with their line number and the reason (invalid line, skipped because the team exists, missing pet, unknown species, special tag...). An invalid line never blocks the valid ones. The dialog stays open when something was skipped or invalid.

## Tests

Offline tests of the parser, the model and the exporter (no game needed; they need Python with `pip install lupa`):

```
python tests/run.py
```

## Commands

### Export
```
/pbexport
/petbattleexport
```
Open the team export dialog.

### Import
```
/pbimport
/petbattleimport
```
Open the team import dialog.

## Tips

- **Batch Import** — Multiple teams can be imported at once, one team per line
- **ReMatch Headers** — ReMatch group headers can be present in the imported text; they will be ignored
- **Preferences** — ReMatch P: leveling preferences are kept and re-exported but not used
- **Multi-line Notes** — Team notes can contain multiple lines
- **Battle Scripts** — Pet battle scripts can be stored inside the notes using the PetBattleTeams script markers
- **Pet Selection** — If several owned pets match the requested species and breed, PetBattleTeams selects one using its own pet-selection logic
- **Missing Pets** — A missing pet does not prevent the team itself from being imported; the slot may remain empty if no suitable owned pet is available
- **Backups** — Export includes everything PetBattleTeams stores; the original ReMatch string is still the safest backup of ReMatch-only data (groups)