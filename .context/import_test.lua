-- Pure Lua 5.1 tests for RematchImporter / RematchExporter / TeamModel (no WoW API needed).
-- Run from the repository root:  lua tests/rematch_import_test.lua   (or python tests/run.py)

local ns = {}
local function load(path)
    return assert(loadfile(path))("PetBattleTeams", ns)
end
local MODULES = "PetBattleTeams/modules/"
local Importer = load(MODULES .. "RematchImporter.lua")
local Exporter = load(MODULES .. "RematchExporter.lua")
local TeamModel = load(MODULES .. "TeamModel.lua")

---------------------------------------------------------------- framework
local passed, failed = 0, {}
local currentGroup = ""

local function check(cond, description, detail)
    if cond then
        passed = passed + 1
    else
        failed[#failed + 1] = currentGroup .. ": " .. description .. (detail and (" -> " .. tostring(detail)) or "")
    end
end

local function eq(actual, expected, description)
    check(actual == expected, description, "expected [" .. tostring(expected) .. "] got [" .. tostring(actual) .. "]")
end

local function group(name) currentGroup = name end

---------------------------------------------------------------- fake game
local EMPTY = TeamModel.EMPTY_PET
local SPECIES = {
    [1000] = { 101, 102, 103, 201, 202, 203 },
    [2000] = { 111, 112, 113, 211, 212, 213 },
    [3000] = { 121, 122, 123, 221, 222, 223 },
    [794] = { 131, 132, 133, 231, 232, 233 },
    [2089] = { 141, 142, 143, 241, 242, 243 },
}
local function NewPets()
    return {
        { id = "BattlePet-0-A", species = 1000, level = 25, breed = 4, rarity = 3 },
        { id = "BattlePet-0-B", species = 1000, level = 10, breed = 5, rarity = 2 },
        { id = "BattlePet-0-C", species = 2000, level = 25, breed = 6, rarity = 3 },
    }
end

local function NewApi(pets)
    pets = pets or NewPets()
    local byID = {}
    for _, p in ipairs(pets) do byID[p.id] = p end
    local api = {}
    function api.SpeciesExists(id) return SPECIES[id] ~= nil end
    function api.AbilityList(id) return SPECIES[id] or {} end
    function api.PetSpecies(petID) return byID[petID] and byID[petID].species end
    function api.Breed(petID) return byID[petID] and byID[petID].breed or 0 end
    function api.FindPetID(speciesID, breed, used)
        local best, bestWeight = nil, 0
        for _, p in ipairs(pets) do
            if p.species == speciesID and not used[p.id] then
                local weight = p.level * 100 + ((breed ~= 0 and p.breed == breed) and 10 or 0) + p.rarity
                if weight > bestWeight then best, bestWeight = p.id, weight end
            end
        end
        return best
    end
    return api
end

local function Import(text, teams, api, options)
    teams = teams or {}
    api = api or NewApi()
    local report = TeamModel.Merge(teams, Importer.Parse(text), api, options)
    return teams, report, api
end

local function Export(team, api)
    return TeamModel.ToString(team, team.name, api)
end

-- import one string, export it again, compare
local function RoundTrip(text, description)
    local teams, report, api = Import(text)
    check(teams[1] ~= nil, description .. ": a team was imported", report.entries[1] and report.entries[1].reason)
    if teams[1] then
        eq(Export(teams[1], api), text, description .. ": export == input")
    end
    return teams, report, api
end

local BEGIN = "-----BEGIN PET BATTLE SCRIPT-----"
local END = "-----END PET BATTLE SCRIPT-----"

---------------------------------------------------------------- A-K round trips
group("A-C ability tiers")
do
    local teams = RoundTrip("T000:36VF:0004V8:ZL:ZI:", "tiers 000")
    eq(teams[1][1].petID, "BattlePet-0-A", "000: best pet chosen")
    eq(teams[1][1].abilities[1], 101, "000: concrete ability is tier 1 for WoW")
    eq(teams[1].rematch.slots[1].abilityTiers[1], 0, "000: 0 kept in the model")

    RoundTrip("T101:36VF:1014V8:ZL:ZI:", "tiers 101")

    local t = RoundTrip("T012:36VF:01261UG:ZL:ZI:", "tiers 012")
    eq(t[1][1].abilities[1], 111, "012: slot1 tier 0 -> first ability")
    eq(t[1][1].abilities[2], 112, "012: slot2 tier 1")
    eq(t[1][1].abilities[3], 213, "012: slot3 tier 2 -> second-tier ability")
end

group("D npc ids")
do
    local teams, _, api = RoundTrip("Npc:36VF,1A2B,4K9:1014V8:ZL:ZI:", "three npc ids")
    eq(teams[1].npcID, tonumber("36VF", 32) .. ", " .. tonumber("1A2B", 32) .. ", " .. tonumber("4K9", 32), "npc list stored")
    teams[1].npcID = "12345 (Zone 2)"
    eq(Export(teams[1], api), "Npc:C1P:1014V8:ZL:ZI:", "npc edited in the UI format: only the id is exported, not digits of the name")
    teams[1].npcID = "12345 (A, 7), 99"
    eq(Export(teams[1], api), "Npc:C1P,33:1014V8:ZL:ZI:", "npc names containing digits/commas are ignored, ids re-encoded in base32")
    local ids = TeamModel.ParseNpcField("12345 (A, 7), 99")
    eq(#ids, 2, "npc field with names containing commas/digits")
    RoundTrip("NoNpc::1014V8:ZL:ZI:", "no npc id")
    RoundTrip("Zero:0,36VF:1014V8:ZL:ZI:", "npc id 0 kept verbatim")
end

group("E-F notes and scripts")
do
    RoundTrip("N1:1A:1014V8:ZL:ZI:N:one line", "note only")
    RoundTrip("N2:1A:1014V8:ZL:ZI:N:l1\\nl2\\n\\nl4", "multi-line note")
    local t = RoundTrip("S1:1A:1014V8:ZL:ZI:N:" .. BEGIN .. "\\nchange(#1)\\n" .. END, "script only")
    eq(t[1].script, "change(#1)", "script only: stored in team.script")
    eq(t[1].note, nil, "script only: no note")

    t = RoundTrip("S2:1A:1014V8:ZL:ZI:N:Hello\\n\\n" .. BEGIN .. "\\nchange(#1)\\n" .. END, "note + script")
    eq(t[1].note, "Hello", "note + script: note separate")
    eq(t[1].script, "change(#1)", "note + script: script separate")

    t = RoundTrip("S3:1A:1014V8:ZL:ZI:N:a\\nb\\nc\\n\\n" .. BEGIN .. "\\nif [self(#1).active]\\nchange(#1)\\nendif\\n" .. END, "multi-line note + multi-line script")
    eq(t[1].script, "if [self(#1).active]\nchange(#1)\nendif", "multi-line script")

    local teams, _, api = RoundTrip("S4:1A:1014V8:ZL:ZI:N:Intro\\n" .. BEGIN .. "\\nx\\n" .. END .. "\\nAfter", "script followed by a note")
    eq(teams[1].script, "x", "script followed by note: script")
    eq(teams[1].note, "Intro\n\nAfter", "script followed by note: nothing dropped from the visible note")
    teams[1].note = "Intro2\n\nAfter"
    eq(Export(teams[1], api), "S4:1A:1014V8:ZL:ZI:N:Intro2\\n\\nAfter\\n\\n" .. BEGIN .. "\\nx\\n" .. END, "edited note is rebuilt, nothing lost")

    teams, _, api = RoundTrip("S5:1A:1014V8:ZL:ZI:N:" .. BEGIN .. "\\nx\\n" .. END .. "\\nmid\\n" .. BEGIN .. "\\ny\\n" .. END, "two script blocks")
    teams[1].script = "x2"
    local exported = Export(teams[1], api)
    check(exported:find("y", 1, true) ~= nil, "second script block survives an edit of the first")
    check(exported:find("x2", 1, true) ~= nil, "edited script exported")

    teams, _, api = Import("N3:1A:1014V8:ZL:ZI:")
    teams[1].note = "added in UI"
    teams[1].script = "s"
    eq(Export(teams[1], api), "N3:1A:1014V8:ZL:ZI:N:added in UI\\n\\n" .. BEGIN .. "\\ns\\n" .. END, "note and script added in the UI")
end

group("G-I pets")
do
    local t, _, api = RoundTrip("Br:1A:0005V8:ZL:ZI:", "explicit breed")
    eq(t[1][1].petID, "BattlePet-0-A", "explicit breed: level still wins like in Rematch")
    eq(t[1].rematch.slots[1].breed, 5, "explicit breed: requested breed kept although pet A is breed 4")
    t[1][1].abilities[1] = 201
    eq(Export(t[1], api), "Br:1A:2005V8:ZL:ZI:", "explicit breed: requested breed (5) survives an edit, not replaced by the pet's breed (4)")

    t, _, api = RoundTrip("Tw:1A:1014V8:2014V8:ZL:", "two pets, same species")
    eq(t[1][1].petID, "BattlePet-0-A", "twins: first gets best pet")
    eq(t[1][2].petID, "BattlePet-0-B", "twins: second gets another pet")
    eq(t[1][2].abilities[1], 201, "twins: tier 2 concrete ability")

    t = RoundTrip("Tw3:1A:1014V8:1014V8:1014V8:", "three requests, two owned")
    eq(t[1][3].petID, EMPTY, "third request: slot left empty (never the same pet twice)")

    local report
    t, report = RoundTrip("Ghost:1A:11102TO:ZI:ZI:", "requested but not owned")
    eq(t[1][1].petID, EMPTY, "unowned: empty slot")
    check(#report.entries[1].warnings > 0, "unowned: a warning is reported")

    t, report = RoundTrip("Unk:1A:11104GF:ZI:ZI:", "unknown species")
    check(#report.entries[1].warnings > 0, "unknown species: warning")

    RoundTrip("Empty:1A::::", "three empty slots")
end

group("pet edited in the UI")
do
    local teams, _, api = Import("E:1A:0004V8:ZL:ZI:")
    local team = teams[1]
    eq(Export(team, api), "E:1A:0004V8:ZL:ZI:", "baseline")
    team[1].abilities[1] = 101
    eq(Export(team, api), "E:1A:0004V8:ZL:ZI:", "value unchanged: tier 0 (any) is not turned into 1")
    team[1].abilities[1] = 201
    eq(Export(team, api), "E:1A:2004V8:ZL:ZI:", "ability changed to a tier 2 one")
    team[1].abilities[2] = 102
    team[1].abilities[3] = 203
    eq(Export(team, api), "E:1A:2024V8:ZL:ZI:", "slots that did not change keep their 0 while others are recomputed")
    team[1].abilities = { 101, 202, 103 }
    eq(Export(team, api), "E:1A:0204V8:ZL:ZI:", "back to the imported values: untouched slots 0, changed slot recomputed")
    team[1].petID = "BattlePet-0-B"
    team[1].abilities = { 101, 202, 103 }
    eq(Export(team, api), "E:1A:1215V8:ZL:ZI:", "other pet: actual breed and recomputed tiers")
    team[1].petID = EMPTY
    eq(Export(team, api), "E:1A::ZL:ZI:", "pet removed from the slot exports as an empty slot")
end

group("J P: preferences")
do
    RoundTrip("P1:1A:1014V8:ZL:ZI:P:1000::::::", "P: alone")
    RoundTrip("P2:1A:1014V8:ZL:ZI:P::1:::::", "P: allowMM")
    RoundTrip("P3:1A:1014V8:ZL:ZI:P:::::20:25.5:", "P: xp with decimals")
    RoundTrip("P4:1A:1014V8:ZL:ZI:P:1000:1:2:3000:20:25:N:note\\nline 2", "P: + N:")
    local parsed = Importer.Parse("P5:1A:1014V8:ZL:ZI:P:1000:1:2:3000:20:25:N:x")
    eq(parsed.teams[1].preferences.minHP, "1000", "P: fields parsed")
    eq(parsed.teams[1].notes, "x", "P: then notes")
end

group("K group headers")
do
    local text = "__ My Group:1:123:ABC:1: __\nInGroup:1A:1014V8:ZL:ZI:\n__ Legacy __\nAfterLegacy:1A:1014V8:ZL:ZI:"
    local teams, report, api = Import(text)
    eq(#teams, 2, "teams after headers are imported")
    eq(report.ignored, 2, "two headers reported as ignored")
    eq(Export(teams[1], api), "InGroup:1A:1014V8:ZL:ZI:", "team after header exported without header")
    eq(teams[1].rematch.group, "My Group", "group name kept as metadata")

    local parsed = Importer.Parse("T:1A:ZL:ZL:ZL:\n__ G:1:1:1:1: __\nU:1A:ZL:ZL:ZL:")
    eq(parsed.groupsApplicable, false, "team before any group: groups not applicable (Rematch rule)")

    eq(Importer.ParseGroupHeader("__ G:1:2A:FF0:1:P:1000::::::  __") == nil, false, "group header with preferences recognized")
end

---------------------------------------------------------------- special tags
group("special tags ZI ZU ZL ZR ZN Q")
do
    for _, tag in ipairs({ "ZI", "ZU", "ZL", "ZR3", "ZR0", "ZN1A2B", "Q1A4V8" }) do
        local text = "Sp:1A:" .. tag .. ":1014V8:ZL:"
        local teams, report, api = Import(text)
        eq(teams[1][1].petID, EMPTY, tag .. ": slot empty in PBT")
        eq(Export(teams[1], api), text, tag .. ": tag preserved on export")
        check(#report.entries[1].warnings > 0, tag .. ": warning explains it")
    end
    local t = Importer.ParseTag("ZR3")
    eq(t.type .. t.petType, "random3", "ZR petType parsed")
    t = Importer.ParseTag("ZN1A2B")
    eq(t.type .. t.npcID, "unnotable" .. tonumber("1A2B", 32), "ZN npcID parsed")
    eq(Importer.ParseTag("Q1A4V8").type, "queue", "Q is a queue tag")

    local teams, _, api = Import("Sp2:1A:ZL:ZI:ZU:")
    teams[1][1] = { petID = "BattlePet-0-A", speciesID = 1000, abilities = { 101, 102, 103 } }
    eq(Export(teams[1], api), "Sp2:1A:1114V8:ZI:ZU:", "a pet put in a ZL slot replaces the tag")
    teams[1][1] = { petID = EMPTY, abilities = { 0, 0, 0 } }
    eq(Export(teams[1], api), "Sp2:1A:ZL:ZI:ZU:", "slot emptied again: the original special tag is restored")
end

---------------------------------------------------------------- real example
group("export.txt")
do
    local file = io.open("export.txt", "rb")
    if file then
        local content = file:read("*a")
        file:close()
        content = content:gsub("^\239\187\191", ""):gsub("%s+$", "")
        local teams, report, api = Import(content)
        eq(#teams, 1, "export.txt imports one team")
        eq(Export(teams[1], api), content, "export.txt round trip is identical")
        eq(teams[1].name, "Jarrun's Ladder", "name")
        check(teams[1].script ~= nil and teams[1].script:find("change%(#1%)") ~= nil, "script extracted")
        check(teams[1].note and teams[1].note:find("Strategy added by Askevin", 1, true), "note extracted")
        local _, again = Import(content, teams, api)
        eq(again.unchanged, 1, "importing export.txt twice is a no-op")
    else
        check(false, "export.txt not found (run from the repository root)")
    end
end

---------------------------------------------------------------- architecture-level cases
group("simple / multiple / metadata")
do
    local _, report = Import("One:1A:1014V8:ZL:ZI:")
    eq(report.imported, 1, "simple string")

    local teams
    teams, report = Import("One:1A:1014V8:ZL:ZI:\nTwo:2B:ZL:ZL:ZL:\nThree::::ZI:\n")
    eq(report.imported, 3, "multiple strings")
    eq(#teams, 3, "three teams")

    teams = RoundTrip("Meta:36VF,1A2B:01261UG:1014V8:ZL:P:1000:1:2:3000:20:25:N:a\\nb", "all metadata together")
    eq(teams[1].npcID ~= nil and teams[1].rematch.preferences.maxHP, "3000", "preferences kept in team.rematch")
end

group("placeholders and special characters")
do
    RoundTrip("P%s {x} $v:1A:ZL:ZL:ZL:N:%s {name} $1 [x] ^ $ . * + ? (a)", "pattern characters in name and notes stay literal")
    RoundTrip("Équipe Ünïcode 龍 ñ:1A:1014V8:ZL:ZI:N:Ça va? 日本語 — ñ «quotes»\\nligne 2", "unicode name and notes")
    local teams, _, api = Import("x:1A:ZL:ZL:ZL:")
    teams[1].name = "with:colon\nand newline"
    eq(Export(teams[1], api), "with-colon and newline:1A:ZL:ZL:ZL:", "name is sanitized so the format stays parseable")
    local _, report = Import("Dupe Ñ:1A:ZL:ZL:ZL:\ndupe ñ:1A:ZL:ZL:ZL:")
    check(report.imported >= 1, "non-ASCII case differences do not crash")
    RoundTrip("Windows:1A:1014V8:ZL:ZI:N:l1\\nl2", "plain line")
    local crlf, report2 = Import("A:1A:ZL:ZL:ZL:\r\nB:1A:ZL:ZL:ZL:\r\n")
    eq(#crlf, 2, "CRLF line endings")
    eq(crlf[1].name, "A", "no stray \\r in name")
    eq(report2.errors, 0, "no error with CRLF")
end

group("invalid strings / partial import")
do
    local text = "Good1:1A:1014V8:ZL:ZI:\nthis is not a team\n:1A:ZL:ZL:ZL:\nGood2:1A:ZL:ZL:ZL:\nBad:1A:ZL:ZL\nGood3:1A!:ZL:ZL:ZL:"
    local teams, report = Import(text)
    eq(#teams, 2, "valid lines imported despite the invalid ones")
    eq(report.errors, 4, "four invalid lines reported")
    local lines = {}
    for _, e in ipairs(report.entries) do if e.status == "error" then lines[#lines + 1] = e.line end end
    eq(table.concat(lines, ","), "2,3,5,6", "error line numbers")
    check(report.entries[2].reason ~= nil, "each error has a reason")
    _, report = Import("")
    eq(report.imported + report.errors, 0, "empty input")
    _, report = Import(nil)
    eq(report.imported + report.errors, 0, "nil input")
    _, report = Import("T:1A:ZL:ZL:ZL:garbage")
    eq(report.imported, 1, "unrecognized trailing data does not block the team")
    check(#report.entries[1].warnings > 0, "trailing garbage produces a warning")
    _, report = Import("T:1A!:ZL:ZL:ZL:")
    eq(report.errors, 1, "invalid npc characters: line rejected")
    local p = Importer.ParseTeamLine("T:ZZ,1A:ZL:ZL:ZL:")
    check(p ~= nil and #p.warnings == 1 and #p.npcIDs == 1, "alphanumeric but non-base32 npc id is skipped with a warning")
end

group("duplicates and idempotence")
do
    local teams, report = Import("Dup:1A:1014V8:ZL:ZI:\nDup:1A:1014V8:ZL:ZI:")
    eq(#teams, 1, "same line twice -> one team")
    eq(report.unchanged, 1, "second occurrence reported unchanged")

    local api = NewApi()
    local text = "A:1A:1014V8:ZL:ZI:N:x\nB:2B:01261UG:ZL:ZI:P:1000::::::\nC:::ZL:ZI:"
    teams, report = Import(text, nil, api)
    eq(report.imported, 3, "first import")
    local before = {}
    for i, t in ipairs(teams) do before[i] = Export(t, api) end
    _, report = Import(text, teams, api)
    eq(report.unchanged, 3, "second import of the same text: all unchanged")
    eq(#teams, 3, "no duplicates created")
    for i, t in ipairs(teams) do eq(Export(t, api), before[i], "team " .. i .. " unchanged") end
    -- exporting then importing the export is also a no-op
    local all = {}
    for i, t in ipairs(teams) do all[i] = Export(t, api) end
    _, report = Import(table.concat(all, "\n"), teams, api)
    eq(report.unchanged, 3, "importing the addon's own export is a no-op")
    -- importing into a fresh profile then exporting gives the same text
    local fresh = Import(table.concat(all, "\n"))
    local text2 = {}
    for i, t in ipairs(fresh) do text2[i] = Export(t, NewApi()) end
    eq(table.concat(text2, "\n"), table.concat(all, "\n"), "export -> import -> export is stable")
    -- case-insensitive identity
    _, report = Import("a:1A:1014V8:ZL:ZI:N:x", teams, api)
    eq(report.unchanged, 1, "identity ignores case (like a name lookup)")
end

group("re-import after modification")
do
    local api = NewApi()
    local teams = Import("T:1A:1014V8:ZL:ZI:N:v1", nil, api)
    local original = teams[1]

    local _, report = Import("T:1A:1014V8:ZL:ZI:N:v2", teams, api)
    eq(report.skipped, 1, "default policy: conflict reported, nothing replaced")
    eq(original.note, "v1", "existing team untouched")
    eq(#teams, 1, "no team added")

    _, report = Import("T:1A:1014V8:ZL:ZI:N:v2", teams, api, { conflict = "overwrite" })
    eq(report.updated, 1, "overwrite: updated")
    eq(teams[1], original, "overwrite keeps the same table (selection/UI references stay valid)")
    eq(original.note, "v2", "overwrite: new content")
    _, report = Import("T:1A:1014V8:ZL:ZI:N:v2", teams, api, { conflict = "overwrite" })
    eq(report.unchanged, 1, "overwrite twice: second is a no-op")

    original.locked = true
    _, report = Import("T:1A:1014V8:ZL:ZI:N:v3", teams, api, { conflict = "overwrite" })
    eq(report.skipped, 1, "locked team is never overwritten")
    eq(original.note, "v2", "locked team untouched")
    original.locked = nil

    _, report = Import("T:1A:1014V8:ZL:ZI:N:v3", teams, api, { conflict = "copy" })
    eq(report.imported, 1, "copy policy: new team")
    eq(teams[2].name, "T (2)", "copy gets a unique name")
    _, report = Import("T:1A:1014V8:ZL:ZI:N:v3", teams, api, { conflict = "copy" })
    eq(report.unchanged, 1, "copy policy is idempotent too")
    eq(#teams, 2, "still two teams")
    _, report = Import("T:1A:1014V8:ZL:ZI:N:v4", teams, api, { conflict = "copy" })
    eq(teams[3] and teams[3].name, "T (3)", "next modification -> T (3)")

    -- a team modified in PBT then re-imported from the original string
    local t2 = Import("M:1A:1014V8:ZL:ZI:N:orig", nil, api)
    t2[1].note = "my edit"
    _, report = Import("M:1A:1014V8:ZL:ZI:N:orig", t2, api)
    eq(report.skipped, 1, "local edits are detected as a difference, not silently replaced")
    _, report = Import("M:1A:1014V8:ZL:ZI:N:orig", t2, api, { conflict = "overwrite" })
    eq(t2[1].note, "orig", "overwrite restores the original")
end

group("large set")
do
    local lines = {}
    local tags = { "1014V8", "01261UG", "2014V8", "ZL", "ZI", "", "0004V8" }
    for i = 1, 2000 do
        lines[#lines + 1] = string.format("Team %04d:%s:%s:%s:%s:N:note %d\\nsecond", i, Exporter.ToBase32(i * 7),
            tags[i % #tags + 1], tags[(i + 2) % #tags + 1], tags[(i + 4) % #tags + 1], i)
    end
    local text = table.concat(lines, "\n")
    local api = NewApi()
    local start = os.clock()
    local teams, report = Import(text, nil, api)
    local t1 = os.clock() - start
    eq(report.imported, 2000, "2000 teams imported")
    start = os.clock()
    local _, again = Import(text, teams, api)
    local t2 = os.clock() - start
    eq(again.unchanged, 2000, "2000 teams re-imported as unchanged")
    local all = {}
    for i, t in ipairs(teams) do all[i] = Export(t, api) end
    eq(table.concat(all, "\n"), text, "2000 teams: export == input")
    print(string.format("  large set: import %.3fs, re-import %.3fs", t1, t2))
end

group("parser is independent from the game")
do
    local parsed = Importer.Parse("X:1A:1014V8:ZL:ZI:N:n")
    eq(parsed.entries[1].kind, "team", "Parse works with no game API loaded")
    eq(parsed.teams[1].pets[1].type, "pet", "tag parsed into a structure")
    eq(parsed.teams[1].pets[1].speciesID, 1000, "species decoded")
    eq(parsed.teams[1].pets[1].breed, 4, "breed decoded")
    eq(parsed.teams[1].pets[1].abilityTiers[2], 0, "0 is decoded as 0")
end

---------------------------------------------------------------- unnamed teams
group("unnamed teams")
do
    local LABEL = "\195\137quipe : |cff00ffff"
    local function UnnamedApi()
        local api = NewApi()
        function api.IsDefaultName(name) return TeamModel.IsDefaultName(name, LABEL) end
        return api
    end

    check(TeamModel.IsDefaultName("Team 1", LABEL), "'Team 1' is a default name")
    check(TeamModel.IsDefaultName("Team: |cff00ffff12", LABEL), "'Team: <color>12' is a default name")
    check(TeamModel.IsDefaultName("\195\137quipe - 3", LABEL), "localized name rewritten by the exporter is a default name")
    check(TeamModel.IsDefaultName("\195\137quipe : |cff00ffff3", LABEL), "localized display name is a default name")
    check(not TeamModel.IsDefaultName("Team", LABEL), "'Team' alone is a real name")
    check(not TeamModel.IsDefaultName("Team Rocket 1", LABEL), "'Team Rocket 1' is a real name")
    check(not TeamModel.IsDefaultName("Boss 1", LABEL), "'Boss 1' is a real name")

    local api = UnnamedApi()
    local teams, report = Import("Team 1:36VF:1014V8:ZL:ZI:\n\195\137quipe - 2::0004V8::ZI:\nBoss:::::", nil, api)
    eq(report.imported, 3, "three teams imported")
    eq(teams[1].name, nil, "'Team 1' imported without a name")
    eq(teams[2].name, nil, "localized default name imported without a name")
    eq(teams[3].name, "Boss", "a real name is kept")
    eq(TeamModel.ToString(teams[1], TeamModel.DefaultExportName(1), api), "Team 1:36VF:1014V8:ZL:ZI:", "unnamed team exports as 'Team N'")

    local _, again = Import("Team 1:36VF:1014V8:ZL:ZI:\nBoss:::::", teams, api)
    eq(again.unchanged, 2, "re-importing unnamed and named teams changes nothing")
    eq(#teams, 3, "no duplicate created")

    local _, other = Import("Team 5:36VF:2014V8:ZL:ZI:", teams, api)
    eq(other.imported, 1, "a different unnamed team is added")
    eq(#teams, 4, "now four teams")
end

---------------------------------------------------------------- summary
print(string.format("%d checks passed, %d failed", passed, #failed))
for _, message in ipairs(failed) do print("FAIL " .. message) end
if #failed > 0 then error("tests failed") end
