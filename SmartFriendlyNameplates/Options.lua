-- SPDX-License-Identifier: MIT
local _, addon = ...
local L = addon.L
local TITLE = "Smart Friendly Nameplates"
local panel, category, content, scroll, state, ruleSummary, metricsState
local checks, rows = {}, {}
local sliders = {}
local subtitleColor, colorPickerSession
local buttonRow
local globalProfile, profileState
local metricsCheck, copyGlobal, copyCharacter
local refreshing = false
local report
local hoveredRow, tooltipOwner

local function Text(template, text, left, spacing)
    local label = content:CreateFontString(nil, "ARTWORK", template)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    rows[#rows + 1] = { label = label, left = left or 24, spacing = spacing or 16 }
    return label
end

local function Section(title)
    Text("GameFontHighlightLarge", title)
    rows[#rows].section = true
end

local function ShowTooltip(row, owner)
    if hoveredRow and hoveredRow ~= row then hoveredRow.highlight:Hide() end
    row.highlight:Show()
    hoveredRow, tooltipOwner = row, owner
    -- The row spans the panel; anchor label hover beside its control instead.
    local anchor = owner == row.frame and (row.check or row.slider or row.color) or owner
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.title, 1, 0.82, 0, 1, true)
    if row.description then GameTooltip:AddLine(row.description, 1, 1, 1, true) end
    local options = addon.GetOptions()
    if options and row.applies and not row.applies(options) and row.dependency then
        GameTooltip:AddLine(row.dependency, 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

local function RowHover(row, widget)
    widget:SetScript("OnEnter", function(self) ShowTooltip(row, self) end)
    local function Clear()
        if hoveredRow ~= row then return end
        row.highlight:Hide()
        hoveredRow, tooltipOwner = nil, nil
        GameTooltip:Hide()
    end
    widget:SetScript("OnLeave", function()
        if tooltipOwner == widget then Clear() end
    end)
    widget:SetScript("OnHide", Clear)
end

local function SettingRow(title, description, applies, dependency)
    local frame = CreateFrame("Button", nil, content)
    local highlight = frame:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(frame)
    highlight:SetColorTexture(1, 1, 1, 0.08)
    highlight:Hide()
    local row = { frame = frame, highlight = highlight, title = title,
        description = description, applies = applies, dependency = dependency }
    RowHover(row, frame)
    rows[#rows + 1] = row
    return row
end

local function Checkbox(key, title, description, callback, applies, dependency)
    local row = SettingRow(title, description, applies, dependency)
    local check = CreateFrame("CheckButton", nil, row.frame, "UICheckButtonTemplate")
    check.Text:SetText(title)
    check.Text:SetFontObject("GameFontNormal")
    check.Text:SetJustifyH("LEFT")
    check.Text:ClearAllPoints()
    check:SetScript("OnClick", function(self)
        local checked = not not self:GetChecked()
        if callback then callback(checked) else addon.SetOption(key, checked) end
    end)
    row.check, row.label = check, check.Text
    row.frame:SetScript("OnClick", function() check:Click() end)
    RowHover(row, check)
    if key then checks[key] = check end
    return check
end

local function Slider(key, title, minimum, maximum, step, applies)
    local row = SettingRow(title, L.UI_SUBTITLES_HELP, applies, L.UI_REQUIRES_SUBTITLES)
    local label = row.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetJustifyH("LEFT")
    label:SetText(title)
    local slider = CreateFrame("Slider", nil, row.frame, "OptionsSliderTemplate")
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
    row.slider, row.label, row.key, row.step = slider, label, key, step
    row.value = row.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.value:SetPoint("BOTTOM", slider, "TOP", 0, 3)
    RowHover(row, slider)
    sliders[#sliders + 1] = row
end

local function SubtitleColor(applies)
    local row = SettingRow(L.UI_SUBTITLE_COLOR, L.UI_SUBTITLES_HELP, applies, L.UI_REQUIRES_SUBTITLES)
    local button = CreateFrame("Button", nil, row.frame, "UIPanelButtonTemplate")
    button:SetSize(32, 24)
    local swatch = button:CreateTexture(nil, "OVERLAY")
    swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
    swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
    local label = row.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetJustifyH("LEFT")
    label:SetText(L.UI_SUBTITLE_COLOR)
    local default = CreateFrame("Button", nil, row.frame, "UIPanelButtonTemplate")
    default:SetText(L.UI_SUBTITLE_COLOR_DEFAULT)
    local defaultLabel = default:GetFontString()
    defaultLabel:SetWordWrap(true)
    default:SetScript("OnClick", function()
        local session = colorPickerSession
        colorPickerSession = nil
        if session and session.picker.swatchFunc == session.onChanged then session.picker:Hide() end
        local defaults = addon.DEFAULTS
        addon.SetSubtitleColor(defaults.subtitleRed, defaults.subtitleGreen, defaults.subtitleBlue)
    end)
    row.color, row.swatch, row.label = button, swatch, label
    row.default, row.defaultLabel, row.defaultWidth = default, defaultLabel, defaultLabel:GetStringWidth() + 24
    subtitleColor = row
    row.frame:SetScript("OnClick", function() button:Click() end)
    RowHover(row, button)
    RowHover(row, default)
    button:SetScript("OnClick", function()
        local options = addon.GetOptions()
        if not options then return end
        local r, g, b = options.subtitleRed, options.subtitleGreen, options.subtitleBlue
        local picker = ColorPickerFrame
        local session = { options = options, picker = picker, r = r, g = g, b = b }
        local function Apply(red, green, blue)
            if colorPickerSession ~= session or addon.GetOptions() ~= options then return end
            session.r, session.g, session.b = red, green, blue
            addon.SetSubtitleColor(red, green, blue)
        end
        session.onChanged = function() Apply(picker:GetColorRGB()) end
        colorPickerSession = session
        picker:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = session.onChanged,
            cancelFunc = function() Apply(r, g, b) end,
        })
    end)
end

local function Buttons()
    buttonRow = {}
    rows[#rows + 1] = { buttons = buttonRow }
end

local function Button(title, width, callback, headerRow)
    local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(title)
    button:SetScript("OnClick", callback)
    local label = button:GetFontString()
    label:SetWordWrap(true)
    local entry = {
        button = button,
        label = label,
        width = math.max(width, label:GetStringWidth() + 24),
    }
    if headerRow then headerRow.reset = entry else buttonRow[#buttonRow + 1] = entry end
    return button
end

-- Measure wrapped labels rather than assuming a particular UI scale or canvas
-- height. The native scrollbar keeps every setting and diagnostic reachable.
local function Layout()
    if not content then return end
    local width = content:GetWidth()
    local top = 16
    for _, row in ipairs(rows) do
        if row.frame then
            local rowWidth = math.max(1, width - 48)
            local controlLeft = math.floor(math.min(300, rowWidth * 0.5))
            local controlWidth = math.max(1, rowWidth - controlLeft - 8)
            row.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -top)
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row.frame, "LEFT", 16, 0)
            row.label:SetWidth(math.max(1, controlLeft - 28))
            local height = math.max(40, row.label:GetStringHeight() + 12)
            if row.check then
                row.check:SetSize(32, 32)
                row.check:SetPoint("LEFT", row.frame, "LEFT", controlLeft - 4, 0)
            elseif row.slider then
                row.slider:SetPoint("LEFT", row.frame, "LEFT", controlLeft + 8, 0)
                row.slider:SetSize(math.max(32, controlWidth - 16), 16)
                height = math.max(52, height)
            elseif row.color then
                row.color:SetPoint("LEFT", row.frame, "LEFT", controlLeft, 0)
                local defaultWidth = math.min(row.defaultWidth, math.max(32, controlWidth - 44))
                row.defaultLabel:SetWidth(math.max(1, defaultWidth - 24))
                local buttonHeight = math.max(24, row.defaultLabel:GetStringHeight() + 12)
                row.default:SetPoint("LEFT", row.frame, "LEFT", controlLeft + 44, 0)
                row.default:SetSize(defaultWidth, buttonHeight)
                height = math.max(height, buttonHeight + 8)
            end
            row.frame:SetSize(rowWidth, height)
            top = top + height
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
        elseif row.reset then
            local entry = row.reset
            local available = math.max(32, width - 48)
            local buttonWidth = math.min(entry.width, available)
            entry.label:SetWidth(math.max(1, buttonWidth - 24))
            local buttonHeight = math.max(24, entry.label:GetStringHeight() + 12)
            row.label:SetWidth(available)
            local sameLine = row.label:GetStringWidth() + buttonWidth + 16 <= available
            if sameLine then row.label:SetWidth(math.max(1, available - buttonWidth - 16)) end
            row.label:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -top)
            local buttonTop = sameLine and top or top + row.label:GetStringHeight() + 12
            entry.button:SetSize(buttonWidth, buttonHeight)
            entry.button:SetPoint("TOPLEFT", content, "TOPLEFT", width - 24 - buttonWidth, -buttonTop)
            top = math.max(top + row.label:GetStringHeight(), buttonTop + buttonHeight) + 20
        else
            if row.section then top = top + 20 end
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
    if colorPickerSession then
        local session = colorPickerSession
        if session.picker.swatchFunc ~= session.onChanged then
            colorPickerSession = nil
        elseif session.options ~= options or session.r ~= options.subtitleRed
            or session.g ~= options.subtitleGreen or session.b ~= options.subtitleBlue then
            -- Profile switches, defaults and other edits invalidate this preview.
            -- Never close a picker that another addon has since taken over.
            colorPickerSession = nil
            session.picker:Hide()
        end
    end
    refreshing = true
    for key, check in pairs(checks) do check:SetChecked(options[key]) end
    for _, row in ipairs(sliders) do
        row.slider:SetValue(options[row.key])
        local value = row.step < 1 and string.format("%.2f", options[row.key]) or tostring(options[row.key])
        row.value:SetText(value)
        local alpha = (not row.applies or row.applies(options)) and 1 or 0.5
        row.label:SetAlpha(alpha)
        row.slider:SetAlpha(alpha)
        row.value:SetAlpha(alpha)
    end
    for _, row in ipairs(rows) do
        if row.check then
            local active = not row.applies or row.applies(options)
            row.check:SetAlpha(active and 1 or 0.5)
        end
    end
    if subtitleColor then
        subtitleColor.swatch:SetColorTexture(options.subtitleRed, options.subtitleGreen, options.subtitleBlue)
        local alpha = subtitleColor.applies(options) and 1 or 0.5
        subtitleColor.color:SetAlpha(alpha)
        subtitleColor.label:SetAlpha(alpha)
        subtitleColor.default:SetAlpha(alpha)
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
    if hoveredRow then ShowTooltip(hoveredRow, tooltipOwner) end
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
    Button(L.UI_DEFAULTS, 132, RestoreDefaults, rows[#rows])
    Text("GameFontHighlightSmall", L.UI_INTRO)
    Text("GameFontHighlightSmall", L.UI_AUTO_SETUP)
    state = Text("GameFontHighlightSmall", "")
    ruleSummary = Text("GameFontHighlightSmall", "")

    Section(L.UI_SECTION_PROFILES)
    globalProfile = Checkbox(nil, L.UI_PROFILE_GLOBAL, L.UI_PROFILE_GLOBAL_DESC, function(checked)
        addon.SetProfile(checked and "global" or "character")
    end)
    profileState = Text("GameFontHighlightSmall", "")
    Text("GameFontHighlightSmall", L.UI_COPY_HELP)
    Buttons()
    copyGlobal = Button(L.UI_COPY_GLOBAL, 140, function() addon.CopyProfile("global") end)
    copyCharacter = Button(L.UI_COPY_CHARACTER, 140, function() addon.CopyProfile("character") end)

    Section(L.UI_SECTION_PLAYERS)
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
    Section(L.UI_SECTION_MINIONS)
    Checkbox("includeMinions", L.UI_MINIONS,
        L.UI_MINIONS_DESC)
    Section(L.UI_SECTION_NPCS)
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

    Section(L.UI_SECTION_APPEARANCE)
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
    SubtitleColor(Subtitles)
    Section(L.UI_SECTION_DIAGNOSTICS)
    Buttons()
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
