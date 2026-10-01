--[[
TeamModel: bridge between Rematch records and PetBattleTeams' own team tables.

Direction of dependencies: Rematch strings -> RematchImporter -> TeamModel -> TeamManager.teams.
TeamModel never reads or writes a Rematch string itself; it only works with records
(RematchImporter output / RematchExporter input) and the addon's team tables.

Everything that touches the game is injected through `api`:
  api.SpeciesExists(speciesID) -> boolean
  api.AbilityList(speciesID)   -> { [1..6] = abilityID }   ([i] tier 1, [i+3] tier 2)
  api.PetSpecies(petID)        -> speciesID or nil
  api.Breed(petID)             -> breed (3..12) or 0
  api.FindPetID(speciesID, breed, usedPetIDs) -> petID or nil

Rematch information PetBattleTeams cannot represent (tiers 0 = "any ability", requested
breed, special tags ZL/ZI/ZR/ZN/ZU, P: preferences, raw NPC list, exact notes layout) is kept
in team.rematch. It is only re-used on export while it is still consistent with the team
(same pet, same abilities, same notes/script, same NPC text); otherwise the value is
recomputed from the current team. Nothing in TeamManager has to know about it.
]]

local _, ns = ...
ns = ns or {}

local Importer = ns.RematchImporter
local Exporter = ns.RematchExporter
local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local TeamModel = {}
ns.TeamModel = TeamModel

local PETS_PER_TEAM = 3
local EMPTY_PET = "BattlePet-0-000000000000"
local SCRIPT_BEGIN = "-----BEGIN PET BATTLE SCRIPT-----"
local SCRIPT_END = "-----END PET BATTLE SCRIPT-----"

TeamModel.EMPTY_PET = EMPTY_PET

local Trim = Importer.Trim

function TeamModel.KeyFor(name)
    return Trim(name or ""):lower()
end

