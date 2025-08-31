local PetBattleTeams = LibStub("AceAddon-3.0"):GetAddon("PetBattleTeams")
local DescriptionEditor = PetBattleTeams:NewModule("DescriptionEditor")
local TeamManager = PetBattleTeams:GetModule("TeamManager")

local _, addon = ...
local L = addon.L

local descriptionEditFrame
local descriptionEditBox
local saveButton
local cancelButton
local editorCurrentTeamIndex
local battleDescriptionFrame
local battleDescriptionText
local teamNameEditorText -- Nouvelle variable pour afficher le nom de l'équipe dans l'éditeur
local infoTextEditor -- Nouvelle variable pour le texte d'information sur la validation

function DescriptionEditor:OnInitialize()
    self:CreateDescriptionEditor()
    self:CreateBattleDescriptionFrame()
    self:RegisterEvents()
end

function DescriptionEditor:CreateDescriptionEditor()
    descriptionEditFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    descriptionEditFrame:SetSize(410, 317)
    descriptionEditFrame:SetPoint("CENTER", UIParent, "CENTER")
    descriptionEditFrame:SetFrameStrata("DIALOG")
    descriptionEditFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\LFGFRAME\\LFGBorder",
        tile = true,
        tileSize = 16,
        edgeSize = 16
    })
    descriptionEditFrame:Hide();

    -- Nom de l'équipe (au-dessus de l'EditBox)
    teamNameEditorText = descriptionEditFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    teamNameEditorText:SetPoint("TOPLEFT", descriptionEditFrame, "TOPLEFT", 30, -15)
    teamNameEditorText:SetPoint("TOPRIGHT", descriptionEditFrame, "TOPRIGHT", -30, -15)
    teamNameEditorText:SetTextColor(1.0, 0.82, 0.0)
    teamNameEditorText:SetJustifyH("LEFT")
    teamNameEditorText:SetJustifyV("TOP")
    teamNameEditorText:Hide() -- Caché par défaut

    -- Texte d'information (au-dessus de l'EditBox, sous le nom de l'équipe)
    infoTextEditor = descriptionEditFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoTextEditor:SetPoint("TOPLEFT", teamNameEditorText, "BOTTOMLEFT", 0, -7)
    infoTextEditor:SetPoint("TOPRIGHT", teamNameEditorText, "BOTTOMRIGHT", 0, -7)
    infoTextEditor:SetTextColor(0.7, 0.7, 0.7)
    -- Utilise une clé de localisation ou un texte par défaut si non défini
    infoTextEditor:SetText(L["Press Ctrl+Enter to save the description"] or "Appuyez sur Ctrl+Entrée pour sauvegarder la description.")
    infoTextEditor:SetJustifyH("LEFT")
    infoTextEditor:Hide() -- Caché par défaut

    -- EditBox
    descriptionEditBox = CreateFrame("EditBox", nil, descriptionEditFrame, "InputBoxTemplate BackdropTemplate")
    descriptionEditBox:SetMultiLine(true)
    descriptionEditBox:SetMaxLetters(1000)
    descriptionEditBox:SetAutoFocus(false)
    descriptionEditBox:SetFrameStrata("DIALOG")
    descriptionEditBox:SetFrameLevel(1000)
    -- descriptionEditBox:SetFont("GameFontNormal", 12) -- Définir une police pour que le texte s'affiche correctement
    descriptionEditBox:SetBackdrop({
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
        }
    })
    -- Positionner l'EditBox à l'intérieur du cadre, en laissant de la place pour les boutons en bas
    descriptionEditBox:SetTextInsets(5, 5, 5, 5)
    -- Ajuster les points pour faire de la place aux nouveaux éléments (nom de l'équipe et texte d'info)
    descriptionEditBox:SetPoint("TOPLEFT", descriptionEditFrame, "TOPLEFT", 30, -60)
    descriptionEditBox:SetPoint("TOPRIGHT", descriptionEditFrame, "TOPRIGHT", -37, -60)
    descriptionEditBox:SetPoint("BOTTOM", descriptionEditFrame, "BOTTOM", 0, 60)

    -- Gestion des raccourcis clavier
    descriptionEditBox:SetScript("OnKeyDown", function(self, key)
        if key == "ENTER" then
            if IsModifierKeyDown() then
                DescriptionEditor:SaveDescription()
            end
        elseif key == "ESCAPE" then
            DescriptionEditor:HideEditor()
            return
        end
    end)

    -- Masque pour masquer l'inputtext singleline
    local editBoxBorder = descriptionEditBox:CreateTexture(nil, "BORDER")
    editBoxBorder:SetPoint("TOPLEFT", descriptionEditBox, "TOPLEFT", 0, 0)
    editBoxBorder:SetPoint("BOTTOMRIGHT", descriptionEditBox, "BOTTOMRIGHT", 0, 0)
    editBoxBorder:SetColorTexture(0, 0, 0, 1)
    editBoxBorder:SetDrawLayer("BORDER", -1)

    local frameInset = 20
    saveButton = CreateFrame("Button", nil, descriptionEditFrame, "UIPanelButtonTemplate")
    saveButton:SetSize(150, 20)
    saveButton:SetPoint("BOTTOMLEFT", descriptionEditFrame, "BOTTOMLEFT", frameInset, frameInset)
    saveButton:SetText(L["OK"])
    saveButton:SetFrameStrata("DIALOG")
    saveButton:SetFrameLevel(1001)
    saveButton:SetScript("OnClick", function()
        DescriptionEditor:SaveDescription()
    end)

    cancelButton = CreateFrame("Button", nil, descriptionEditFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(150, 20)
    cancelButton:SetPoint("BOTTOMRIGHT", descriptionEditFrame, "BOTTOMRIGHT", -frameInset, frameInset)
    cancelButton:SetText(L["Cancel"])
    cancelButton:SetFrameStrata("DIALOG")
    cancelButton:SetFrameLevel(1001)
    cancelButton:SetScript("OnClick", function()
        DescriptionEditor:HideEditor()
    end)
end

function DescriptionEditor:CreateBattleDescriptionFrame()
    battleDescriptionFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
    battleDescriptionFrame:SetSize(380, 200)
    battleDescriptionFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5, -6)
    if (UIParent:GetWidth() < 1200) then
        battleDescriptionFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5, 120)
    end
    battleDescriptionFrame:SetFrameStrata("HIGH")
    battleDescriptionFrame:SetFrameLevel(100)
    battleDescriptionFrame:Hide()

    battleDescriptionFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
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
    })

    -- Nom de l'équipe (en bas du cadre)
    local teamNameText = battleDescriptionFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    teamNameText:SetPoint("BOTTOMLEFT", battleDescriptionFrame, "BOTTOMLEFT", 10, 10)
    teamNameText:SetPoint("BOTTOMRIGHT", battleDescriptionFrame, "BOTTOMRIGHT", -10, 10)
    teamNameText:SetTextColor(1.0, 0.82, 0.0)
    teamNameText:SetJustifyH("LEFT")
    battleDescriptionFrame.teamNameText = teamNameText

    local scrollFrame = CreateFrame("ScrollFrame", nil, battleDescriptionFrame)
    -- local scrollFrame = CreateFrame("ScrollFrame", nil, battleDescriptionFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", battleDescriptionFrame, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", teamNameText, "TOPRIGHT", -20, 5)
    scrollFrame:SetFrameStrata("DIALOG")

    -- local scrollChild = CreateFrame("Frame")
    -- scrollFrame:SetScrollChild(scrollChild)
    -- scrollChild:SetWidth(battleDescriptionFrame:GetWidth())
    -- scrollChild:SetHeight(battleDescriptionFrame:GetHeight())

    -- Créer le FontString à l'intérieur du ScrollFrame
    battleDescriptionText = scrollFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    battleDescriptionText:SetPoint("TOPLEFT")
    battleDescriptionText:SetPoint("BOTTOMRIGHT")
    battleDescriptionText:SetTextColor(0.9, 0.9, 0.9)
    battleDescriptionText:SetJustifyH("LEFT")
    battleDescriptionText:SetJustifyV("TOP")
    battleDescriptionText:SetNonSpaceWrap(true) -- Permet le retour à la ligne automatique
    battleDescriptionText:SetMaxLines(14)
