-- SPDX-License-Identifier: MIT
-- WoW Forever 1.60.1. No dependency; only ordinary, accessible nameplates.
local ADDON_NAME, addon = ...
local L = addon.L
local VERSION = "0.2.3"
addon.VERSION = VERSION
local DEFAULTS = {
    enabled = true,
    classColorsOnly = true,
    showGroup = true,
    showCombat = true,
    showTarget = false,
    includeMinions = false,
    showMinionTitle = false,
    showGuild = false,
    includeNPCs = false,
    showNPCBars = false,
    showNPCTitle = true,
    npcNameColors = true,
    showFocus = false,
    showMouseover = false,
    npcShowTarget = false,
    customNameSize = false,
    nameSize = 12,
    subtitleSize = 12,
    subtitleOffset = 2,
    subtitleRed = 0.7,
    subtitleGreen = 0.85,
    subtitleBlue = 0.7,
    subtitleBrackets = true,
}
addon.DEFAULTS = DEFAULTS
local RANGES = { nameSize = { 8, 32 }, subtitleSize = { 8, 24 }, subtitleOffset = { 0, 12 },
    subtitleRed = { 0, 1 }, subtitleGreen = { 0, 1 }, subtitleBlue = { 0, 1 } }
local SELECTION_RULES = { { "showTarget", "target" }, { "showFocus", "focus" }, { "showMouseover", "mouseover" } }
local PREFIX = "|cff66ccffSmart Friendly Nameplates:|r "
local INTERVAL = 0.20
local CVARS = {
    { name = "nameplateShowFriendlyPlayers", value = "1" },
    { name = "nameplateShowOnlyNameForFriendlyPlayerUnits", value = "0" },
    { name = "nameplateUseClassColorForFriendlyPlayerUnitNames", value = "0", option = "classColorsOnly" },
    { name = "nameplateShowFriendlyPlayerMinions", value = "1", option = "includeMinions" },
    { name = "nameplateShowFriendlyNpcs", value = "1", option = "includeNPCs" },
    { name = "nameplateSimplifiedTypes", value = "0", enforce = true },
}

local driver = CreateFrame("Frame")
local db, characterDB, globalDB
local plates, forbidden = {}, {}
local nameOnlyFrames = setmetatable({}, { __mode = "k" })
local nameColors = setmetatable({}, { __mode = "k" })
local nameLayouts = setmetatable({}, { __mode = "k" })
local nameWidths = setmetatable({}, { __mode = "k" })
local nameFonts = setmetatable({}, { __mode = "k" })
local pendingNameFonts = setmetatable({}, { __mode = "k" })
local layoutHooks = setmetatable({}, { __mode = "k" })
local centerStatus = setmetatable({}, { __mode = "k" })
local InstallLayoutHook
local subtitleLabels = setmetatable({}, { __mode = "k" })
local subtitleState = setmetatable({}, { __mode = "k" })
local warnings = {}
local pendingCVars = false
local elapsedSinceUpdate = 0
local updateTime = 0
local lastError
local nameHookInstalled = false
local applyingCVars = false
local applyingDistanceCVars = false
local distanceAttempts = {}
local DISTANCE_CVARS = { "nameplateMaxDistance", "nameplatePlayerMaxDistance" }
addon.DISTANCE_CVARS = DISTANCE_CVARS
local cvarProblems = {}
local groupSnapshot, groupTokens, groupTokenSet, groupTokenKey
local metricsEnabled = false
local metrics = {}
local metricKeys = { "updates", "alphaWrites", "colorWrites", "subtitleWrites", "tooltipReads", "ownerChecks", "fullUpdates" }
function addon.ResetMetrics()
    for _, key in ipairs(metricKeys) do metrics[key] = 0 end
end
addon.ResetMetrics()
function addon.GetMetrics()
    local copy = {}
    for _, key in ipairs(metricKeys) do copy[key] = metrics[key] end
    return copy
end
function addon.SetMetricsEnabled(value) metricsEnabled = value == true end
function addon.MetricsEnabled() return metricsEnabled end
local function Measure(key)
    if metricsEnabled then metrics[key] = metrics[key] + 1 end
end

local function Say(message)
    print(PREFIX .. message)
end

local function Warn(key, message)
    lastError = message
    if warnings[key] then return end
    warnings[key] = true
    Say(message)
end

-- A secret is never compared, converted to text, or used as a condition.
-- The second return distinguishes an unavailable result from an ordinary nil.
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil, false end
    local ok, value = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil, false end
    return value, true
end

local function Flag(fn, ...)
    local value, known = Read(fn, ...)
    if known then return not not value end
end

local function Accessible(frame)
    return frame and not frame:IsForbidden()
end

local function NameFont(name)
    if not Accessible(name) or type(name.GetFont) ~= "function" then return end
    local ok, path, size, flags = pcall(name.GetFont, name)
    if not ok then return end
    for _, value in pairs({ path, size, flags }) do
        if issecretvalue and issecretvalue(value) then return end
    end
    if type(path) ~= "string" or path == "" or type(size) ~= "number"
        or size <= 0 or size ~= size or size == math.huge or type(flags) ~= "string" then return end
    return path, size, flags
end

local function SameFontSize(left, right)
    -- The client can normalize a requested font height to a nearby float.
    return math.abs(left - right) < 0.01
end

local function SameNativeFont(saved, path, flags, setupSize)
    return path == saved.path and flags == saved.flags and setupSize == saved.setupSize
end

local function RestoreNameFont(name)
    local saved = nameFonts[name]
    if not saved then pendingNameFonts[name] = nil; return end
    -- A temporarily restricted read/write must not strand our custom size
    -- after removal, a paused plate, or disabling the filter stops updates.
    pendingNameFonts[name] = true
    if Accessible(name) then
        local path, size, flags = NameFont(name)
        if not path then return end
        local setupSize = Read(function() return NamePlateSetupOptions.healthBarFontHeight end)
        -- Native layout can derive another height from our resized text, even
        -- immediately before bars return. Restore that too when the native
        -- font configuration is unchanged; preserve newer paths/flags.
        if SameFontSize(size, saved.applied) or SameNativeFont(saved, path, flags, setupSize) then
            local ok, result = pcall(name.SetFont, name, path, saved.before, flags)
            if not ok or result == false then Warn("font", L.ERROR_RESTORE_VISUAL); return end
        end
    end
    nameFonts[name] = nil
    pendingNameFonts[name] = nil
end

local function SizeName(name)
    if not db.customNameSize then return RestoreNameFont(name) end
    if name then pendingNameFonts[name] = nil end
    local path, size, flags = NameFont(name)
    if not path or type(name.SetFont) ~= "function" then return end
    local saved = nameFonts[name]
    local setupSize = Read(function() return NamePlateSetupOptions.healthBarFontHeight end)
    if saved and not SameFontSize(size, saved.applied) then
        -- UpdateAnchors derives a height from GetLineHeight, which may already
        -- include our custom size. That is not a new native font baseline.
        local derived = SameNativeFont(saved, path, flags, setupSize)
        if not derived then saved.before = size end
    end
    if saved then saved.path, saved.flags, saved.setupSize = path, flags, setupSize end
    if saved and saved.requested == db.nameSize and SameFontSize(size, saved.applied) then return end
    if not saved and SameFontSize(size, db.nameSize) then return end
    saved = saved or { before = size }
    nameFonts[name] = saved
    -- Record the attempted size before the write so error recovery can also
    -- undo a visual method that changes the font and then raises an error.
    saved.applied = db.nameSize
    saved.requested, saved.path, saved.flags, saved.setupSize = db.nameSize, path, flags, setupSize
    local ok, result = pcall(name.SetFont, name, path, db.nameSize, flags)
    local _, currentSize = NameFont(name)
    saved.applied = currentSize or saved.applied
    if not ok or result == false then
        error(ok and L.ERROR_RESTORE_VISUAL or result)
    end
