local PetBattleTeams = LibStub("AceAddon-3.0"):GetAddon("PetBattleTeams")
local ScriptEditor = PetBattleTeams:NewModule("ScriptEditor")
local TeamManager = PetBattleTeams:GetModule("TeamManager")
local GUI = PetBattleTeams:GetModule("GUI")

local _, addon = ...
local L = addon.L

local descriptionEditFrame
local descriptionEditBox
local editorCurrentTeamIndex
local teamNameEditorText

function ScriptEditor:OnInitialize()
    if not ScriptEditor:IsLoaded() then
        return
    end
    -- self:CreateDescriptionEditor()
    -- self:CreateBattleDescriptionFrame()
    -- self:RegisterEvents()
end

function ScriptEditor:IsLoaded()
    return C_AddOns.IsAddOnLoaded("tdBattlePetScript")
end



function ScriptEditor:ShowEditor(teamIndex)
    if not teamIndex then return end

    editorCurrentTeamIndex = teamIndex
    local currentScript = TeamManager:GetTeamScript(teamIndex) or ""

    local frame = CreateFrame("Frame", "MyScriptEditor", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 300)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
    frame.title:SetText("Éditeur de script pour l'équipe "..teamIndex)

    -- local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    -- editBox:SetMultiLine(true)
    -- editBox:SetSize(370, 220)
    -- editBox:SetPoint("TOP", 0, -40)
    -- editBox:SetAutoFocus(false)
    -- editBox:SetFontObject(ChatFontNormal)
    -- editBox:SetText(currentScript)
    -- editBox:SetCursorPosition(0)
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
    local scrollContainer = CreateFrame("Frame", nil, frame,"BackdropTemplate")
    --  descriptionEditFrame:SetSize(410, 317)
    scrollContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -60)
    scrollContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -60)
    scrollContainer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 60)
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
                DescriptionEditor:SaveDescription()
            end
        elseif key == "ESCAPE" then
            DescriptionEditor:HideEditor()
            return
        end
    end)
    editBox = scrollContainer.Text
    editBox.Scroll = scrollContainer.Scroll
    -- End Scroll EditBox

    -- Bouton Enregistrer
    local saveButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    saveButton:SetPoint("BOTTOM", 0, 10)
    saveButton:SetSize(120, 25)
    saveButton:SetText("Enregistrer")
    saveButton:SetScript("OnClick", function()
        local text = editBox:GetText()
        self.teams[teamIndex].script = text
        self:RegisterScriptWithPBS(teamIndex) -- Met à jour PetBattleScripts
        frame:Hide()
    end)
    descriptionEditFrame = frame
    descriptionEditBox = editBox

    descriptionEditFrame:Show()
    descriptionEditBox:SetFocus()
end

function ScriptEditor:Hide()
    descriptionEditFrame:Hide()
    descriptionEditBox:ClearFocus()
    teamNameEditorText:SetText("")

    editorCurrentTeamIndex = nil
end

function ScriptEditor:Save()
    if not editorCurrentTeamIndex then ScriptEditor:Hide(); return end

    local newScript = descriptionEditBox:GetText()
    -- isBlank description.trim()
    if newScript and string.gsub(newScript, "^%s*(.-)%s*$", "%1") == "" then
        newScript = nil
    end
    -- FIXME:
    local isValid, err = ScriptEditor:ValidateScript(newScript)
    if not isValid then
        print(err)
        -- StaticPopup_Show("SCRIPT_ERROR_POPUP", err)
        return
    end
    -- FIXME:

    TeamManager:SetTeamScript(editorCurrentTeamIndex, newScript)
    self:Hide()
end

function ScriptEditor:PBS_ValidateScript(script)
    local engine = PetBattleScripts:GetScriptEngine()
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
    local teamID = ScriptEditor:GetTeamID(teamIndex)
    PetBattleScripts:SetCurrentTeamID(teamID)
end
function ScriptEditor:PBS_DeleteTeam(teamIndex)
    local teamID = ScriptEditor:GetTeamID(teamIndex)
    if PetBattleScripts:GetScript(teamID) then
        PetBattleScripts:DeleteScript(teamID)
        print("Script PBS deleted for team "..teamIndex)
    else
        print("Team not found: "..teamID)
    end
end

