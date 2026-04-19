local addon = EasyDisenchant

local ROW_HEIGHT = 24
local VISIBLE_ROWS = 10
local BLACKLIST_ROWS = 10
local FILTER_GAP = 20
local FILTER_LABEL_Y = -14
local FILTER_CONTROL_Y = -34
local NAME_WIDTH = 280
local ILVL_WIDTH = 42
local MONEY_WIDTH = 28
local MONEY_GAP = 2
local ACTION_WIDTH = 24
local BLACKLIST_WIDTH = 18
local RIGHT_PADDING = 4

local function CreateBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 10, right = 10, top = 10, bottom = 10 },
    })
    frame:SetBackdropColor(0.09, 0.08, 0.06, 0.98)
    frame:SetBackdropBorderColor(0.7, 0.58, 0.18, 0.9)
end

local function SaveWindowPosition(key, frame)
    if not EasyDisenchantDB or not EasyDisenchantDB.windows or not frame then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    EasyDisenchantDB.windows[key] = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function RestoreWindowPosition(key, frame)
    if not EasyDisenchantDB or not EasyDisenchantDB.windows or not frame then
        return false
    end

    local saved = EasyDisenchantDB.windows[key]
    if not saved or not saved.point or not saved.relativePoint then
        return false
    end

    frame:ClearAllPoints()
    frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x or 0, saved.y or 0)
    return true
end

local function CreateInsetPanel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, height)
    panel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.03, 0.03, 0.03, 0.88)
    panel:SetBackdropBorderColor(0.35, 0.30, 0.12, 0.9)
    return panel
end

local function SetButtonState(button, enabled)
    if enabled then
        button:SetAlpha(1)
    else
        button:SetAlpha(0.45)
    end
end

local function StylePrimaryActionButton(button)
    local text = button:GetFontString()
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", 0, 0)
    end

    for _, textureKey in ipairs({ "glow", "topLine", "bottomShadow", "sideGlow", "sideGlowRight", "tint" }) do
        if button[textureKey] then
            button[textureKey]:Hide()
            button[textureKey] = nil
        end
    end
end

local function StyleRowMiniButton(button)
    local text = button:GetFontString()
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", 0, 0)
    end
end

local function ConfigureSecureActionButton(button, item, actionKey)
    if not button then
        return
    end

    button.item = item
    button.actionKey = actionKey

    if InCombatLockdown() then
        return
    end

    local spellName = addon.GetSpellToCast and addon:GetSpellToCast(actionKey)
    if item and spellName then
        local targetItem = string.format("%d %d", item.bagID, item.slotID)
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", spellName)
        button:SetAttribute("target-item", targetItem)
        button:SetAttribute("target-bag", item.bagID)
        button:SetAttribute("target-slot", item.slotID)
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell1", spellName)
        button:SetAttribute("target-item1", targetItem)
        button:SetAttribute("target-bag1", item.bagID)
        button:SetAttribute("target-slot1", item.slotID)
        button:SetAttribute("useOnKeyDown", false)
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("target-item", nil)
        button:SetAttribute("target-bag", nil)
        button:SetAttribute("target-slot", nil)
        button:SetAttribute("type1", nil)
        button:SetAttribute("spell1", nil)
        button:SetAttribute("target-item1", nil)
        button:SetAttribute("target-bag1", nil)
        button:SetAttribute("target-slot1", nil)
    end
end

local function ClearRow(row)
    row.item = nil
    row:SetAlpha(0)
    row.icon:SetTexture(nil)
    row.name:SetText("")
    row.itemLevel:SetText("")
    row.bind:SetText("")
    row.gold:SetText("")
    row.silver:SetText("")
    row.copper:SetText("")
    row.reason:SetText("")
    row.selection:Hide()
    row.actionButton:SetText("")
    ConfigureSecureActionButton(row.actionButton, nil, EasyDisenchantDB and EasyDisenchantDB.selectedAction)
end

local function GetEmptyStateText()
    local topReason, topCount
    for reason, count in pairs(addon.state.filteredReasonCounts or {}) do
        if not topCount or count > topCount then
            topReason = reason
            topCount = count
        end
    end

    if topReason and topCount and topCount > 0 then
        return string.format("No ready items. Most items are excluded by %s (%d).", topReason, topCount)
    end

    return "No items available for the selected action and filters."
end

