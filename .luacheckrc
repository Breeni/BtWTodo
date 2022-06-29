std = 'lua51'

quiet = 1 -- suppress report output for files without warnings

exclude_files = {
    '.luacheckrc',
    'Locales/enUS.lua',
    '.release',
    'Libs',
}

ignore = {
	'11./SLASH_.*', -- Setting an undefined (Slash handler) global variable
	'11./BINDING_.*', -- Setting an undefined (Keybinding header) global variable
	'11./BTWTODO.*', -- Setting an undefined (Constant) global variable
	'631', -- line is too long

    -- Probably Remove later
	'211', -- unused local variable
	'212', -- unused argument
    '213', -- unused loop variable
	'231', -- local variable never accessed
	'232', -- argument never accessed
    '233', -- loop variable never accessed
    '311', -- overwritten variable before use
    '314', -- overwritten field in table
    '4..', -- redefining variables
    '542', -- empty if branch
    '611', -- lines containing only whitespaces
}

globals = {
    -- BtWTodo Frames
    'BtWTodoConfigListsPanel',
    'BtWTodoConfigPanel',
    'BtWTodoConfigTodoPanel',
    'BtWTodoImportFrame',
    'BtWTodoMainFrame',
    'BtWTodoSmallFrame',
    'BtWTodoTooltipFrame',

    -- BtWTodo Mixins
    'BtWTodoAddFrameAutoCompleteListMixin',
    'BtWTodoAddFrameEditBoxMixin',
    'BtWTodoAddItemOverlayMixin',
    'BtWTodoAutoCompleteButtonMixin',
    'BtWTodoConfigCharacterItemMixin',
    'BtWTodoConfigEditorMixin',
    'BtWTodoConfigListsPanelMixin',
    'BtWTodoConfigPanelMixin',
    'BtWTodoConfigStatesInputItemMixin',
    'BtWTodoConfigStatesInputMixin',
    'BtWTodoConfigTodoItemMixin',
    'BtWTodoConfigTodoPanelMixin',
    'BtWTodoConfigWindowsPanelMixin',
    'BtWTodoDraggableViewMixin',
    'BtWTodoDragScrollBoxItemMixin',
    'BtWTodoDragScrollBoxMixin',
    'BtWTodoFrameMixin',
    'BtWTodoImportFrameMixin',
    'BtWTodoItemMixin',
    'BtWTodoMainFrameMixin',
    'BtWTodoRowMixin',
    'BtWTodoScrollRowMixin',
    'BtWTodoStateProviderDropDownMixin',
    'BtWTodoTooltipFrameMixin',
    'BtWTodoTooltipRowMixin',
    'BtWTodoViewMixin',

    -- BtWTodo Functions

    -- BtWTodo Saved Variables
    'BtWTodoAuthorization',
    'BtWTodoCache',
    'BtWTodoCategories',
    'BtWTodoCharacters',
    'BtWTodoData',
    'BtWTodoDataBroker',
    'BtWTodoLists',
    'BtWTodoWindows',

    -- FrameXML Misc
    'ColorPickerFrame',
    'SlashCmdList',
    'StaticPopupDialogs',
    'UISpecialFrames',
}
new_read_globals = {
    -- Addon Globals
    'ChatThrottleLib.SendAddonMessage',
    'ElvUI',
    'GetMinimapShape',
    'LibStub',
    'OneRingLib',

    --
    'Enum',

    -- Deprecated API Functions
    'IsQuestFlaggedCompleted',

    -- API Functions
    'bit.band',
    'bit.bor',
    'bit.bxor',
    'bit.lshift',
    'bit.rshift',
    'C_AzeriteEmpoweredItem.GetAllTierInfo',
    'C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem',
    'C_AzeriteEmpoweredItem.IsPowerSelected',
    'C_AzeriteEssence.ActivateEssence',
    'C_AzeriteEssence.GetEssenceHyperlink',
    'C_AzeriteEssence.GetEssenceInfo',
    'C_AzeriteEssence.GetEssences',
    'C_AzeriteEssence.GetMilestoneEssence',
    'C_AzeriteEssence.GetMilestoneInfo',
    'C_AzeriteEssence.UnlockMilestone',
    'C_Calendar.GetEventIndexInfo',
    'C_Calendar.GetHolidayInfo',
    'C_Calendar.OpenCalendar',
    'C_CampaignInfo.GetAvailableCampaigns',
    'C_CampaignInfo.GetCampaignChapterInfo',
    'C_CampaignInfo.GetCampaignID',
    'C_CampaignInfo.GetCampaignInfo',
    'C_CampaignInfo.GetChapterIDs',
    'C_CampaignInfo.GetState',
    'C_CampaignInfo.IsCampaignQuest',
    'C_ChallengeMode.GetAffixInfo',
    'C_ChallengeMode.GetDungeonScoreRarityColor',
    'C_ChallengeMode.GetMapUIInfo',
    'C_ChallengeMode.GetOverallDungeonScore',
    'C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor',
    'C_ChatInfo.RegisterAddonMessagePrefix',
    'C_ClassColor.GetClassColor',
    'C_CovenantCallings.RequestCallings',
    'C_Covenants.GetActiveCovenantID',
    'C_Covenants.GetCovenantData',
    'C_Covenants.GetCovenantIDs',
    'C_CreatureInfo.GetClassInfo',
    'C_CreatureInfo.GetFactionInfo',
    'C_CreatureInfo.GetRaceInfo',
    'C_CurrencyInfo.GetCurrencyInfo',
    'C_CurrencyInfo.GetCurrencyListLink',
    'C_CurrencyInfo.GetCurrencyListSize',
    'C_DateAndTime.CompareCalendarTime',
    'C_DateAndTime.GetCurrentCalendarTime',
    'C_DateAndTime.GetSecondsUntilDailyReset',
    'C_DateAndTime.GetSecondsUntilWeeklyReset',
    'C_EncounterJournal.IsEncounterComplete',
    'C_EquipmentSet.GetEquipmentSetID',
    'C_EquipmentSet.GetEquipmentSetIDs',
    'C_EquipmentSet.GetEquipmentSetInfo',
    'C_EquipmentSet.GetIgnoredSlots',
    'C_EquipmentSet.GetItemIDs',
    'C_EquipmentSet.GetItemLocations',
    'C_EquipmentSet.ModifyEquipmentSet',
    'C_EquipmentSet.PickupEquipmentSet',
    'C_EquipmentSet.SaveEquipmentSet',
    'C_Garrison.GetCurrentCypherEquipmentLevel',
    'C_Garrison.GetMaxCypherEquipmentLevel',
    'C_Garrison.GetCyphersToNextEquipmentLevel',
    'C_Item.GetItemLink',
    'C_Map.GetAreaInfo',
    'C_Map.GetBestMapForUnit',
    'C_MountJournal.GetDisplayedMountInfo',
    'C_MountJournal.GetMountInfoByID',
    'C_MountJournal.GetNumDisplayedMounts',
    'C_MountJournal.Pickup',
    'C_MythicPlus.GetCurrentAffixes',
    'C_MythicPlus.GetCurrentSeason',
    'C_MythicPlus.GetOwnedKeystoneChallengeMapID',
    'C_MythicPlus.GetOwnedKeystoneLevel',
    'C_MythicPlus.GetRewardLevelForDifficultyLevel',
    'C_MythicPlus.GetRunHistory',
    'C_MythicPlus.GetSeasonBestAffixScoreInfoForMap',
    'C_MythicPlus.RequestMapInfo',
    'C_PetJournal.GetPetInfoByPetID',
    'C_PetJournal.PickupPet',
    'C_QuestLine.GetQuestLineQuests',
    'C_QuestLine.IsComplete',
    'C_QuestLog.GetAllCompletedQuestIDs',
    'C_QuestLog.GetInfo',
    'C_QuestLog.GetLogIndexForQuestID',
    'C_QuestLog.GetNumQuestLogEntries',
    'C_QuestLog.GetQuestObjectives',
    'C_QuestLog.IsComplete',
    'C_QuestLog.IsLegendaryQuest',
    'C_QuestLog.IsOnQuest',
    'C_QuestLog.IsQuestCalling',
    'C_QuestLog.IsQuestFlaggedCompleted',
    'C_QuestLog.IsRepeatableQuest',
    'C_RaidLocks.IsEncounterComplete',
    'C_Reputation.GetFactionParagonInfo',
    'C_Soulbinds.ActivateSoulbind',
    'C_Soulbinds.GetActiveSoulbindID',
    'C_Soulbinds.GetNode',
    'C_Soulbinds.GetSoulbindData',
    'C_Soulbinds.SelectNode',
    'C_SpecializationInfo.GetAllSelectedPvpTalentIDs',
    'C_SpecializationInfo.GetPvpTalentSlotInfo',
    'C_SpecializationInfo.GetPvpTalentUnlockLevel',
    'C_TaskQuest.GetQuestsForPlayerByMapID',
    'C_TaskQuest.GetQuestTimeLeftSeconds',
    'C_Timer.After',
    'C_UIWidgetManager.GetAllWidgetsBySetID',
    'C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo',
    'C_VignetteInfo.GetVignetteInfo',
    'C_VignetteInfo.GetVignettes',
    'C_WeeklyRewards.GetActivities',
    'C_WeeklyRewards.GetActivityEncounterInfo',
    'ClearCursor',
    'CreateFrame',
    'CreateMacro',
    'CursorHasItem',
    'date',
    'EditMacro',
    'EJ_GetEncounterInfo',
    'FindBaseSpellByID',
    'format',
    'GetAchievementCriteriaInfoByID',
    'GetActionInfo',
    'GetActionText',
    'GetActionTexture',
    'GetAddOnInfo',
    'GetAddOnMetadata',
    'GetAverageItemLevel',
    'GetBuildInfo',
    'GetClassInfo',
    'GetContainerFreeSlots',
    'GetContainerItemInfo',
    'GetContainerItemInfo',
    'GetContainerItemLink',
    'GetContainerNumFreeSlots',
    'GetContainerNumSlots',
    'GetCurrentRegion',
    'GetCursorInfo',
    'GetCursorPosition',
    'GetDifficultyInfo',
    'geterrorhandler',
    'GetExpansionLevel',
    'GetFactionInfo',
    'GetFactionInfoByID',
    'GetFlyoutInfo',
    'GetFriendshipReputation',
    'GetInstanceInfo',
    'GetInventoryItemID',
    'GetInventoryItemLink',
    'GetInventorySlotInfo',
    'GetItemCount',
    'GetItemFamily',
    'GetItemGem',
    'GetItemInfo',
    'GetItemInfoInstant',
    'GetItemQualityColor',
    'GetItemUniqueness',
    'GetLocale',
    'GetMacroBody',
    'GetMacroIndexByName',
    'GetMacroInfo',
    'GetMoney',
    'GetMouseFocus',
    'GetNumClasses',
    'GetNumFactions',
    'GetNumMacros',
    'GetNumSavedInstances',
    'GetNumSpecializations',
    'GetNumSpecializationsForClassID',
    'GetNumSpellTabs',
    'GetPersonalRatedInfo',
    'GetPlayerAuraBySpellID',
    'GetPvpTalentInfoByID',
    'GetPvpTalentLink',
    'GetQuestObjectiveInfo',
    'GetRealmName',
    'GetRealZoneText',
    'GetSavedInstanceChatLink',
    'GetSavedInstanceInfo',
    'GetServerTime',
    'GetSpecialization',
    'GetSpecializationInfo',
    'GetSpecializationInfoByID',
    'GetSpecializationInfoForClassID',
    'GetSpecializationRole',
    'GetSpecializationRoleByID',
    'GetSpellBookItemInfo',
    'GetSpellInfo',
    'GetSpellTabInfo',
    'GetSubZoneText',
    'GetTalentInfo',
    'GetTalentInfoByID',
    'GetTalentInfoBySpecialization',
    'GetTalentLink',
    'GetTalentTierInfo',
    'GetTime',
    'GetVoidItemHyperlinkString',
    'GetVoidItemInfo',
    'gmatch',
    'gsub',
    'hooksecurefunc',
    'InCombatLockdown',
    'IsAltKeyDown',
    'IsControlKeyDown',
    'IsEncounterInProgress',
    'IsEquippableItem',
    'IsInGroup',
    'IsInGuild',
    'IsInRaid',
    'IsInventoryItemLocked',
    'IsLeftShiftKeyDown',
    'IsModifiedClick',
    'IsModifierKeyDown',
    'IsPlayerMoving',
    'IsResting',
    'IsRightShiftKeyDown',
    'IsShiftKeyDown',
    'IsSpellKnown',
    'LearnPvpTalent',
    'LearnTalent',
    'max',
    'min',
    'mod',
    'MouseIsOver',
    'PickupAction',
    'PickupContainerItem',
    'PickupInventoryItem',
    'PickupItem',
    'PickupMacro',
    'PickupPetSpell',
    'PickupPvpTalent',
    'PickupSpell',
    'PickupSpellBookItem',
    'PlaceAction',
    'PlaySound',
    'SetCursor',
    'SetSpecialization',
    'sort',
    'strbyte',
    'strfind',
    'strlen',
    'strlenutf8',
    'strlower',
    'strmatch',
    'strrep',
    'strsplit',
    'strsub',
    'strtrim',
    'table.wipe',
    'time',
    'tinsert',
    'tremove',
    'UnitAura',
    'UnitCastingInfo',
    'UnitClass',
    'UnitFullName',
    'UnitGUID',
    'UnitIsDead',
    'UnitLevel',
    'UnitName',
    'UnitOnTaxi',
    'UnitRace',
    'UnitSex',
    'wipe',

    -- Global Strings
    'ARENA_BATTLES_2V2',
    'ARENA_BATTLES_3V3',
    'ARENA',
    'BAG_FILTER_EQUIPMENT',
    'BATTLEGROUNDS',
    'CONTINUE',
    'COVENANT_PREVIEW_SOULBINDS',
    'CYPHER_EQUIPMENT_LEVEL_TOOLTIP',
    'DAILY_QUESTS_RESET',
    'DELETE',
    'DUNGEONS',
    'DURABILITY_TEMPLATE',
    'EFFECTS_LABEL',
    'EQUIPMENT_SETS',
    'ERR_ITEM_UNIQUE_EQUIPPABLE',
    'ERR_LEARN_ABILITY_S',
    'ERR_LEARN_PASSIVE_S',
    'ERR_LEARN_SPELL_S',
    'ERR_SPELL_UNLEARNED_S',
    'FACTION_ALLIANCE',
    'FACTION_HORDE',
    'GOAL_COMPLETED',
    'ITEM_ARTIFACT_VIEWABLE',
    'ITEM_AZERITE_EMPOWERED_VIEWABLE',
    'ITEM_AZERITE_ESSENCES_VIEWABLE',
    'ITEM_CREATED_BY',
    'ITEM_SET_BONUS',
    'ITEM_SOCKETABLE',
    'ITEM_UNSELLABLE',
    'LOCALE_TEXT_LABEL',
    'MYTHIC_DUNGEONS',
    'NAME',
    'NEW',
    'NO',
    'NONE',
    'OTHER',
    'PAPERDOLL_NEWEQUIPMENTSET',
    'PVP_RATED_BATTLEGROUNDS',
    'PVP_TALENTS',
    'PVP',
    'RAIDS',
    'SCENARIOS',
    'SELL_PRICE',
    'SPECIALIZATION',
    'TALENT_SPEC_ACTIVATE',
    'TALENTS',
    'UPDATE',
    'VIDEO_OPTIONS_ENABLED',
    'WORLD',
    'YES',

	-- FrameXML Functions
    'BackdropTemplateMixin.OnBackdropLoaded',
    'C_AzeriteEssence.GetMilestoneSpell',
    'ChatFrame_AddMessageEventFilter',
    'ChatFrame_RemoveMessageEventFilter',
    'ChatEdit_TryInsertChatLink',
    'CloseDropDownMenus',
    'CopyTable',
    'CreateAndInitFromMixin',
    'CreateColor',
    'CreateDataProvider',
    'CreateFramePool',
    'CreateFromMixins',
    'CreateScrollBoxListLinearView',
    'CreateTexturePool',
    'DifficultyUtil.GetDifficultyName',
    'EditBox_ClearFocus',
    'EquipmentManager_UnpackLocation',
    'FindSpellOverrideByID',
    'FramePool_HideAndClearAnchors',
    'GameTooltip_Hide',
    'GetFactionColor',
    'GetInventoryItemsForSlot',
    'GetMoneyString',
    'GetSpellCooldown',
    'HybridScrollFrame_CreateButtons',
    'HybridScrollFrame_GetOffset',
    'HybridScrollFrame_Update',
    'InterfaceOptions_AddCategory',
    'InterfaceOptionsFrame_OpenToCategory',
    'InterfaceOptionsFrame_Show',
    'ItemLocation.CreateEmpty',
    'ItemLocation.CreateFromBagAndSlot',
    'ItemLocation.CreateFromEquipmentSlot',
    'MacroFrame_Update',
    'Mixin',
    'PanelTemplates_GetSelectedTab',
    'PanelTemplates_SetNumTabs',
    'PanelTemplates_SetTab',
    'PanelTemplates_UpdateTabs',
    'PixelUtil.SetHeight',
    'PixelUtil.SetPoint',
    'QuestEventListener.AddCallback',
    'QuestUtils_GetQuestName',
    'RegionUtil.CalculateAngleBetween',
    'RegisterStateDriver',
    'ScrollUtil.InitScrollBoxListWithScrollBar',
    'SecondsToTime',
    'SetItemButtonQuality',
    'SetItemButtonTexture',
    'SharedTooltip_SetBackdropStyle',
    'StaticPopup_Hide',
    'StaticPopup_Show',
    'StaticPopup_Visible',
    'tCompare',
    'tContains',
    'tFilter',
    'tInvert',
    'ToggleDropDownMenu',
    'UIDropDownMenu_AddButton',
    'UIDropDownMenu_AddSeparator',
    'UIDropDownMenu_CreateInfo',
    'UIDropDownMenu_DisableDropDown',
    'UIDropDownMenu_EnableDropDown',
    'UIDropDownMenu_Initialize',
    'UIDropDownMenu_JustifyText',
    'UIDropDownMenu_SetSelectedValue',
    'UIDropDownMenu_SetText',
    'UIDropDownMenu_SetWidth',
    'UIErrorsFrame',
    'WeeklyRewards_ShowUI',

    -- FrameXML Frames
    'BankFrame',
    'GameTooltip',
    'IconIntroTracker',
    'InterfaceOptionsFrame',
    'ItemRefTooltip',
    'MacroFrame',
    'Minimap',
    'UIErrorsFrame',
    'UIParent',

    -- FrameXML Constants
	'ARTIFACT_GOLD_COLOR',
	'COMMON_GRAY_COLOR',
	'EPIC_PURPLE_COLOR',
	'HEIRLOOM_BLUE_COLOR',
	'LEGENDARY_ORANGE_COLOR',
	'RARE_BLUE_COLOR',
	'UNCOMMON_GREEN_COLOR',
    'ARTIFACT_GOLD_COLOR',
    'BACKPACK_CONTAINER',
    'BANK_CONTAINER',
    'GAME_TOOLTIP_BACKDROP_STYLE_AZERITE_ITEM',
    'INVSLOT_BODY',
    'INVSLOT_FIRST_EQUIPPED',
    'INVSLOT_LAST_EQUIPPED',
    'INVSLOT_NECK',
    'INVSLOT_TABARD',
    'ITEM_INVENTORY_BAG_BIT_OFFSET',
    'ITEM_INVENTORY_BANK_BAG_OFFSET',
    'ITEM_INVENTORY_LOCATION_BAG',
    'ITEM_INVENTORY_LOCATION_BAGS',
    'ITEM_INVENTORY_LOCATION_BANK',
    'ITEM_INVENTORY_LOCATION_PLAYER',
    'LE_PARTY_CATEGORY_HOME',
    'LE_PARTY_CATEGORY_INSTANCE',
    'LOCALIZED_CLASS_NAMES_MALE',
    'MAX_ACCOUNT_MACROS',
    'MAX_CHARACTER_MACROS',
    'MAX_TALENT_TIERS',
    'NORMAL_FONT_COLOR',
    'NUM_BAG_SLOTS',
    'NUM_BANKBAGSLOTS',
    'ScrollBoxConstants.AlignNearest',
    'SOUNDKIT',
    'STATICPOPUP_NUMDIALOGS',

    -- FrameXML Mixins
    'ScrollBoxListMixin',
}