--- Enregistrement pour PetBattleScripts, fonctionnement:
--- * 1. Si un script est enregistré pour l’ennemi, il l’utilise (par ID ou nom de PNJ),
--- * 2. Sinon, si un script est lié à l’équipe active, il l’utilise
--- ! il faut PetBattleScripts:SetCurrentTeamID(teamID)
function ScriptEditor:PBS_SaveScript(teamIndex)
    local team = self.teams[teamIndex]
    if not team then
        print("Équipe invalide.")
        return
    end

    local teamID = ScriptEditor:GetTeamID(teamIndex)
    local scriptName = "Script de l'équipe "..teamIndex
    local script = TeamManager:GetTeamScript(teamIndex)
    if not script or script:trim() == "" then
        print("Aucun script défini pour cette équipe.")
        return
    end

    -- FIXME:
    local isValid, err = ScriptEditor:ValidateScript(script)
    if not isValid then
        print(err)
        return
    end
    -- FIXME:
    PetBattleScripts:SaveScript(teamID, script, scriptName)
    print("Script enregistré dans PetBattleScripts.")
end

StaticPopupDialogs["SCRIPT_ERROR_POPUP"] = {
    text = "Erreur dans le script :\n%s",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

--[[
-- Charger un bouton si on est sur un NPC de la liste... obligé de linker les ID aux mascottes.
local petTrainers = {
    [12345] = "EquipeTruc", -- ID du PNJ => équipe Rematch
    [67890] = "EquipeMachin",
    [66815] = "Aki la Élue",
    [66135] = "Dagra la Féroce",
    [66738] = "Zonya la Sadique"
}

local f = CreateFrame("Button", "MonBoutonPetTeam", UIParent, "UIPanelButtonTemplate")
f:SetSize(120, 30)
f:SetText("Charger Équipe")
f:SetPoint("CENTER")
f:Hide()

f:SetScript("OnClick", function()
    local npcID = tonumber((UnitGUID("target") or ""):match("-(%d+)-%x+$"))
    if npcID then
        local teamID = TeamManager:GetTeamIDByNpcID(npcID) -- TODO: if not ScriptEditor:IsLoaded() ... Build cache teamIDsbyNBC, from teams[].npcID
        if teamID then
            TeamManager:ApplyTeam(teamID)
        end
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

eventFrame:SetScript("OnEvent", function()
    local guid = UnitGUID("target")
    local npcID = guid and tonumber(guid:match("-(%d+)-%x+$"))
    if npcID and petTrainers[npcID] then
        f:Show()
    else
        f:Hide()
    end
end)
]]
--[[
function DescriptionEditor:OnInitialize()
    self:CreateDescriptionEditor()
    self:CreateBattleDescriptionFrame()
    self:RegisterEvents()
end

function DescriptionEditor:CreateDescriptionEditor()
    descriptionEditFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    descriptionEditFrame:SetSize(430, 317)
    -- descriptionEditFrame:SetSize(500, 317)
    descriptionEditFrame:SetPoint("CENTER", UIParent, "CENTER")
    descriptionEditFrame:SetFrameStrata("DIALOG")
    descriptionEditFrame:SetBackdrop(tinyBackdrop)
    descriptionEditFrame:SetBackdropColor(0.1, 0.1, 0.1, 1)
    descriptionEditFrame:Hide();

    -- Nom de l'équipe (au-dessus de l'EditBox)
    teamNameEditorText = descriptionEditFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    teamNameEditorText:SetPoint("TOPLEFT", descriptionEditFrame, "TOPLEFT", 30, -15)
    teamNameEditorText:SetPoint("TOPRIGHT", descriptionEditFrame, "TOPRIGHT", -30, -15)
    teamNameEditorText:SetTextColor(1.0, 0.82, 0.0)
    teamNameEditorText:SetJustifyH("LEFT")
    teamNameEditorText:SetJustifyV("TOP")

    -- Texte d'information
    local infoTextEditor = descriptionEditFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoTextEditor:SetPoint("TOPLEFT", teamNameEditorText, "BOTTOMLEFT", 0, -7)
    infoTextEditor:SetPoint("TOPRIGHT", teamNameEditorText, "BOTTOMRIGHT", 0, -7)
    infoTextEditor:SetTextColor(0.7, 0.7, 0.7)
    infoTextEditor:SetText(L["Press Ctrl+Enter to save the description"])
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
    local scrollContainer = CreateFrame("Frame", nil, descriptionEditFrame,"BackdropTemplate")
    --  descriptionEditFrame:SetSize(410, 317)
    scrollContainer:SetPoint("TOPLEFT", descriptionEditFrame, "TOPLEFT", 30, -60)
    scrollContainer:SetPoint("TOPRIGHT", descriptionEditFrame, "TOPRIGHT", -30, -60)
    scrollContainer:SetPoint("BOTTOM", descriptionEditFrame, "BOTTOM", 0, 60)
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
                DescriptionEditor:SaveDescription()
            end
        elseif key == "ESCAPE" then
            DescriptionEditor:HideEditor()
            return
        end
    end)
    descriptionEditBox = scrollContainer.Text
    descriptionEditBox.Scroll = scrollContainer.Scroll
    -- End Scroll EditBox

    local frameInset = 20
    local saveButton = CreateFrame("Button", nil, descriptionEditFrame, "UIPanelButtonTemplate")
    saveButton:SetSize(150, 20)
    saveButton:SetPoint("BOTTOMLEFT", descriptionEditFrame, "BOTTOMLEFT", frameInset, frameInset)
    saveButton:SetText(OKAY)
    saveButton:SetFrameStrata("DIALOG")
    saveButton:SetFrameLevel(1001)
    saveButton:SetScript("OnClick", function()
        DescriptionEditor:SaveDescription()
    end)

    local cancelButton = CreateFrame("Button", nil, descriptionEditFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(150, 20)
    cancelButton:SetPoint("BOTTOMRIGHT", descriptionEditFrame, "BOTTOMRIGHT", -frameInset, frameInset)
    cancelButton:SetText(CANCEL)
    cancelButton:SetFrameStrata("DIALOG")
    cancelButton:SetFrameLevel(1001)
    cancelButton:SetScript("OnClick", function()
        DescriptionEditor:HideEditor()
    end)
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_CENTER");
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L["PetBattle Teams"], 1, 1, 1)
    GameTooltip:AddLine(L["Show the team roster"], 0,1,0)
    GameTooltip:Show()
end
local function OnLeave(self)
    GameTooltip:Hide()
end

function DescriptionEditor:CreateBattleDescriptionFrame()
    battleDescriptionFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
    battleDescriptionFrame:SetSize(380, 200)
    battleDescriptionFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5, 15)
    if (UIParent:GetWidth() < 1200) then
        battleDescriptionFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5, 120)
    end
    battleDescriptionFrame:SetFrameStrata("HIGH")
    battleDescriptionFrame:SetFrameLevel(100)
    battleDescriptionFrame:Hide()

    battleDescriptionFrame:SetBackdrop(tinyBackdrop)
    battleDescriptionFrame:SetBackdropColor(0.1, 0.1, 0.1, 1)

    -- Nom de l'équipe (en bas du cadre)
    local teamNameContainer = CreateFrame("Frame", nil, battleDescriptionFrame, BackdropTemplateMixin and "BackdropTemplate")
    teamNameContainer:SetHeight(25)
    teamNameContainer:SetPoint("BOTTOMLEFT", battleDescriptionFrame, "BOTTOMLEFT", 4, -15)
    teamNameContainer:SetPoint("BOTTOMRIGHT", battleDescriptionFrame, "BOTTOMRIGHT", -3, -15)
    teamNameContainer:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    teamNameContainer:SetBackdropColor(0.1, 0.1, 0.1, 1)
    teamNameContainer:SetFrameStrata("HIGH")
    teamNameContainer:SetFrameLevel(101)

    local teamNameText = teamNameContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    teamNameText:SetPoint("LEFT", teamNameContainer, "LEFT", 10, 0)
    teamNameText:SetPoint("RIGHT", teamNameContainer, "RIGHT", -10, 0)
    teamNameText:SetTextColor(1.0, 0.82, 0.0)
    battleDescriptionFrame.teamNameText = teamNameText

    battleDescriptionFrame.Scroll = CreateFrame("ScrollFrame", nil, battleDescriptionFrame, "ScrollFrameTemplate")
    battleDescriptionFrame.Scroll.scrollBarX = 6
    battleDescriptionFrame.Scroll.scrollBarTopY = -4
    battleDescriptionFrame.Scroll.scrollBarBottomY = 5

    battleDescriptionFrame.Scroll:SetPoint("TOPLEFT", 9, -10)
    battleDescriptionFrame.Scroll:SetPoint("BOTTOMRIGHT", -25, 10)

    local scrollContentFrame = CreateFrame("Frame", nil, battleDescriptionFrame.Scroll)
    scrollContentFrame:SetPoint("TOPLEFT", 0, 0)
    scrollContentFrame:SetWidth(battleDescriptionFrame.Scroll:GetWidth())
    scrollContentFrame:SetHeight(1)
    battleDescriptionFrame.Scroll:SetScrollChild(scrollContentFrame)
    battleDescriptionFrame.ScrollContent = scrollContentFrame

    battleDescriptionFrame.Text = scrollContentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    battleDescriptionFrame.Text:SetPoint("TOPLEFT", scrollContentFrame, "TOPLEFT", 0, 0)
    battleDescriptionFrame.Text:SetWidth(scrollContentFrame:GetWidth())
    battleDescriptionFrame.Text:SetJustifyH("LEFT")
    battleDescriptionFrame.Text:SetJustifyV("TOP")
    battleDescriptionFrame.Text:SetWordWrap(true)
    battleDescriptionFrame.SetText = function (self, text)
        self.Text:SetText(text or "")
        self.ScrollContent:SetHeight(self.Text:GetHeight()) -- Nécessaire à l'update car FontString
        self.Scroll:SetVerticalScroll(0)
    end

    local button = CreateFrame("BUTTON", nil, battleDescriptionFrame)
    button:SetSize(33,33)
    button:ClearAllPoints()
    button:SetPoint("LEFT", teamNameText, "LEFT", -20, 0)

    button.icon = button:CreateTexture("PetBattleTeambuttonButtonIcon","ARTWORK")
    button.icon:SetTexture("Interface\\Icons\\INV_PET_BATTLEPETTRAINING")
    button.icon:SetSize(25,25)
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT",button,"TOPLEFT",7,-6)

    button.overlay = button:CreateTexture("PetBattleTeambuttonButtonIcon","OVERLAY")
    button.overlay:SetTexture("Interface\\MiniMap\\MiniMap-TrackingBorder")
    button.overlay:SetSize(60,60)
    button.overlay:ClearAllPoints()
    button.overlay:SetPoint("TOPLEFT",button,"TOPLEFT")

    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(battleDescriptionFrame:GetFrameLevel() + 1)

    button:SetHighlightTexture("Interface\\MiniMap\\UI-MiniMap-ZoomButton-Highlight","ADD")
    button:RegisterForClicks("LeftButtonUp","RightButtonUp")
    button:SetScript("OnClick", function(_,_)
        -- GameTooltip:Hide()
        ToggleCollectionsJournal(COLLECTIONS_JOURNAL_TAB_INDEX_PETS)
    end)
    button:SetScript("OnEnter",OnEnter)
    button:SetScript("OnLeave",OnLeave)
