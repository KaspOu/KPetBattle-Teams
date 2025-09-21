local PetBattleTeams = LibStub("AceAddon-3.0"):GetAddon("PetBattleTeams")
local ScriptEditor = PetBattleTeams:NewModule("ScriptEditor")
local TeamManager = PetBattleTeams:GetModule("TeamManager")
local GUI = PetBattleTeams:GetModule("GUI")

local _, addon = ...
local L = addon.L


local tinyBackdrop = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface\\LFGFRAME\\LFGBorder",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
        left = 5,
        right = 5,
        top = 5,
        bottom = 5
    }
}

function ScriptEditor:OnInitialize()
    self:CreateEditor()
    if not self:IsLoaded() then
        return
    end
    -- self:CreateBattleDescriptionFrame()
    -- self:RegisterEvents()
end

function ScriptEditor:IsLoaded()
    return C_AddOns.IsAddOnLoaded("tdBattlePetScript")
end


function ScriptEditor:CreateEditor(teamIndex)
    self.editor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    self.editor:SetSize(630, 417)
    self.editor:SetPoint("CENTER", UIParent, "CENTER")
    self.editor:SetFrameStrata("DIALOG")
    self.editor:SetBackdrop(tinyBackdrop)
    self.editor:SetBackdropColor(0.1, 0.1, 0.1, 1)
    self.editor:SetMovable(true)
    self.editor:SetClampedToScreen(true)
    self.editor:EnableMouse(true)
    self.editor:RegisterForDrag("LeftButton")
    self.editor:SetScript("OnDragStart", self.editor.StartMoving)
    self.editor:SetScript("OnDragStop", self.editor.StopMovingOrSizing)
    self.editor:Hide();

    -- Nom de l'équipe (au-dessus de l'EditBox)
    self.editorTitle = self.editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.editorTitle:SetPoint("TOPLEFT", self.editor, "TOPLEFT", 30, -15)
    self.editorTitle:SetPoint("TOPRIGHT", self.editor, "TOPRIGHT", -30, -15)
    self.editorTitle:SetTextColor(1.0, 0.82, 0.0)
    self.editorTitle:SetJustifyH("LEFT")
    self.editorTitle:SetJustifyV("TOP")

    -- Texte d'information
    local infoTextEditor = self.editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoTextEditor:SetPoint("TOPLEFT", self.editorTitle, "BOTTOMLEFT", 0, -7)
    infoTextEditor:SetPoint("TOPRIGHT", self.editorTitle, "BOTTOMRIGHT", 0, -7)
    infoTextEditor:SetTextColor(0.7, 0.7, 0.7)
    infoTextEditor:SetText(L["Press Ctrl+Enter to save the note"])
    infoTextEditor:SetJustifyH("LEFT")

    -- Scroll EditBox
    local backdrop = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0
        },
    }
    local scrollContainer = CreateFrame("Frame", nil, self.editor,"BackdropTemplate")
    --  descriptionEditFrame:SetSize(410, 317)
    scrollContainer:SetPoint("TOPLEFT", self.editor, "TOPLEFT", 30, -60)
    scrollContainer:SetPoint("TOPRIGHT", self.editor, "TOPRIGHT", -30, -60)
    scrollContainer:SetPoint("BOTTOM", self.editor, "BOTTOM", 0, 60)
    scrollContainer:SetPoint("CENTER")
    scrollContainer:SetBackdrop(backdrop)
    scrollContainer:SetBackdropColor(0, 0, 0)
    scrollContainer:SetFrameStrata("DIALOG")
    scrollContainer:SetFrameLevel(1000)
    scrollContainer.Scroll = CreateFrame("ScrollFrame", nil, scrollContainer, "ScrollFrameTemplate")
    scrollContainer.Scroll.scrollBarX = 6
    scrollContainer.Scroll.scrollBarTopY = -4
    scrollContainer.Scroll.scrollBarBottomY = 5

    scrollContainer.Scroll:SetPoint("TOPLEFT", 5, -10)
    scrollContainer.Scroll:SetPoint("BOTTOMRIGHT", -25, 5)

    scrollContainer.Text = CreateFrame("EditBox", nil, scrollContainer)
    scrollContainer.Text:SetMultiLine(true)
    scrollContainer.Text:SetSize(scrollContainer.Scroll:GetWidth(), scrollContainer.Scroll:GetHeight())
    scrollContainer.Text:SetPoint("TOPLEFT", scrollContainer.SF)
    scrollContainer.Text:SetPoint("BOTTOMRIGHT", scrollContainer.SF)
    scrollContainer.Text:SetMaxLetters(99999)
    scrollContainer.Text:SetFontObject(GameFontNormal)
    scrollContainer.Text:SetAutoFocus(false)
    scrollContainer.Scroll:SetScrollChild(scrollContainer.Text)
    -- Raccourcis clavier
    scrollContainer.Text:SetScript("OnKeyDown", function(_, key)
        if key == "ENTER" then
            if IsModifierKeyDown() then
                self:SaveEditor()
            end
        elseif key == "ESCAPE" then
            self:HideEditor()
            return
        end
    end)
    self.editBox = scrollContainer.Text
    self.editBox.Scroll = scrollContainer.Scroll
    -- End Scroll EditBox

    local frameInset = 20
    local saveButton = CreateFrame("Button", nil, self.editor, "UIPanelButtonTemplate")
    saveButton:SetSize(150, 20)
    saveButton:SetPoint("BOTTOMLEFT", self.editor, "BOTTOMLEFT", frameInset, frameInset)
    saveButton:SetText(OKAY)
    saveButton:SetFrameStrata("DIALOG")
    saveButton:SetFrameLevel(1001)
    saveButton:SetScript("OnClick", function()
        self:SaveEditor()
    end)

    local cancelButton = CreateFrame("Button", nil, self.editor, "UIPanelButtonTemplate")
    cancelButton:SetSize(150, 20)
    cancelButton:SetPoint("BOTTOMRIGHT", self.editor, "BOTTOMRIGHT", -frameInset, frameInset)
    cancelButton:SetText(CANCEL)
    cancelButton:SetFrameStrata("DIALOG")
    cancelButton:SetFrameLevel(1001)
    cancelButton:SetScript("OnClick", function()
        self:HideEditor()
    end)
