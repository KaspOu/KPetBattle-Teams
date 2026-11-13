# AGENTS.md — PetBattleTeams (KPetBattle-Teams)

Guide de travail pour les agents IA (et les humains) qui modifient cet addon. Ce document
décrit le code tel qu'il existe aujourd'hui — ne « réparez » pas l'architecture décrite ici sans
demander. Voir `docs/ARCHITECTURE.md` pour la référence technique complète et `backlog.md` pour
l'audit sécurité/correction du 2026-11-13 (les défauts connus y sont listés, pas corrigés
discrètement ici).

## 1. Contexte technique

- **Objectif.** Gestionnaire d'équipes de mascottes de combat : constituer des équipes de 3
  mascottes de combat, basculer le loadout entre elles, glisser-déposer des mascottes, notes par
  équipe et intégration Pet Battle Scripts (PBS), import/export compatible Rematch, changement
  d'équipe automatique selon l'ID du NPC ciblé.
- **Clients ciblés.** `## Interface: 120100, 120105, 120107` (retail 12.x / Midnight) et
  `50504` (Mists of Pandaria Classic) ; `## AllowLoadGameType: standard, mists`
  (`PetBattleTeams/PetBattleTeams.toc:1-2`). Version `12.1.503` (TOC ligne 11).
- **Environnement.** Lua 5.1 embarqué dans WoW (LuaJIT sur retail) : pas de `os`/`io`/accès
  filesystem, pas de `require`, programmation événementielle mono-thread, SavedVariables
  sérialisées par le client à la déconnexion. Sur retail 12.x, le **système de secret values**
  s'applique : les API d'identité d'unité retournent des valeurs secrètes en combat/contexte
  teinté — voir `docs/WoWAddonDevGuide-master/12a_Secret_Safe_APIs.md`.
- **Bibliothèques embarquées** (vendored sous `PetBattleTeams/libs/`, déclarées en externals
  dans `.pkgmeta`) : sous-ensemble Ace3 (AceAddon/AceConfig/AceConfigDialog/AceConfigCmd/
  AceConfigRegistry/AceConsole/AceDB/AceGUI), LibStub, CallbackHandler-1.0,
  LibPetJournal-2.0 (fork KaspOu), LibPetBreedInfo-1.0, LibDropDownMenu (Hizuros),
  LibSharedMedia-3.0 et EmbedHandler-1.0 (ces deux derniers chargés par le TOC mais **jamais
  référencés par le code first-party**).
- **Addon externe optionnel.** `tdBattlePetScript` (« Pet Battle Scripts ») : `ScriptEditor`
  s'intègre via `GetAddon("PetBattleScripts")` / son module `Director` / `GetClass("Script")`.
  Sans lui, les fonctionnalités de script dégradent en popup « addon required ».

## 2. Organisation du code

```
KPetBattle-Teams/
├── PetBattleTeams/            # l'addon lui-même (nom du dossier = nom de l'addon)
│   ├── PetBattleTeams.toc     # ordre de chargement + métadonnées (source de vérité)
│   ├── PetBattleTeams.lua     # création addon, slash, StaticPopups, métable L
│   ├── i18n/                  # 9 fichiers de localisation (en d'abord, puis 8 traductions)
│   ├── modules/               # modules AceAddon + fichiers modèle purs
│   │   ├── TeamManager.lua    # cœur : données équipes, application du loadout, autoswitch, SV
│   │   ├── RematchImporter.lua / RematchExporter.lua / TeamModel.lua  # couche modèle pure
│   │   ├── ImportExport.lua   # colle runtime du dialogue import/export
│   │   ├── TeamManagerUnitTests.lua   # tests in-game (livrés, jamais auto-exécutés)
│   │   ├── Tooltip.lua / Cursor.lua / Config.lua / Tutorial.lua (mort)
│   │   └── GUI/               # constructeurs UI + éditeurs (GUI.lua, MainFrame, ScrollFrame…)
│   ├── classes/               # classes UI en mixin : TeamFrame, PetUnitFrame
│   └── libs/                  # bibliothèques vendored (code amont — ne pas éditer)
├── .context/                  # outillage dev (run.py, import_test.lua — actuellement cassé)
├── .pkgmeta                   # manifeste du packager BigWigs (externals)
└── .release*.bat              # enveloppes release Windows → ../packager/release.sh
```