end

function DescriptionEditor:RegisterEvents()
    battleDescriptionFrame:RegisterEvent("PET_BATTLE_OPENING_START")
    battleDescriptionFrame:RegisterEvent("PET_BATTLE_CLOSE")
    battleDescriptionFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PET_BATTLE_OPENING_START" then
            DescriptionEditor:ShowBattleDescription()
        elseif event == "PET_BATTLE_CLOSE" then
            DescriptionEditor:HideBattleDescription()
        end
    end)
end

function DescriptionEditor:ShowEditor(teamIndex)
    if not teamIndex then return end

    editorCurrentTeamIndex = teamIndex

    local currentDescription = TeamManager:GetTeamDescription(teamIndex)
    local name, _, customName = TeamManager:GetTeamName(teamIndex)
    if currentDescription ~= descriptionEditBox:GetText() then
        descriptionEditBox:SetText(currentDescription or "")
        C_Timer.After(0.1, function()
            local verticalScrollRange = descriptionEditBox.Scroll:GetVerticalScrollRange()
            descriptionEditBox.Scroll:SetVerticalScroll(verticalScrollRange)
        end)
    end
    teamNameEditorText:SetText(customName or name)

    descriptionEditFrame:Show()
    descriptionEditBox:SetFocus()
end

function DescriptionEditor:HideEditor()
    descriptionEditFrame:Hide()
    descriptionEditBox:ClearFocus()
    teamNameEditorText:SetText("")

    editorCurrentTeamIndex = nil
