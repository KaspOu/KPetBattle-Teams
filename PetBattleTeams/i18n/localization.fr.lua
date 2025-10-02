-------------------------------------------------------------------------------
-- French localization
-------------------------------------------------------------------------------

if (GetLocale() ~= "frFR") then return end

local _, addon = ...
local baseLocale = {
    ["Selected Team"] = "\195\137quipe s\195\169lectionn\195\169e",
    ["Team Roster"] = "Liste des \195\169quipes",
    ["Teams and Pets"] = "\195\137quipes et Mascottes",
    ["Display pets xp as part of the pets level"] = "Afficher l'exp\195\169rience des mascottes dans leur niveau",
    ["Display pets xp instead of the health bar"] = "Afficher l'exp\195\169rience des mascottes \195\160 la place de la barre de sant\195\169",
    ["Display team name above the team"] = "Afficher le nom de l'\195\169quipe au-dessus de l'\195\169quipe",
    ["Display team note in tooltip"] = "Afficher la note d'\195\169quipe dans l'infobulle",
    ["Show team note during pet battles"] = "Afficher la note d'\195\169quipe pendant les combats de mascottes",
    ["Press Ctrl+Enter to save the note"] = "Appuyez sur Ctrl+Entr\195\169e pour sauvegarder la note d'\195\169quipe",
    ["Press Ctrl+Enter to save the script"] = "Appuyez sur Ctrl+Entr\195\169e pour sauvegarder le script d'\195\169quipe",
    ["Enable mouse wheel scrolling for the selected team"] = "Activer le d\195\169filement de la molette de la souris pour l'\195\169quipe s\195\169lectionn\195\169e",
    ["When enabled allows you to change the selected team by using the mouse wheel on the selected team (above the roster)"] = "Lorsqu'activ\195\169, permet de changer l'\195\169quipe s\195\169lectionn\195\169e en utilisant la molette de la souris sur l'affichage de l'\195\169quipe (au-dessus de la liste).",
    ["Main"] = "Principal",
    ["Attach PetBattle Teams to Pet Journal"] = "Attacher les \195\137quipes de Bataille de Mascottes au Journal des Mascottes",
    ["When attached, PetBattle Teams will only be usable from the Pet Journal."] = "Lorsqu'attach\195\169es, les \195\137quipes de Bataille de Mascottes ne seront utilisables que depuis le Journal des Mascottes.",
    ["Hide PetBattle Teams while in combat or in a Pet Battle"] = "Cacher les \195\137quipes de Bataille de Mascottes pendant un combat ou une Bataille de Mascottes",
    ["Hides PetBattle Teams while in combat or in a Pet Battle."] = "Cache les \195\137quipes de Bataille de Mascottes pendant un combat ou une Bataille de Mascottes.",
    ["Lock PetBattle Teams Position"] = "Verrouiller la position des \195\137quipes de Bataille de Mascottes",
    ["When the team frame is not attached to the Pet Journal then if the frame is locked it cannot be moved."] = "Lorsque le cadre de l'\195\169quipe n'est pas attach\195\169 au Journal des Mascottes, si le cadre est verrouill\195\169, il ne peut pas \195\170tre d\195\169plac\195\169.",
    ["Show the selected team indicator"] = "Afficher l'indicateur de l'\195\169quipe s\195\169lectionn\195\169e",
    ["When enabled:|nThe currently selected team will have its pets updated to match the pet journal at all times unless the selected team is locked.|n|nNewly created teams will be created using the currently selected pets."] = "Lorsqu'activ\195\169 :|nLes mascottes de l'\195\169quipe actuellement s\195\169lectionn\195\169e seront mises \195\160 jour pour correspondre au journal des mascottes en permanence, sauf si l'\195\169quipe est verrouill\195\169e.|n|nLes nouvelles \195\169quipes seront cr\195\169\195\169es \195\160 partir des mascottes actuellement s\195\169lectionn\195\169es.",
    ["Show control buttons"] = "Afficher les boutons de contr\195\180le",
    ["When enabled, Your active pet will be dismissed when switching teams"] = "Lorsqu'activ\195\169, votre mascotte active sera renvoy\195\169e lors du changement d'\195\169quipes",
    ["Show the team roster"] = "Afficher la liste des \195\169quipes",
    ["Attempts to reconstuct teams with invalid pets"] = "Tente de reconstruire des \195\169quipes avec des mascottes invalides",
    ["Tooltip"] = "Infobulle",
    ["Show keybinding helper text in tooltip"] = "Afficher l'aide des raccourcis clavier dans l'infobulle",
    ["Show strong/weak hints in tooltip"] = "Afficher les forces/faiblesses dans l'infobulle",
    ["Show breed information in tooltip"] = "Afficher les informations de race dans l'infobulle",
    ["Autoswitch team feature"] = "Changement d'\195\169quipe automatique",
    ["When enabled, you can associate teams with NPC IDs, and your team will automatically switch when you target them."] = "Lorsqu'activ\195\169, vous pouvez associer des \195\169quipes \195\160 des IDs de PNJ, et votre \195\169quipe changera automatiquement lorsque vous les ciblerez.",
    ["Automatically Sort Teams Alphabetically"] = "Trier automatiquement les \195\169quipes par ordre alphab\195\169tique",
    ["When enabled, teams will be sorted alphabetically by name."] = "Lorsqu'activ\195\169, les \195\169quipes seront tri\195\169es par ordre alphab\195\169tique par nom.",
    ["Team Management"] = "Gestion d'\195\137quipe",
    ["Automatically Save Teams"] = "Sauvegarder automatiquement les \195\169quipes",
    ["Automatically Dismiss pet after team changes"] = "Renvoyer automatiquement la mascotte apr\195\168s les changements d'\195\169quipe",
    ["Reconstruct teams"] = "Reconstruire les \195\169quipes",
    ["Unlock all existing teams"] = "D\195\169verrouiller toutes les \195\169quipes existantes",
    ["This does not prevent you from locking individual teams."] = "Cela ne vous emp\195\170che pas de verrouiller des \195\169quipes individuelles.",
    ["Lock all existing teams"] = "Verrouiller toutes les \195\169quipes existantes",
    ["This does not lock newly created teams or prevent you from unlocking individual teams."] = "Cela ne verrouille pas les \195\169quipes nouvellement cr\195\169\195\169es ou ne vous emp\195\170che pas de d\195\169verrouiller des \195\169quipes individuelles.",
    ["Delete all teams"] = "Supprimer toutes les \195\169quipes",
    ["Permanently deletes all teams."] = "Supprime d\195\169finitivement toutes les \195\169quipes.",
    ["Reset UI"] = "R\195\169initialiser l'interface utilisateur",
    ["Resets the UI to its default settings. There is no confirmation for this action."] = "R\195\169initialise l'interface utilisateur aux param\195\168tres par d\195\169faut. Il n'y a pas de confirmation pour cette action.",

    ["Team: "] = "\195\137quipe : ",
    ["Team Options"] = "Options de l'\195\169quipe",
    ["Lock Team"] = "Verrouiller l'\195\169quipe",
    ["Rename Team"] = "Renommer l'\195\169quipe",
    ["Edit Note"] = "Editer la note",
    ["Add Note"] = "Ajouter une note",
    ["Edit Script"] = "Editer le Script",
    ["Edit NPC ID for AutoSwitch"] = "Editer l'ID PNJ pour le changement automatique",
    ["Set NPC ID from current Target"] = "D\195\169finir l'ID PNJ \195\160 partir de la cible actuelle",
    ["Linked to NPC: %s"] = "Li\195\169e au PNJ : %s",
    ["Click: %s|nRight-click: %s|nCtrl-Right-click: Clear NPC ID"] = "Clic gauche : %s|nClic droit : %s|nCtrl+Clic droit : Effacer l'ID PNJ",
    ["Delete Team"] = "Supprimer l'\195\169quipe",
    ["Remove Pet"] = "Retirer la mascotte",
    ["Team XX"] = "\195\137quipe XX",
    ["Click to add a new team"] = "Ajouter une nouvelle \195\169quipe",
    ["Right-click to show options menu.|nClick to toggle teams frame."] = "Clic droit pour afficher le menu des options.|nClic gauche pour afficher/masquer les \195\169quipes.",
    ["Drag to swap pets between teams.|nShift-Drag to copy pet to a new team.|nControl-Drag to move team."] = "Glisser pour \195\169changer les mascottes entre les \195\169quipes.|nMaj+Glisser pour copier la mascotte dans une nouvelle \195\169quipe.|nCtrl+Glisser pour d\195\169placer l'\195\169quipe.",

    ["Team '|cffffd200%s|r': script loaded"] = "\195\137quipe '|cffffd200%s|r' : script charg\195\169",
    ["PetBattleTeams: Warning: NPC ID %s is linked to multiple teams: %s and %s.|nOnly the last team will be chosen for autoswitch."] = "PetBattleTeams: Attention : L'ID PNJ %s est li\195\169 \195\160 plusieurs \195\169quipes : %s et %s.|nSeule la derni\195\168re \195\169quipe sera choisie pour l'autoswitch.",
    ["PetBattleTeams: |cffffd200%s|r found, autoswitch to team: |cffffd200%s|r"] = "PetBattleTeams : |cffffd200%s|r trouv\195\169, chargement automatique de l'\195\169quipe : |cffffd200%s|r",
    ["PetBattleTeams:\nAutoswitch to team: |cffffd200%s|r"] = "PetBattleTeams :\nChargement automatique de l'\195\169quipe : |cffffd200%s|r",
    ["SCRIPT: %s"] = "SCRIPT: %s",

    ["PetBattleTeams:|nAre you sure you want to delete |cffffd200%s|r?"] = "PetBattleTeams:|n\195\138tes-vous s\195\187r de vouloir|nsupprimer |cffffd200%s|r ?",
    ["PetBattleTeams:|nEnter a name for |cffffd200%s|r."] = "PetBattleTeams:|nEntrez un nom pour |cffffd200%s|r.",
    ["PetBattleTeams:|nEnter a NPC ID for |cffffd200%s|r."] = "PetBattleTeams:|nEntrez un ID de PNJ pour |cffffd200%s|r.",
    ["PetBattleTeams:|nWould you like to import your pets from previous versions of PetBattleTeams?"] = "PetBattleTeams:|nSouhaitez-vous importer vos mascottes depuis les versions pr\195\169c\195\169dentes de PetBattleTeams ?",
    ["PetBattleTeams:|nAre you sure you want to |cffffd200reset all teams|r?"] = "PetBattleTeams:|n\195\138tes-vous s\195\187r de vouloir|n|cffffd200r\195\169initialiser toutes les \195\169quipes|r?",
    ["PetBattleTeams:|n'|cffffd200Pet Battle Scripts|r' addon is required.\n\nWrite scripts to automate pet battles."] = "PetBattleTeams:|nL'addon '|cffffd200Pet Battle Scripts|r' est requis.\n\n\195\142crivez des scripts pour automatiser les combats de mascottes.",
    ["PetBattleTeams:|n|cffffd200Invalid script (not saved)|r:\n%s"] = "PetBattleTeams:|n|cffffd200Script invalide (non sauvegard\195\169)|r:\n%s"
}

addon:RegisterLocale('frFR', baseLocale)

--@do-not-package@
-- https://code.google.com/archive/p/mangadmin/wikis/SpecialCharacters.wiki
-- https://wowwiki.fandom.com/wiki/Localizing_an_addon
--@end-do-not-package@