end

function DescriptionEditor:RegisterEvents()
    battleDescriptionFrame:RegisterEvent("PET_BATTLE_OPENING_START")
    battleDescriptionFrame:RegisterEvent("PET_BATTLE_CLOSE")
    battleDescriptionFrame:SetScript("OnEvent", function(self, event, ...)
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

    -- Charger le texte existant
    local currentDescription = TeamManager:GetTeamDescription(teamIndex)
    descriptionEditBox:SetText(currentDescription or "")

    -- Charger et afficher le nom de l'équipe
    local name, _, customName = TeamManager:GetTeamName(teamIndex)
    teamNameEditorText:SetText(customName or name)
    teamNameEditorText:Show()
    infoTextEditor:Show()

    -- Afficher l'éditeur
    descriptionEditFrame:Show()
    saveButton:Show()
    cancelButton:Show()

    -- Focus sur l'EditBox
    descriptionEditBox:SetFocus()
end

function DescriptionEditor:HideEditor()
    descriptionEditFrame:Hide()
    saveButton:Hide()
    cancelButton:Hide()
    teamNameEditorText:Hide() -- Cacher le nom de l'équipe
    infoTextEditor:Hide() -- Cacher le texte d'information
    descriptionEditBox:ClearFocus()
    teamNameEditorText:SetText("") -- Effacer le texte du nom de l'équipe

    editorCurrentTeamIndex = nil
end

function DescriptionEditor:SaveDescription()
    if not editorCurrentTeamIndex then DescriptionEditor:HideEditor(); return end

    local newDescription = descriptionEditBox:GetText()

    -- Supprimer les espaces en début et fin
    if newDescription then
        newDescription = string.gsub(newDescription, "^%s*(.-)%s*$", "%1")
        if newDescription == "" then
            newDescription = nil
        end
    end

    TeamManager:SetTeamDescription(editorCurrentTeamIndex, newDescription)
    self:HideEditor()
end

function DescriptionEditor:ShowBattleDescription()
    -- Vérifier si l'option est activée
    if not TeamManager:GetShowBattleDescription() then
        return
    end

    local selectedTeam = TeamManager:GetSelected()
    if selectedTeam and selectedTeam > 0 then
        local description = TeamManager:GetTeamDescription(selectedTeam)
        if description and description ~= "" then
            battleDescriptionText:SetText(description)
            local name, _, customName = TeamManager:GetTeamName(selectedTeam)
            battleDescriptionFrame.teamNameText:SetText(customName or name)
            battleDescriptionFrame:Show()
        end
    end
end

function DescriptionEditor:HideBattleDescription()
    battleDescriptionFrame:Hide()
end
