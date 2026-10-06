--[[
RematchImporter: reads Rematch team strings and returns plain Lua records.

Pure parser. No WoW API, no TeamManager, no pet journal. The patterns are the
ones used by Rematch itself (process/teamStrings.lua, process/petTags.lua).

Real format, one entry per line:
  Name:npcIDs:tag1:tag2:tag3:                          team
  Name:npcIDs:tag1:tag2:tag3:P:a:b:c:d:e:f:            + preferences
  Name:npcIDs:tag1:tag2:tag3:[P:...:]N:notes           + notes ("\n" = newline)
  __ Name:sort:icon:color:showTab:[P:...:] __          group header (or legacy "__ Name __")

npcIDs: base32 numbers separated by commas.
tag: "" (empty) | AAA B SSS.. (3 ability chars 0/1/2, 1 breed char, base32 species)
     | Q L R B SSS.. (leveling queue) | ZL | ZI | ZR<type> | ZN<npc> | ZU
]]

local _, ns = ...
ns = ns or {}

local L = ns.L or setmetatable({}, { __index = function(_, k) return k end })

local RematchImporter = {}
ns.RematchImporter = RematchImporter

local function Trim(str)
    return (str:match("^%s*(.-)%s*$"))
end
RematchImporter.Trim = Trim

function RematchImporter.ParseTag(tag)
    local info = { raw = tag }

    if tag == "" then
        info.type = "empty"
    elseif tag == "ZL" then
        info.type = "leveling"
    elseif tag == "ZI" then
        info.type = "ignored"
    elseif tag:match("^ZR%w") then
        info.type = "random"
        info.petType = tonumber(tag:match("^ZR(%w+)"), 32)
    elseif tag:match("^ZN%w") then
        info.type = "unnotable"
        info.npcID = tonumber(tag:match("^ZN(%w+)"), 32)
    elseif tag:match("^Z") then
        info.type = "unknown"
    else
        local speciesID = tonumber(tag:sub(5, -1), 32)
        if not speciesID or speciesID <= 0 then
            info.type = "invalid"
        else
            info.speciesID = speciesID
            info.breed = tonumber(tag:sub(4, 4), 32) or 0
            if tag:sub(1, 1) == "Q" then
                info.type = "queue"
                info.level = tonumber(tag:sub(2, 2), 32) or 0
                info.rarity = tonumber(tag:sub(3, 3), 32) or 0
            else
                info.type = "pet"
                info.abilityTiers = {}
                for i = 1, 3 do
                    local tier = tonumber(tag:sub(i, i), 32)
                    info.abilityTiers[i] = (tier == 1 or tier == 2) and tier or 0
                end
            end
        end
    end
    return info
end

function RematchImporter.ParseNpcIDs(npcIDs)
    local ids, warnings = {}, {}
    for token in npcIDs:gmatch("[^,]+") do
        local id = tonumber(token, 32)
        if id then
            ids[#ids + 1] = id
        else
            warnings[#warnings + 1] = string.format(L["NPC id '%s' is not valid base32 and was ignored"], token)
        end
    end
    return ids, warnings
end

-- Returns preferences (table of raw strings or nil), notes (unescaped or nil), recognized (boolean)
function RematchImporter.ParseExtras(extras)
    local a, b, c, d, e, f, notes = extras:match("^P:(%d*):(%d*):(%d*):(%d*):([%d%.]*):([%d%.]*):N:(.+)$")
    if not a then
        a, b, c, d, e, f = extras:match("^P:(%d*):(%d*):(%d*):(%d*):([%d%.]*):([%d%.]*):$")
    end
    if not a then
        notes = extras:match("^N:(.+)$")
    end

    local preferences
    if a then
        preferences = { minHP = a, allowMM = b, expectedDD = c, maxHP = d, minXP = e, maxXP = f }
    end
    if notes then
        notes = notes:gsub("\\n", "\n")
    end
    return preferences, notes, (a ~= nil or notes ~= nil)
end

function RematchImporter.ParseGroupHeader(line)
    local name, sort, icon, color, showTab, extras = line:match("^__ ([^\n]-):(%d*):(%w*):(%w*):(%w*):(.+) __$")
    if not name then
        name, sort, icon, color, showTab = line:match("^__ ([^\n]-):(%d*):(%w*):(%w*):(%w*): __$")
    end
    if not name then
        name = line:match("^__ (.+) __$")
    end
    if not name then
        return nil
    end
    return { name = Trim(name), sort = sort, icon = icon, color = color, showTab = showTab, extras = extras }
end

-- Returns a team record, or nil and the reason the line was rejected
function RematchImporter.ParseTeamLine(line)
    local teamString, extras = line:match("^([^\n]-:[%w,]*:%w*:%w*:%w*:)(.+)$")
    if not teamString then
        teamString = line:match("^([^\n]-:[%w,]*:%w*:%w*:%w*:)$")
    end
    if not teamString then
        return nil, L["does not match Name:npcIDs:tag:tag:tag:"]
    end

    local name, npcIDsRaw, tag1, tag2, tag3 = teamString:match("([^\n]-):([%w,]*):(%w*):(%w*):(%w*):$")
    name = Trim(name)
    if name == "" then
        return nil, L["team name is empty"]
    end

    local record = {
        name = name,
        npcIDsRaw = npcIDsRaw,
        tags = { tag1, tag2, tag3 },
        pets = {},
        warnings = {},
    }

    record.npcIDs, record.warnings = RematchImporter.ParseNpcIDs(npcIDsRaw)
    for i = 1, 3 do
        record.pets[i] = RematchImporter.ParseTag(record.tags[i])
    end

    if extras then
        local preferences, notes, recognized = RematchImporter.ParseExtras(extras)
        record.preferences = preferences
        record.notes = notes
        if not recognized then
            record.warnings[#record.warnings + 1] = L["trailing data is neither P: preferences nor N: notes and was ignored"]
        end
    end

    return record
end

--[[
Parse(text) -> result
  result.entries: in order, { line = n, kind = "team"|"group"|"invalid", ... }
    team    -> .record
    group   -> .group
    invalid -> .text, .reason
  result.teams:  team records in order
  result.groupsApplicable: Rematch only builds groups when the first valid line is a group header;
    when it is, each record carries .group = header name
]]
function RematchImporter.Parse(text)
    local result = { entries = {}, teams = {}, groupsApplicable = false }
    local firstKind
    local lineNumber = 0

    for rawLine in ((text or "") .. "\n"):gmatch("(.-)\n") do
        lineNumber = lineNumber + 1
        local line = Trim(rawLine)
        if line ~= "" then
            local entry = { line = lineNumber }
            if line:match("^__ (.-):*.* __$") then
                entry.kind = "group"
                entry.group = RematchImporter.ParseGroupHeader(line) or { name = Trim(line:match("^__ (.-):*.* __$")) }
                firstKind = firstKind or "group"
            else
                local record, reason = RematchImporter.ParseTeamLine(line)
                if record then
                    entry.kind = "team"
                    entry.record = record
                    record.line = lineNumber
                    record.raw = line
                    result.teams[#result.teams + 1] = record
                    firstKind = firstKind or "team"
                else
                    entry.kind = "invalid"
                    entry.text = line
                    entry.reason = reason
                end
            end
            result.entries[#result.entries + 1] = entry
        end
    end

    result.groupsApplicable = (firstKind == "group")
    if result.groupsApplicable then
        local current
        for _, entry in ipairs(result.entries) do
            if entry.kind == "group" then
                current = entry.group.name
            elseif entry.kind == "team" then
                entry.record.group = current
            end
        end
    end

    return result
end

return RematchImporter