### Responsabilités des modules et ordre de chargement

L'ordre de `PetBattleTeams.toc` est impératif ; plusieurs fichiers capturent des références de
modules au chargement du fichier. Dépendances critiques :

1. `PetBattleTeams.lua` **en premier** : crée l'objet AceAddon `PetBattleTeams`, la métable de
   localisation `addon.L`, le gestionnaire slash et les StaticPopups.
2. `i18n/*` ensuite : chaque fichier appelle `addon:RegisterLocale` ;
   `Localization.en.lua` est la base.
3. `TeamManager.lua` avant tout fichier appelant `GetModule("TeamManager")` au niveau module
   (ImportExport, GUI, Config, classes…).
4. Ordre de la chaîne de modèle : `RematchImporter.lua` → `RematchExporter.lua` →
   `TeamModel.lua` → `ImportExport.lua` (chacun capture `ns.<Modèle>` depuis la table privée au
   niveau fichier).
5. `classes/*.lua` avant `modules/GUI/ScrollFrame.lua` (qui lit
   `PetBattleTeams.PetBattleTeamsFrame` au niveau fichier) et avant toute construction de frames.

Styles de modules en usage (suivez celui qui existe déjà en ajoutant du code) :

- **Modules AceAddon** (`PetBattleTeams:NewModule(...)`) : TeamManager, GUI, Config (embarque
  AceConsole-3.0), Tooltip, Cursor, NoteEditor, ScriptEditor, ImportExport. Interrogés avec
  `GetModule("Nom")`.
