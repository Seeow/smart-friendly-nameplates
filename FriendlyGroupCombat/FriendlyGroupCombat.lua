-- SPDX-License-Identifier: MIT
-- WoW Forever 1.60.1. No dependency; only ordinary, accessible nameplates.
local ADDON_NAME, addon = ...
local L = addon.L
local VERSION = "0.1.14"
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
}
addon.DEFAULTS = DEFAULTS
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
local warnings = {}
local pendingCVars = false
local elapsedSinceUpdate = 0
local updateTime = 0
local lastError
local nameHookInstalled = false

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
    saved.applied = { color.r, color.g, color.b, current[4] }
    name:SetVertexColor(saved.applied[1], saved.applied[2], saved.applied[3], saved.applied[4])
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
    if Accessible(label) then
        local ok = pcall(function() label:SetText(""); label:Hide() end)
        if not ok then Warn("subtitle", L.ERROR_HIDE_LABEL) end
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
        label:SetTextColor(0.7, 0.85, 0.7)
        label:SetWordWrap(false)
    end
    local justify = Read(frame.name.GetJustifyH, frame.name)
    local edge = justify == "LEFT" and "LEFT" or (justify == "RIGHT" and "RIGHT" or "")
    label:ClearAllPoints()
    label:SetPoint("TOP" .. edge, frame.name, "BOTTOM" .. edge, 0, -2)
    label:SetText("<" .. text .. ">")
    label:Show()
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
        if before[piece] == nil then
            local alpha, known = Read(piece.GetAlpha, piece)
            if not known or type(alpha) ~= "number" then return end
            before[piece] = alpha
        end
        piece:SetAlpha(0)
    end
    for _, child in ipairs({ frame:GetChildren() }) do Fade(child) end
    for _, region in ipairs({ frame:GetRegions() }) do Fade(region) end
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
    local grouped = Flag(IsInGroup)
    if grouped == false then return false end
    if grouped == nil then return end
    local inRaid = Flag(IsInRaid)
    local count, known = Read(GetNumGroupMembers)
    if inRaid == nil or not known or type(count) ~= "number" or count < 1 or count > 40 then return end
    local unknown = false
    for index = 1, count do
        local owner = inRaid and ("raid" .. index) or (index == 1 and "player" or "party" .. (index - 1))
        local owned = Flag(UnitIsOwnerOrControllerOfUnit, owner, unit)
        if owned == true then return true end
        if owned == nil then unknown = true end
    end
    if unknown then return end
    return false
end

local function ShouldShowNameOnly(unit)
    if not db or not db.enabled then return false end
    if Flag(UnitExists, unit) ~= true then return false end
    if Flag(UnitIsFriend, "player", unit) ~= true then return false end
    -- Never change the personal resource display, even in a party.
    if Flag(UnitIsUnit, unit, "player") ~= false then return false end

    local player = Flag(UnitIsPlayer, unit)
    if player ~= true then
        if player ~= false then return false end
        local minion = Flag(UnitIsMinion, unit)
        if minion == false then
            -- NPC display is an explicit mode, independent of player rules.
            return db.includeNPCs and not db.showNPCBars
        end
        if minion ~= true or not db.includeMinions then return false end
    end

    if db.showTarget and Flag(UnitIsUnit, unit, "target") ~= false then return false end

    -- Enabled rules are ORed. Only consult active rules: a disabled criterion
    -- must not keep bars visible merely because its data is restricted.
    if db.showGroup then
        if player then
            local party = Flag(UnitInParty, unit)
            local raid = Flag(UnitInRaid, unit)
            if party ~= false or raid ~= false then return false end
        elseif MinionInGroup(unit) ~= false then
            -- Unknown/restricted data: leave the bar visible rather than guess.
            return false
        end
    end
    if db.showCombat and Flag(UnitAffectingCombat, unit) ~= false then return false end
    return true
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
        end
    else
        RestoreFrame(frame)
    end
end

local function UpdateAll()
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

local function ScanPlates()
    RestoreAll()
    plates, forbidden = {}, {}
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
        pendingCVars = true
        RefreshOptions()
        return
    end
    pendingCVars = false
    for _, setting in ipairs(CVARS) do
        local name = setting.name
        local current, known = GetValue(name)
        -- Restoration state belongs to this character's game settings, never
        -- to the shared preference profile or to the currently selected mode.
        local saved = characterDB.originalCVars[name]
        local wanted = db.enabled and (not setting.option or db[setting.option])
        if known and current ~= nil then
            if wanted then
                if current ~= setting.value then
                    if not saved then
                        saved = { before = current, applied = setting.value }
                        characterDB.originalCVars[name] = saved
                    end
                    if not WriteValue(name, setting.value) then pendingCVars = true end
                end
            elseif saved then
                if current == saved.applied and not WriteValue(name, saved.before) then
                    pendingCVars = true
                else
                    characterDB.originalCVars[name] = nil
                end
            end
        elseif wanted then
            Warn(name, string.format(L.ERROR_CVAR_UNAVAILABLE, name))
        end
    end
    RefreshOptions()
