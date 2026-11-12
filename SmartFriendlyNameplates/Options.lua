-- SPDX-License-Identifier: MIT
local _, addon = ...
local L = addon.L
local TITLE = "Smart Friendly Nameplates"
local panel, category, content, scroll, state
local checks, rows = {}, {}
local buttonRow
local globalProfile, profileState

local function Text(template, text, left, spacing)
    local label = content:CreateFontString(nil, "ARTWORK", template)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    rows[#rows + 1] = { label = label, left = left or 24, spacing = spacing or 16 }
    return label
end

local function Checkbox(key, title, description, callback)
    local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    check.Text:SetText(title)
    check.Text:SetFontObject("GameFontNormal")
    check.Text:SetJustifyH("LEFT")
    check.Text:ClearAllPoints()
    check.Text:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -8)
    check:SetScript("OnClick", function(self)
        local checked = not not self:GetChecked()
        if callback then callback(checked) else addon.SetOption(key, checked) end
    end)
    local detail = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail:SetJustifyH("LEFT")
    detail:SetText(description)
    rows[#rows + 1] = { check = check, detail = detail }
    if key then checks[key] = check end
    return check
end

local function Button(title, width, callback)
    local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(title)
    button:SetScript("OnClick", callback)
    local label = button:GetFontString()
    label:SetWordWrap(true)
    buttonRow[#buttonRow + 1] = {
        button = button,
        label = label,
        width = math.max(width, label:GetStringWidth() + 24),
    }
    return button
end

-- Measure wrapped labels rather than assuming a particular UI scale or canvas
-- height. The native scrollbar keeps every setting and diagnostic reachable.
local function Layout()
    if not content then return end
    local width = content:GetWidth()
    local top = 16
    for _, row in ipairs(rows) do
        if row.check then
            row.check:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -top)
            row.check.Text:SetWidth(math.max(1, width - 80))
            top = top + math.max(32, row.check.Text:GetStringHeight() + 16) + 4
            row.detail:SetPoint("TOPLEFT", content, "TOPLEFT", 56, -top)
            row.detail:SetWidth(math.max(1, width - 80))
            top = top + row.detail:GetStringHeight() + 20
        elseif row.buttons then
            local left = 24
            local lineHeight = 0
            for _, entry in ipairs(row.buttons) do
                local buttonWidth = math.min(entry.width, math.max(32, width - 48))
                if left > 24 and left + buttonWidth > width - 24 then
                    left = 24
                    top = top + lineHeight + 8
                    lineHeight = 0
                end
                entry.label:SetWidth(math.max(1, buttonWidth - 24))
                local height = math.max(24, entry.label:GetStringHeight() + 12)
                entry.button:SetSize(buttonWidth, height)
                entry.button:SetPoint("TOPLEFT", content, "TOPLEFT", left, -top)
                left = left + buttonWidth + 12
                lineHeight = math.max(lineHeight, height)
            end
            top = top + lineHeight + 16
        else
            row.label:SetPoint("TOPLEFT", content, "TOPLEFT", row.left, -top)
            row.label:SetWidth(math.max(1, width - row.left - 24))
            top = top + row.label:GetStringHeight() + row.spacing
        end
    end
    content:SetHeight(top)
end

function addon.RefreshOptions()
    if not panel then return end
    local options, pending = addon.GetOptions()
    if not options then return end
    for key, check in pairs(checks) do check:SetChecked(options[key]) end
    local shared = addon.GetProfile() == "global"
    globalProfile:SetChecked(shared)
    profileState:SetText(string.format(L.UI_PROFILE_CURRENT,
        shared and L.VALUE_PROFILE_GLOBAL or L.VALUE_PROFILE_CHARACTER))
    -- Preferences remain editable while the master filter is off.
    if pending then
        state:SetText(L.UI_PENDING)
    elseif options.enabled then
        state:SetText(L.UI_ENABLED)
    else
        state:SetText(L.UI_DISABLED)
    end
    Layout()
end

local function RestoreDefaults()
    for key, value in pairs(addon.DEFAULTS) do addon.SetOption(key, value) end
end

function addon.RegisterOptions()
    if category then return end
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end

    panel = CreateFrame("Frame")
    panel:Hide()
    scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 0)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(500, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, width)
        if width > 0 then content:SetWidth(width) end
        Layout()
    end)

    Text("GameFontNormalLarge", TITLE .. " |cff888888v" .. addon.VERSION .. "|r")
    Text("GameFontHighlightSmall", L.UI_INTRO)

    globalProfile = Checkbox(nil, L.UI_PROFILE_GLOBAL, L.UI_PROFILE_GLOBAL_DESC, function(checked)
        addon.SetProfile(checked and "global" or "character")
    end)
    profileState = Text("GameFontHighlightSmall", "")

    Checkbox("enabled", L.UI_ENABLE,
        L.UI_ENABLE_DESC)
    Checkbox("showGroup", L.UI_GROUP,
        L.UI_GROUP_DESC)
    Checkbox("showCombat", L.UI_COMBAT,
        L.UI_COMBAT_DESC)
    Checkbox("showTarget", L.UI_TARGET,
        L.UI_TARGET_DESC)
    Checkbox("includeMinions", L.UI_MINIONS,
        L.UI_MINIONS_DESC)
    Checkbox("classColorsOnly", L.UI_COLORS,
        L.UI_COLORS_DESC)
    Checkbox("showGuild", L.UI_GUILD,
        L.UI_GUILD_DESC)
    Checkbox("includeNPCs", L.UI_NPCS,
        L.UI_NPCS_DESC)
    Checkbox("showNPCBars", L.UI_NPC_BARS,
        L.UI_NPC_BARS_DESC)
    Checkbox("showNPCTitle", L.UI_NPC_TITLE,
        L.UI_NPC_TITLE_DESC)
    Checkbox("npcNameColors", L.UI_NPC_COLORS,
        L.UI_NPC_COLORS_DESC)
    state = Text("GameFontHighlightSmall", "")

    buttonRow = {}
    rows[#rows + 1] = { buttons = buttonRow }
    Button(L.UI_DEFAULTS, 132, RestoreDefaults)
    Button(L.UI_STATUS, 112, function() addon.PrintStatus() end)
    Button(L.UI_INSPECT, 120, function() addon.DebugTarget() end)
    Text("GameFontHighlightSmall", L.UI_DIAGNOSTICS)
    Text("GameFontDisableSmall", L.UI_RESTRICTIONS)

    panel.OnRefresh = addon.RefreshOptions
    panel.OnDefault = RestoreDefaults
    panel:SetScript("OnShow", addon.RefreshOptions)
    category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
    addon.RefreshOptions()
end

function addon.OpenOptions()
    addon.RegisterOptions()
    if not category or not Settings.OpenToCategory then return false end
    Settings.OpenToCategory(category:GetID())
    return true
end
