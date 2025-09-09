-------------------------------------------------------------------------------
-- Russian localization ZamestoTV
-------------------------------------------------------------------------------
if (GetLocale() ~= "ruRU") then return end

local _, addon = ...
local baseLocale = {
    ["Selected Team"] = "Выбранная команда",
    ["Team Roster"] = "Состав команды",
    ["Teams and Pets"] = "Команды и питомцы",
    ["Display pets xp as part of the pets level"] = "Отображать опыт питомцев как часть их уровня",
    ["Display pets xp instead of the health bar"] = "Отображать опыт питомцев вместо шкалы здоровья",
    ["Display team name above the team"] = "Отображать название команды над командой",
    ["Show team description during pet battles"] = "Показывать описание команды во время битв питомцев", -- ChatGPT
    ["Press Ctrl+Enter to save the description"] = "Нажмите Ctrl+Enter, чтобы сохранить описание", -- ChatGPT
    ["Enable mouse wheel scrolling for the selected team"] = "Включить прокрутку колесом мыши для выбранной команды",
    ["When enabled allows you to change the selected team by using the mouse wheel on the selected team (above the roster)"] = "Когда включено, позволяет менять выбранную команду с помощью колеса мыши на выбранной команде (над составом)",
    ["Main"] = "Основное",
    ["Attach PetBattle Teams to Pet Journal"] = "Прикрепить команды PetBattle к журналу питомцев",
    ["When attached, PetBattle Teams will only be usable from the Pet Journal."] = "Когда прикреплено, команды PetBattle будут доступны только из журнала питомцев.",
    ["Hide PetBattle Teams while in combat or in a Pet Battle"] = "Скрывать команды PetBattle во время боя или битвы питомцев",
    ["Hides PetBattle Teams while in combat or in a Pet Battle."] = "Скрывает команды PetBattle во время боя или битвы питомцев.",
    ["Lock PetBattle Teams Position"] = "Заблокировать положение команд PetBattle",
    ["When the team frame is not attached to the Pet Journal then if the frame is locked it cannot be moved."] = "Когда рамка команды не прикреплена к журналу питомцев, если рамка заблокирована, её нельзя переместить.",
    ["Show the selected team indicator"] = "Показывать индикатор выбранной команды",
    ["When enabled:|nThe currently selected team will have its pets updated to match the pet journal at all times unless the selected team is locked.|n|nNewly created teams will be created using the currently selected pets."] = "Когда включено:|nТекущая выбранная команда будет обновлять своих питомцев в соответствии с журналом питомцев, если команда не заблокирована.|n|nНовые команды будут создаваться с использованием текущих выбранных питомцев.",
    ["Show control buttons"] = "Показывать кнопки управления",
    ["When enabled, Your active pet will be dismissed when switching teams"] = "Когда включено, ваш активный питомец будет отозван при смене команд",
    ["Show the team roster"] = "Показывать состав команды",
    ["Attempts to reconstuct teams with invalid pets"] = "Попытки восстановить команды с недействительными питомцами",
    ["Tooltip"] = "Подсказка",
    ["Show keybinding helper text in tooltip"] = "Показывать текст помощи по привязке клавиш в подсказке",
    ["Show strong/weak hints in tooltip"] = "Показывать подсказки о сильных/слабых сторонах в подсказке", -- ChatGPT
    ["Show breed information in tooltip"] = "Показывать информацию о породе в подсказке",
    ["Automatically Sort Teams Alphabetically"] = "Автоматически сортировать команды в алфавитном порядке", -- ChatGPT
    ["When enabled, teams will be sorted alphabetically by name."] = "Когда включено, команды будут сортироваться в алфавитном порядке по имени.", -- ChatGPT
    ["Team Management"] = "Управление командами",
    ["Automatically Save Teams"] = "Автоматически сохранять команды",
    ["Automatically Dismiss pet after team changes"] = "Автоматически отзывать питомца после смены команды",
    ["Reconstruct teams"] = "Восстановить команды",
    ["Unlock all existing teams"] = "Разблокировать все существующие команды",
    ["This does not prevent you from locking individual teams."] = "Это не мешает блокировать отдельные команды.",
    ["Lock all existing teams"] = "Заблокировать все существующие команды",
    ["This does not lock newly created teams or prevent you from unlocking individual teams."] = "Это не блокирует новые команды и не мешает разблокировать отдельные команды.",
    ["Delete all teams"] = "Удалить все команды",
    ["Permanently deletes all teams."] = "Безвозвратно удаляет все команды.",
    ["Reset UI"] = "Сбросить интерфейс",
    ["Resets the UI to its default settings. There is no confirmation for this action."] = "Сбрасывает интерфейс на стандартные настройки. Для этого действия нет подтверждения.",

    ["Team: "] = "Команда: ",
    ["Team Options"] = "Настройки команды",
    ["Lock Team"] = "Заблокировать команду",
    ["Rename Team"] = "Переименовать команду",
    ["Edit Description"] = "Редактировать описание", -- ChatGPT
    ["Add Description"] = "Добавить описание", -- ChatGPT
    ["Delete Team"] = "Удалить команду",
    ["Remove Pet"] = "Удалить питомца",
    ["Team XX"] = "Команда XX",
    ["Click to add a new team"] = "Нажмите, чтобы добавить новую команду", -- ChatGPT
    ["Right-click to show options menu.|nClick to toggle teams frame."] = "Нажмите правой кнопкой мыши, чтобы открыть меню опций.|nНажмите левой кнопкой мыши, чтобы переключить рамку команд.", -- ChatGPT
    ["Drag to swap pets between teams.|nShift-Drag to copy pet to a new team.|nControl-Drag to move team."] = "Перетаскивайте, чтобы поменять питомцев между командами.|nShift+Перетаскивание для копирования питомца в новую команду.|nCtrl+Перетаскивание для перемещения команды.",
    ["PetBattleTeams:|nAre you sure you want to delete |cffffd200%s|r?"] = "PetBattleTeams:|nВы уверены, что хотите удалить |cffffd200%s|r?",
    ["PetBattleTeams:|nEnter a name for |cffffd200%s|r."] = "PetBattleTeams:|nВведите имя для |cffffd200%s|r.",
    ["PetBattleTeams:|nWould you like to import your pets from previous versions of PetBattleTeams?"] = "PetBattleTeams:|nХотите импортировать питомцев из предыдущих версий PetBattleTeams?",
    ["PetBattleTeams:|nAre you sure you want to |cffffd200reset all teams|r?"] = "PetBattleTeams:|nВы уверены, что хотите |cffffd200сбросить все команды|r?", -- ChatGPT
}


addon:RegisterLocale('ruRU', baseLocale)
