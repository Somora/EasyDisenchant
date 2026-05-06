EasyDisenchant = {}
local addon = EasyDisenchant
local addonName = ...
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

BINDING_NAME_EASYDISENCHANT_TOGGLE_WINDOW = "Toggle Window"
BINDING_NAME_EASYDISENCHANT_TOGGLE_BLACKLIST = "Toggle Blacklist"
BINDING_NAME_EASYDISENCHANT_DISENCHANT_SELECTED = "Use Selected Action"
BINDING_NAME_EASYDISENCHANT_TOGGLE_ALL = "Toggle All Windows"

local frame = CreateFrame("Frame")
addon.frame = frame

local function ResolveSpellName(spellID, fallbackName)
    if C_Spell and C_Spell.GetSpellName then
        local spellName = C_Spell.GetSpellName(spellID)
        if spellName and spellName ~= "" then
            return spellName
        end
    end

    if GetSpellInfo then
        local spellName = GetSpellInfo(spellID)
        if spellName and spellName ~= "" then
            return spellName
        end
    end

    return fallbackName
end

addon.defaults = {
    minimap = {
        hide = false,
        minimapPos = 220,
    },
    windows = {
        main = nil,
        blacklist = nil,
    },
    filters = {
        rarity = "ALL",
        minItemLevel = 1,
        maxItemLevel = 9999,
        bindType = "ALL",
        search = "",
    },
    blacklist = {},
    selectedAction = "DISENCHANT",
    selectedItem = nil,
    lockInCombat = true,
}

addon.state = {
    items = {},
    filteredOut = {},
    blacklistedCount = 0,
    filteredReasonCounts = {},
    selectedKey = nil,
    mainScrollOffset = 0,
    blacklistScrollOffset = 0,
}