end

local function VertexColor(region)
    if type(region.GetVertexColor) ~= "function" then return end
    local ok, r, g, b, a = pcall(region.GetVertexColor, region)
    if not ok then return end
    local color = { r, g, b, a }
    for index = 1, 4 do
        local value = color[index]
        if (issecretvalue and issecretvalue(value)) or type(value) ~= "number" then return end
    end
    return color
end

local function SameColor(left, right)
    for index = 1, 4 do
        if left[index] ~= right[index] then return false end
    end
    return true
end

local function RestoreNameColor(name)
    local saved = nameColors[name]
    if not saved then return end
    if Accessible(name) then
        local current = VertexColor(name)
        -- Respect any newer native colour (selection, faction, options, etc.).
        if current and SameColor(current, saved.applied) then
            local color = saved.before
            local ok = pcall(name.SetVertexColor, name, color[1], color[2], color[3], color[4])
            if not ok then
                Warn("color", L.ERROR_RESTORE_COLOR)
                return
            end
            Measure("colorWrites")
        end
    end
    nameColors[name] = nil
end

local function NameLayout(name)
    local count = Read(name.GetNumPoints, name)
    local justify = Read(name.GetJustifyH, name)
    if type(count) ~= "number" or count < 1
        or (justify ~= "LEFT" and justify ~= "CENTER" and justify ~= "RIGHT") then return end
    local layout = { justify = justify, points = {} }
    for index = 1, count do
        local ok, point, relative, relativePoint, x, y = pcall(name.GetPoint, name, index)
        if not ok then return end
        local values = { point, relative, relativePoint, x, y }
        for field = 1, 5 do
            if issecretvalue and issecretvalue(values[field]) then return end
        end
        if type(point) ~= "string" or not relative or type(relativePoint) ~= "string"
            or type(x) ~= "number" or type(y) ~= "number" then return end
        layout.points[index] = values
    end
    return layout
end

local function SamePoints(left, right)
    if #left ~= #right then return false end
    for _, point in ipairs(left) do
        local match
        for _, candidate in ipairs(right) do
            if point[1] == candidate[1] then match = candidate; break end
        end
        if not match then return false end
        for field = 2, 5 do
            if point[field] ~= match[field] then return false end
        end
    end
    return true
end

local function SameLayout(left, right)
    return left.justify == right.justify and SamePoints(left.points, right.points)
end

local function SetNameLayout(name, layout)
    name:ClearAllPoints()
    for _, point in ipairs(layout.points) do
        name:SetPoint(point[1], point[2], point[3], point[4], point[5])
    end
    name:SetJustifyH(layout.justify)
end

local function NativeNameLayout(frame)
    local style = Read(function() return NamePlateSetupOptions.unitNameAnchorStyle end)
    local styles = Read(function() return NamePlateConstants.NAME_ANCHOR_STYLES end)
    if style == nil or type(styles) ~= "table"
        or Read(C_CVar.GetCVar, "nameplateShowOnlyNameForFriendlyPlayerUnits") ~= "0" then return end
    local container = frame.HealthBarsContainer
    local text = container and container.healthBar and container.healthBar.Text
    if not container or not text then return end
    -- GetPoint is unavailable on some client nameplates. Reconstruct supported
    -- native layouts from public configuration, without calling layout helpers.
    if style == styles.InsideHealthBar then
        return { justify = "LEFT", points = {
            { "LEFT", container, "LEFT", 4, 0 },
            { "RIGHT", text, "LEFT", -2, 0 },
        } }
    end
    local spacing = Read(function() return NamePlateSetupOptions.healthBarToNameAboveSpacing end)
    if type(spacing) ~= "number" or spacing ~= spacing or math.abs(spacing) == math.huge then return end
    if style == styles.CenteredAboveHealthBar then
        return { justify = "CENTER", points = { { "BOTTOM", container, "TOP", 0, spacing } } }
    end
    if style ~= styles.AboveHealthBar then return end
    -- Only reconstruct this shape when friendly frames do not reserve a
    -- level-indicator span. Otherwise an unreadable layout cannot be restored
    -- exactly and must remain under native control.
    if Read(function() return NamePlateFriendlyFrameOptions.showLevel end) ~= false then return end
    local justify = Read(function() return NamePlateSetupOptions.nameJustificationWhenAboveHealthBar end)
    local healthInside = Read(function() return NamePlateSetupOptions.healthTextInsideBarWhenNameAboveHealthBar end)
    if (justify ~= "LEFT" and justify ~= "CENTER" and justify ~= "RIGHT")
        or type(healthInside) ~= "boolean" then return end
    return { justify = justify, points = {
        { "BOTTOMLEFT", container, "TOPLEFT", 0, spacing },
        { "RIGHT", healthInside and container or text, healthInside and "RIGHT" or "LEFT", healthInside and 0 or -2, 0 },
    } }
end

local function ClearNameWidth(name)
    if not Accessible(name) then return end
    local width = Read(name.GetWidth, name, true)
    if type(width) ~= "number" or width <= 0 or width ~= width or width == math.huge then return end
    -- Preserve explicit width independently of anchor snapshots: native anchor
    -- updates do not necessarily reset a width previously cleared by the addon.
    nameWidths[name] = width
    name:SetWidth(0)
end

local function RestoreNameWidth(name)
    local before = nameWidths[name]
    if before == nil then return end
    if Accessible(name) then
        local width = Read(name.GetWidth, name, true)
        if type(width) ~= "number" then return end
        if width == 0 then
            local ok = pcall(name.SetWidth, name, before)
            if not ok then Warn("layout", L.ERROR_RESTORE_VISUAL); return end
        end
    end
    nameWidths[name] = nil
end

local function RestoreNameLayout(frame)
    centerStatus[frame] = nil
    local saved = nameLayouts[frame]
    if not saved then return end
    if Accessible(saved.name) then
        local current = saved.applied and NameLayout(saved.name)
        local fallback = saved.applied and not current and NativeNameLayout(frame)
        if saved.applied and not current and not fallback then return end
        -- A newer native layout takes precedence over our saved snapshot.
        if not saved.applied or (current and SameLayout(current, saved.applied)
            and not SameLayout(current, saved.before))
            or fallback then
            local ok = pcall(SetNameLayout, saved.name, fallback or saved.before)
            if not ok then Warn("layout", L.ERROR_RESTORE_VISUAL); return end
        end
    end
    nameLayouts[frame] = nil
end

