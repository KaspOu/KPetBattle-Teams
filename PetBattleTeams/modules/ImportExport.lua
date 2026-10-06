--[[
Runtime glue for team import/export: game API, TeamManager integration, dialog, slash commands.

Layers (each only depends on the ones above it):
  RematchImporter  Rematch string -> records (pure parser)
  TeamModel        records <-> PetBattleTeams team tables, merge/idempotence/report (pure, game API injected)
  RematchExporter  records -> Rematch string (pure serializer)
  ImportExport     this file: supplies the game API, updates TeamManager, shows the dialog

Rematch is only an input/output text format here; PetBattleTeams keeps its own team model.
See IMPORT_EXPORT.md for the user-facing description.
]]

local PetBattleTeams = LibStub("AceAddon-3.0"):GetAddon("PetBattleTeams")
local ImportExport = PetBattleTeams:NewModule("ImportExport")
local TeamManager = PetBattleTeams:GetModule("TeamManager")
local LibPetJournal = LibStub("LibPetJournal-2.0")
local LibPetBreedInfo = LibStub("LibPetBreedInfo-1.0", true)

local _, ns = ...
local Importer = ns.RematchImporter
local TeamModel = ns.TeamModel
local L = ns.L

local MAX_REPORT_LINES = 15

local function GetBreedByPetID(petID)
    if LibPetBreedInfo then
        local ok, breed = pcall(LibPetBreedInfo.GetBreedByPetID, LibPetBreedInfo, petID)
        if ok and type(breed) == "number" and breed >= 3 and breed <= 12 then
            return breed
        end
    end
    return 0
end

local function CreateApi()
    local petIndex

    local function GetPetIndex()
        if not petIndex then
            petIndex = {}
            for _, petID in LibPetJournal:IteratePetIDs() do
                local speciesID = C_PetJournal.GetPetInfoByPetID(petID)
                if speciesID then
                    petIndex[speciesID] = petIndex[speciesID] or {}
                    table.insert(petIndex[speciesID], petID)
                end
            end
        end
        return petIndex
    end

    local api = {}

    function api.IsDefaultName(name)
        return TeamModel.IsDefaultName(name, L["Team: "])
    end

    function api.SpeciesExists(speciesID)
        return C_PetJournal.GetPetInfoBySpeciesID(speciesID) ~= nil
    end

    function api.AbilityList(speciesID)
        local abilityIDs = {}
        C_PetJournal.GetPetAbilityList(speciesID, abilityIDs, {})
        return abilityIDs
    end

    function api.PetSpecies(petID)
        return (C_PetJournal.GetPetInfoByPetID(petID))
    end

    api.Breed = GetBreedByPetID

    -- Same weighting as Rematch: level first, then breed match, then rarity
    function api.FindPetID(speciesID, breed, usedPetIDs)
        local bestPetID, bestWeight = nil, 0
        for _, petID in ipairs(GetPetIndex()[speciesID] or {}) do
            if not usedPetIDs[petID] then
                local _, _, level, _, _, _, _, _, _, _, _, _, _, _, canBattle = C_PetJournal.GetPetInfoByPetID(petID)
                if level and canBattle ~= false then
                    local rarity = select(5, C_PetJournal.GetPetStats(petID)) or 0
                    local breedWeight = (breed ~= 0 and GetBreedByPetID(petID) == breed) and 1 or 0
                    local weight = level * 100 + breedWeight * 10 + rarity
                    if weight > bestWeight then
                        bestPetID, bestWeight = petID, weight
                    end
                end
            end
        end
        return bestPetID
    end

    return api
end

function ImportExport:ExportTeam(teamIndex, api)
    local team = TeamManager.teams[teamIndex]
    if not team then return nil end
    local name = (team.name and team.name ~= "") and team.name or TeamModel.DefaultExportName(teamIndex)
    return TeamModel.ToString(team, name, api or CreateApi())
end