end


function ScriptEditor:ShowEditor(teamIndex)
    if not teamIndex then return end

    self.currentTeamIndex = teamIndex

    local currentScript = TeamManager:GetTeamScript(teamIndex)
    local name, _, customName = TeamManager:GetTeamName(teamIndex)
    if currentScript ~= self.editBox:GetText() then
        self.editBox:SetText(currentScript or "")
        C_Timer.After(0.1, function()
            local verticalScrollRange = self.editBox.Scroll:GetVerticalScrollRange()
            self.editBox.Scroll:SetVerticalScroll(verticalScrollRange)
        end)
    end
    self.editorTitle:SetText("SCRIPT: "..(customName or name))

    self.editor:Show()
    self.editBox:SetFocus()
end

function ScriptEditor:HideEditor()
    self.editor:Hide()
    self.editBox:ClearFocus()
    self.editorTitle:SetText("")

    self.currentTeamIndex = nil
end

function ScriptEditor:SaveEditor()
    if not self.currentTeamIndex then self:HideEditor(); return end

    local newScript = self.editBox:GetText()
    -- isBlank description.trim()
    if newScript and string.gsub(newScript, "^%s*(.-)%s*$", "%1") == "" then
        newScript = nil
    end
    -- FIXME:
    -- local isValid, err = self:PBS_ValidateScript(newScript)
    -- if not isValid then
    --     print(err)
    --     StaticPopup_Show("SCRIPT_ERROR_POPUP", err)
    --     return
    -- end
    -- -- FIXME:

    TeamManager:SetTeamScript(self.currentTeamIndex, newScript)
    -- self:PBS_SaveScript(self:GetTeamID(self.currentTeamIndex))
    self:HideEditor()
end

function ScriptEditor:PBS_ValidateScript(script)
    local engine = PetBattleScripts.GetScriptEngine and PetBattleScripts:GetScriptEngine() or nil
    if not engine then
        return false, "Moteur de script non disponible"
    end

    local isValid, err = engine:CheckScript(script)
    if (not isValid) then
        err = "Invalid script:"..err
    end
    return isValid, err
end


function ScriptEditor:GetTeamID(teamIndex)
    -- "PetBattleTeams"..teamIndex
    local name, _, customName = TeamManager:GetTeamName(teamIndex)
    return customName or name
end
function ScriptEditor:PBS_SetTeamID(teamIndex)
    local teamID = self:GetTeamID(teamIndex)
    PetBattleScripts:SetCurrentTeamID(teamID)
end
function ScriptEditor:PBS_DeleteTeam(teamIndex)
    local teamID = self:GetTeamID(teamIndex)
    if PetBattleScripts:GetScript(teamID) then
        PetBattleScripts:DeleteScript(teamID)
        print("Script PBS deleted for team "..teamIndex)
    else
        print("Team not found: "..teamID)
    end
end

--- Enregistrement pour PetBattleScripts, fonctionnement:
--- * 1. Si un script est enregistré pour l’ennemi, il l'utilise (par ID ou nom de PNJ),
--- * 2. Sinon, si un script est lié à l’équipe active, il l'utilise
--- ! il faut PetBattleScripts:SetCurrentTeamID(teamID)
function ScriptEditor:PBS_SaveScript(teamIndex)
    local team = self.teams[teamIndex]
    if not team then
        print("Équipe invalide.")
        return
    end

    local teamID = self:GetTeamID(teamIndex)
    local scriptName = "Script de l'équipe "..teamIndex
    local script = TeamManager:GetTeamScript(teamIndex)
    if not script or script:trim() == "" then
        print("Aucun script défini pour cette équipe.")
        return
    end

    -- FIXME:
    local isValid, err = self:ValidateScript(script)
    if not isValid then
        print(err)
        return
    end
    -- FIXME:
    PetBattleScripts:Save(teamID, script, scriptName)
    print("Script enregistré dans PetBattleScripts.")
end



function ScriptEditor:SetTargetNpcID(teamIndex)
    if not teamIndex then return end

    local unitGuid = UnitGUID("target")
    if unitGuid == nil then
        TeamManager:SetNpcID(teamIndex, nil)
        print("Debug: No target, Team association removed")
    end
    local npcID = unitGuid:match("-(%d+)-%x+$")
    TeamManager:SetNpcID(teamIndex, npcID)
    print("Debug: Team associated to #"..npcID.." - "..UnitName("target"))
end

function ScriptEditor:EditNpcID(teamIndex)
    local teamIndex = menuFrame.teamIndex
    local displayName = TeamManager:GetTeamName(teamIndex)
    StaticPopup_Show("PBT_TEAM_EDITNPCID", displayName, nil, teamIndex)
end

StaticPopupDialogs["SCRIPT_ERROR_POPUP"] = {
    text = "Error in script :\n%s",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