local function AttachHeaderTooltip(widget, title, description)
    if not widget then
        return
    end

    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(title)
        GameTooltip:AddLine(description, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function GetActionButtonLabel()
    local labels = {
        DISENCHANT = "DE",
        MILL = "ML",
        PROSPECT = "PR",
    }
    return labels[EasyDisenchantDB and EasyDisenchantDB.selectedAction] or "Do"
end

local function GetActionIcon(actionKey)
    local action = addon.actions and addon.actions[actionKey]
    local spellName = action and action.fallbackSpell
    if spellName and C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(spellName)
        if texture then
            return texture
        end
    end

    local fallbackIcons = {
        DISENCHANT = 136244,
        MILL = 237171,
        PROSPECT = 236169,
    }
    return fallbackIcons[actionKey] or 134400
end

local function RefreshItemLevelInputs(frame)
    if not frame or not frame.minLevel or not frame.maxLevel then
        return
    end

    frame.minLevel:SetText(tostring(EasyDisenchantDB.filters.minItemLevel or 1))

    local maxValue = EasyDisenchantDB.filters.maxItemLevel or 9999
    if maxValue >= 9999 then
        frame.maxLevel:SetText("")
    else
        frame.maxLevel:SetText(tostring(maxValue))
    end
end

local function CreateMoneyColumns(parent, anchorX)
    local gold = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gold:SetPoint("RIGHT", parent, "RIGHT", anchorX, 0)
    gold:SetWidth(MONEY_WIDTH)
    gold:SetJustifyH("RIGHT")

    local silver = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    silver:SetPoint("LEFT", gold, "RIGHT", MONEY_GAP, 0)
    silver:SetWidth(MONEY_WIDTH)
    silver:SetJustifyH("RIGHT")

    local copper = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copper:SetPoint("LEFT", silver, "RIGHT", MONEY_GAP, 0)
    copper:SetWidth(MONEY_WIDTH)
    copper:SetJustifyH("RIGHT")

    return gold, silver, copper
end

local function ApplyMoneyColumns(goldText, silverText, copperText, value)
    local gold, silver, copper = addon.FormatMoneyParts(value or 0)
    goldText:SetText(string.format("%d|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t", gold))
    silverText:SetText(string.format("%d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t", silver))
    copperText:SetText(string.format("%d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t", copper))
end

local function CreateListRow(parent, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_HEIGHT)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(1, 1, 1, 0.035)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(0.26, 0.45, 0.8, 0.18)

    row.selection = row:CreateTexture(nil, "ARTWORK")
    row.selection:SetAllPoints()
    row.selection:SetColorTexture(0.28, 0.45, 0.78, 0.28)
    row.selection:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 6, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetJustifyH("LEFT")

    row.itemLevel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemLevel:SetPoint("LEFT", row.name, "RIGHT", 12, 0)
    row.itemLevel:SetWidth(ILVL_WIDTH)
    row.itemLevel:SetJustifyH("RIGHT")

    row.actionButton = CreateFrame("Button", nil, row, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    row.actionButton:SetSize(ACTION_WIDTH, 18)
    row.actionButton:SetPoint("RIGHT", row, "RIGHT", -(RIGHT_PADDING + BLACKLIST_WIDTH + 8), 0)
    row.actionButton:SetNormalFontObject("GameFontHighlightSmall")
    row.actionButton:SetHighlightFontObject("GameFontHighlightSmall")
    StyleRowMiniButton(row.actionButton)
    row.actionButton:RegisterForClicks("AnyUp")
    row.actionButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local action = addon.actions[EasyDisenchantDB.selectedAction]
        GameTooltip:AddLine(action and action.label or "Use action")
        GameTooltip:AddLine("Use the selected profession action on this item.", 1, 1, 1)
        GameTooltip:Show()
    end)
    row.actionButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.blacklistButton = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.blacklistButton:SetSize(BLACKLIST_WIDTH, BLACKLIST_WIDTH)
    row.blacklistButton:SetPoint("RIGHT", -RIGHT_PADDING, 0)
    row.blacklistButton:SetNormalTexture("Interface/Buttons/UI-GroupLoot-Pass-Up")
    row.blacklistButton:SetPushedTexture("Interface/Buttons/UI-GroupLoot-Pass-Down")
    row.blacklistButton:SetHighlightTexture("Interface/Buttons/UI-GroupLoot-Pass-Highlight")
    row.blacklistButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Blacklist item")
        GameTooltip:AddLine("Hide this item from the list.", 1, 1, 1)
        GameTooltip:Show()
    end)
    row.blacklistButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row.blacklistButton:SetScript("OnClick", function(self)
        local parentRow = self:GetParent()
        if parentRow and parentRow.item then
            addon:BlacklistItem(parentRow.item)
        end
    end)

    row.gold, row.silver, row.copper = CreateMoneyColumns(row, -(RIGHT_PADDING + BLACKLIST_WIDTH + 8 + ACTION_WIDTH + 8 + MONEY_WIDTH * 2 + MONEY_GAP * 2))

    row.bind = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.bind:SetPoint("RIGHT", row.gold, "LEFT", -10, 0)
    row.bind:SetWidth(58)
    row.bind:SetJustifyH("RIGHT")

    row.reason = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.reason:SetPoint("RIGHT", row.bind, "LEFT", 0, 0)
    row.reason:SetWidth(1)
    row.reason:SetJustifyH("RIGHT")
    row.reason:Hide()

    row:SetScript("OnEnter", function(self)
        if not self.item then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(self.item.bagID, self.item.slotID)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:SetScript("OnClick", function(self, mouseButton)
        if not self.item then
            return
        end
        if mouseButton == "LeftButton" then
            addon:SetSelectedItem(self.item.key)
        end
    end)
    return row
end

local function UpdateRow(row, item, isSelected, showReason)
    row.item = item
    if not item then
        ClearRow(row)
        return
    end

    row:SetAlpha(1)
    row.icon:SetTexture(item.icon or 134400)
    row.name:SetText(item.name or UNKNOWN)
    row.itemLevel:SetText(item.itemLevel or 0)
    row.bind:SetText(item.bindTypeText or "")
    ApplyMoneyColumns(row.gold, row.silver, row.copper, item.vendorPrice or 0)
    row.selection:SetShown(isSelected)
    row.reason:SetText("")
    row.actionButton:SetText(GetActionButtonLabel())
    ConfigureSecureActionButton(row.actionButton, item, EasyDisenchantDB.selectedAction)
    local color = ITEM_QUALITY_COLORS[item.quality or 0] or NORMAL_FONT_COLOR
    row.name:SetTextColor(color.r, color.g, color.b)
    if row.rowIndex and row.rowIndex % 2 == 0 then
        row.background:SetColorTexture(1, 1, 1, 0.055)
    else
        row.background:SetColorTexture(1, 1, 1, 0.028)
    end
end

local function ShouldShowBindColumn()
    return EasyDisenchantDB and EasyDisenchantDB.filters and EasyDisenchantDB.filters.bindType ~= "ALL"
end

local function LayoutMoneyColumns(row, showBindColumn)
    row.gold:ClearAllPoints()
    row.silver:ClearAllPoints()
    row.copper:ClearAllPoints()

    local copperRight = -(RIGHT_PADDING + BLACKLIST_WIDTH + 8 + ACTION_WIDTH + 10)
    local silverRight = copperRight - MONEY_WIDTH - MONEY_GAP
    local goldRight = silverRight - MONEY_WIDTH - MONEY_GAP

    local rightOffset = goldRight
    row.gold:SetPoint("RIGHT", row, "RIGHT", rightOffset, 0)
    row.silver:SetPoint("LEFT", row.gold, "RIGHT", MONEY_GAP, 0)
    row.copper:SetPoint("LEFT", row.silver, "RIGHT", MONEY_GAP, 0)

    row.bind:ClearAllPoints()
    row.bind:SetPoint("RIGHT", row.gold, "LEFT", showBindColumn and -14 or -6, 0)
end

local function LayoutHeaderColumns(frame, showBindColumn)
    frame.headerValue:ClearAllPoints()
    frame.headerIlvl:ClearAllPoints()
    frame.headerBind:ClearAllPoints()
    frame.headerAction:ClearAllPoints()
    frame.headerBlacklist:ClearAllPoints()
    frame.headerBlacklist:SetPoint("CENTER", frame.rows[1].blacklistButton, "CENTER", 0, 24)
    frame.headerAction:SetPoint("CENTER", frame.rows[1].actionButton, "CENTER", 0, 24)
    frame.headerIlvl:SetPoint("CENTER", frame.rows[1].itemLevel, "CENTER", 0, 24)

    if showBindColumn then
        frame.headerValue:SetPoint("CENTER", frame.rows[1].silver, "CENTER", 12, 24)
        frame.headerBind:SetPoint("RIGHT", frame.rows[1].bind, "RIGHT", 0, 24)
    else
        frame.headerValue:SetPoint("CENTER", frame.rows[1].silver, "CENTER", 12, 24)
        frame.headerBind:SetPoint("RIGHT", frame.rows[1].bind, "RIGHT", 0, 24)
    end
end

local function CreateScrollRows(parent, count, width, topOffset)
    local rows = {}
    for index = 1, count do
        local row = CreateListRow(parent, width)
        row.rowIndex = index
        if index == 1 then
            row:SetPoint("TOPLEFT", 0, topOffset)
        else
            row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, -1)
        end
        rows[index] = row
    end
    return rows