end

function DescriptionEditor:SaveDescription()
    if not editorCurrentTeamIndex then DescriptionEditor:HideEditor(); return end

    local newDescription = descriptionEditBox:GetText()
    -- isBlank description.trim()
    if newDescription and string.gsub(newDescription, "^%s*(.-)%s*$", "%1") == "" then
        newDescription = nil
    end

    TeamManager:SetTeamDescription(editorCurrentTeamIndex, newDescription)
    self:HideEditor()
end

function DescriptionEditor:ShowBattleDescription(selectedTeam)
    if selectedTeam == nil and not TeamManager:GetShowBattleDescription() then
        return
    end

    selectedTeam = selectedTeam or TeamManager:GetSelected()
    if selectedTeam and selectedTeam > 0 then
        local description = TeamManager:GetTeamDescription(selectedTeam)
        if description and description ~= "" then
            battleDescriptionFrame.ScrollContent:SetHeight(battleDescriptionFrame.Text:GetHeight())
            battleDescriptionFrame:SetText(description)
            local name, _, customName = TeamManager:GetTeamName(selectedTeam)
            battleDescriptionFrame.teamNameText:SetText(customName or name)
            battleDescriptionFrame:Show()
        else
            battleDescriptionFrame:Hide()
        end
    end
end

function DescriptionEditor:HideBattleDescription()
    battleDescriptionFrame:Hide()
end
]]