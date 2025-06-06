local PetBattleTeams = LibStub("AceAddon-3.0"):NewAddon("PetBattleTeams")
local _, addon = ...

-- luacheck: globals StaticPopup_OnClick

--handles addon stuff instansciates objects
function PetBattleTeams:OnInitialize()
end

function PetBattleTeams.Embed(self,other)
    for k,v in pairs(other) do
        assert(self[k] == nil,"Assert Failed: '"..tostring(k).."' Already exists")
        self[k] = v
    end
end


SLASH_PETBATTLETEAMS1, SLASH_PETBATTLETEAMS2 = '/pbt', '/PetBattleTeams';
function PetBattleTeams.slashHandler(msg, chatPromptFrame)
    local self = PetBattleTeams
    local GUI = self:GetModule("GUI")
    local TeamManager = self:GetModule("TeamManager")
    msg = string.lower(msg)
    if msg == "lock frame" then
        GUI:SetLocked(true)
        print("PetBattleTeams: Frame Locked")
    elseif msg == "unlock frame" then
        GUI:SetLocked(false)
        print("PetBattleTeams: Frame unlocked")
    elseif msg == "attach" then
        GUI:SetAttached(true)
        print("PetBattleTeams: Frame Attached")
    elseif msg == "toggle" then
        GUI:SetAttached(not GUI:GetAttached())
        if GUI:GetAttached() then
            print("PetBattleTeams: Frame Attached")
        else
            print("PetBattleTeams: Frame Detached")
        end
    elseif msg == "detach" then
        GUI:SetAttached(false)
        print("PetBattleTeams: Frame Detached")
    elseif msg == "max" then
        GUI:ToggleMinimize(false)
        print("PetBattleTeams: Frame Maximized")
    elseif msg == "min" then
        GUI:ToggleMinimize(true)
        print("PetBattleTeams: Frame Minimized")
    elseif msg == "lock teams" then
        TeamManager:SetLockStateAllTeams(true)
        print("PetBattleTeams: Teams Locked")
    elseif msg == "unlock teams" then
        TeamManager:SetLockStateAllTeams(false)
        print("PetBattleTeams: Teams Unlocked")
    elseif msg == "reset teams" then
        TeamManager:ResetTeams()
        GUI:ResetScrollBar()
        print("PetBattleTeams: Teams Reset")
    elseif msg == "reset ui" then
        GUI:ResetUI()
        self:GetModule("TeamManager"):ResetUI()
    else
        print("/pbt","lock frame",": Locks PetBattleTeams when detached preventing it from being moved or resized")
        print("/pbt","unlock frame",": Unlocks PetBattleTeams allowing it to be moved or resized while detached")
        print("/pbt","attach", ": Attach PetBattleTeams to the Pet Journal")
        print("/pbt", "detach", ": Detaches PetBattleTeams from the Pet Journal")
        print("/pbt","lock teams", ": Locks all existing teams, preventing changes to those teams. Does not effect new teams")
        print("/pbt","unlock teams", ": Unlocks all existing Teams, allowing changes to be made")
        print("/pbt","max", ": Maximize PetBattleTeams frame (if hidden)")
        print("/pbt","min", ": Minimize PetBattleTeams frame")
        print("/pbt","reset teams" , ": Deletes all teams, Warning no confirmation is given")
        print("/pbt","reset ui", ": Resets the UI to its defualt configuration")
    end
end

SlashCmdList["PETBATTLETEAMS"] = PetBattleTeams.slashHandler --


StaticPopupDialogs["PBT_TEAM_DELETE"] = {
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    text = "PetBattleTeams:|nAre you sure you want to delete |cffffd200%s|r?",
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function(self)
        local teamManager = PetBattleTeams:GetModule("TeamManager")
        teamManager:DeleteTeam(self.data)
    end,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["PBT_TEAM_RENAME"] = {
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    text = "PetBattleTeams:|nEnter a name for |cffffd200%s|r.",
    hasEditBox = 1,
    button1 = OKAY,
    button2 = DEFAULT,
    OnShow = function(self)
        local teamManager = PetBattleTeams:GetModule("TeamManager")
        local _, _, customName = teamManager:GetTeamName(self.data)
        if customName then
            self.editBox:SetText(customName)
        end
        self.editBox:SetAutoFocus(1)
    end,
    OnAccept = function(self)
        local text = self.editBox:GetText()
        local teamManager = PetBattleTeams:GetModule("TeamManager")
        teamManager:SetTeamName(self.data, text)
    end,
    OnCancel = function(self)
        local teamManager = PetBattleTeams:GetModule("TeamManager")
        teamManager:SetTeamName(self.data, nil)
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
    enterClicksFirstButton = true,
}

StaticPopupDialogs["PBT_IMPORT_TEAMS"] = {
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    text = "PetBattleTeams:|nWould you like to import your pets from previous versions of PetBattleTeams?",
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function(self)
        self.data:ImportTeams()
    end,
    OnCancel = function(self)

    end,
    timeout = 0,
    exclusive = 1,
    hideOnEscape = 1,
}

--[[-------------------------------------------------------------------------
--  Localization
-------------------------------------------------------------------------]]--

addon.L = addon.L or setmetatable({}, {
    __index = function(t, k)
        rawset(t, k, k)
        return k
    end,
    __newindex = function(t, k, v)
        if v == true then
            rawset(t, k, k)
        else
            rawset(t, k, v)
        end
    end,
})

function addon:RegisterLocale(locale, tbl)
    if locale == "enUS" or locale == GetLocale() then
        for k,v in pairs(tbl) do
            if v == true then
                self.L[k] = k
            elseif type(v) == "string" then
                self.L[k] = v
            else
                self.L[k] = k
            end
        end

        StaticPopupDialogs["PBT_TEAM_DELETE"].text = self.L["PetBattleTeams:|nAre you sure you want to delete |cffffd200%s|r?"]
        StaticPopupDialogs["PBT_TEAM_RENAME"].text = self.L["PetBattleTeams:|nEnter a name for |cffffd200%s|r."]
        StaticPopupDialogs["PBT_IMPORT_TEAMS"].text = self.L["PetBattleTeams:|nWould you like to import your pets from previous versions of PetBattleTeams?"]
    end
end