local function CenterName(frame)
    if not Accessible(frame.name) then return end
    -- A post-hook improves responsiveness, but failure to hook must not disable
    -- centering. Polling also detects native changes outside UpdateAnchors.
    InstallLayoutHook(frame)
    local before = NameLayout(frame.name)
    local fallback = not before
    local saved = nameLayouts[frame]
    if saved then
        if before and SameLayout(before, saved.applied) then return end
        if before then
            -- FontObject updates may reset only justification. Do not save our
            -- own centered anchors as the native full-bar layout in that case.
            if SamePoints(before.points, saved.applied.points) then before.points = saved.before.points end
            if before.justify == saved.applied.justify then before.justify = saved.before.justify end
        else
            local native = NativeNameLayout(frame)
            if not native then
                if not saved.fallback then centerStatus[frame] = "layout-unavailable"; return end
            elseif saved.fallback and SameLayout(native, saved.before)
                and Read(frame.name.GetJustifyH, frame.name) == "CENTER" then
                local count = Read(frame.name.GetNumPoints, frame.name)
                if count == #saved.applied.points or (count == nil and layoutHooks[frame]) then return end
                before = native
            else
                before = native
            end
        end
        nameLayouts[frame] = nil -- The native layout has superseded our last write.
    end
    before = before or NativeNameLayout(frame)
    if not before then centerStatus[frame] = "layout-unavailable"; return end
    local container = frame.HealthBarsContainer
    local first
    for _, point in ipairs(before.points) do
        if point[2] == container then first = point; break end
    end
    if not first then centerStatus[frame] = "no-container-anchor"; return end
    -- Preserve native vertical placement. One horizontal anchor lets Blizzard's
    -- non-wrapping FontString use its natural text width, without truncating it
    -- to the hidden health bar or reserving space for health text.
    local vertical = first[1]:match("TOP") or first[1]:match("BOTTOM") or ""
    local relativeVertical = first[3]:match("TOP") or first[3]:match("BOTTOM") or ""
    -- A single centered anchor already allows natural text width. Keep it,
    -- while still watching for subsequent style changes.
    if not fallback and #before.points == 1 and before.justify == "CENTER" and first[4] == 0
        and first[1] == vertical and first[3] == relativeVertical then
        nameLayouts[frame] = { name = frame.name, before = before, applied = before }
        centerStatus[frame] = "native-centered"
        return
    end
    local centered = { justify = "CENTER", points = {
        { vertical ~= "" and vertical or "CENTER", container,
            relativeVertical ~= "" and relativeVertical or "CENTER", 0, first[5] },
    } }
    if not fallback and SameLayout(before, centered) then
        nameLayouts[frame] = { name = frame.name, before = before, applied = before }
        centerStatus[frame] = "native-centered"
        return
    end
    saved = { name = frame.name, before = before, fallback = fallback }
    nameLayouts[frame] = saved
    SetNameLayout(frame.name, centered)
    saved.applied = centered
    centerStatus[frame] = fallback and "centered-from-style" or "centered"
end

-- NPCs must be positively distinguished from player minions. Unknown identity
-- leaves the native display alone, as it does for unknown player information.
local function IsOrdinaryNPC(unit)
    return Flag(UnitIsPlayer, unit) == false and Flag(UnitIsMinion, unit) == false
end

local function NPCNameColor(unit)
    if type(UnitSelectionColor) ~= "function" then return end
    local ok, r, g, b = pcall(UnitSelectionColor, unit)
    if not ok then return end
    local color = { r, g, b }
    for index = 1, 3 do
        local value = color[index]
        if (issecretvalue and issecretvalue(value)) or type(value) ~= "number" then return end
    end
    return { r = r, g = g, b = b }
end

local function ColorName(name, unit)
    local color
    if db.classColorsOnly and Flag(UnitIsPlayer, unit) == true then
        local class, known = Read(UnitClassBase, unit)
        color = known and type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    elseif db.includeNPCs and db.npcNameColors and IsOrdinaryNPC(unit) then
        color = NPCNameColor(unit)
    end
    if not color then return RestoreNameColor(name) end
    local current = VertexColor(name)
    if not current then return end
    local saved = nameColors[name]
    if not saved then
        saved = { before = current }
        nameColors[name] = saved
    elseif not SameColor(current, saved.applied) then
        saved.before = current
    end
    saved.applied = saved.applied or {}
    saved.applied[1], saved.applied[2], saved.applied[3], saved.applied[4] = color.r, color.g, color.b, current[4]
    if not SameColor(current, saved.applied) then
        name:SetVertexColor(saved.applied[1], saved.applied[2], saved.applied[3], saved.applied[4])
        Measure("colorWrites")
    end
end

local function Field(object, key)
    return Read(function() return object[key] end)
end

local function UnitTitle(frame, unit, minion)
    local record = plates[unit]
    if not record or record.frame ~= frame then return end
    if record.unitTitle then return record.unitTitle end
    if record.nextTitleRead and updateTime < record.nextTitleRead then return end
    -- Retry unavailable data without scanning every name update or polling tick.
    record.nextTitleRead = updateTime + 2
    local types = Enum and Enum.TooltipDataLineType
    if not types or not C_TooltipInfo then return end
    Measure("tooltipReads")
    local data = Read(C_TooltipInfo.GetUnit, unit)
    if type(data) ~= "table" then return end
    local lines = Field(data, "lines")
    if type(lines) ~= "table" then return end
    local first = Field(lines, 1)
    if type(first) ~= "table" or Field(first, "type") ~= types.UnitName then return end
    local line, ownerTitle
    if minion and types.UnitOwner then
        -- Pet/guardian ownership titles have their own line type. Their
        -- position does not depend on the NPC title or colourblind layout.
        for index = 2, #lines do
            local candidate = Field(lines, index)
            if type(candidate) == "table" and Field(candidate, "type") == types.UnitOwner then
                line, ownerTitle = candidate, true
                break
            end
        end
    end
    if not ownerTitle then
        local colorblind = Read(C_CVar.GetCVar, "colorblindmode")
        if colorblind ~= "0" and colorblind ~= "1" then return end
        -- Untyped titles use the expected slot, after the reaction line in
        -- colourblind mode. Never mistake level/type/quest lines for titles.
        line = Field(lines, colorblind == "1" and 3 or 2)
        if type(line) ~= "table" or Field(line, "type") ~= types.None then return end
    end
    local text = Field(line, "leftText")
    if type(text) ~= "string" or text == "" then return end
    -- This client can also return the level as an untyped line when no title
    -- exists. Use the game's localized label, as in ElvUI's GetTitleNPC.
    if not ownerTitle and type(LEVEL) == "string" and LEVEL ~= ""
        and text:lower():find(LEVEL:lower(), 1, true) then return end
    record.unitTitle = text
    return text
end

local function HideSubtitle(frame)
    local label = subtitleLabels[frame]
    local state = subtitleState[frame]
    if Accessible(label) and state and state.shown then
        local ok = pcall(function() label:SetText(""); label:Hide() end)
        if not ok then Warn("subtitle", L.ERROR_HIDE_LABEL) end
        if ok then state.shown, state.text = false, nil; Measure("subtitleWrites"); Measure("subtitleWrites") end
    end
end

local function ShowSubtitle(frame, unit)
    -- This sibling region must follow native name visibility explicitly.
    if Flag(frame.name.IsShown, frame.name) ~= true then return HideSubtitle(frame) end
    local text
    if db.showGuild and Flag(UnitIsPlayer, unit) == true then
        text = Read(GetGuildInfo, unit)
    elseif db.includeMinions and db.showMinionTitle and Flag(UnitIsPlayer, unit) == false
        and Flag(UnitIsMinion, unit) == true then
        text = UnitTitle(frame, unit, true)
    elseif db.includeNPCs and db.showNPCTitle and IsOrdinaryNPC(unit) then
        text = UnitTitle(frame, unit)
    end
    if type(text) ~= "string" or text == "" then return HideSubtitle(frame) end
    local label = subtitleLabels[frame]
    if not label then
        label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitleLabels[frame] = label
        label:SetWordWrap(false)
        subtitleState[frame] = {}
    end
    local state = subtitleState[frame]
    local justify = Read(frame.name.GetJustifyH, frame.name)
    local edge = justify == "LEFT" and "LEFT" or (justify == "RIGHT" and "RIGHT" or "")
    if state.edge ~= edge or state.offset ~= db.subtitleOffset or state.anchor ~= frame.name then
        label:ClearAllPoints()
        label:SetPoint("TOP" .. edge, frame.name, "BOTTOM" .. edge, 0, -db.subtitleOffset)
        state.edge, state.offset, state.anchor = edge, db.subtitleOffset, frame.name
        Measure("subtitleWrites"); Measure("subtitleWrites")
    end
    if state.size ~= db.subtitleSize then
        local font, _, flags = label:GetFont()
        label:SetFont(font, db.subtitleSize, flags)
        state.size = db.subtitleSize
        Measure("subtitleWrites")
    end
    if state.r ~= db.subtitleRed or state.g ~= db.subtitleGreen or state.b ~= db.subtitleBlue then
        label:SetTextColor(db.subtitleRed, db.subtitleGreen, db.subtitleBlue)
        state.r, state.g, state.b = db.subtitleRed, db.subtitleGreen, db.subtitleBlue
        Measure("subtitleWrites")
    end
    text = db.subtitleBrackets and ("<" .. text .. ">") or text
    if state.text ~= text then label:SetText(text); state.text = text; Measure("subtitleWrites") end
    if not state.shown then label:Show(); state.shown = true; Measure("subtitleWrites") end
