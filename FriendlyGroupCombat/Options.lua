-- SPDX-License-Identifier: MIT
local _, addon = ...
local TITLE = "Smart Friendly Nameplates"
local panel, category, content, scroll, state
local checks, rows = {}, {}
local buttonRow

local function Text(template, text, left, spacing)
    local label = content:CreateFontString(nil, "ARTWORK", template)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    rows[#rows + 1] = { label = label, left = left or 24, spacing = spacing or 16 }
    return label
end

local function Checkbox(key, title, description)
    local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    check.Text:SetText(title)
    check.Text:SetFontObject("GameFontNormal")
    check.Text:SetJustifyH("LEFT")
    check.Text:ClearAllPoints()
    check.Text:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -8)
    check:SetScript("OnClick", function(self)
        addon.SetOption(key, not not self:GetChecked())
    end)
    local detail = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail:SetJustifyH("LEFT")
    detail:SetText(description)
    rows[#rows + 1] = { check = check, detail = detail }
    checks[key] = check
    return check
end

local function Button(title, width, callback)
    local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(title)
    button:SetScript("OnClick", callback)
    buttonRow[#buttonRow + 1] = { button = button, width = width }
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
            local lineHeight = 24
            for _, entry in ipairs(row.buttons) do
                if left > 24 and left + entry.width > width - 24 then
                    left = 24
                    top = top + lineHeight + 8
                end
                entry.button:SetPoint("TOPLEFT", content, "TOPLEFT", left, -top)
                left = left + entry.width + 12
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
    -- Preferences remain editable while the master filter is off.
    if pending then
        state:SetText("Game-setting changes are pending until combat ends. If they still cannot be applied, use Print status for details.")
    elseif options.enabled then
        state:SetText("Filter enabled. Changes apply immediately and are saved for this character.")
    else
        state:SetText("Filter disabled. Previous game settings have been restored where still managed by the addon.")
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
    Text("GameFontHighlightSmall", "Choose when friendly health bars stay visible. Any enabled condition can show a full bar; other eligible units show names only. Settings are saved per character.")

    Checkbox("enabled", "Enable friendly nameplate filtering",
        "Master switch for all filtering and selective class colours. Your other preferences are kept when this is off.")
    Checkbox("showGroup", "Show health bars for group members",
        "Keep full health bars for your party and raid, even out of combat.")
    Checkbox("showCombat", "Show health bars for units in combat",
        "Keep a full health bar while that unit is in combat, regardless of your own combat state.")
    Checkbox("showTarget", "Show health bar for current target",
        "Keep a full health bar for your selected friendly player or eligible minion, even if no other condition applies.")
    Checkbox("includeMinions", "Apply filtering to friendly player minions",
        "Apply the same conditions to friendly player pets, guardians and totems. Ordinary NPCs are unchanged.")
    Checkbox("classColorsOnly", "Use class colours for names without health bars",
        "Colour name-only players by class. Names with a visible health bar keep their normal colour. Applies while the filter is enabled.")
    Checkbox("showGuild", "Show guild below name-only players",
        "Display the player's guild below their name while the health bar is hidden. Only shown when guild information is available.")
    state = Text("GameFontHighlightSmall", "")

    buttonRow = {}
    rows[#rows + 1] = { buttons = buttonRow }
    Button("Restore defaults", 132, RestoreDefaults)
    Button("Print status", 112, function() addon.PrintStatus() end)
    Button("Inspect target", 120, function() addon.DebugTarget() end)
    Text("GameFontHighlightSmall", "Diagnostics are printed in chat. Select a friendly player or minion before using Inspect target.")
    Text("GameFontDisableSmall", "Protected friendly nameplates in dungeons and raids remain under Blizzard's control.")

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