local BAG_IDS = {}
for bag = 0, NUM_BAG_SLOTS do
    BAG_IDS[#BAG_IDS + 1] = bag
end

local ACTIONS = {
    DISENCHANT = {
        label = "Disenchant",
        fallbackSpell = ResolveSpellName(13262, "Disenchant"),
        canUseItem = function(item)
            if item.classID == Enum.ItemClass.Armor or item.classID == Enum.ItemClass.Weapon then
                return true
            end

            if item.classID == Enum.ItemClass.Profession then
                return true
            end

            return item.equipLoc == "INVTYPE_PROFESSION_TOOL" or item.equipLoc == "INVTYPE_PROFESSION_GEAR"
        end,
    },
    MILL = {
        label = "Mill",
        fallbackSpell = ResolveSpellName(51005, "Milling"),
        canUseItem = function(item)
            return item.classID == Enum.ItemClass.Tradegoods and item.subclassID == 9
        end,
    },
    PROSPECT = {
        label = "Prospect",
        fallbackSpell = ResolveSpellName(31252, "Prospecting"),
        canUseItem = function(item)
            return item.classID == Enum.ItemClass.Tradegoods and item.subclassID == 7
        end,
    },
}

addon.actions = ACTIONS

local function DeepCopy(source)
    local result = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = DeepCopy(value)
        else
            result[key] = value
        end
    end
    return result
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = DeepCopy(value)
            else
                MergeDefaults(target[key], value)
            end
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function GetSpellToCast(actionKey)
    local action = ACTIONS[actionKey]
    return action and action.fallbackSpell or nil
end

function addon:GetSpellToCast(actionKey)
    return GetSpellToCast(actionKey)
end

local FILTER_REASON_LABELS = {
    RARITY = "Rarity",
    ITEM_LEVEL = "iLvl",
    BIND = "Bind",
    SEARCH = "Search",
    BLACKLIST = "Blacklist",
}

function addon.FormatMoneyParts(value)
    local gold = floor(value / (COPPER_PER_SILVER * SILVER_PER_GOLD))
    local silver = floor((value % (COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
    local copper = value % COPPER_PER_SILVER
    return gold, silver, copper
end

local function GetBindTypeText(bindType)
    if bindType == Enum.ItemBind.OnEquip then
        return "BoE"
    elseif bindType == Enum.ItemBind.OnAcquire or bindType == Enum.ItemBind.Quest then
        return "BoP"
    elseif bindType == Enum.ItemBind.ToWoWAccount or bindType == Enum.ItemBind.ToBnetAccount or bindType == Enum.ItemBind.ToBnetAccountUntilEquipped then
        return "Warband"
    end
    return ""
end

local function IsWarbandItem(location)
    if C_Item and C_Item.IsBoundToAccountUntilEquip and C_Item.IsBoundToAccountUntilEquip(location) then
        return true
    end
    if C_Item and C_Item.IsBoundToAccount and C_Item.IsBoundToAccount(location) then
        return true
    end
    return false
end

local function BuildItemData(bagID, slotID)
    local location = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if not C_Item.DoesItemExist(location) then
        return nil
    end

    local itemID = C_Item.GetItemID(location)
    if not itemID then
        return nil
    end

    local itemLink = C_Item.GetItemLink(location)
    if not itemLink then
        return nil
    end

    local itemName, _, itemQuality, itemLevel, _, _, _, _, _, itemTexture, vendorPrice, classID, subclassID, bindType = C_Item.GetItemInfo(itemLink)
    if not itemName then
        return nil
    end

    local isWarband = IsWarbandItem(location)
    local _, _, _, itemEquipLoc = GetItemInfoInstant(itemLink)

    return {
        key = bagID .. ":" .. slotID,
        bagID = bagID,
        slotID = slotID,
        location = location,
        link = itemLink,
        itemID = itemID,
        name = itemName or UNKNOWN,
        quality = itemQuality or 0,
        icon = itemTexture or 134400,
        itemLevel = C_Item.GetCurrentItemLevel(location) or itemLevel or 0,
        classID = classID,
        subclassID = subclassID,
        equipLoc = itemEquipLoc,
        vendorPrice = vendorPrice or 0,
        bindType = bindType,
        bindTypeText = isWarband and "Warband" or GetBindTypeText(bindType),
        isWarband = isWarband,
    }
end

local function MatchesSearch(item, text)
    if text == "" then
        return true
    end
    return string.find(string.lower(item.name or ""), string.lower(text), 1, true) ~= nil
end

local function MatchesFilters(item)
    local filters = EasyDisenchantDB.filters
    if EasyDisenchantDB.blacklist[item.itemID] then
        return false, "BLACKLIST"
    end

    local action = ACTIONS[EasyDisenchantDB.selectedAction]
    if not action or not action.canUseItem(item) then
        return false, "ACTION"
    end

    if filters.rarity == "ALL" and EasyDisenchantDB.selectedAction == "DISENCHANT" and item.quality < 2 then
        return false, "RARITY"
    end
    if filters.rarity ~= "ALL" and item.quality ~= filters.rarity then
        return false, "RARITY"
    end
    if item.itemLevel < filters.minItemLevel or item.itemLevel > filters.maxItemLevel then
        return false, "ITEM_LEVEL"
    end
    if filters.bindType == "BOE" and item.bindType ~= Enum.ItemBind.OnEquip then
        return false, "BIND"
    end
    if filters.bindType == "BOP" and item.bindType ~= Enum.ItemBind.OnAcquire and item.bindType ~= Enum.ItemBind.Quest then
        return false, "BIND"
    end
    if filters.bindType == "WARBAND" and not item.isWarband then
        return false, "BIND"
    end
    if not MatchesSearch(item, filters.search or "") then
        return false, "SEARCH"
    end
    return true, nil
end

local function IsActionCandidate(item)
    local action = ACTIONS[EasyDisenchantDB.selectedAction]
    return action and action.canUseItem(item) or false
end

local function ShouldHideFilteredItem(item, reason)
    if EasyDisenchantDB.selectedAction == "DISENCHANT" and reason == "RARITY" and (item.quality or 0) < 2 then
        return true
    end
    return false
end

function addon:RefreshItems()
    wipe(self.state.items)
    wipe(self.state.filteredOut)
    self.state.blacklistedCount = 0
    wipe(self.state.filteredReasonCounts)

    for _, bagID in ipairs(BAG_IDS) do
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            local item = BuildItemData(bagID, slotID)
            if item then
                if IsActionCandidate(item) then
                    local ok, reason = MatchesFilters(item)
                    if ok then
                        self.state.items[#self.state.items + 1] = item
                    elseif not ShouldHideFilteredItem(item, reason) then
                        item.filteredReason = FILTER_REASON_LABELS[reason] or reason
                        self.state.filteredOut[#self.state.filteredOut + 1] = item
                        local label = FILTER_REASON_LABELS[reason] or reason
                        self.state.filteredReasonCounts[label] = (self.state.filteredReasonCounts[label] or 0) + 1
                        if reason == "BLACKLIST" then
                            self.state.blacklistedCount = (self.state.blacklistedCount or 0) + 1
                        end
                    else
                        item.filteredReason = nil
                    end
                end
            end
        end
    end

    table.sort(self.state.items, function(left, right)
        if left.quality ~= right.quality then
            return left.quality > right.quality
        end
        if left.itemLevel ~= right.itemLevel then
            return left.itemLevel > right.itemLevel
        end
        return left.name < right.name
    end)

    table.sort(self.state.filteredOut, function(left, right)
        return left.name < right.name
    end)

    self.state.mainScrollOffset = math.min(self.state.mainScrollOffset or 0, math.max(0, #self.state.items - 10))

    if self.state.selectedKey then
        local stillExists = false
        for _, item in ipairs(self.state.items) do
            if item.key == self.state.selectedKey then
                stillExists = true
                break
            end
        end
        if not stillExists then
            for _, item in ipairs(self.state.filteredOut) do
                if item.key == self.state.selectedKey then
                    stillExists = true
                    break
                end
            end
        end
        if not stillExists then
            self.state.selectedKey = nil
        end
    end

    if not self.state.selectedKey and self.state.items[1] then
        self.state.selectedKey = self.state.items[1].key
    end

    if self.RefreshUI then
        self:RefreshUI()
    end
end

function addon:GetSelectedItem()
    for _, item in ipairs(self.state.items) do
        if item.key == self.state.selectedKey then
            return item
        end
    end
    return nil
end

function addon:SetSelectedItem(itemKey)
    self.state.selectedKey = itemKey
    if self.RefreshUI then
        self:RefreshUI()
    end
end

function addon:ShowMessage(text)
    UIErrorsFrame:AddMessage("|cff4cc9f0EasyDisenchant:|r " .. text, 1.0, 0.82, 0)
end

function addon:GetExcludedBreakdownText(limit)
    local parts = {}
    for reason, count in pairs(self.state.filteredReasonCounts or {}) do
        if count and count > 0 then
            parts[#parts + 1] = {
                reason = reason,
                count = count,
            }
        end
    end

    table.sort(parts, function(left, right)
        if left.count ~= right.count then
            return left.count > right.count
        end
        return left.reason < right.reason
    end)

    local shown = {}
    local maxShown = math.min(limit or #parts, #parts)
    for index = 1, maxShown do
        local part = parts[index]
        shown[#shown + 1] = string.format("%d by %s", part.count, part.reason)
    end

    if #parts > maxShown then
        local remaining = 0
        for index = maxShown + 1, #parts do
            remaining = remaining + parts[index].count
        end
        shown[#shown + 1] = string.format("%d other", remaining)
    end

    return table.concat(shown, ", ")
end

function addon:IsLockedByCombat()
    return InCombatLockdown() and EasyDisenchantDB.lockInCombat
end

function addon:BlacklistItem(item)
    if not item then
        return
    end
    EasyDisenchantDB.blacklist[item.itemID] = item.name
    if self.state.selectedKey == item.key then
        self.state.selectedKey = nil
    end
    self:RefreshItems()
end

function addon:RemoveFromBlacklist(itemID)
    EasyDisenchantDB.blacklist[itemID] = nil
    self:RefreshItems()
end

function addon:ResetTransientFilters()
    EasyDisenchantDB.filters.rarity = "ALL"
    EasyDisenchantDB.filters.bindType = "ALL"
    if self.RefreshFilterSelectors then
        self:RefreshFilterSelectors()
    end
    self:RefreshItems()
end

function addon:ToggleWindow()
    if not self.mainFrame then
        return
    end
    if self.mainFrame:IsShown() then
        self:ResetTransientFilters()
        if self.blacklistFrame and self.blacklistFrame:IsShown() then
            self.blacklistFrame:Hide()
        end
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        if self.RefreshFilterSelectors then
            self:RefreshFilterSelectors()
        end
        self:RefreshItems()
    end
end

function addon:ToggleBlacklistWindow()
    if not self.blacklistFrame then
        return
    end
    if self.blacklistFrame:IsShown() then
        self.blacklistFrame:Hide()
    else
        self.blacklistFrame:Show()
        self:RefreshBlacklistUI()
    end
end

function addon:ToggleAllWindows()
    self:ToggleWindow()
    self:ToggleBlacklistWindow()
end

function addon:GetBlacklistEntries()
    local entries = {}
    for itemID, label in pairs(EasyDisenchantDB.blacklist) do
        entries[#entries + 1] = { itemID = itemID, label = label }
    end
    table.sort(entries, function(left, right)
        return tostring(left.label) < tostring(right.label)
    end)
    return entries
end

function addon:SetMainScrollOffset(offset)
    self.state.mainScrollOffset = math.max(0, floor(offset or 0))
    if self.RefreshUI then
        self:RefreshUI()
    end
end

function addon:SetBlacklistScrollOffset(offset)
    self.state.blacklistScrollOffset = math.max(0, floor(offset or 0))
    if self.RefreshBlacklistUI then
        self:RefreshBlacklistUI()
    end
end

function addon:InitializeDatabase()
    if type(EasyDisenchantDB) ~= "table" then
        EasyDisenchantDB = DeepCopy(self.defaults)
    else
        MergeDefaults(EasyDisenchantDB, self.defaults)
    end

    if EasyDisenchantDB.minimap.hide == nil and EasyDisenchantDB.minimap.hidden ~= nil then
        EasyDisenchantDB.minimap.hide = EasyDisenchantDB.minimap.hidden
    end

    if EasyDisenchantDB.minimap.minimapPos == nil and EasyDisenchantDB.minimap.angle ~= nil then
        EasyDisenchantDB.minimap.minimapPos = EasyDisenchantDB.minimap.angle
    end
end

function addon:RegisterMinimapLauncher()
    if self.ldbLauncher then
        return
    end

    self.ldbLauncher = LDB:NewDataObject(addonName or "EasyDisenchant", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Enchant_Disenchant",
        label = "EasyDisenchant",
        OnClick = function(_, button)
            if IsShiftKeyDown() then
                EasyDisenchantDB.minimap.hide = false
                EasyDisenchantDB.minimap.minimapPos = 220
                self:RefreshMinimapButton()
                return
            end

            if button == "RightButton" then
                self:ToggleBlacklistWindow()
            else
                self:ToggleWindow()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("EasyDisenchant")
            tooltip:AddLine("Left-click: toggle main window", 1, 1, 1)
            tooltip:AddLine("Right-click: toggle blacklist", 1, 1, 1)
            tooltip:AddLine("Shift-click: reset minimap button position", 1, 1, 1)
        end,
    })

    LDBIcon:Register("EasyDisenchant", self.ldbLauncher, EasyDisenchantDB.minimap)
end

function addon:HandleSlashCommand(message)
    local command = string.lower(strtrim(message or ""))
    if command == "help" or command == "?" then
        self:ShowMessage("Commands: /sde, /sde blacklist, /sde minimap, /sde resetpos")
        return
    end
    if command == "blacklist" then
        self:ToggleBlacklistWindow()
        return
    end
    if command == "minimap" then
        EasyDisenchantDB.minimap.hide = false
        EasyDisenchantDB.minimap.minimapPos = EasyDisenchantDB.minimap.minimapPos or 220
        if self.RefreshMinimapButton then
            self:RefreshMinimapButton()
        end
        self:ShowMessage("Minimap button restored.")
        return
    end
    if command == "resetpos" then
        if self.ResetWindowPositions then
            self:ResetWindowPositions()
        end
        self:ShowMessage("Window positions reset.")
        return
    end
    self:ToggleWindow()
end

function addon:RegisterSlashCommands()
    SLASH_EASYDISENCHANT1 = "/easydisenchant"
    SLASH_EASYDISENCHANT2 = "/ed"
    SLASH_EASYDISENCHANT3 = "/sde"
    SlashCmdList.EASYDISENCHANT = function(message)
        addon:HandleSlashCommand(message)
    end
end

function addon:RegisterCompartment()
end

frame:SetScript("OnEvent", function(_, event, ...)
    if addon[event] then
        addon[event](addon, ...)
    end
end)

function addon:ADDON_LOADED(loadedAddon)
    if loadedAddon ~= "EasyDisenchant" then
        return
    end
    self:InitializeDatabase()
    self:RegisterSlashCommands()
    self:RegisterCompartment()
    if self.InitializeUI then
        self:InitializeUI()
    end
    self:RegisterMinimapLauncher()
    self:RefreshItems()
end

function addon:BAG_UPDATE_DELAYED()
    self:RefreshItems()
end

function addon:PLAYER_REGEN_DISABLED()
    if self.RefreshCombatState then
        self:RefreshCombatState()
    end
end

function addon:PLAYER_REGEN_ENABLED()
    if self.RefreshCombatState then
        self:RefreshCombatState()
    end
end

function addon:SKILL_LINES_CHANGED()
    self:RefreshItems()
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("SKILL_LINES_CHANGED")

function EasyDisenchant_ToggleWindow()
    addon:ToggleWindow()
end

function EasyDisenchant_ToggleBlacklist()
    addon:ToggleBlacklistWindow()
end

function EasyDisenchant_DispatchSelected()
    addon:ShowMessage("Use the EasyDisenchant window buttons to perform actions.")
end

function EasyDisenchant_ToggleAll()
    addon:ToggleAllWindows()
end

function EasyDisenchant_AddonCompartmentClick(_, buttonName)
    if IsShiftKeyDown() then
        EasyDisenchantDB.minimap.hide = not EasyDisenchantDB.minimap.hide
        addon:RefreshMinimapButton()
        return
    end

    if buttonName == "RightButton" then
        addon:ToggleBlacklistWindow()
    else
        addon:ToggleWindow()
    end
end

function EasyDisenchant_AddonCompartmentEnter(_, menuButtonFrame)
    if not menuButtonFrame then
        return
    end

    if MenuUtil and MenuUtil.ShowTooltip then
        MenuUtil.ShowTooltip(menuButtonFrame, function(tooltip)
            tooltip:AddLine("EasyDisenchant")
            tooltip:AddLine("Left-click: toggle main window", 1, 1, 1)
            tooltip:AddLine("Right-click: toggle blacklist", 1, 1, 1)
            tooltip:AddLine("Shift-click: reset minimap button position", 1, 1, 1)
        end)
    end
end

function EasyDisenchant_AddonCompartmentLeave(_, menuButtonFrame)
    if MenuUtil and MenuUtil.HideTooltip and menuButtonFrame then
        MenuUtil.HideTooltip(menuButtonFrame)
    end
end