- **Classes mixin** avec `PetBattleTeams.Embed` (copie la table de méthodes dans l'instance) :
  `PetBattleTeamsFrame` (classes/TeamFrame.lua) et `PetBattleTeamsUnitFrame`
  (classes/PetUnitFrame.lua).
- **Fichiers modèle purs** partageant la table vararg privée de l'addon
  (`local _, ns = ...`) : RematchImporter, RematchExporter, TeamModel — aucune API WoW hors
  injection d'un `api`.

### Namespaces et variables globales

- `PetBattleTeams` (objet AceAddon) est l'unique namespace de l'addon ; les modules y
  accrochent.
- La table vararg privée (`local _, addon = ...` / `local _, ns = ...`) porte `L`
  (localisation) et les trois fichiers de modèle. Ne créez pas de nouvelles globales.
- **Frames globales existantes** : `PetBattleTeamFrame` (MainFrame), `PetBattleTeamsTooltip`,
  `PetBattleTeamsImportExportFrame` (dans `UISpecialFrames`), `CursorTeamFrame` (dans
  `UISpecialFrames`), boutons Revive/Bandage nommés dynamiquement (motif
  `parent:GetName()..name`).
- **Globales slash** : `SLASH_PETBATTLETEAMS1/2` (`/pbt`, `/PetBattleTeams`) +
  `SlashCmdList.PETBATTLETEAMS`. Attention : `Config.lua:351` enregistre aussi `/pbt` via
  AceConfig (`SLASH_ACECONSOLE_PBT1`) — collision connue (backlog.md constat 6).
- **Globales SavedVariables** : `PetBattleTeamsDB` (AceDB-3.0), `PetBattleTeamsSettings`
  (table simple, clé `ForceEnglish`).
- Les clés de localisation sont les **chaînes anglaises sources** ; `L[...]` retombe sur la clé
  elle-même.

## 3. Règles spécifiques à WoW

- **API par version de client.** Le code tourne sur retail 12.x et MoP Classic. Protégez les
  globales propres à 12.x (`issecretvalue` en `TeamManager.lua:175` est le motif :
  `if issecretvalue and issecretvalue(v) then … end`). Ne supposez jamais qu'une API existe sur
  les deux clients sans vérifier `docs/WoWAddonDevGuide-master/01_API_Reference.md`.
- **Secret values (12.x).** Pas d'arithmétique, de comparaison ni d'opération de chaîne sur les
  valeurs des API d'identité d'unité en combat/contexte teinté. `UnitGUID`/`UnitName` exigent
  une garde `issecretvalue` partout où elles sont utilisées (`TeamManager.lua:418-429` en manque
  une — backlog.md constat 13). Recharges de sort : passez des objets duration aux frames de
  cooldown, pas les `startTime`/`duration` bruts (`ReviveButton.lua:14-16` viole cette règle —
  backlog.md constat 4).
- **Combat lockdown.** Les frames créées depuis `secureactionbuttontemplate`
  (`ReviveButton.lua:41`, `PetBandageButton.lua:35`) sont protégées : `SetAttribute`,
  `Show`/`Hide`, `SetParent`, `SetPoint` dessus doivent être gardés par `InCombatLockdown()` ou
  différés (motif : `MainFrame.lua:99`, `GUI.lua:119`). Les violations connues sont listées
  dans backlog.md constats 2-3, 8 — ne les reproduisez pas dans le nouveau code.
- **Cycle de vie des événements.** Tout repose sur `ADDON_LOADED` et les callbacks
  `OnInitialize` d'AceAddon (voir `docs/ARCHITECTURE.md` §4). `PLAYER_LOGIN` /
  `PLAYER_ENTERING_WORLD` **ne sont pas** utilisés. L'UI est construite paresseusement au
  chargement de l'addon LoadOnDemand `Blizzard_Collections` (`GUI.lua:21-36`) — ne supposez
  jamais que `PetJournal` existe avant cela.
- **SavedVariables.** Ouvertes via AceDB-3.0 dans `OnInitialize` (après le chargement du
  fichier SV par le client ; `## LoadSavedVariablesFirst: 1` est défini dans le TOC). Validez
  les types en lisant des valeurs éditables à la main par l'utilisateur (précédent :
  `TeamManager:ConvertDeprecated`, `TeamManager.lua:764-808`). Ajoutez les défauts dans la
  table de défauts du namespace (`TeamManager.lua:816-832`, `GUI.lua:58-73`,
  `Tooltip.lua:44-50`).
- **Communication entre addons.** Aucune par chat (`C_ChatInfo` inutilisé). L'intégration passe
  par LibStub (AceAddon `GetAddon`, callbacks CallbackHandler). Si vous ajoutez des
  fonctionnalités PBS, respectez le contrat `ScriptEditor` : valider via
  `ScriptClass:SetCode` avant stockage.
- **API obsolètes/legacy.** `SetBackdrop` est utilisé sur des frames `BackdropTemplate` (valide
  sur les deux clients) ; `PetJournal_UpdatePetLoadOut` n'est appelé que derrière une garde
  d'existence (`TeamManager.lua:88-90`). Préférez les espaces de noms `C_*` aux globales
  obsolètes pour le nouveau code.

## 4. Instructions pour les agents IA

Avant toute modification :

1. Lisez intégralement le fichier cible et ses voisins dans le TOC — vérifiez ce qui capture des
   références au niveau fichier avant tout réordonnancement.
2. Identifiez le style de module en usage (module AceAddon / classe mixin / modèle pur) et
   suivez-le.
3. Cherchez (`grep`) tous les appelants d'une fonction que vous changez (outillage de
   l'espace de travail : `rtk grep` ou `grep` simple depuis la racine ; voir l'`AGENTS.md` de
   l'espace de travail §9).
