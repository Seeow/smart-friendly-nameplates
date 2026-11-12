-- SPDX-License-Identifier: MIT
-- WoW Forever 1.60.1. No dependency; only ordinary, accessible nameplates.
local ADDON_NAME, addon = ...
local L = addon.L
local VERSION = "0.2.0"
addon.VERSION = VERSION
local DEFAULTS = {
    enabled = true,
    classColorsOnly = true,
    showGroup = true,
    showCombat = true,
    showTarget = false,
    includeMinions = false,
    showGuild = false,
    includeNPCs = false,
    showNPCBars = false,
    showNPCTitle = true,
    npcNameColors = true,
    showFocus = false,
    showMouseover = false,
    npcShowTarget = false,
    subtitleSize = 12,
    subtitleOffset = 2,
    subtitleRed = 0.7,
    subtitleGreen = 0.85,
    subtitleBlue = 0.7,
    subtitleBrackets = true,
}
addon.DEFAULTS = DEFAULTS
local RANGES = { subtitleSize = { 8, 24 }, subtitleOffset = { 0, 12 },
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
}

local driver = CreateFrame("Frame")
local db, characterDB, globalDB
local plates, forbidden = {}, {}
local nameOnlyFrames = setmetatable({}, { __mode = "k" })
local nameColors = setmetatable({}, { __mode = "k" })
local subtitleLabels = setmetatable({}, { __mode = "k" })
local subtitleState = setmetatable({}, { __mode = "k" })
local warnings = {}
local pendingCVars = false
local elapsedSinceUpdate = 0
local updateTime = 0
local lastError
local nameHookInstalled = false
local applyingCVars = false
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

local function NPCTitle(frame, unit)
    local record = plates[unit]
    if not record or record.frame ~= frame then return end
    if record.npcTitle then return record.npcTitle end
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
    local colorblind = Read(C_CVar.GetCVar, "colorblindmode")
    if colorblind ~= "0" and colorblind ~= "1" then return end
    -- In colourblind mode the native tooltip inserts a reaction line after
    -- the name. Titles are untyped; a level/type/quest line is never a title.
    local line = Field(lines, colorblind == "1" and 3 or 2)
    if type(line) ~= "table" or Field(line, "type") ~= types.None then return end
    local text = Field(line, "leftText")
    if type(text) ~= "string" or text == "" then return end
    record.npcTitle = text
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
    elseif db.includeNPCs and db.showNPCTitle and IsOrdinaryNPC(unit) then
        text = NPCTitle(frame, unit)
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
    if frame.name then
        RestoreNameColor(frame.name)
    end
    HideSubtitle(frame)
end

local function UpdateNameVisuals(frame, unit)
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

