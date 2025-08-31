local PetBattleTeamsFrame = {}

local PETS_PER_TEAM = 3
local PetBattleTeams =  LibStub("AceAddon-3.0"):GetAddon("PetBattleTeams")
local TeamManager = PetBattleTeams:GetModule("TeamManager")
local Cursor =  PetBattleTeams:GetModule("Cursor")
local Embed = PetBattleTeams.Embed
local HEIGHT_WITH_NAME = 55
local HEIGHT_WITH_DESCRIPTION = 70
local HEIGHT = 42
local PetBattleTeamsUnitFrame = PetBattleTeams.PetBattleTeamsUnitFrame

local _, addon = ...
local L = addon.L

local function CalculateTeamHeight(teamIndex)
    local height = HEIGHT
    if TeamManager:GetShowTeamName() then
        height = HEIGHT_WITH_NAME
    end
    return height
end

local function OnEnter(self)
    local operation = Cursor:GetCursorInfo()
    self.helperText:Show()

    local parent = self:GetParent()
    parent:SetHeight(55*1.5)
end

local function OnLeave(self)
    local parent = self:GetParent()
    self.helperText:Hide()
    parent:SetHeight(CalculateTeamHeight(parent.teamIndex))
end

local function OnClickOrDrag(self)
    local parent = self:GetParent()
    local operation, petID, teamIndex, petIndex = Cursor:GetCursorInfo()
    if operation == "MOVE TEAM" then
        TeamManager:MoveTeam(teamIndex,parent.teamIndex)
    end

    parent:SetHeight(CalculateTeamHeight(parent.teamIndex))
    ClearCursor()
end

local function OnEvent(self,event,...)
    if event == "PET_BATTLE_QUEUE_STATUS" or event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_CLOSE" then
        self:PET_BATTLE_QUEUE_STATUS(event,...)
    end
end

function PetBattleTeamsFrame:New()
    local petBattleTeamsFrame = CreateFrame("frame")
    Embed(petBattleTeamsFrame, PetBattleTeamsFrame)

    local width = 135
    local height = HEIGHT
    petBattleTeamsFrame:SetSize(width,height)

    petBattleTeamsFrame.unitFrames = {}
    petBattleTeamsFrame.unitFrames[1]= PetBattleTeamsUnitFrame:New()
    petBattleTeamsFrame.unitFrames[1]:SetParent(petBattleTeamsFrame)
    petBattleTeamsFrame.unitFrames[1]:SetPoint("BOTTOMLEFT",petBattleTeamsFrame,"BOTTOMLEFT",15,2)

    for i=2,PETS_PER_TEAM do
        local unitFrame = PetBattleTeamsUnitFrame:New()
        unitFrame:SetParent(petBattleTeamsFrame)
        unitFrame:SetPoint("LEFT",petBattleTeamsFrame.unitFrames[i-1],"RIGHT",1,0)
        petBattleTeamsFrame.unitFrames[i] = unitFrame;
    end

    petBattleTeamsFrame.logicalLeft = petBattleTeamsFrame.unitFrames[1]
    petBattleTeamsFrame.logicalRight = petBattleTeamsFrame.unitFrames[PETS_PER_TEAM]

    local teamMovementFrame = CreateFrame("button")
    petBattleTeamsFrame.teamMovementFrame = teamMovementFrame
    teamMovementFrame:SetParent(petBattleTeamsFrame)
    teamMovementFrame:SetAllPoints(petBattleTeamsFrame)
    teamMovementFrame:SetFrameLevel(10000)
    teamMovementFrame:Hide()

    teamMovementFrame:SetScript("OnEnter",OnEnter)
    teamMovementFrame:SetScript("OnLeave",OnLeave)
    teamMovementFrame:SetScript("OnClick",OnClickOrDrag)
    teamMovementFrame:SetScript("OnReceiveDrag",OnClickOrDrag)

    local helperText = petBattleTeamsFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    teamMovementFrame.helperText = helperText
    helperText:SetParent(teamMovementFrame)
    helperText:SetText("Place Team Here")
    helperText:SetPoint("CENTER", teamMovementFrame, "TOP",0,-15)
    helperText:SetJustifyH("CENTER")
    helperText:Hide()

    local teamNameText = petBattleTeamsFrame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    petBattleTeamsFrame.teamNameText = teamNameText

    teamNameText:SetText("")
    teamNameText:SetPoint("BOTTOMLEFT", petBattleTeamsFrame.unitFrames[1], "TOPLEFT",0,2)
    teamNameText:SetPoint("BOTTOMRIGHT", petBattleTeamsFrame.unitFrames[3], "TOPRIGHT",0,2)
    teamNameText:SetJustifyH("LEFT")
    teamNameText:Hide()

    local teamDescriptionIcon = petBattleTeamsFrame:CreateTexture(nil, "OVERLAY")
    petBattleTeamsFrame.teamDescriptionIcon = teamDescriptionIcon
    teamDescriptionIcon:SetSize(16, 16)
    teamDescriptionIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    teamDescriptionIcon:SetPoint("BOTTOMRIGHT", petBattleTeamsFrame.unitFrames[3], "TOPRIGHT", -2, 2)
    teamDescriptionIcon:Hide()

    local teamDescriptionButton = CreateFrame("Button", nil, petBattleTeamsFrame)
    petBattleTeamsFrame.teamDescriptionButton = teamDescriptionButton
    teamDescriptionButton:SetSize(16, 16)
    teamDescriptionButton:SetPoint("CENTER", teamDescriptionIcon, "CENTER")
    teamDescriptionButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    teamDescriptionButton:SetScript("OnEnter", function(self)
        local teamIndex = self:GetParent().teamIndex
        local description = TeamManager:GetTeamDescription(teamIndex)
        if description and description ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(L["Team Description"], 1, 1, 1)
            GameTooltip:AddLine(description, 0.8, 0.8, 0.8, false)
            GameTooltip:Show()
        end
    end)
    teamDescriptionButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    teamDescriptionButton:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        parent:ShowDescriptionEditor()
    end)

    petBattleTeamsFrame.selectedTexture = petBattleTeamsFrame:CreateTexture(nil,"OVERLAY")
    petBattleTeamsFrame.selectedTexture:SetSize(36,36)
    petBattleTeamsFrame.selectedTexture:SetTexture("Interface\\PetBattles\\PetJournal")
    petBattleTeamsFrame.selectedTexture:SetTexCoord(0.11328125,0.16210938,0.02246094,0.04687500)
    petBattleTeamsFrame.selectedTexture:SetPoint("CENTER",petBattleTeamsFrame.unitFrames[1],"LEFT",0,0)
    petBattleTeamsFrame.selectedTexture:SetParent(petBattleTeamsFrame.unitFrames[1])
    petBattleTeamsFrame.selectedTexture:Hide()

    petBattleTeamsFrame.lockedTexture = petBattleTeamsFrame:CreateTexture(nil,"OVERLAY")
    petBattleTeamsFrame.lockedTexture:SetSize(30,30)
    petBattleTeamsFrame.lockedTexture:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    petBattleTeamsFrame.lockedTexture:SetPoint("CENTER",petBattleTeamsFrame.unitFrames[1],"LEFT",0,0)
    petBattleTeamsFrame.lockedTexture:SetParent(petBattleTeamsFrame.unitFrames[1])
    petBattleTeamsFrame.lockedTexture:Hide()

    TeamManager.RegisterCallback(petBattleTeamsFrame,"TEAM_UPDATED")
    TeamManager.RegisterCallback(petBattleTeamsFrame,"TEAM_DELETED")
    TeamManager.RegisterCallback(petBattleTeamsFrame,"SELECTED_TEAM_CHANGED")

    Cursor.RegisterCallback(petBattleTeamsFrame,"BATTLE_PET_CURSOR_CHANGED")

    petBattleTeamsFrame:RegisterEvent("PET_BATTLE_QUEUE_STATUS")
    petBattleTeamsFrame:RegisterEvent("PET_BATTLE_OPENING_START")
    petBattleTeamsFrame:RegisterEvent("PET_BATTLE_CLOSE")
    petBattleTeamsFrame:SetScript("OnEvent",OnEvent)

    return petBattleTeamsFrame