function ImportExport:ExportAll()
    local api = CreateApi()
    local lines = {}
    for i = 1, TeamManager:GetNumTeams() do
        lines[#lines + 1] = self:ExportTeam(i, api)
    end
    return table.concat(lines, "\n")
end

-- options.conflict: "skip" (default) | "overwrite" | "copy". Returns the import report.
function ImportExport:ImportString(text, options)
    local parsed = Importer.Parse(text)
    local teams = TeamManager.teams
    local selectedTeam = teams[TeamManager:GetSelected()]

    local report = TeamModel.Merge(teams, parsed, CreateApi(), options)

    if #report.touched > 0 then
        TeamManager:SortTeamsByName()
        TeamManager:RebuildNpcIDCache()
        for i, team in ipairs(teams) do
            if team == selectedTeam then
                TeamManager.db.global.selected = i
                break
            end
        end
        if TeamManager:GetSelected() <= 0 then
            TeamManager:SetSelected(1)
        end
        for _, team in ipairs(report.touched) do
            if team == selectedTeam then
                TeamManager:ApplyTeam(TeamManager:GetSelected())
                break
            end
        end
        TeamManager.callbacks:Fire("TEAM_UPDATED")
    end

    return report
end

local function PrintReport(report)
    print(string.format(L["PetBattleTeams import: %d imported, %d updated, %d unchanged, %d skipped, %d ignored, %d error(s)"],
        report.imported, report.updated, report.unchanged, report.skipped, report.ignored, report.errors))

    local shown = 0
    for _, entry in ipairs(report.entries) do
        local notable = entry.status == "error" or entry.status == "skipped" or entry.status == "updated"
            or (entry.warnings and #entry.warnings > 0) or (entry.status == "imported" and entry.reason)
        if notable then
            if shown >= MAX_REPORT_LINES then
                print(L["PetBattleTeams import: ... more entries not shown"])
                break
            end
            shown = shown + 1
            local detail = entry.reason or ""
            if entry.warnings and #entry.warnings > 0 then
                detail = detail .. (detail ~= "" and "; " or "") .. table.concat(entry.warnings, "; ")
            end
            print(string.format(L["  line %d '%s' [%s] %s"], entry.line, tostring(entry.name), L[entry.status], detail))
        end
    end
end

local dialog

local function CreateDialog()
    local frame = CreateFrame("Frame", "PetBattleTeamsImportExportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(520, 440)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface\\LFGFRAME\\LFGBorder",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 1)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    table.insert(UISpecialFrames, "PetBattleTeamsImportExportFrame")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOPLEFT", 30, -15)
    frame.title:SetPoint("TOPRIGHT", -30, -15)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetTextColor(1.0, 0.82, 0.0)

    frame.info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.info:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -7)
    frame.info:SetPoint("TOPRIGHT", frame.title, "BOTTOMRIGHT", 0, -7)
    frame.info:SetJustifyH("LEFT")
    frame.info:SetTextColor(0.7, 0.7, 0.7)

    local container = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    container:SetPoint("TOPLEFT", 20, -60)
    container:SetPoint("BOTTOMRIGHT", -20, 80)
    container:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    container:SetBackdropColor(0, 0, 0)

    local scroll = CreateFrame("ScrollFrame", nil, container, "ScrollFrameTemplate")
    scroll.scrollBarX = 6
    scroll.scrollBarTopY = -4
    scroll.scrollBarBottomY = 5
    scroll:SetPoint("TOPLEFT", 5, -10)
    scroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetWidth(430)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    scroll:SetScrollChild(editBox)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() editBox:SetFocus() end)
    frame.editBox = editBox

    frame.overwrite = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.overwrite:SetSize(24, 24)
    frame.overwrite:SetPoint("BOTTOMLEFT", 18, 48)
    frame.overwriteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.overwriteLabel:SetPoint("LEFT", frame.overwrite, "RIGHT", 2, 0)
    frame.overwriteLabel:SetText(L["Overwrite existing teams that have the same name"])

    frame.acceptButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.acceptButton:SetSize(150, 20)
    frame.acceptButton:SetPoint("BOTTOMLEFT", 20, 20)

    frame.cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.cancelButton:SetSize(150, 20)
    frame.cancelButton:SetPoint("BOTTOMRIGHT", -20, 20)
    frame.cancelButton:SetText(CANCEL)
    frame.cancelButton:SetScript("OnClick", function() frame:Hide() end)

    return frame
end

-- teamIndex: export that team only; nil exports every team
function ImportExport:ShowExport(teamIndex)
    dialog = dialog or CreateDialog()
    dialog.title:SetText(teamIndex and L["Export Team"] or L["Export Teams"])
    dialog.info:SetText(L["Copy the text below (Ctrl+C) to share or back up your teams. Compatible with ReMatch."])
    dialog.acceptButton:SetText(CLOSE)
    dialog.acceptButton:SetScript("OnClick", function() dialog:Hide() end)
    dialog.cancelButton:Hide()
    dialog.overwrite:Hide()
    dialog.overwriteLabel:Hide()
    dialog.editBox:SetText((teamIndex and self:ExportTeam(teamIndex)) or self:ExportAll())
    dialog:Show()
    dialog.editBox:SetFocus()
    dialog.editBox:HighlightText()
end

function ImportExport:ShowImport()
    dialog = dialog or CreateDialog()
    dialog.title:SetText(L["Import Teams"])
    dialog.info:SetText(L["Paste team strings (one team per line, ReMatch compatible), then click Import."])
    dialog.acceptButton:SetText(L["Import"])
    dialog.acceptButton:SetScript("OnClick", function()
        local conflict = dialog.overwrite:GetChecked() and "overwrite" or "skip"
        local report = self:ImportString(dialog.editBox:GetText(), { conflict = conflict })
        PrintReport(report)
        if report.errors == 0 and report.skipped == 0 then
            dialog:Hide()
        end
    end)
    dialog.cancelButton:Show()
    dialog.overwrite:SetChecked(false)
    dialog.overwrite:Show()
    dialog.overwriteLabel:Show()
    dialog.editBox:SetText("")
    dialog:Show()
    dialog.editBox:SetFocus()
end