4. Vérifiez l'API WoW dans `docs/WoWAddonDevGuide-master/` pour les deux clients ciblés.
5. Respectez les règles combat/frames protégées et les règles de secret values ci-dessus.

Après toute modification :

1. Lancez la porte de syntaxe Lua (§5) sur chaque fichier touché.
2. Revérifiez les dépendances entre modules et l'ordre de chargement (TOC).
3. Revérifiez les enregistrements d'événements et les callbacks touchés.
4. Considérez les deux clients (retail 12.x et MoP Classic) et les chemins en combat.
5. Listez les tests in-game restant à effectuer (aucun test automatisé d'exécution n'existe).

Localisation : toute modification de chaîne visible par l'utilisateur doit mettre à jour
**les 9 fichiers de `i18n/`** (les clés sont les chaînes anglaises sources ; voir
l'`AGENTS.md` de l'espace de travail §10.6).

## 5. Commandes et outils (tous réels — rien d'autre n'existe)

- **Porte de syntaxe Lua** (analyseur Lua 5.1 ; à lancer depuis la racine de l'espace de
  travail `/mnt/d/RProjects/_KaspOu`) :

    ```bash
    python3 tools/validate_lua.py KPetBattle-Teams/PetBattleTeams   # cet addon
    python3 tools/validate_lua.py --selftest                        # auto-test du vérificateur
    ```

- **Tests unitaires in jeu** : `PetBattleTeams/modules/TeamManagerUnitTests.lua` est chargé par
  le TOC mais ne s'exécute jamais automatiquement. Lancement manuel in-game :
  `/run PetBattleTeams.TeamManagerUnitTests:Run()` (le commentaire ligne 53 affiche une
  commande cassée — il n'existe pas de global `TeamManagerUnitTests`). Avertissement : une
  exécution a des effets de bord réels (déclenche de vrais callbacks, ré-applique le loadout ;
  backlog.md constat 16).
- **Banc de dev** : `.context/run.py` (nécessite `pip install lupa`) est **cassé** — il ouvre
  `tests/import_test.lua`, qui n'existe pas (le fichier est dans `.context/`), et le fixture
  `export.txt` est absent (backlog.md constat 17). Inutilisable en l'état.
- **Packaging** : `.release.bat` → `wsl bash ../packager/release.sh -d` (BigWigs WoW packager,
  manifeste `.pkgmeta`), plus `.release.live.bat` et `.release.xcopylibs.bat`. Les scripts de
  release modifient l'état — ne lancez-les que si on vous le demande explicitement.
- **Aucun lint, aucun build, aucune CI** dans ce dépôt. Les fichiers Lua portent des annotations
  `-- luacheck: globals …`, mais il n'y a ni `.luacheckrc` ni commande de lint. N'en inventez
  pas.

## 6. Mines terrestres connues (ne pas reproduire ; détails dans backlog.md)

- Deux sentinelles `EMPTY_PET` coexistent : `TeamManager.lua:31`
  (`"BattlePet-0-000000000000"`) est la vraie ; `Cursor.lua:18` porte encore l'ancienne
  `"0x0000000000000000"` (backlog.md constat 5).
- `/pbt` est enregistré deux fois (backlog.md constat 6).
- Des chaînes d'équipe importées peuvent transporter des scripts PBS au-delà de la validation
  (backlog.md constat 1).
- Artefacts morts : `modules/GUI/DescriptionEditor .lua` (fichier vide, espace dans le nom,
  absent du TOC), `modules/Tutorial.lua` (absent du TOC, dépend de `CustomTutorials-2.0` non
  livré), `modules/GUI/LockTeamsButton.lua` (`GUI:CreateLockTeamsButton` jamais appelé),
  `StaticPopupDialogs.PBT_IMPORT_TEAMS` (jamais affiché, appelle une méthode inexistante).
- `TeamManager:GetIgnoreEmptyPets` est en dur `return true` (`TeamManager.lua:300-302`) — la
  clé DB est ignorée.