end

local function RestoreNameVisuals(frame)
    RestoreNameLayout(frame)
    if frame.name then
        RestoreNameFont(frame.name)
        RestoreNameWidth(frame.name)
        RestoreNameColor(frame.name)
    end
    HideSubtitle(frame)
end

local function UpdateNameVisuals(frame, unit)
    SizeName(frame.name)
    CenterName(frame)
    if centerStatus[frame] ~= "layout-unavailable" and centerStatus[frame] ~= "no-container-anchor" then
        ClearNameWidth(frame.name)
    end
    ColorName(frame.name, unit)
    ShowSubtitle(frame, unit)
end

local function RestoreFrame(frame)
    if Accessible(frame) then RestoreNameVisuals(frame) end
    local before = nameOnlyFrames[frame]
    if not before then return end
    if Accessible(frame) then
        for piece, alpha in pairs(before) do
            if Accessible(piece) then
                local ok = pcall(piece.SetAlpha, piece, alpha)
                if not ok then
                    Warn("nameOnly", L.ERROR_RESTORE_VISUAL)
                    return
                end
                Measure("alphaWrites")
            end
        end
    end
    nameOnlyFrames[frame] = nil
end

local function PauseFrame(frame, err)
    RestoreFrame(frame)
    local record = plates[frame.unit]
    if record and record.frame == frame then record.failed = true end
    local detail = (issecretvalue and issecretvalue(err)) and L.PROTECTED_ERROR or tostring(err)
    Warn("nameOnly", string.format(L.FILTER_PAUSED, detail))
    if addon.RefreshOptions then addon.RefreshOptions() end
end

local function ShowNameOnly(frame, unit)
    if not frame.name then return end
    local before = nameOnlyFrames[frame]
    if not before then
        before = {}
        nameOnlyFrames[frame] = before
    end
    -- Only call C-backed visual methods. Calling Blizzard's Lua layout or
    -- SetShowOnlyName helpers taints fields later read by health calculations.
    -- Keep ALL addon bookkeeping outside Blizzard frames. Never read native
    -- health-bar state or pass health values through Blizzard's Lua helpers.
    local function Fade(piece)
        if piece == frame.name or piece == subtitleLabels[frame] or not Accessible(piece) then return end
        local alpha, known = Read(piece.GetAlpha, piece)
        if not known or type(alpha) ~= "number" then return end
        if before[piece] == nil then
            before[piece] = alpha
        end
        if alpha ~= 0 then piece:SetAlpha(0); Measure("alphaWrites") end
    end
    local function FadeAll(...)
        for index = 1, select("#", ...) do Fade(select(index, ...)) end
    end
    FadeAll(frame:GetChildren())
    FadeAll(frame:GetRegions())
    UpdateNameVisuals(frame, unit)
end

local function RestoreAll()
    for frame in pairs(nameOnlyFrames) do RestoreFrame(frame) end
end

local function MinionInGroup(unit)
    local party = Flag(UnitPlayerOrPetInParty, unit)
    local raid = Flag(UnitPlayerOrPetInRaid, unit)
    if party == true or raid == true then return true end
    -- Pet membership helpers do not identify every guardian or totem. For
    -- those, check the group's owners without relying on names or GUIDs.
    if not groupSnapshot then
        local grouped, inRaid = Flag(IsInGroup), Flag(IsInRaid)
        local count, known = Read(GetNumGroupMembers)
        if grouped == false then groupSnapshot = { grouped = false }
        elseif grouped == true and inRaid ~= nil and known and type(count) == "number" and count >= 1 and count <= 40 then
            local key = (inRaid and "raid" or "party") .. count
            if groupTokenKey ~= key then
                groupTokens, groupTokenSet = {}, {}
                for index = 1, count do
                    groupTokens[index] = inRaid and ("raid" .. index) or (index == 1 and "player" or "party" .. (index - 1))
                    groupTokenSet[groupTokens[index]] = true
                end
                groupTokenKey = key
            end
            groupSnapshot = { grouped = true, tokens = groupTokens, tokenSet = groupTokenSet }
        else groupSnapshot = {} end
    end
    local grouped = groupSnapshot.grouped
    if grouped == false then return false end
    if grouped == nil then return end
    local record = plates[unit]
    local previousOwner = record and record.owner
    if previousOwner and groupSnapshot.tokenSet[previousOwner] then
        Measure("ownerChecks")
        local owned = Flag(UnitIsOwnerOrControllerOfUnit, previousOwner, unit)
        if owned == true then return true end
        record.owner = nil
        if owned == nil then return end
    end
    local unknown = false
    for _, owner in ipairs(groupSnapshot.tokens) do
        Measure("ownerChecks")
        local owned = Flag(UnitIsOwnerOrControllerOfUnit, owner, unit)
        if owned == true then
            if record then record.owner = owner end
            return true
        end
        if owned == nil then unknown = true end
    end
    if unknown then return end
    return false
end

local function ShouldShowNameOnly(unit)
    if not db or not db.enabled then return false, "disabled" end
    if Flag(UnitExists, unit) ~= true then return false, "missing" end
    local friendly = Flag(UnitIsFriend, "player", unit)
    if friendly ~= true then return false, friendly == false and "enemy" or "restricted" end
    -- Never change the personal resource display, even in a party.
    local self = Flag(UnitIsUnit, unit, "player")
    if self ~= false then return false, self and "self" or "restricted" end

    local player = Flag(UnitIsPlayer, unit)
    if player ~= true then
        if player ~= false then return false, "restricted" end
        local minion = Flag(UnitIsMinion, unit)
        if minion == false then
            -- NPC display is an explicit mode, independent of player rules.
            if not db.includeNPCs then return false, "npcs-excluded" end
            if db.showNPCBars then return false, "npc-bars" end
            if db.npcShowTarget then
                local target = Flag(UnitIsUnit, unit, "target")
                if target ~= false then return false, target and "npc-target" or "restricted" end
            end
            return true, "name-only"
        end
        if minion ~= true then return false, "restricted" end
        if not db.includeMinions then return false, "minions-excluded" end
    end

    for _, rule in ipairs(SELECTION_RULES) do
        if db[rule[1]] then
            local selected = Flag(UnitIsUnit, unit, rule[2])
            if selected ~= false then return false, selected and rule[2] or "restricted" end
        end
    end

    -- Enabled rules are ORed. Only consult active rules: a disabled criterion
    -- must not keep bars visible merely because its data is restricted.
    if db.showGroup then
        if player then
            local party = Flag(UnitInParty, unit)
            local raid = Flag(UnitInRaid, unit)
            if party == true or raid == true then return false, "group" end
            if party == nil or raid == nil then return false, "restricted" end
        else
            local grouped = MinionInGroup(unit)
            -- Unknown/restricted data: leave the bar visible rather than guess.
            if grouped ~= false then return false, grouped and "group" or "restricted" end
        end
    end
    if db.showCombat then
        local combat = Flag(UnitAffectingCombat, unit)
        if combat ~= false then return false, combat and "combat" or "restricted" end
    end
    return true, "name-only"