end

function addon:RefreshCombatState()
    if not self.mainFrame or not self.mainFrame.combatOverlay then
        return
    end

    local locked = self:IsLockedByCombat()
    self.mainFrame.combatOverlay:SetShown(locked)
    if locked then
        self.mainFrame.actionButton:SetAlpha(0.45)
    else
        self.mainFrame.actionButton:SetAlpha(1)
    end
end

local function CreateDropdown(frame, name, width, labelText, initialize)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(labelText)

    local dropdown = CreateFrame("Frame", name, frame, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width)
    dropdown.initializeMenu = initialize
    return label, dropdown
end

local function SetDropdownLabel(dropdown, text, value, selectedID)
    if not dropdown then
        return
    end

    local frameName = dropdown.GetName and dropdown:GetName() or nil
    if frameName then
        local textRegion = _G[frameName .. "Text"]
        if textRegion then
            textRegion:SetText(text)
        end
    end

    if value ~= nil then
        UIDropDownMenu_SetSelectedValue(dropdown, value)
    end
    if selectedID ~= nil then
        UIDropDownMenu_SetSelectedID(dropdown, selectedID)
    else
        UIDropDownMenu_SetSelectedName(dropdown, text)
    end
end

local function CreateSelector(frame, width, labelText)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(labelText)

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetSize(width, 24)
    button:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button:SetBackdropColor(0.06, 0.06, 0.05, 0.96)
    button:SetBackdropBorderColor(0.45, 0.38, 0.08, 0.95)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("LEFT", 10, 0)
    button.text:SetPoint("RIGHT", -20, 0)
    button.text:SetJustifyH("LEFT")

    if labelText == "Action" then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(16, 16)
        button.icon:SetPoint("LEFT", 8, 1)
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 6, 1)
        button.text:SetPoint("RIGHT", -20, 1)
        button.updateVisual = function(self, value)
            self.icon:SetTexture(GetActionIcon(value))
        end
    end

    button.arrow = button:CreateTexture(nil, "OVERLAY")
    button.arrow:SetTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Up")
    button.arrow:SetSize(14, 14)
    button.arrow:SetPoint("RIGHT", -6, 0)

    button.menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    button.menu:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    button.menu:SetBackdropColor(0.05, 0.05, 0.04, 0.98)
    button.menu:SetBackdropBorderColor(0.45, 0.38, 0.08, 0.95)
    button.menu:SetFrameStrata("FULLSCREEN_DIALOG")
    button.menu:Hide()

    button:SetScript("OnClick", function(self)
        if self.menu:IsShown() then
            self.menu:Hide()
        else
            self.menu:ClearAllPoints()
            self.menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            self.menu:Show()
        end
    end)

    return label, button