-- An unnamed team is shown as "<Team: >N" and exported as "Team N"; colour codes, ":" and "-" are
-- ignored because the exporter rewrites ":" into "-".
local function NormalizeLabel(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[:%-]", " "):gsub("%s+", " ")
    return Trim(text):lower()
end

function TeamModel.DefaultExportName(teamIndex)
    return "Team " .. teamIndex
end

-- localizedPrefix: the localized "Team: " label used for unnamed teams (may be nil)
function TeamModel.IsDefaultName(name, localizedPrefix)
    if type(name) ~= "string" then return false end
    local normalized = NormalizeLabel(name)
    local labels = { "team" }
    if localizedPrefix and localizedPrefix ~= "" then
        labels[2] = NormalizeLabel(localizedPrefix)
    end
    for _, label in ipairs(labels) do
        local digits = label ~= "" and normalized:match("^" .. label:gsub("%p", "%%%0") .. " (%d+)$")
        if digits then return true end
    end
    return false
end

local function AsString(value)
    if value == nil then return nil end
    return tostring(value)
end

local function CopyList(list)
    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    return copy
end

-- Scripts: only the first BEGIN/END block is split out. Text after it is appended to the note.
local function SplitScript(text)
    local beginStart, beginEnd = text:find(SCRIPT_BEGIN, 1, true)
    local endStart, endEnd
    if beginStart then
        endStart, endEnd = text:find(SCRIPT_END, beginEnd + 1, true)
    end
    if not (beginStart and endStart) then
        return Trim(text), nil
    end

    local before = Trim(text:sub(1, beginStart - 1))
    local after = Trim(text:sub(endEnd + 1))
    local note = before
    if after ~= "" then
        note = (note ~= "" and (note .. "\n\n") or "") .. after
    end
    local script = Trim(text:sub(beginEnd + 1, endStart - 1))
    return note, (script ~= "" and script or nil)
end

local function JoinNotes(note, script)
    local parts = {}
    if note ~= "" then parts[#parts + 1] = note end
    if script ~= "" then parts[#parts + 1] = SCRIPT_BEGIN .. "\n" .. script .. "\n" .. SCRIPT_END end
    return table.concat(parts, "\n\n")
end

-- NPC text such as "12345", "12345 (Name)", "1, 2, 3" or "1 (A 2), 3 (B)" -> { 12345 } / { 1, 2, 3 }
function TeamModel.ParseNpcField(value)
    local ids = {}
    if value == nil then return ids end
    local text = tostring(value):gsub("%b()", "")
    for digits in text:gmatch("%d+") do
        ids[#ids + 1] = tonumber(digits)
    end
    return ids
end

local function TierOf(abilityList, abilityID, index)
    if not abilityID or abilityID == 0 then return 0 end
    if abilityID == abilityList[index] then return 1 end
    if abilityID == abilityList[index + 3] then return 2 end
    return 0
end

-- Rematch info -> addon pet. Returns the pet and the slot metadata (nil for a plain empty slot).
local function BuildPet(info, api, used, slot, warnings)
    local pet = { petID = EMPTY_PET, abilities = { 0, 0, 0 } }
    if info.type == "empty" then
        return pet, nil
    end

    local meta = { tag = info.raw, type = info.type, petID = EMPTY_PET }

    if info.type ~= "pet" then
        warnings[#warnings + 1] = string.format(
            L["slot %d: tag '%s' cannot be represented by PetBattleTeams; slot left empty, tag kept for export"],
            slot, info.raw)
        return pet, meta
    end

    if not api.SpeciesExists(info.speciesID) then
        warnings[#warnings + 1] = string.format(L["slot %d: species %d is unknown; slot left empty, tag kept for export"], slot, info.speciesID)
        return pet, meta
    end

    meta.speciesID = info.speciesID
    meta.breed = info.breed
    meta.abilityTiers = CopyList(info.abilityTiers)

    local list = api.AbilityList(info.speciesID)
    local abilities = {}
    for i = 1, 3 do
        abilities[i] = (info.abilityTiers[i] == 2 and list[i + 3] or list[i]) or 0
    end

    local petID = api.FindPetID(info.speciesID, info.breed, used)
    if petID then
        used[petID] = true
        pet.petID = petID
        pet.speciesID = info.speciesID
        pet.abilities = abilities
        meta.petID = petID
        meta.abilities = CopyList(abilities)
    else
        warnings[#warnings + 1] = string.format(L["slot %d: no owned pet of species %d; slot left empty, tag kept for export"], slot, info.speciesID)
    end
    return pet, meta
end

function TeamModel.FromRecord(record, api)
    local warnings = {}
    for _, warning in ipairs(record.warnings or {}) do
        warnings[#warnings + 1] = warning
    end

    local team = { name = record.name, enabled = { true, true, true } }
    local meta = {
        key = TeamModel.KeyFor(record.name),
        npcIDsRaw = record.npcIDsRaw,
        preferences = record.preferences,
        group = record.group,
        slots = {},
    }
    team.rematch = meta

    local ids = {}
    for _, id in ipairs(record.npcIDs or {}) do
        if id > 0 then ids[#ids + 1] = tostring(id) end
    end
    if #ids > 0 then
        team.npcID = table.concat(ids, ", ")
    end
    meta.npcIDsSnapshot = team.npcID

    if record.notes then
        local note, script = SplitScript(record.notes)
        team.note = note ~= "" and note or nil
        team.script = script
        meta.notes = record.notes
        meta.noteSnapshot = team.note or ""
        meta.scriptSnapshot = script or ""
    end

    local used = {}
    for i = 1, PETS_PER_TEAM do
        team[i], meta.slots[i] = BuildPet(record.pets[i], api, used, i, warnings)
    end

    return team, warnings
end

local function SlotTag(pet, slotMeta, api)
    local petID = pet and pet.petID
    if not petID or petID == EMPTY_PET then
        if slotMeta and slotMeta.petID == EMPTY_PET then return slotMeta.tag end
        return ""
    end

    local sameAsImport = slotMeta ~= nil and slotMeta.petID == petID
    local speciesID = api.PetSpecies(petID)
    if not speciesID then
        if sameAsImport then return slotMeta.tag end
        return "ZU"
    end

    local abilities = pet.abilities or {}
    local sameSlot = sameAsImport and slotMeta.speciesID == speciesID and slotMeta.abilityTiers ~= nil
    local allSame = sameSlot
    local tiers, list = {}, nil
    for i = 1, 3 do
        if sameSlot and abilities[i] == slotMeta.abilities[i] then
            tiers[i] = slotMeta.abilityTiers[i]
        else
            allSame = false
            list = list or api.AbilityList(speciesID)
            tiers[i] = TierOf(list, abilities[i], i)
        end
    end
    if allSame then return slotMeta.tag end

    local breed
    if sameAsImport and slotMeta.speciesID == speciesID and slotMeta.breed ~= nil then
        breed = slotMeta.breed
    else
        breed = api.Breed(petID)
    end
    return table.concat(tiers) .. Exporter.ToBase32(breed) .. Exporter.ToBase32(speciesID)
end

function TeamModel.ToRecord(team, name, api)
    local meta = team.rematch or {}
    local record = { name = name, tags = {} }

    if meta.npcIDsRaw and AsString(team.npcID) == meta.npcIDsSnapshot then
        record.npcIDsRaw = meta.npcIDsRaw
    else
        record.npcIDs = TeamModel.ParseNpcField(team.npcID)
    end

    local note, script = Trim(team.note or ""), Trim(team.script or "")
    if meta.notes and note == meta.noteSnapshot and script == meta.scriptSnapshot then
        record.notes = meta.notes
    else
        record.notes = JoinNotes(note, script)
    end

    record.preferences = meta.preferences

    local slots = meta.slots or {}
    for i = 1, PETS_PER_TEAM do
        record.tags[i] = SlotTag(team[i], slots[i], api)
    end
    return record
end

function TeamModel.ToString(team, name, api)
    return Exporter.Serialize(TeamModel.ToRecord(team, name, api))
end

local function WithName(record, name)
    local renamed = {}
    for k, v in pairs(record) do renamed[k] = v end
    renamed.name = name
    return renamed
end

-- First name of the series "Name", "Name (2)", ... that is free, or that already holds an identical team
local function ResolveCopyName(record, byKey, api)
    local candidate, n = record.name, 1
    while true do
        local team = byKey[TeamModel.KeyFor(candidate)]
        if not team then return candidate, nil end
        if TeamModel.ToString(team, team.name, api) == Exporter.Serialize(WithName(record, team.name)) then
            return candidate, team
        end
        n = n + 1
        candidate = string.format("%s (%d)", record.name, n)
    end
end

local MANAGED_KEYS = { "name", "note", "script", "npcID", "enabled", "rematch", 1, 2, 3 }

--[[
Merge(teams, parsed, api, options) -> report
  teams:   the addon's team array (modified in place)
  parsed:  RematchImporter.Parse result
  options.conflict: what to do when a team with the same name already exists AND differs
    "skip" (default) | "overwrite" (update in place) | "copy" (import as "Name (2)")
  Identity of a team is its normalized name (same rule as Rematch). A team whose exported string is
  identical to the incoming one is reported "unchanged", so importing the same text twice is a no-op.
  api.IsDefaultName(name) (optional): true when the name is the placeholder of an unnamed team; such a
    record is imported without a name and identified by its content instead.
  report.entries[i] = { line, name, status = imported|updated|unchanged|skipped|ignored|error, reason, warnings }
  report.touched = list of team tables that were added or updated
]]
function TeamModel.Merge(teams, parsed, api, options)
    local conflict = options and options.conflict or "skip"
    local report = {
        imported = 0, updated = 0, unchanged = 0, skipped = 0, ignored = 0, errors = 0,
        entries = {}, touched = {},
    }

    local byKey = {}
    for _, team in ipairs(teams) do
        if team.name then
            byKey[TeamModel.KeyFor(team.name)] = team
        end
    end

    local function add(entry, status, reason, warnings)
        local counter = status == "error" and "errors" or status
        report[counter] = report[counter] + 1
        report.entries[#report.entries + 1] = {
            line = entry.line, name = entry.name, status = status, reason = reason, warnings = warnings,
        }
    end

    for _, entry in ipairs(parsed.entries) do
        if entry.kind == "group" then
            add({ line = entry.line, name = entry.group.name }, "ignored", L["group header (groups are not supported)"])
        elseif entry.kind == "invalid" then
            add({ line = entry.line, name = entry.text }, "error", entry.reason)
        else
            local record = entry.record
            local info = { line = entry.line, name = record.name }
            local unnamed = api.IsDefaultName and api.IsDefaultName(record.name)
            if unnamed then
                record.name = nil
            end
            local existing = (not unnamed) and byKey[TeamModel.KeyFor(record.name)] or nil
            local identical = existing and TeamModel.ToString(existing, existing.name, api) == Exporter.Serialize(WithName(record, existing.name))
            local copyName

            if existing and not identical and conflict == "copy" then
                local identicalCopy
                copyName, identicalCopy = ResolveCopyName(record, byKey, api)
                identical = identicalCopy ~= nil
            end

            if unnamed then
                local incoming = Exporter.Serialize(record)
                for _, team in ipairs(teams) do
                    if not team.name and TeamModel.ToString(team, nil, api) == incoming then
                        identical = true
                        break
                    end
                end
            end

            if identical then
                add(info, "unchanged", L["identical team already present"])
            elseif unnamed then
                local team, warnings = TeamModel.FromRecord(record, api)
                teams[#teams + 1] = team
                report.touched[#report.touched + 1] = team
                add(info, "imported", nil, warnings)
            elseif existing and conflict == "overwrite" then
                if existing.locked == true then
                    add(info, "skipped", L["the existing team is locked"])
                else
                    local team, warnings = TeamModel.FromRecord(record, api)
                    for _, k in ipairs(MANAGED_KEYS) do existing[k] = nil end
                    for k, v in pairs(team) do existing[k] = v end
                    report.touched[#report.touched + 1] = existing
                    add(info, "updated", L["existing team replaced"], warnings)
                end
            elseif existing and conflict ~= "copy" then
                add(info, "skipped", L["a team with this name already exists and differs (choose overwrite to update it)"])
            else
                if copyName then record.name = copyName end
                local team, warnings = TeamModel.FromRecord(record, api)
                teams[#teams + 1] = team
                byKey[TeamModel.KeyFor(team.name)] = team
                report.touched[#report.touched + 1] = team
                info.name = team.name
                add(info, "imported", copyName and L["name already used, imported as a copy"] or nil, warnings)
            end
        end
    end

    return report
end

return TeamModel