local function InstallNameHook()
    if nameHookInstalled then return end
    if type(hooksecurefunc) ~= "function" or type(CompactUnitFrame_UpdateName) ~= "function" then return end
    -- Blizzard recolours names on mouseover, target and health/name updates.
    -- A secure POST-hook reapplies our visual colour in the same update, before
    -- rendering. Never call/replace its Lua updater or write its state fields.
    local ok = pcall(hooksecurefunc, "CompactUnitFrame_UpdateName", function(frame)
        if not db or not db.enabled or not nameOnlyFrames[frame] then return end
        if not Accessible(frame) or not frame.unit or not frame.name then return end
        local recoloured = pcall(function()
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
            Warn("colorHook", L.ERROR_COLOR_SYNC)
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
        record.npcTitle, record.nextTitleRead = nil, nil
    end
    if not Accessible(frame) or not frame.unit then return end

    if ShouldShowNameOnly(unit) then
        local ok, err = pcall(ShowNameOnly, frame, unit)
        if not ok then
            RestoreFrame(frame)
            record.failed = true -- Do not retry a failing operation every 0.2 s.
            local detail = (issecretvalue and issecretvalue(err)) and L.PROTECTED_ERROR or tostring(err)
            Warn("nameOnly", string.format(L.FILTER_PAUSED, detail))
            if addon.RefreshOptions then addon.RefreshOptions() end
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
    for _, record in pairs(plates) do record.npcTitle, record.nextTitleRead, record.owner = nil, nil, nil end
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

local PRESETS = {
    minimal = { showGroup = false, showCombat = false },
    group = { showGroup = true, showCombat = false },
    default = {},
    exploration = { includeNPCs = true },
}
function addon.ApplyPreset(id)
    if not db or not PRESETS[id] then return end
    -- Presets change display behaviour, preserving the user's subtitle style.
    for key, value in pairs(DEFAULTS) do
        if not RANGES[key] and key ~= "subtitleBrackets" then db[key] = value end
    end
    for key, value in pairs(PRESETS[id]) do db[key] = value end
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
    if key == "includeNPCs" or key == "showNPCTitle" then
        for _, record in pairs(plates) do record.npcTitle, record.nextTitleRead = nil, nil end
    end
    if not db.enabled then RestoreAll() end
    if not db.classColorsOnly then
        for name in pairs(nameColors) do RestoreNameColor(name) end
    end
    ApplyCVars()
    UpdateAll()
end

addon.SetOption = SetOption
addon.GetOptions = function()
    if not db then return end
    return db, pendingCVars
end

local SETTING_LABELS = { "SETTING_PLAYERS", "SETTING_NAME_MODE", "SETTING_COLORS", "SETTING_MINIONS", "SETTING_NPCS" }
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
    emit(string.format(L.STATUS_NPCS, db.includeNPCs and L.VALUE_YES or L.VALUE_NO,
        db.showNPCBars and L.VALUE_YES or L.VALUE_NO, db.showNPCTitle and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_RULES, db.showGroup and L.VALUE_YES or L.VALUE_NO,
        db.showCombat and L.VALUE_YES or L.VALUE_NO, db.showTarget and L.VALUE_YES or L.VALUE_NO,
        db.includeMinions and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_SELECTIONS, db.showFocus and L.VALUE_YES or L.VALUE_NO,
        db.showMouseover and L.VALUE_YES or L.VALUE_NO, db.npcShowTarget and L.VALUE_YES or L.VALUE_NO))
    emit(string.format(L.STATUS_SUBTITLE, db.subtitleSize, db.subtitleOffset,
        db.subtitleRed, db.subtitleGreen, db.subtitleBlue, db.subtitleBrackets and L.VALUE_YES or L.VALUE_NO))
    for _, setting in ipairs(CVARS) do
        local value = GetValue(setting.name)
        emit(string.format(L.STATUS_CVAR, setting.name, tostring(value or L.VALUE_UNAVAILABLE)))
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
    elseif event == "CVAR_UPDATE" then
        if applyingCVars or not db then return end
        for _, setting in ipairs(CVARS) do
            if setting.name:lower() == tostring(unit):lower() then
                cvarProblems[setting.name] = nil
                local value = GetValue(setting.name)
                if db.enabled and (not setting.option or db[setting.option]) and value ~= setting.value then
                    Warn("conflict-" .. setting.name, L.CMD_CONFLICT)
                end
                RefreshOptions()
                return
            end
        end
        if unit == "colorblindmode" then
            for _, record in pairs(plates) do record.npcTitle, record.nextTitleRead = nil, nil end
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
            if event == "UNIT_NAME_UPDATE" then record.npcTitle, record.nextTitleRead = nil, nil end
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
        for _, record in pairs(plates) do record.owner = nil end
        UpdateAll()
    else
        UpdateAll()
    end
end)

driver:SetScript("OnUpdate", function(_, elapsed)
    updateTime = updateTime + elapsed
    if not db or not db.enabled or not next(plates) then return end
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < INTERVAL then return end
    elapsedSinceUpdate = 0
    -- Other players can enter/leave combat without our own combat changing.
    UpdateAll()
end)

for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "FORBIDDEN_NAME_PLATE_UNIT_ADDED", "FORBIDDEN_NAME_PLATE_UNIT_REMOVED",
    "GROUP_ROSTER_UPDATE", "UNIT_FLAGS", "UNIT_FACTION", "PLAYER_TARGET_CHANGED",
    "UNIT_PET", "UNIT_NAME_UPDATE", "PLAYER_GUILD_UPDATE",
    "CVAR_UPDATE", "PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT",
}) do
    driver:RegisterEvent(event)
end