end

InstallLayoutHook = function(frame)
    if layoutHooks[frame] ~= nil then return layoutHooks[frame] end
    if type(hooksecurefunc) ~= "function" or type(frame.UpdateAnchors) ~= "function" then return false end
    -- Hook the actual pooled frame, not the mixin whose methods were copied at
    -- creation. Never call Blizzard's Lua layout/health helpers ourselves.
    local ok = pcall(hooksecurefunc, frame, "UpdateAnchors", function(updated)
        -- Blizzard just supplied fresh geometry, so an older style snapshot
        -- must never be restored over it, even if this frame has been reused.
        nameLayouts[updated] = nil
        centerStatus[updated] = nil
        if not db or not db.enabled or not nameOnlyFrames[updated] then return end
        if not Accessible(updated) or not updated.unit or not updated.name then return end
        local synced, err = pcall(function()
            groupSnapshot = nil
            if ShouldShowNameOnly(updated.unit) then
                UpdateNameVisuals(updated, updated.unit)
            else
                RestoreNameVisuals(updated)
            end
        end)
        if not synced then PauseFrame(updated, err) end
    end)
    layoutHooks[frame] = ok
    return ok
end

local function InstallNameHook()
    if nameHookInstalled then return end
    if type(hooksecurefunc) ~= "function" or type(CompactUnitFrame_UpdateName) ~= "function" then return end
    -- Blizzard recolours names on mouseover, target and health/name updates.
    -- A secure POST-hook reapplies our visual colour in the same update, before
    -- rendering. Never call/replace its Lua updater or write its state fields.
    local ok = pcall(hooksecurefunc, "CompactUnitFrame_UpdateName", function(frame)
        if not db or not db.enabled or not nameOnlyFrames[frame] then return end
        if not Accessible(frame) or not frame.unit or not frame.name then return end
        local recoloured, err = pcall(function()
            groupSnapshot = nil
            -- Re-check the live unit: pooled frames may already represent a
            -- different player/NPC before our removal event is delivered.
            if ShouldShowNameOnly(frame.unit) then
                UpdateNameVisuals(frame, frame.unit)
            else
                RestoreNameVisuals(frame)
            end
        end)
        if not recoloured then
            PauseFrame(frame, err)
        end
    end)
    nameHookInstalled = ok
end

local function UpdatePlate(unit)
    local record = plates[unit]
    if not record or record.failed or not Accessible(record.plate) then return end
    Measure("updates")
    local frame = record.plate.UnitFrame
    -- Blizzard pools UnitFrames independently of the plate bases.
    if record.frame ~= frame then
        if record.frame then RestoreFrame(record.frame) end
        record.frame = frame
        record.unitTitle, record.nextTitleRead = nil, nil
    end
    if not Accessible(frame) or not frame.unit then return end

    if ShouldShowNameOnly(unit) then
        local ok, err = pcall(ShowNameOnly, frame, unit)
        if not ok then
            PauseFrame(frame, err) -- Do not retry a failing operation every 0.2 s.
        end
    else
        RestoreFrame(frame)
    end
end

local function UpdateAll()
    Measure("fullUpdates")
    groupSnapshot = nil
    for unit in pairs(plates) do UpdatePlate(unit) end
end

local function RemovePlate(unit)
    local record = plates[unit]
    if record and record.frame then RestoreFrame(record.frame) end
    plates[unit] = nil
    forbidden[unit] = nil
end