end

local function SetSelectorValue(selector, text, value)
    selector.value = value
    selector.text:SetText(text)
    if selector.updateVisual then
        selector:updateVisual(value)
    end
    if selector.colorizeValue then
        local color = selector.colorizeValue(value)
        selector.text:SetTextColor(color.r, color.g, color.b)
    else
        selector.text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    end
    selector.menu:Hide()
end

local function BuildSelectorMenu(selector, options, onSelect)
    selector.buttons = selector.buttons or {}
    local maxWidth = selector:GetWidth()

    for index, option in ipairs(options) do
        local row = selector.buttons[index]
        if not row then
            row = CreateFrame("Button", nil, selector.menu)
            row:SetHeight(20)
            row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 8, 0)
            row.text:SetPoint("RIGHT", -8, 0)
            row.text:SetJustifyH("LEFT")
            selector.buttons[index] = row
        end

        row:SetWidth(selector:GetWidth() - 8)
        row:ClearAllPoints()
        if index == 1 then
            row:SetPoint("TOPLEFT", 4, -4)
        else
            row:SetPoint("TOPLEFT", selector.buttons[index - 1], "BOTTOMLEFT", 0, -2)
        end
        row.text:SetText(option.text)
        if selector.colorizeValue then
            local color = selector.colorizeValue(option.value)
            row.text:SetTextColor(color.r, color.g, color.b)
        else
            row.text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        end
        row:SetScript("OnClick", function()
            SetSelectorValue(selector, option.text, option.value)
            onSelect(option)
        end)
        row:Show()
        maxWidth = math.max(maxWidth, row.text:GetStringWidth() + 20)
    end

    for index = #options + 1, #selector.buttons do
        selector.buttons[index]:Hide()
    end

    selector.menu:SetSize(maxWidth + 8, (#options * 22) + 8)
end

local function GetRarityLabel(value)
    local labels = {
        ALL = "All",
        [2] = "Uncommon",
        [3] = "Rare",
        [4] = "Epic",
    }
    return labels[value] or "All"
end

local function GetRarityColor(value)
    if value == "ALL" then
        return HIGHLIGHT_FONT_COLOR
    end

    local color = ITEM_QUALITY_COLORS[value]
    return color or HIGHLIGHT_FONT_COLOR
end

local function GetBindFilterLabel(value)
    local labels = {
        ALL = "All",
        BOE = "BoE",
        BOP = "BoP",
        WARBAND = "Warband",
    }
    return labels[value] or "All"
end

function addon:RefreshFilterSelectors()
    if not self.mainFrame then
        return
    end

    if self.mainFrame.raritySelector then
        SetSelectorValue(self.mainFrame.raritySelector, GetRarityLabel(EasyDisenchantDB.filters.rarity), EasyDisenchantDB.filters.rarity)
    end
    if self.mainFrame.bindSelector then
        SetSelectorValue(self.mainFrame.bindSelector, GetBindFilterLabel(EasyDisenchantDB.filters.bindType), EasyDisenchantDB.filters.bindType)
    end
end

function addon:HideSelectorMenus()
    if not self.mainFrame then
        return
    end

    for _, selectorKey in ipairs({ "actionSelector", "raritySelector", "bindSelector" }) do
        local selector = self.mainFrame[selectorKey]
        if selector and selector.menu then
            selector.menu:Hide()
        end
    end
end

local function ShouldShowRarityFilter()
    return EasyDisenchantDB and EasyDisenchantDB.selectedAction == "DISENCHANT"
end

local function ShouldShowBindFilterSelector()
    return EasyDisenchantDB and EasyDisenchantDB.selectedAction == "DISENCHANT"
end

local function ShouldShowItemLevelFilter()
    return EasyDisenchantDB and EasyDisenchantDB.selectedAction == "DISENCHANT"
end

local function ApplyActionButtonText()
    local action = addon.actions[EasyDisenchantDB.selectedAction]
    if addon.mainFrame and addon.mainFrame.actionButton and action then
        local selectedItem = addon.GetSelectedItem and addon:GetSelectedItem() or nil
        if selectedItem and selectedItem.filteredReason then
            addon.mainFrame.actionButton:SetText(action.label .. " anyway")
        else
            addon.mainFrame.actionButton:SetText(action.label)
        end
    end
end

function addon:RefreshMinimapButton()
    local ldbIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not ldbIcon or not EasyDisenchantDB or not EasyDisenchantDB.minimap then
        return
    end

    if EasyDisenchantDB.minimap.hide then
        ldbIcon:Hide("EasyDisenchant")
    else
        ldbIcon:Show("EasyDisenchant")
        ldbIcon:Refresh("EasyDisenchant", EasyDisenchantDB.minimap)
    end
end

function addon:RefreshBlacklistUI()
    if not self.blacklistFrame or not self.blacklistFrame.rows then
        return
    end

    local entries = self:GetBlacklistEntries()
    local maxOffset = math.max(0, #entries - BLACKLIST_ROWS)
    local offset = math.min(self.state.blacklistScrollOffset or 0, maxOffset)
    self.state.blacklistScrollOffset = offset
    for index, row in ipairs(self.blacklistFrame.rows) do
        local entry = entries[index + offset]
        if entry then
            row:Show()
            row.itemID = entry.itemID
            row.name:SetText(tostring(entry.label))
            local quality = select(3, GetItemInfo(entry.itemID))
            local color = ITEM_QUALITY_COLORS[quality or 1] or NORMAL_FONT_COLOR
            row.name:SetTextColor(color.r, color.g, color.b)
        else
            row.itemID = nil
            row:Hide()
        end
    end

    if self.blacklistFrame.scrollBar then
        self.blacklistFrame._updatingScroll = true
        self.blacklistFrame.scrollBar:SetMinMaxValues(0, maxOffset)
        self.blacklistFrame.scrollBar:SetValue(math.min(offset, maxOffset))
        self.blacklistFrame._updatingScroll = false
        self.blacklistFrame.scrollBar:SetShown(maxOffset > 0)
    end
end

function addon:RefreshUI()
    if not self.mainFrame or not self.mainFrame.rows then
        return
    end

    local selectedItem = self:GetSelectedItem()
    local showBindColumn = ShouldShowBindColumn()
    local showRarityFilter = ShouldShowRarityFilter()
    local showBindFilter = ShouldShowBindFilterSelector()
    local showItemLevelFilter = ShouldShowItemLevelFilter()
    local offset = self.state.mainScrollOffset or 0

    for index, row in ipairs(self.mainFrame.rows) do
        local item = self.state.items[index + offset]
        UpdateRow(row, item, selectedItem and item and item.key == selectedItem.key, false)
        LayoutMoneyColumns(row, showBindColumn)
        row.bind:SetShown(showBindColumn and item ~= nil)
    end

    self.mainFrame.summary:SetText(string.format("Ready: %d  Excluded: %d", #self.state.items, #self.state.filteredOut))
    local canAct = selectedItem and not self:IsLockedByCombat()
    ConfigureSecureActionButton(self.mainFrame.actionButton, selectedItem, EasyDisenchantDB.selectedAction)
    SetButtonState(self.mainFrame.actionButton, canAct)
    ApplyActionButtonText()
    self:RefreshCombatState()
    self:RefreshBlacklistUI()
    self:RefreshMinimapButton()

    self.mainFrame.separator:Hide()
    self.mainFrame.filteredTitle:Hide()
    if #self.state.items == 0 then
        self.mainFrame.emptyState:SetText(GetEmptyStateText())
        self.mainFrame.emptyState:Show()
    else
        self.mainFrame.emptyState:Hide()
    end
    self.mainFrame.headerBind:SetShown(showBindColumn)
    LayoutHeaderColumns(self.mainFrame, showBindColumn)
    self.mainFrame.rarityLabel:SetShown(showRarityFilter)
    self.mainFrame.raritySelector:SetShown(showRarityFilter)
    self.mainFrame.bindLabel:SetShown(showBindFilter)
    self.mainFrame.bindSelector:SetShown(showBindFilter)
    self.mainFrame.rangeLabel:SetShown(showItemLevelFilter)
    self.mainFrame.minLevel:SetShown(showItemLevelFilter)
    self.mainFrame.rangeDash:SetShown(showItemLevelFilter)
    self.mainFrame.maxLevel:SetShown(showItemLevelFilter)
    self.mainFrame.maxLevelHint:SetShown(showItemLevelFilter)

    if self.mainFrame.scrollBar then
        local maxOffset = math.max(0, #self.state.items - VISIBLE_ROWS)
        self.mainFrame._updatingScroll = true
        self.mainFrame.scrollBar:SetMinMaxValues(0, maxOffset)
        self.mainFrame.scrollBar:SetValue(math.min(offset, maxOffset))
        self.mainFrame._updatingScroll = false
        self.mainFrame.scrollBar:SetShown(maxOffset > 0)
    end
end

function addon:InitializeUI()
    local frame = CreateFrame("Frame", "EasyDisenchantFrame", UIParent, "BackdropTemplate")
    frame:SetSize(650, 528)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition("main", self)
    end)
    frame:SetScript("OnHide", function()
        addon:HideSelectorMenus()
        if addon.blacklistFrame and addon.blacklistFrame:IsShown() then
            addon.blacklistFrame:Hide()
        end
        addon:ResetTransientFilters()
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if not addon.state.items or #addon.state.items <= VISIBLE_ROWS then
            return
        end
        addon:SetMainScrollOffset((addon.state.mainScrollOffset or 0) - delta)
    end)
    frame:Hide()
    CreateBackdrop(frame)
    self.mainFrame = frame
    RestoreWindowPosition("main", frame)

    tinsert(UISpecialFrames, frame:GetName())

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 20, -18)
    frame.title:SetText("EasyDisenchant")

    frame.titleLine = frame:CreateTexture(nil, "ARTWORK")
    frame.titleLine:SetColorTexture(0.7, 0.58, 0.18, 0.28)
    frame.titleLine:SetPoint("TOPLEFT", 18, -38)
    frame.titleLine:SetPoint("TOPRIGHT", -18, -38)
    frame.titleLine:SetHeight(1)

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -4, -4)

    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPRIGHT", -38, -18)

    frame.filterPanel = CreateInsetPanel(frame, 614, 110)
    frame.filterPanel:SetPoint("TOPLEFT", 18, -48)

    frame.listPanel = CreateInsetPanel(frame, 614, 290)
    frame.listPanel:SetPoint("TOPLEFT", frame.filterPanel, "BOTTOMLEFT", 0, -14)

    local actionLabel, actionDrop = CreateSelector(frame.filterPanel, 146, "Action")
    frame.actionSelector = actionDrop
    actionLabel:SetPoint("TOPLEFT", frame.filterPanel, 18, FILTER_LABEL_Y)
    actionDrop:SetPoint("TOPLEFT", frame.filterPanel, 14, FILTER_CONTROL_Y)
    BuildSelectorMenu(actionDrop, {
        { text = "Disenchant", value = "DISENCHANT" },
        { text = "Mill", value = "MILL" },
        { text = "Prospect", value = "PROSPECT" },
    }, function(option)
        EasyDisenchantDB.selectedAction = option.value
        if option.value ~= "DISENCHANT" then
            EasyDisenchantDB.filters.rarity = "ALL"
            EasyDisenchantDB.filters.bindType = "ALL"
            addon:RefreshFilterSelectors()
        end
        ApplyActionButtonText()
        addon:RefreshItems()
    end)
    SetSelectorValue(actionDrop, addon.actions[EasyDisenchantDB.selectedAction].label, EasyDisenchantDB.selectedAction)

    local rarityLabel, rarityDrop = CreateSelector(frame.filterPanel, 108, "Rarity")
    frame.raritySelector = rarityDrop
    frame.rarityLabel = rarityLabel
    rarityDrop.colorizeValue = GetRarityColor
    rarityLabel:SetPoint("TOPLEFT", actionDrop, "TOPRIGHT", FILTER_GAP, 20)
    rarityDrop:SetPoint("TOPLEFT", actionDrop, "TOPRIGHT", FILTER_GAP, 0)
    BuildSelectorMenu(rarityDrop, {
        { text = "All", value = "ALL" },
        { text = "Uncommon", value = 2 },
        { text = "Rare", value = 3 },
        { text = "Epic", value = 4 },
    }, function(option)
        EasyDisenchantDB.filters.rarity = option.value
        addon:RefreshItems()
    end)
    SetSelectorValue(rarityDrop, GetRarityLabel(EasyDisenchantDB.filters.rarity), EasyDisenchantDB.filters.rarity)

    local bindLabel, bindDrop = CreateSelector(frame.filterPanel, 108, "Bind")
    frame.bindSelector = bindDrop
    frame.bindLabel = bindLabel
    bindLabel:SetPoint("TOPLEFT", rarityDrop, "TOPRIGHT", FILTER_GAP, 20)
    bindDrop:SetPoint("TOPLEFT", rarityDrop, "TOPRIGHT", FILTER_GAP, 0)
    BuildSelectorMenu(bindDrop, {
        { text = "All", value = "ALL" },
        { text = "BoE", value = "BOE" },
        { text = "BoP", value = "BOP" },
        { text = "Warband", value = "WARBAND" },
    }, function(option)
        EasyDisenchantDB.filters.bindType = option.value
        addon:RefreshItems()
    end)
    SetSelectorValue(bindDrop, GetBindFilterLabel(EasyDisenchantDB.filters.bindType), EasyDisenchantDB.filters.bindType)

    frame.searchBox = CreateFrame("EditBox", nil, frame.filterPanel, "SearchBoxTemplate")
    frame.searchBox:SetSize(164, 22)
    frame.searchBox:SetPoint("TOPRIGHT", -16, FILTER_CONTROL_Y)
    frame.searchBox:SetText(EasyDisenchantDB.filters.search or "")
    frame.searchBox:SetScript("OnTextChanged", function(selfBox)
        SearchBoxTemplate_OnTextChanged(selfBox)
        EasyDisenchantDB.filters.search = selfBox:GetText() or ""
        addon:RefreshItems()
    end)
    frame.searchBox:SetScript("OnEscapePressed", function(selfBox)
        selfBox:ClearFocus()
    end)

    frame.rangeLabel = frame.filterPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.rangeLabel:SetPoint("TOPLEFT", actionLabel, "BOTTOMLEFT", 0, -42)
    frame.rangeLabel:SetText("Item level")

    frame.minLevel = CreateFrame("EditBox", nil, frame.filterPanel, "InputBoxTemplate")
    frame.minLevel:SetSize(44, 20)
    frame.minLevel:SetPoint("LEFT", frame.rangeLabel, "RIGHT", 8, 0)
    frame.minLevel:SetAutoFocus(false)
    frame.minLevel:SetNumeric(true)

    frame.rangeDash = frame.filterPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.rangeDash:SetPoint("LEFT", frame.minLevel, "RIGHT", 8, 0)
    frame.rangeDash:SetText("-")

    frame.maxLevel = CreateFrame("EditBox", nil, frame.filterPanel, "InputBoxTemplate")
    frame.maxLevel:SetSize(44, 20)
    frame.maxLevel:SetPoint("LEFT", frame.rangeDash, "RIGHT", 8, 0)
    frame.maxLevel:SetAutoFocus(false)
    frame.maxLevel:SetNumeric(true)
    frame.maxLevel:SetMaxLetters(4)

    frame.maxLevelHint = frame.filterPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.maxLevelHint:SetPoint("LEFT", frame.maxLevel, "RIGHT", 8, 0)
    frame.maxLevelHint:SetText("blank = no limit")

    local function CommitNumericFilters()
        EasyDisenchantDB.filters.minItemLevel = tonumber(frame.minLevel:GetText()) or 1
        EasyDisenchantDB.filters.maxItemLevel = tonumber(frame.maxLevel:GetText()) or 9999
        RefreshItemLevelInputs(frame)
        addon:RefreshItems()
    end

    for _, editBox in ipairs({ frame.minLevel, frame.maxLevel }) do
        editBox:SetScript("OnEnterPressed", function(selfBox)
            selfBox:ClearFocus()
            CommitNumericFilters()
        end)
        editBox:SetScript("OnEditFocusLost", CommitNumericFilters)
    end

    RefreshItemLevelInputs(frame)

    frame.headerName = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerName:SetPoint("TOPLEFT", 14, -14)
    frame.headerName:SetText("Item")
    frame.headerName:EnableMouse(true)
    AttachHeaderTooltip(frame.headerName, "Item", "The item that can be used for the selected profession action.")

    frame.headerIlvl = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerIlvl:SetPoint("TOPLEFT", 286, -14)
    frame.headerIlvl:SetText("iLvl")
    frame.headerIlvl:EnableMouse(true)
    AttachHeaderTooltip(frame.headerIlvl, "iLvl", "The current item level of the item.")

    frame.headerBind = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerBind:SetPoint("TOPLEFT", 530, -14)
    frame.headerBind:SetText("Bind")
    frame.headerBind:EnableMouse(true)
    AttachHeaderTooltip(frame.headerBind, "Bind", "Shows whether the item is Bind on Equip, Bind on Pickup, or Warband-bound.")

    frame.headerValue = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerValue:SetPoint("TOPRIGHT", -18, -14)
    frame.headerValue:SetText("Vendor")
    frame.headerValue:EnableMouse(true)
    AttachHeaderTooltip(frame.headerValue, "Vendor", "The sell price of the item at a vendor, shown as gold, silver, and copper.")

    frame.headerAction = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerAction:SetPoint("TOPRIGHT", -36, -14)
    frame.headerAction:SetText("Use")
    frame.headerAction:EnableMouse(true)
    AttachHeaderTooltip(frame.headerAction, "Use", "Use the selected action directly on this item.")

    frame.headerBlacklist = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerBlacklist:SetPoint("TOPRIGHT", -12, -14)
    frame.headerBlacklist:SetText("BL")
    frame.headerBlacklist:EnableMouse(true)
    AttachHeaderTooltip(frame.headerBlacklist, "BL", "Add this item to the blacklist so it no longer appears in the list.")

    frame.rows = CreateScrollRows(frame.listPanel, VISIBLE_ROWS, 594, -34)

    frame.scrollBar = CreateFrame("Slider", nil, frame.listPanel, "UIPanelScrollBarTemplate")
    frame.scrollBar:SetPoint("TOPRIGHT", -6, -34)
    frame.scrollBar:SetPoint("BOTTOMRIGHT", -6, 8)
    frame.scrollBar:SetMinMaxValues(0, 0)
    frame.scrollBar:SetValueStep(1)
    frame.scrollBar:SetObeyStepOnDrag(true)
    frame.scrollBar:SetScript("OnValueChanged", function(_, value)
        if frame._updatingScroll then
            return
        end
        addon:SetMainScrollOffset(value)
    end)
    frame.scrollBar:Hide()

    frame.emptyState = frame.listPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    frame.emptyState:SetPoint("CENTER", 0, 0)
    frame.emptyState:SetText("No items available for the selected action and filters.")
    frame.emptyState:Hide()

    frame.separator = frame:CreateTexture(nil, "ARTWORK")
    frame.separator:SetColorTexture(1, 1, 1, 0.1)
    frame.separator:SetPoint("TOPLEFT", 18, -474)
    frame.separator:SetPoint("TOPRIGHT", -18, -474)
    frame.separator:SetHeight(1)

    frame.filteredTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.filteredTitle:SetPoint("TOPLEFT", 18, -375)
    frame.filteredTitle:SetText("Filtered items")
    frame.filteredTitle:Hide()

    frame.actionButton = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    frame.actionButton:SetSize(120, 24)
    frame.actionButton:SetPoint("BOTTOMRIGHT", -18, 18)
    StylePrimaryActionButton(frame.actionButton)
    frame.actionButton:RegisterForClicks("AnyUp")
    frame.blacklistButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.blacklistButton:SetSize(88, 24)
    frame.blacklistButton:SetPoint("RIGHT", frame.actionButton, "LEFT", -8, 0)
    frame.blacklistButton:SetText("Blacklist")
    frame.blacklistButton:SetScript("OnClick", function()
        addon:ToggleBlacklistWindow()
    end)

    frame.combatOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.combatOverlay:SetAllPoints()
    frame.combatOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.combatOverlay:EnableMouse(true)
    frame.combatOverlay:Hide()
    frame.combatOverlay:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8x8" })
    frame.combatOverlay:SetBackdropColor(0, 0, 0, 0.55)
    frame.combatOverlay.text = frame.combatOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.combatOverlay.text:SetPoint("CENTER")
    frame.combatOverlay.text:SetText("Locked during combat")

    local blacklistFrame = CreateFrame("Frame", "EasyDisenchantBlacklistFrame", UIParent, "BackdropTemplate")
    blacklistFrame:SetSize(380, 336)
    blacklistFrame:SetPoint("CENTER", UIParent, "CENTER", 420, 0)
    blacklistFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    blacklistFrame:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    blacklistFrame:SetMovable(true)
    blacklistFrame:EnableMouse(true)
    blacklistFrame:RegisterForDrag("LeftButton")
    blacklistFrame:SetScript("OnDragStart", blacklistFrame.StartMoving)
    blacklistFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition("blacklist", self)
    end)
    blacklistFrame:EnableMouseWheel(true)
    blacklistFrame:SetScript("OnMouseWheel", function(_, delta)
        local entries = addon.GetBlacklistEntries and addon:GetBlacklistEntries() or {}
        if #entries <= BLACKLIST_ROWS then
            return
        end
        addon:SetBlacklistScrollOffset((addon.state.blacklistScrollOffset or 0) - delta)
    end)
    blacklistFrame:Hide()
    CreateBackdrop(blacklistFrame)
    RestoreWindowPosition("blacklist", blacklistFrame)
    blacklistFrame.title = blacklistFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    blacklistFrame.title:SetPoint("TOPLEFT", 18, -16)
    blacklistFrame.title:SetText("EasyDisenchant Blacklist")
    blacklistFrame.line = blacklistFrame:CreateTexture(nil, "ARTWORK")
    blacklistFrame.line:SetColorTexture(0.7, 0.58, 0.18, 0.28)
    blacklistFrame.line:SetPoint("TOPLEFT", 18, -38)
    blacklistFrame.line:SetPoint("TOPRIGHT", -18, -38)
    blacklistFrame.line:SetHeight(1)
    blacklistFrame.close = CreateFrame("Button", nil, blacklistFrame, "UIPanelCloseButton")
    blacklistFrame.close:SetPoint("TOPRIGHT", -4, -4)
    self.blacklistFrame = blacklistFrame

    blacklistFrame.rows = {}
    for index = 1, BLACKLIST_ROWS do
        local row = CreateFrame("Button", nil, blacklistFrame)
        row:SetSize(300, 22)
        if index == 1 then
            row:SetPoint("TOPLEFT", 18, -50)
        else
            row:SetPoint("TOPLEFT", blacklistFrame.rows[index - 1], "BOTTOMLEFT", 0, -4)
        end
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT")
        row.name:SetWidth(210)
        row.name:SetJustifyH("LEFT")
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetSize(82, 20)
        row.remove:SetPoint("RIGHT")
        row.remove:SetText("Remove")
        row.remove:SetScript("OnClick", function(selfButton)
            addon:RemoveFromBlacklist(selfButton:GetParent().itemID)
        end)
        row:SetScript("OnEnter", function(selfRow)
            if not selfRow.itemID then
                return
            end
            GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(selfRow.itemID)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        blacklistFrame.rows[index] = row
    end

    blacklistFrame.scrollBar = CreateFrame("Slider", nil, blacklistFrame, "UIPanelScrollBarTemplate")
    blacklistFrame.scrollBar:SetPoint("TOPRIGHT", -10, -50)
    blacklistFrame.scrollBar:SetPoint("BOTTOMRIGHT", -10, 18)
    blacklistFrame.scrollBar:SetMinMaxValues(0, 0)
    blacklistFrame.scrollBar:SetValueStep(1)
    blacklistFrame.scrollBar:SetObeyStepOnDrag(true)
    blacklistFrame.scrollBar:SetScript("OnValueChanged", function(_, value)
        if blacklistFrame._updatingScroll then
            return
        end
        addon:SetBlacklistScrollOffset(value)
    end)
    blacklistFrame.scrollBar:Hide()

    local profButton = CreateFrame("Button", "EasyDisenchantProfessionButton", UIParent, "UIPanelButtonTemplate")
    profButton:SetSize(100, 22)
    profButton:SetText("EasyDisenchant")
    profButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    profButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            addon:ToggleBlacklistWindow()
        else
            addon:ToggleWindow()
        end
    end)
    profButton:SetScript("OnUpdate", function(selfButton)
        if ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm then
            selfButton:ClearAllPoints()
            selfButton:SetParent(ProfessionsFrame)
            selfButton:SetPoint("TOPRIGHT", ProfessionsFrame.CraftingPage.SchematicForm, "TOPRIGHT", -40, -6)
            selfButton:Show()
        else
            selfButton:Hide()
        end
    end)
    profButton:Hide()
    self.professionButton = profButton

    ApplyActionButtonText()
    self:RefreshCombatState()
    self:RefreshMinimapButton()
end

function addon:ResetWindowPositions()
    if EasyDisenchantDB and EasyDisenchantDB.windows then
        EasyDisenchantDB.windows.main = nil
        EasyDisenchantDB.windows.blacklist = nil
    end

    if self.mainFrame then
        self.mainFrame:ClearAllPoints()
        self.mainFrame:SetPoint("CENTER")
    end

    if self.blacklistFrame then
        self.blacklistFrame:ClearAllPoints()
        self.blacklistFrame:SetPoint("CENTER", UIParent, "CENTER", 420, 0)
    end
end
