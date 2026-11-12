-- SPDX-License-Identifier: MIT
local _, addon = ...
local L = addon.L
local TITLE = "Smart Friendly Nameplates"
local panel, category, content, scroll, state, ruleSummary, metricsState
local checks, rows = {}, {}
local sliders = {}
local buttonRow
local globalProfile, profileState
local metricsCheck, copyGlobal, copyCharacter
local refreshing = false
local report

local function Text(template, text, left, spacing)
    local label = content:CreateFontString(nil, "ARTWORK", template)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    rows[#rows + 1] = { label = label, left = left or 24, spacing = spacing or 16 }
    return label
end

local function Checkbox(key, title, description, callback, applies, dependency)
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
    rows[#rows + 1] = { check = check, detail = detail, description = description,
        applies = applies, dependency = dependency }
    if key then checks[key] = check end
    return check
end

local function Slider(key, title, minimum, maximum, step, applies)
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetJustifyH("LEFT")
    local slider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    -- Anonymous template regions are named in modern clients. Our own label
    -- also handles older template shapes without relying on generated globals.
    if slider.Low then slider.Low:SetText(tostring(minimum)) end
    if slider.High then slider.High:SetText(tostring(maximum)) end
    if slider.Text then slider.Text:SetText("") end
    slider:SetScript("OnValueChanged", function(_, value)
        if refreshing then return end
        local rounded = math.floor(value / step + 0.5) * step
        addon.SetOption(key, rounded)
    end)
    local row = { slider = slider, label = label, title = title, key = key, step = step, applies = applies }
    rows[#rows + 1] = row
    sliders[#sliders + 1] = row
end

local function Buttons()
    buttonRow = {}
    rows[#rows + 1] = { buttons = buttonRow }
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
        elseif row.slider then
            row.label:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -top)
            row.label:SetWidth(math.max(1, width - 48))
            top = top + row.label:GetStringHeight() + 12
            row.slider:SetPoint("TOPLEFT", content, "TOPLEFT", 32, -top)
            row.slider:SetSize(math.max(32, width - 72), 16)
            top = top + 44
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
    local options = addon.GetOptions()
    if not options then return end
    refreshing = true
    for key, check in pairs(checks) do check:SetChecked(options[key]) end
    for _, row in ipairs(sliders) do
        row.slider:SetValue(options[row.key])
        local value = row.step < 1 and string.format("%.2f", options[row.key]) or tostring(options[row.key])
        row.label:SetText(row.title .. ": " .. value)
        local alpha = (not row.applies or row.applies(options)) and 1 or 0.5
        row.label:SetAlpha(alpha)
        row.slider:SetAlpha(alpha)
    end
    for _, row in ipairs(rows) do
        if row.check then
            local active = not row.applies or row.applies(options)
            row.check:SetAlpha(active and 1 or 0.5)
            row.detail:SetAlpha(active and 1 or 0.6)
            row.detail:SetText(row.description .. (not active and row.dependency and (" " .. row.dependency) or ""))
        end
    end
    local shared = addon.GetProfile() == "global"
    globalProfile:SetChecked(shared)
    profileState:SetText(string.format(L.UI_PROFILE_CURRENT,
        shared and L.VALUE_PROFILE_GLOBAL or L.VALUE_PROFILE_CHARACTER))
    copyGlobal:SetEnabled(not shared)
    copyCharacter:SetEnabled(shared)
    -- Dependent preferences are dimmed, but stay editable for later use.
    -- The effective state comes from live game settings, not just the switch.
    state:SetText(addon.GetHealthSummary())
    ruleSummary:SetText(addon.GetRuleSummary())
    metricsCheck:SetChecked(addon.MetricsEnabled())
    local metrics = addon.GetMetrics()
    metricsState:SetText(string.format(L.UI_METRICS_VALUES, metrics.updates or 0,
        metrics.alphaWrites or 0, metrics.colorWrites or 0, metrics.subtitleWrites or 0,
        metrics.tooltipReads or 0, metrics.ownerChecks or 0))
    refreshing = false
    Layout()
end

local function RestoreDefaults()
    addon.RestoreDefaults()
end

-- A selectable report stays local: the player chooses where to paste it.
-- Creation is lazy, so its widgets add no work during ordinary nameplate use.
function addon.ShowReport()
    if not report then
        report = CreateFrame("Frame", "SmartFriendlyNameplatesReport", UIParent, "BasicFrameTemplateWithInset")
        report:SetSize(620, 440)
        report:SetPoint("CENTER")
        report:SetFrameStrata("DIALOG")
        report.TitleText:SetText(L.UI_REPORT)
        report:SetMovable(true)
        report:EnableMouse(true)
        report:RegisterForDrag("LeftButton")
        report:SetScript("OnDragStart", report.StartMoving)
        report:SetScript("OnDragStop", report.StopMovingOrSizing)
        if UISpecialFrames then table.insert(UISpecialFrames, "SmartFriendlyNameplatesReport") end
        local help = report:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", report, "TOPLEFT", 16, -34)
        help:SetPoint("TOPRIGHT", report, "TOPRIGHT", -16, -34)
        help:SetJustifyH("LEFT")
        help:SetText(L.UI_REPORT_HELP)
        local viewport = CreateFrame("ScrollFrame", nil, report, "UIPanelScrollFrameTemplate")
        viewport:SetPoint("TOPLEFT", report, "TOPLEFT", 18, -78)
        viewport:SetPoint("BOTTOMRIGHT", report, "BOTTOMRIGHT", -36, 18)
        local edit = CreateFrame("EditBox", nil, viewport)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetTextInsets(4, 4, 4, 4)
        edit:SetWidth(554)
        edit:SetScript("OnEscapePressed", function() report:Hide() end)
        viewport:SetScrollChild(edit)
        local measure = report:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        measure:SetWidth(546)
        measure:SetWordWrap(true)
        measure:Hide()
        report.edit, report.measure, report.viewport = edit, measure, viewport
        report:SetScript("OnHide", function(self) self.edit:ClearFocus() end)
    end
    local text = addon.BuildReport()
    report.measure:SetText(text)
    report.edit:SetHeight(math.max(320, report.measure:GetStringHeight() + 20))
    report.edit:SetText(text)
    report.viewport:SetVerticalScroll(0)
    report:Show()
    report.edit:SetFocus()
    report.edit:HighlightText()
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
    Text("GameFontHighlightSmall", L.UI_AUTO_SETUP)
    state = Text("GameFontHighlightSmall", "")
    ruleSummary = Text("GameFontHighlightSmall", "")

    Text("GameFontNormal", L.UI_SECTION_PROFILES)
    globalProfile = Checkbox(nil, L.UI_PROFILE_GLOBAL, L.UI_PROFILE_GLOBAL_DESC, function(checked)
        addon.SetProfile(checked and "global" or "character")
    end)
    profileState = Text("GameFontHighlightSmall", "")
    Text("GameFontHighlightSmall", L.UI_COPY_HELP)
    Buttons()
    copyGlobal = Button(L.UI_COPY_GLOBAL, 140, function() addon.CopyProfile("global") end)
    copyCharacter = Button(L.UI_COPY_CHARACTER, 140, function() addon.CopyProfile("character") end)
    Text("GameFontNormal", L.UI_SECTION_PRESETS)
    Text("GameFontHighlightSmall", L.UI_PRESETS_HELP)
    Buttons()
    Button(L.UI_PRESET_MINIMAL, 112, function() addon.ApplyPreset("minimal") end)
    Button(L.UI_PRESET_GROUP, 112, function() addon.ApplyPreset("group") end)
    Button(L.UI_PRESET_DEFAULT, 132, function() addon.ApplyPreset("default") end)
    Button(L.UI_PRESET_EXPLORATION, 112, function() addon.ApplyPreset("exploration") end)

    Text("GameFontNormal", L.UI_SECTION_PLAYERS)
    Checkbox("enabled", L.UI_ENABLE,
        L.UI_ENABLE_DESC)
    Checkbox("showGroup", L.UI_GROUP,
        L.UI_GROUP_DESC)
    Checkbox("showCombat", L.UI_COMBAT,
        L.UI_COMBAT_DESC)
    Checkbox("showTarget", L.UI_TARGET,
        L.UI_TARGET_DESC)
    Checkbox("showFocus", L.UI_FOCUS, L.UI_FOCUS_DESC)
    Checkbox("showMouseover", L.UI_MOUSEOVER, L.UI_MOUSEOVER_DESC)
    Text("GameFontNormal", L.UI_SECTION_MINIONS)
    Checkbox("includeMinions", L.UI_MINIONS,
        L.UI_MINIONS_DESC)
    Text("GameFontNormal", L.UI_SECTION_NPCS)
    local function NPCs(options) return options.includeNPCs end
    local function NPCNames(options) return options.includeNPCs and not options.showNPCBars end
    Checkbox("includeNPCs", L.UI_NPCS,
        L.UI_NPCS_DESC)
    Checkbox("showNPCBars", L.UI_NPC_BARS,
        L.UI_NPC_BARS_DESC, nil, NPCs, L.UI_REQUIRES_NPCS)
    Checkbox("npcShowTarget", L.UI_NPC_TARGET,
        L.UI_NPC_TARGET_DESC, nil, NPCNames, L.UI_REQUIRES_NPC_NAMES)
    Checkbox("showNPCTitle", L.UI_NPC_TITLE,
        L.UI_NPC_TITLE_DESC, nil, NPCNames, L.UI_REQUIRES_NPC_NAMES)
    Checkbox("npcNameColors", L.UI_NPC_COLORS,
        L.UI_NPC_COLORS_DESC, nil, NPCNames, L.UI_REQUIRES_NPC_NAMES)

    Text("GameFontNormal", L.UI_SECTION_APPEARANCE)
    Checkbox("classColorsOnly", L.UI_COLORS, L.UI_COLORS_DESC)
    Checkbox("showGuild", L.UI_GUILD, L.UI_GUILD_DESC)
    Text("GameFontHighlightSmall", L.UI_SUBTITLES_HELP)
    local function Subtitles(options)
        return options.showGuild or (NPCNames(options) and options.showNPCTitle)
    end
    Checkbox("subtitleBrackets", L.UI_SUBTITLE_BRACKETS, L.UI_SUBTITLE_BRACKETS_DESC,
        nil, Subtitles, L.UI_REQUIRES_SUBTITLES)
    Slider("subtitleSize", L.UI_SUBTITLE_SIZE, 8, 24, 1, Subtitles)
    Slider("subtitleOffset", L.UI_SUBTITLE_OFFSET, 0, 12, 1, Subtitles)
    Slider("subtitleRed", L.UI_SUBTITLE_RED, 0, 1, 0.05, Subtitles)
    Slider("subtitleGreen", L.UI_SUBTITLE_GREEN, 0, 1, 0.05, Subtitles)
    Slider("subtitleBlue", L.UI_SUBTITLE_BLUE, 0, 1, 0.05, Subtitles)
    Text("GameFontNormal", L.UI_SECTION_DIAGNOSTICS)
    Buttons()
    Button(L.UI_DEFAULTS, 132, RestoreDefaults)
    Button(L.UI_STATUS, 112, function() addon.PrintStatus() end)
    Button(L.UI_INSPECT, 120, function() addon.DebugTarget() end)
    Button(L.UI_REPAIR, 112, function() addon.Repair() end)
    Button(L.UI_REPORT, 132, function() addon.ShowReport() end)
    metricsCheck = Checkbox(nil, L.UI_METRICS, L.UI_METRICS_DESC, function(enabled)
        addon.SetMetricsEnabled(enabled)
        addon.RefreshOptions()
    end)
    metricsState = Text("GameFontHighlightSmall", "")
    Buttons()
    Button(L.UI_METRICS_REFRESH, 112, addon.RefreshOptions)
    Button(L.UI_METRICS_RESET, 112, function() addon.ResetMetrics(); addon.RefreshOptions() end)
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
