local PetBattleTeams = LibStub("AceAddon-3.0"):GetAddon("PetBattleTeams")
local DescriptionEditor = PetBattleTeams:NewModule("DescriptionEditor")
local TeamManager = PetBattleTeams:GetModule("TeamManager")
local GUI = PetBattleTeams:GetModule("GUI")

local _, addon = ...
local L = addon.L

local descriptionEditFrame
local descriptionEditBox
local editorCurrentTeamIndex
local battleDescriptionFrame
local teamNameEditorText


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
