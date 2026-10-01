--[[
RematchExporter: turns a plain record into a Rematch team string.

Pure serializer. No WoW API. Record fields:
  name, tags = {t1,t2,t3} (strings, "" for an empty slot),
  npcIDsRaw (string) or npcIDs (list of numbers),
  preferences = { minHP, allowMM, expectedDD, maxHP, minXP, maxXP } (strings) or nil,
  notes (real newlines) or nil
]]

local _, ns = ...
ns = ns or {}

local RematchExporter = {}
ns.RematchExporter = RematchExporter

local BASE32_DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUV"

function RematchExporter.ToBase32(num)
    num = math.floor(tonumber(num) or 0)
    if num <= 0 then return "0" end
    local result = ""
    while num > 0 do
        local digit = num % 32
        result = BASE32_DIGITS:sub(digit + 1, digit + 1) .. result
        num = math.floor(num / 32)
    end
    return result
end

local function Trim(str)
    return (str:match("^%s*(.-)%s*$"))
end

function RematchExporter.Serialize(record)
    local npcIDs = record.npcIDsRaw
    if not npcIDs then
        local ids = {}
        for _, id in ipairs(record.npcIDs or {}) do
            ids[#ids + 1] = RematchExporter.ToBase32(id)
        end
        npcIDs = table.concat(ids, ",")
    end

    local name = (record.name or ""):gsub("[\r\n]+", " "):gsub(":", "-")
    local tags = record.tags or {}
    local result = string.format("%s:%s:%s:%s:%s:", name, npcIDs, tags[1] or "", tags[2] or "", tags[3] or "")

    local p = record.preferences
    if p then
        result = result .. string.format("P:%s:%s:%s:%s:%s:%s:",
            p.minHP or "", p.allowMM or "", p.expectedDD or "", p.maxHP or "", p.minXP or "", p.maxXP or "")
    end

    local notes = Trim(record.notes or "")
    if notes ~= "" then
        result = result .. "N:" .. (notes:gsub("\r", ""):gsub("\n", "\\n"))
    end

    return result
end

return RematchExporter