local function AddPlate(unit)
    RemovePlate(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    if not Accessible(plate) then
        forbidden[unit] = true
        return
    end
    plates[unit] = { plate = plate }
    UpdatePlate(unit)
end

local function ScanPlates(preserveForbidden)
    RestoreAll()
    groupSnapshot = nil
    plates = {}
    if not preserveForbidden then forbidden = {} end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if Accessible(plate) then
            local unit, known = Read(plate.GetUnit, plate)
            if known and type(unit) == "string" then AddPlate(unit) end
        end
    end
end

local function GetValue(name)
    return Read(C_CVar.GetCVar, name)
end

local function WriteValue(name, value)
    local ok, result = pcall(C_CVar.SetCVar, name, value)
    local actual = GetValue(name)
    if not ok or result == false or actual ~= value then
        Warn(name, string.format(L.ERROR_SET_CVAR, name))
        return false
    end
    return true
end

local function RefreshOptions()
    if addon.RefreshOptions then addon.RefreshOptions() end
end

local function IsDistanceCVar(name)
    for _, candidate in ipairs(DISTANCE_CVARS) do
        if name == candidate then return true end
    end
    return false
end

local function DistanceValue(name)
    local raw, known = GetValue(name)
    if not known or (type(raw) ~= "string" and type(raw) ~= "number") then return end
    local value = tonumber(raw)
    if value and value == value and value >= 0 and value < math.huge then return value, tostring(raw) end
end

-- Exploratory controls edit the character's live CVars, independently of the
-- filter and profiles. Loading, reloading and changing profiles never apply a
-- distance. Keep a separate restoration baseline across /reload for each test.
function addon.GetDistanceState(name)
    if not IsDistanceCVar(name) then return { status = "unavailable", canEdit = false } end
    local value = DistanceValue(name)
    local attempt = distanceAttempts[name]
    local status = "ready"
    if value == nil then status = "unavailable"
    elseif InCombatLockdown() then status = "combat"
    elseif attempt and attempt.failed then status = "error"
    elseif attempt and attempt.requested ~= value then status = "limited" end
    return { value = value, requested = attempt and attempt.requested,
        status = status, canEdit = characterDB ~= nil and value ~= nil and not InCombatLockdown() }
end

local function WriteDistanceValue(name, value)
    applyingDistanceCVars = true
    local ok, result = pcall(C_CVar.SetCVar, name, value)
    applyingDistanceCVars = false
    local actual, raw = DistanceValue(name)
    return actual, raw, ok and result ~= false and actual ~= nil
end

function addon.SetDistanceCVar(name, value)
    if not characterDB or not IsDistanceCVar(name) or type(value) ~= "number"
        or value ~= value or value < 1 or value > 45 or value ~= math.floor(value) then return false end
    if InCombatLockdown() then RefreshOptions(); return false end
    local current, before = DistanceValue(name)
    if current == nil then RefreshOptions(); return false end
    if current == value then distanceAttempts[name] = nil; RefreshOptions(); return true end
    local originals = characterDB.distanceTestCVars
    local saved = originals[name]
    -- A manual change starts a new baseline rather than later undoing it.
    if type(saved) ~= "table" or saved.applied ~= before then
        saved = { before = before }
        originals[name] = saved
    end
    local actual, raw, ok = WriteDistanceValue(name, tostring(value))
    distanceAttempts[name] = { requested = value, actual = raw, failed = not ok }
    if raw then
        saved.applied = raw
        if raw == saved.before then originals[name] = nil end
    end
    RefreshOptions()
    return ok and actual == value
end

function addon.CanRestoreDistanceCVars()
    return characterDB ~= nil and next(characterDB.distanceTestCVars) ~= nil and not InCombatLockdown()
end

function addon.RestoreDistanceCVars()
    if not addon.CanRestoreDistanceCVars() then RefreshOptions(); return end
    local originals = characterDB.distanceTestCVars
    for _, name in ipairs(DISTANCE_CVARS) do
        local saved = originals[name]
        if type(saved) == "table" and type(saved.before) == "string" then
            local current, raw = DistanceValue(name)
            if current ~= nil then
                if saved.applied == nil or raw == saved.applied then
                    local actual, applied, ok = WriteDistanceValue(name, saved.before)
                    distanceAttempts[name] = { requested = tonumber(saved.before), actual = applied, failed = not ok }
                    if ok and actual == tonumber(saved.before) then
                        originals[name], distanceAttempts[name] = nil, nil
                    elseif applied then saved.applied = applied end
                else
                    -- Respect settings changed elsewhere after the last slider edit.
                    originals[name], distanceAttempts[name] = nil, nil
                end
            end
        elseif saved ~= nil then originals[name] = nil end
    end
    RefreshOptions()
end

-- Keep originals across /reload. /sfn off restores only settings still at the
-- value we applied, so later manual changes are respected. Never write in combat.
local function ApplyCVars()
    if not db then return end
    if InCombatLockdown() then
        -- Visual-only edits need no protected writes and no combat warning.
        pendingCVars = false
        for _, setting in ipairs(CVARS) do
            local current, known = GetValue(setting.name)
            local wanted = db.enabled and (not setting.option or db[setting.option])
            local saved = characterDB.originalCVars[setting.name]
            if known and current ~= nil then
                if wanted and current ~= setting.value then pendingCVars = true
                elseif not wanted and saved then
                    if current == saved.applied and current ~= saved.before then pendingCVars = true
                    else characterDB.originalCVars[setting.name] = nil end
                end
            end
        end
        RefreshOptions()
        return
    end
    pendingCVars = false
    applyingCVars = true
    for _, setting in ipairs(CVARS) do
        local name = setting.name
        local current, known = GetValue(name)
        -- Restoration state belongs to this character's game settings, never
        -- to the shared preference profile or to the currently selected mode.
        local saved = characterDB.originalCVars[name]
        local wanted = db.enabled and (not setting.option or db[setting.option])
        cvarProblems[name] = nil
        if known and current ~= nil then
            if wanted then
                if current ~= setting.value then
                    if not saved then
                        saved = { before = current, applied = setting.value }
                        characterDB.originalCVars[name] = saved
                    end
                    if not WriteValue(name, setting.value) then pendingCVars = true; cvarProblems[name] = "error" end
                end
            elseif saved then
                if current == saved.applied and not WriteValue(name, saved.before) then
                    pendingCVars = true
                    cvarProblems[name] = "error"
                else
                    characterDB.originalCVars[name] = nil
                end
            end
        elseif wanted then
            cvarProblems[name] = "unavailable"
            Warn(name, string.format(L.ERROR_CVAR_UNAVAILABLE, name))
        elseif saved then
            pendingCVars = true
            cvarProblems[name] = "unavailable"
        end
    end
    applyingCVars = false
    RefreshOptions()
end

local function FillDefaults(profile)
    for key, value in pairs(DEFAULTS) do
        local candidate, range = profile[key], RANGES[key]
        if type(candidate) ~= type(value) or (range and (candidate ~= candidate or candidate < range[1] or candidate > range[2])) then
            profile[key] = value
        end
    end
end

local function ProfileSettings(scope)
    if scope == "global" then
        if type(globalDB.profile) ~= "table" then
            -- Seed once, when someone first chooses Global. Copy only feature
            -- preferences, excluding CVar originals and the profile selector.
            globalDB.profile = {}
            for key in pairs(DEFAULTS) do globalDB.profile[key] = characterDB[key] end
        end
        FillDefaults(globalDB.profile)
        return globalDB.profile
    end
    return characterDB
end

local function RefreshPreferences()
    groupSnapshot = nil
    for _, record in pairs(plates) do record.unitTitle, record.nextTitleRead, record.owner = nil, nil, nil end
    if not db.enabled then RestoreAll() end
    if not db.classColorsOnly then for name in pairs(nameColors) do RestoreNameColor(name) end end
    ApplyCVars()
    UpdateAll()
end

function addon.RestoreDefaults()
    if not db then return end
    for key, value in pairs(DEFAULTS) do db[key] = value end
    RefreshPreferences()
end

function addon.CopyProfile(destination)
    if not db or (destination ~= "character" and destination ~= "global") then return end
    local target = ProfileSettings(destination)
    if target == db then return end
    for key in pairs(DEFAULTS) do target[key] = db[key] end
    -- Copy feature preferences only; CVar originals stay on this character.
    RefreshOptions()
end

function addon.GetProfile()
    return characterDB and characterDB.profileScope
end

function addon.SetProfile(scope)
    if not characterDB or (scope ~= "global" and scope ~= "character") then return end
    if scope == characterDB.profileScope then return end
    RestoreAll()
    characterDB.profileScope = scope
    db = ProfileSettings(scope)
    RefreshPreferences()
end

-- Both the options panel and slash commands use the same update path.
local function SetOption(key, value)
    if not db then return end
    if DEFAULTS[key] == nil then return end
    if type(value) ~= type(DEFAULTS[key]) then return end
    local range = RANGES[key]
    if range and (value ~= value or value < range[1] or value > range[2]) then return end
    db[key] = value
    if key == "includeNPCs" or key == "showNPCTitle" or key == "includeMinions" or key == "showMinionTitle" then
        for _, record in pairs(plates) do record.unitTitle, record.nextTitleRead = nil, nil end
    end
    if not db.enabled then RestoreAll() end
    if not db.classColorsOnly then
        for name in pairs(nameColors) do RestoreNameColor(name) end
    end
    ApplyCVars()
    UpdateAll()
end

addon.SetOption = SetOption

-- A picker drag changes all three channels together, with one visual refresh.
function addon.SetSubtitleColor(r, g, b)
    if not db then return end
    for index = 1, 3 do
        local value = select(index, r, g, b)
        if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return end
    end
    db.subtitleRed, db.subtitleGreen, db.subtitleBlue = r, g, b
    UpdateAll()
    RefreshOptions()
end

addon.GetOptions = function()
    if not db then return end
    return db, pendingCVars
end

local SETTING_LABELS = { "SETTING_PLAYERS", "SETTING_NAME_MODE", "SETTING_COLORS", "SETTING_MINIONS", "SETTING_NPCS", "SETTING_SIMPLIFICATION" }
function addon.GetHealthState()
    if not db then return "unavailable", {} end
    local issues, state = {}, nil
    for _, setting in ipairs(CVARS) do
        local wanted = db.enabled and (not setting.option or db[setting.option])
        local saved = characterDB.originalCVars[setting.name]
        local actual, known = GetValue(setting.name)
        local expected = wanted and setting.value or (saved and saved.before)
        -- When releasing ownership, an unrelated manual value is respected.
        local restoring = not wanted and saved and (not known or actual == nil or actual == saved.applied)
        if wanted or restoring then
            local kind
            if not known or actual == nil then kind = "unavailable"
            elseif actual ~= expected then
                kind = pendingCVars and InCombatLockdown() and "combat" or cvarProblems[setting.name] or "conflict"
            end
            if kind then
                issues[#issues + 1] = { name = setting.name, actual = actual, expected = expected, kind = kind }
                if state ~= "unavailable" and (kind == "unavailable" or state ~= "error" and (kind == "error" or not state)) then state = kind end
            end
        end
    end
    if db.enabled then
        for _, record in pairs(plates) do if record.failed then state = "error"; break end end
    end
    return state or (db.enabled and "ready" or "disabled"), issues
end

function addon.GetHealthSummary()
    local state, issues = addon.GetHealthState()
    local lines = { L["HEALTH_" .. state:upper()] }
    for _, issue in ipairs(issues) do
        for index, setting in ipairs(CVARS) do
            if setting.name == issue.name then
                lines[#lines + 1] = string.format(L.HEALTH_DETAIL, L[SETTING_LABELS[index]], L["HEALTH_" .. issue.kind:upper()])
            end
        end
    end
    local failed = 0
    if db and db.enabled then
        for _, record in pairs(plates) do if record.failed then failed = failed + 1 end end
    end
    if failed > 0 then lines[#lines + 1] = string.format(L.HEALTH_VISUAL, failed) end
    return table.concat(lines, "\n")
end

function addon.GetRuleSummary()
    if not db then return "" end
    local rules = {}
    for _, rule in ipairs({ { "showGroup", "RULE_GROUP" }, { "showCombat", "RULE_COMBAT" },
        { "showTarget", "RULE_TARGET" }, { "showFocus", "RULE_FOCUS" }, { "showMouseover", "RULE_MOUSEOVER" } }) do
        if db[rule[1]] then rules[#rules + 1] = L[rule[2]] end
    end
    return string.format(L.RULE_SUMMARY, #rules > 0 and table.concat(rules, ", ") or L.RULE_ALL_NAMES)
end

function addon.Repair()
    if not db then return end
    warnings, lastError = {}, nil
    ApplyCVars()
    groupSnapshot = nil
    ScanPlates(true)
    RefreshOptions()
end

local function ExplainUnit(unit)
    local _, reason = ShouldShowNameOnly(unit)
    if not db or not db.enabled then return reason end
    if forbidden[unit] then return "forbidden" end
    local record = plates[unit]
    if not record then
        for token, candidate in pairs(plates) do
            if Flag(UnitIsUnit, token, unit) == true then record = candidate; break end
        end
    end
    if not record then return "no-plate", reason end
    if record then
        if record.failed then return "failed" end
        if not Accessible(record.plate) then return "forbidden" end
        if not record.plate.UnitFrame then return "no-plate", reason end
        if not Accessible(record.plate.UnitFrame) then return "forbidden" end
    end
    return reason
end
addon.ExplainUnit = ExplainUnit

local function ReasonText(reason)
    return L["REASON_" .. reason:gsub("-", "_"):upper()] or reason
end

local function Count(entries)
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    return count
end

local function Status(emit)
    emit = emit or Say
    local version, build, _, interface = GetBuildInfo()
    emit(string.format(L.STATUS_HEADER, VERSION, db.enabled and L.VALUE_ENABLED or L.VALUE_DISABLED,
        version, build, interface))
    emit(string.format(L.STATUS_PROFILE, characterDB.profileScope == "global"
        and L.VALUE_PROFILE_GLOBAL or L.VALUE_PROFILE_CHARACTER))
    emit(string.format(L.STATUS_COUNTS, Count(plates), Count(nameOnlyFrames), Count(forbidden)))
    emit(string.format(L.STATUS_COLORS, db.classColorsOnly and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_GUILD, db.showGuild and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_MINION_TITLE, db.showMinionTitle and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_NPCS, db.includeNPCs and L.VALUE_YES or L.VALUE_NO,
        db.showNPCBars and L.VALUE_YES or L.VALUE_NO, db.showNPCTitle and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_RULES, db.showGroup and L.VALUE_YES or L.VALUE_NO,
        db.showCombat and L.VALUE_YES or L.VALUE_NO, db.showTarget and L.VALUE_YES or L.VALUE_NO,
        db.includeMinions and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_SELECTIONS, db.showFocus and L.VALUE_YES or L.VALUE_NO,
        db.showMouseover and L.VALUE_YES or L.VALUE_NO, db.npcShowTarget and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_NAME_SIZE, db.customNameSize and L.VALUE_YES or L.VALUE_NO, db.nameSize))
    emit(string.format(L.STATUS_SUBTITLE, db.subtitleSize, db.subtitleOffset,
        db.subtitleRed, db.subtitleGreen, db.subtitleBlue, db.subtitleBrackets and L.VALUE_YES or L.VALUE_NO))
    for _, setting in ipairs(CVARS) do
        local value = GetValue(setting.name)
        emit(string.format(L.STATUS_CVAR, setting.name, tostring(value or L.VALUE_UNAVAILABLE)))
    end
    for _, name in ipairs(DISTANCE_CVARS) do
        local value = DistanceValue(name)
        emit(string.format(L.STATUS_CVAR, name, tostring(value or L.VALUE_UNAVAILABLE)))
    end
    local state, issues = addon.GetHealthState()
    emit(string.format(L.STATUS_HEALTH, L["HEALTH_" .. state:upper()]))
    for _, issue in ipairs(issues) do
        emit(string.format(L.STATUS_ISSUE, issue.name, tostring(issue.actual or L.VALUE_UNAVAILABLE),
            tostring(issue.expected or L.VALUE_UNAVAILABLE), L["HEALTH_" .. issue.kind:upper()]))
    end
    if pendingCVars and InCombatLockdown() then emit(L.STATUS_PENDING) end
    if lastError then emit(string.format(L.STATUS_LAST_ERROR, lastError) .. " " .. L.HISTORY_NOTE) end
    emit(string.format(L.STATUS_METRICS, metricsEnabled and L.VALUE_YES or L.VALUE_NO,
        metrics.updates, metrics.fullUpdates, metrics.alphaWrites, metrics.colorWrites,
        metrics.subtitleWrites, metrics.tooltipReads, metrics.ownerChecks))
    emit(L.UI_RESTRICTIONS)
end

local function DescribeFlag(fn, ...)
    local value = Flag(fn, ...)
    if value == nil then return L.VALUE_UNAVAILABLE end
    return value and L.VALUE_YES or L.VALUE_NO
end

local function CenterDiagnostics(frame)
    if not Accessible(frame) or not Accessible(frame.name) then return "nameCenter=unavailable" end
    local justify = Read(frame.name.GetJustifyH, frame.name)
    local width = Read(frame.name.GetWidth, frame.name)
    local explicitWidth = Read(frame.name.GetWidth, frame.name, true)
    local truncated = Flag(frame.name.IsTruncated, frame.name)
    local style = Read(function() return NamePlateSetupOptions.unitNameAnchorStyle end)
    local _, fontSize = NameFont(frame.name)
    return "nameCenter=" .. (centerStatus[frame] or "inactive")
        .. "; justify=" .. (type(justify) == "string" and justify or "unavailable")
        .. "; layout=" .. (NameLayout(frame.name) and "readable" or "unavailable")
        .. "; layoutHook=" .. (layoutHooks[frame] and "installed" or "unavailable")
        .. "; nameWidth=" .. (type(width) == "number" and tostring(width) or "unavailable")
        .. "; explicitWidth=" .. (type(explicitWidth) == "number" and tostring(explicitWidth) or "unavailable")
        .. "; truncated=" .. (truncated == nil and "unavailable" or tostring(truncated))
        .. "; anchorStyle=" .. ((type(style) == "string" or type(style) == "number") and tostring(style) or "unavailable")
        .. "; nameFontSize=" .. (fontSize and tostring(fontSize) or "unavailable")
end

local function DebugTarget()
    if Flag(UnitExists, "target") ~= true then
        Say(L.TARGET_PROMPT)
        return
    end
    Say(string.format(L.TARGET_FLAGS, DescribeFlag(UnitIsPlayer, "target"),
        DescribeFlag(UnitIsFriend, "player", "target"), DescribeFlag(UnitInParty, "target"),
        DescribeFlag(UnitInRaid, "target"), DescribeFlag(UnitIsMinion, "target"),
        DescribeFlag(UnitPlayerOrPetInParty, "target"), DescribeFlag(UnitPlayerOrPetInRaid, "target"),
        DescribeFlag(UnitAffectingCombat, "target")))
    Say(string.format(L.TARGET_DISPLAY,
        ShouldShowNameOnly("target") and L.VALUE_NAME_ONLY or L.VALUE_NORMAL_DISPLAY))
    Say(string.format(L.STATUS_REASON, ReasonText(ExplainUnit("target"))))
    for token, record in pairs(plates) do
        if Flag(UnitIsUnit, token, "target") == true then
            Say(CenterDiagnostics(record.frame))
            break
        end
    end
end

addon.PrintStatus = function() Status() end
addon.DebugTarget = DebugTarget
function addon.BuildReport()
    local lines = {}
    Status(function(line) lines[#lines + 1] = line end)
    lines[#lines + 1] = addon.GetRuleSummary()
    if Flag(UnitExists, "target") == true then
        lines[#lines + 1] = string.format(L.STATUS_REASON, ReasonText(ExplainUnit("target")))
    end
    local tokens = {}
    for unit in pairs(plates) do tokens[#tokens + 1] = unit end
    for unit in pairs(forbidden) do tokens[#tokens + 1] = unit end
    table.sort(tokens)
    for _, unit in ipairs(tokens) do
        local record = plates[unit]
        local actual = record and record.frame and nameOnlyFrames[record.frame] and L.VALUE_NAME_ONLY or L.VALUE_NORMAL_DISPLAY
        lines[#lines + 1] = unit .. ": " .. actual .. "; " .. ReasonText(ExplainUnit(unit))
        if record then lines[#lines + 1] = "  " .. CenterDiagnostics(record.frame) end
    end
    return table.concat(lines, "\n")
end

SLASH_SMARTFRIENDLYNAMEPLATES1 = "/sfn"
SlashCmdList.SMARTFRIENDLYNAMEPLATES = function(input)
    if not db then return end
    local command, argument = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "on" or command == "off" then
        SetOption("enabled", command == "on")
        Say(db.enabled and L.CMD_FILTER_ON
            or L.CMD_FILTER_OFF)
        if pendingCVars and InCombatLockdown() then Say(L.CMD_PENDING) end
    elseif command == "colors" and (argument == "on" or argument == "off") then
        SetOption("classColorsOnly", argument == "on")
        Say(db.classColorsOnly and L.CMD_COLORS_ON
            or L.CMD_COLORS_OFF)
    elseif command == "status" then
        Status()
    elseif command == "retry" then
        addon.Repair()
        Say(InCombatLockdown() and L.CMD_PENDING or L.CMD_REPAIRED)
    elseif command == "report" then
        if addon.ShowReport then addon.ShowReport() else Say(addon.BuildReport()) end
    elseif command == "metrics" then
        if argument == "on" or argument == "off" then addon.SetMetricsEnabled(argument == "on")
        elseif argument == "reset" then addon.ResetMetrics() end
        Status()
    elseif command == "debug" then
        DebugTarget()
    elseif command == "" or command == "options" then
        if InCombatLockdown() then
            Say(L.CMD_OPEN_COMBAT)
        elseif not addon.OpenOptions or not addon.OpenOptions() then
            Say(L.CMD_FIND_OPTIONS)
        end
    else
        Say(L.CMD_HELP .. " | retry | report | metrics on/off/reset")
    end
end

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == ADDON_NAME then
            SmartFriendlyNameplatesDB = type(SmartFriendlyNameplatesDB) == "table" and SmartFriendlyNameplatesDB or {}
            characterDB = SmartFriendlyNameplatesDB
            characterDB.nameWidthPercent = nil -- Remove the retired experimental setting.
            FillDefaults(characterDB)
            if type(characterDB.originalCVars) ~= "table" then characterDB.originalCVars = {} end
            if type(characterDB.distanceTestCVars) ~= "table" then characterDB.distanceTestCVars = {} end
            if characterDB.profileScope ~= "global" then characterDB.profileScope = "character" end
            SmartFriendlyNameplatesGlobalDB = type(SmartFriendlyNameplatesGlobalDB) == "table"
                and SmartFriendlyNameplatesGlobalDB or {}
            globalDB = SmartFriendlyNameplatesGlobalDB
            db = ProfileSettings(characterDB.profileScope)
            addon.RegisterOptions()
        end
        InstallNameHook()
        if db and nameHookInstalled then driver:UnregisterEvent("ADDON_LOADED") end
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon.RegisterOptions()
        InstallNameHook()
        ApplyCVars()
        ScanPlates()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingCVars then ApplyCVars() end
        UpdateAll()
        RefreshOptions()
    elseif event == "PLAYER_REGEN_DISABLED" then
        RefreshOptions()
    elseif event == "CVAR_UPDATE" then
        if applyingCVars or applyingDistanceCVars or not db then return end
        for _, name in ipairs(DISTANCE_CVARS) do
            if name:lower() == tostring(unit):lower() then
                local _, raw = DistanceValue(name)
                local attempt = distanceAttempts[name]
                if attempt and attempt.actual ~= raw then distanceAttempts[name] = nil end
                RefreshOptions()
                return
            end
        end
        for _, setting in ipairs(CVARS) do
            if setting.name:lower() == tostring(unit):lower() then
                cvarProblems[setting.name] = nil
                local value = GetValue(setting.name)
                if db.enabled and (not setting.option or db[setting.option]) and value ~= setting.value then
                    if setting.enforce and value ~= nil then
                        -- Simplified plates hide names; keep this menu at None.
                        -- ApplyCVars defers the protected change during combat.
                        ApplyCVars()
                        UpdateAll()
                    else
                        Warn("conflict-" .. setting.name, L.CMD_CONFLICT)
                    end
                end
                RefreshOptions()
                return
            end
        end
        if unit == "colorblindmode" then
            for _, record in pairs(plates) do record.unitTitle, record.nextTitleRead = nil, nil end
            UpdateAll()
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        AddPlate(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" or event == "FORBIDDEN_NAME_PLATE_UNIT_REMOVED" then
        RemovePlate(unit)
    elseif event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" then
        RemovePlate(unit)
        forbidden[unit] = true -- No request for the forbidden frame, even for diagnostics.
    elseif event == "UNIT_FLAGS" or event == "UNIT_FACTION" or event == "UNIT_NAME_UPDATE" then
        groupSnapshot = nil
        local function UpdateMatched(token, record)
            if event == "UNIT_NAME_UPDATE" then record.unitTitle, record.nextTitleRead = nil, nil end
            if event == "UNIT_FACTION" then record.owner = nil end
            UpdatePlate(token)
        end
        if plates[unit] then UpdateMatched(unit, plates[unit])
        elseif type(unit) == "string" then
            -- Events may use aliases such as target/party1 instead of nameplate1.
            for token, record in pairs(plates) do
                if Flag(UnitIsUnit, token, unit) == true then UpdateMatched(token, record) end
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if db and (db.showTarget or db.npcShowTarget) then UpdateAll() end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        if db and db.showFocus then UpdateAll() end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if db and db.showMouseover then UpdateAll() end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
        for token, record in pairs(plates) do
            record.owner = nil
            if event == "UNIT_PET" and Flag(UnitIsMinion, token) == true then
                record.unitTitle, record.nextTitleRead = nil, nil
            end
        end
        UpdateAll()
    else
        UpdateAll()
    end
end)

driver:SetScript("OnUpdate", function(_, elapsed)
    updateTime = updateTime + elapsed
    if not db or ((not db.enabled or not next(plates)) and not next(pendingNameFonts)) then return end
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < INTERVAL then return end
    elapsedSinceUpdate = 0
    for name in pairs(pendingNameFonts) do RestoreNameFont(name) end
    -- Other players can enter/leave combat without our own combat changing.
    if db.enabled and next(plates) then UpdateAll() end
end)

for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "FORBIDDEN_NAME_PLATE_UNIT_ADDED", "FORBIDDEN_NAME_PLATE_UNIT_REMOVED",
    "GROUP_ROSTER_UPDATE", "UNIT_FLAGS", "UNIT_FACTION", "PLAYER_TARGET_CHANGED",
    "UNIT_PET", "UNIT_NAME_UPDATE", "PLAYER_GUILD_UPDATE",
    "CVAR_UPDATE", "PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT",
}) do
    driver:RegisterEvent(event)
end