end
PetBattleTeams.PetBattleTeamsFrame = PetBattleTeamsFrame


function PetBattleTeamsFrame:Update()
    local isSelected = (self.teamIndex == TeamManager:GetSelected())
    local showTeamName = TeamManager:GetShowTeamName()
    local showLocked = TeamManager:IsTeamLocked(self.teamIndex)

    if showTeamName then
        local displayName = TeamManager:GetTeamName(self.teamIndex)
        self.teamNameText:SetText(displayName)
    end
    self.teamNameText:SetShown(showTeamName)

    local description = TeamManager:GetTeamDescription(self.teamIndex)
    if description and description ~= "" then
        self.teamDescriptionIcon:SetShown(showTeamName)
        self.teamDescriptionButton:SetShown(showTeamName)
    else
        self.teamDescriptionIcon:Hide()
        self.teamDescriptionButton:Hide()
    end

    self:SetHeight(CalculateTeamHeight(self.teamIndex))

    if self.teamIndex and TeamManager:IsTeamLockedByUser(self.teamIndex) then
        self.teamNameText:SetTextColor(.95,1,.2)
    else
        self.teamNameText:SetTextColor(1,1,1)
    end

    if isSelected then
        self.selectedTexture:SetShown(not showLocked)
        self.lockedTexture:SetShown(showLocked)
    else
        self.selectedTexture:Hide()
        self.lockedTexture:Hide()
    end

    for i=1,#self.unitFrames do
        self.unitFrames[i]:UpdateWidget()
    end
end

function PetBattleTeamsFrame:SetTeam(teamIndex)
    assert(type(teamIndex) == "number")
    self.teamIndex = teamIndex

    self:Update()

    for i=1,#self.unitFrames do
        self.unitFrames[i]:SetPet(teamIndex,i)
    end
end

function PetBattleTeamsFrame:TEAM_UPDATED(event,teamIndex)
    if teamIndex == self.teamIndex or teamIndex == nil  then
        self:Update()
    end
end

function PetBattleTeamsFrame:TEAM_DELETED(event,teamIndex)
    if teamIndex <= self.teamIndex then
        self:Update()
    end
end

function PetBattleTeamsFrame:SELECTED_TEAM_CHANGED(event,teamIndex)
    self:Update()
end

function PetBattleTeamsFrame:PET_BATTLE_QUEUE_STATUS(event, status)
    self:Update()
end

function PetBattleTeamsFrame:BATTLE_PET_CURSOR_CHANGED(event,operation , petID, teamIndex, petIndex)
    local show =  operation == "MOVE TEAM"
    self.teamMovementFrame:SetShown(show)
end

function PetBattleTeamsFrame:ShowDescriptionEditor()
    if not self.teamIndex then return end
    
    -- Utiliser l'EditBox globale
    local globalEditor = PetBattleTeams:GetModule("DescriptionEditor")
    if globalEditor then
        globalEditor:ShowEditor(self.teamIndex)
    end
end

function PetBattleTeamsFrame:HideDescriptionEditor()
    -- Cette méthode n'est plus nécessaire car l'EditBox est géré globalement
end

function PetBattleTeamsFrame:SaveDescription()
    -- Cette méthode n'est plus nécessaire car l'EditBox est géré globalement
end