end

local function FillDefaults(profile)
    for key, value in pairs(DEFAULTS) do
        if type(profile[key]) ~= type(value) then profile[key] = value end
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

function addon.GetProfile()
    return characterDB and characterDB.profileScope
end

function addon.SetProfile(scope)
    if not characterDB or (scope ~= "global" and scope ~= "character") then return end
    if scope == characterDB.profileScope then return end
    RestoreAll()
    characterDB.profileScope = scope
    db = ProfileSettings(scope)
    for _, record in pairs(plates) do record.npcTitle, record.nextTitleRead = nil, nil end
    ApplyCVars()
    UpdateAll()
end

-- Both the options panel and slash commands use the same update path.
local function SetOption(key, value)
    if not db then return end
    if DEFAULTS[key] == nil then return end
    if type(value) ~= "boolean" then return end
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

local function Count(entries)
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    return count
end

local function Status()
    local version, build, _, interface = GetBuildInfo()
    Say(string.format(L.STATUS_HEADER, VERSION, db.enabled and L.VALUE_ENABLED or L.VALUE_DISABLED,
        version, build, interface))
    Say(string.format(L.STATUS_PROFILE, characterDB.profileScope == "global"
        and L.VALUE_PROFILE_GLOBAL or L.VALUE_PROFILE_CHARACTER))
    Say(string.format(L.STATUS_COUNTS, Count(plates), Count(nameOnlyFrames), Count(forbidden)))
    Say(string.format(L.STATUS_COLORS, db.classColorsOnly and L.VALUE_YES or L.VALUE_NO))
    Say(string.format(L.STATUS_GUILD, db.showGuild and L.VALUE_YES or L.VALUE_NO))
    Say(string.format(L.STATUS_NPCS, db.includeNPCs and L.VALUE_YES or L.VALUE_NO,
        db.showNPCBars and L.VALUE_YES or L.VALUE_NO, db.showNPCTitle and L.VALUE_YES or L.VALUE_NO))
    Say(string.format(L.STATUS_RULES, db.showGroup and L.VALUE_YES or L.VALUE_NO,
        db.showCombat and L.VALUE_YES or L.VALUE_NO, db.showTarget and L.VALUE_YES or L.VALUE_NO,
        db.includeMinions and L.VALUE_YES or L.VALUE_NO))
    for _, setting in ipairs(CVARS) do
        local value = GetValue(setting.name)
        Say(string.format(L.STATUS_CVAR, setting.name, tostring(value or L.VALUE_UNAVAILABLE)))
    end
    if pendingCVars then Say(L.STATUS_PENDING) end
    if lastError then Say(string.format(L.STATUS_LAST_ERROR, lastError)) end
    Say(L.UI_RESTRICTIONS)
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
end

addon.PrintStatus = Status
addon.DebugTarget = DebugTarget

SLASH_FRIENDLYGROUPCOMBAT1 = "/sfn"
SlashCmdList.FRIENDLYGROUPCOMBAT = function(input)
    if not db then return end
    local command, argument = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "on" or command == "off" then
        SetOption("enabled", command == "on")
        Say(db.enabled and L.CMD_FILTER_ON
            or L.CMD_FILTER_OFF)
        if pendingCVars then Say(L.CMD_PENDING) end
    elseif command == "colors" and (argument == "on" or argument == "off") then
        SetOption("classColorsOnly", argument == "on")
        Say(db.classColorsOnly and L.CMD_COLORS_ON
            or L.CMD_COLORS_OFF)
    elseif command == "status" then
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
        Say(L.CMD_HELP)
    end
end

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == ADDON_NAME then
            FriendlyGroupCombatDB = type(FriendlyGroupCombatDB) == "table" and FriendlyGroupCombatDB or {}
            characterDB = FriendlyGroupCombatDB
            characterDB.nameWidthPercent = nil -- Remove the retired experimental setting.
            FillDefaults(characterDB)
            if type(characterDB.originalCVars) ~= "table" then characterDB.originalCVars = {} end
            if characterDB.profileScope ~= "global" then characterDB.profileScope = "character" end
            FriendlyGroupCombatGlobalDB = type(FriendlyGroupCombatGlobalDB) == "table"
                and FriendlyGroupCombatGlobalDB or {}
            globalDB = FriendlyGroupCombatGlobalDB
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
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        AddPlate(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" or event == "FORBIDDEN_NAME_PLATE_UNIT_REMOVED" then
        RemovePlate(unit)
    elseif event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" then
        RemovePlate(unit)
        forbidden[unit] = true -- No request for the forbidden frame, even for diagnostics.
    elseif event == "UNIT_FLAGS" or event == "UNIT_FACTION" or event == "UNIT_NAME_UPDATE" then
        if plates[unit] then plates[unit].npcTitle, plates[unit].nextTitleRead = nil, nil end
        if plates[unit] then UpdatePlate(unit) else UpdateAll() end
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
}) do
    driver:RegisterEvent(event)
end
