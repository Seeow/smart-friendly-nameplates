-- SPDX-License-Identifier: MIT
-- WoW Forever 1.60.1. No dependency; only ordinary, accessible nameplates.
local ADDON_NAME = ...
local VERSION = "0.1.4"
local PREFIX = "|cff66ccffSmart Friendly Nameplates:|r "
local INTERVAL = 0.20
local CVARS = {
    { name = "nameplateShowFriendlyPlayers", value = "1" },
    { name = "nameplateShowOnlyNameForFriendlyPlayerUnits", value = "0" },
    { name = "nameplateUseClassColorForFriendlyPlayerUnitNames", value = "0", option = "classColorsOnly" },
}

local driver = CreateFrame("Frame")
local db
local plates, forbidden = {}, {}
local nameOnlyFrames = setmetatable({}, { __mode = "k" })
local nameColors = setmetatable({}, { __mode = "k" })
local warnings = {}
local pendingCVars = false
local elapsedSinceUpdate = 0
local lastError

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
                Warn("color", "Le client refuse de restaurer une couleur de nom.")
                return
            end
        end
    end
    nameColors[name] = nil
end

local function ColorName(name, unit)
    if not db.classColorsOnly then return RestoreNameColor(name) end
    local class, known = Read(UnitClassBase, unit)
    local color = known and type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
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

local function RestoreFrame(frame)
    if Accessible(frame) and frame.name then RestoreNameColor(frame.name) end
    local before = nameOnlyFrames[frame]
    if not before then return end
    if Accessible(frame) then
        for piece, alpha in pairs(before) do
            if Accessible(piece) then
                local ok = pcall(piece.SetAlpha, piece, alpha)
                if not ok then
                    Warn("nameOnly", "Le client refuse de restaurer un element visuel. /sfn status pour le diagnostic.")
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
    -- Keep ALL addon bookkeeping outside Blizzard frames and never read health.
    local function Fade(piece)
        if piece == frame.name or not Accessible(piece) then return end
        if before[piece] == nil then
            local alpha, known = Read(piece.GetAlpha, piece)
            if not known or type(alpha) ~= "number" then return end
            before[piece] = alpha
        end
        piece:SetAlpha(0)
    end
    for _, child in ipairs({ frame:GetChildren() }) do Fade(child) end
    for _, region in ipairs({ frame:GetRegions() }) do Fade(region) end
    ColorName(frame.name, unit)
end

local function RestoreAll()
    for frame in pairs(nameOnlyFrames) do RestoreFrame(frame) end
end

local function ShouldShowNameOnly(unit)
    if not db or not db.enabled then return false end
    if Flag(UnitExists, unit) ~= true then return false end
    if Flag(UnitIsPlayer, unit) ~= true then return false end
    if Flag(UnitIsFriend, "player", unit) ~= true then return false end
    -- Never change the personal resource display, even in a party.
    if Flag(UnitIsUnit, unit, "player") ~= false then return false end

    local party = Flag(UnitInParty, unit)
    local raid = Flag(UnitInRaid, unit)
    local combat = Flag(UnitAffectingCombat, unit)
    if party == true or raid == true or combat == true then return false end
    -- Unknown/restricted data: leave the plate visible rather than guess.
    return party == false and raid == false and combat == false
end

local function UpdatePlate(unit)
    local record = plates[unit]
    if not record or record.failed or not Accessible(record.plate) then return end
    local frame = record.plate.UnitFrame
    -- Blizzard pools UnitFrames independently of the plate bases.
    if record.frame ~= frame then
        if record.frame then RestoreFrame(record.frame) end
        record.frame = frame
    end
    if not Accessible(frame) or not frame.unit then return end

    if ShouldShowNameOnly(unit) then
        local ok, err = pcall(ShowNameOnly, frame, unit)
        if not ok then
            RestoreFrame(frame)
            record.failed = true -- Do not retry a failing operation every 0.2 s.
            local detail = (issecretvalue and issecretvalue(err)) and "erreur protegee" or tostring(err)
            Warn("nameOnly", "Filtre suspendu pour cette barre : " .. detail)
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
        Warn(name, "Impossible de regler " .. name .. ". Verifie /sfn status hors combat.")
        return false
    end
    return true
end

-- Keep originals across /reload. /sfn off restores only settings still at the
-- value we applied, so later manual changes are respected. Never write in combat.
local function ApplyCVars()
    if not db then return end
    if InCombatLockdown() then
        pendingCVars = true
        return
    end
    pendingCVars = false
    for _, setting in ipairs(CVARS) do
        local name = setting.name
        local current, known = GetValue(name)
        local saved = db.originalCVars[name]
        local wanted = db.enabled and (not setting.option or db[setting.option])
        if known and current ~= nil then
            if wanted then
                if current ~= setting.value then
                    if not saved then
                        saved = { before = current, applied = setting.value }
                        db.originalCVars[name] = saved
                    end
                    if not WriteValue(name, setting.value) then pendingCVars = true end
                end
            elseif saved then
                if current == saved.applied and not WriteValue(name, saved.before) then
                    pendingCVars = true
                else
                    db.originalCVars[name] = nil
                end
            end
        elseif wanted then
            Warn(name, "Reglage absent sur ce client : " .. name .. ".")
        end
    end
end

local function Count(entries)
    local count = 0
    for _ in pairs(entries) do count = count + 1 end
    return count
end

local function Status()
    local version, build, _, interface = GetBuildInfo()
    Say("v" .. VERSION .. " | filtre " .. (db.enabled and "actif" or "inactif")
        .. " | client " .. version .. " (" .. build .. "), interface " .. interface)
    Say("Barres suivies : " .. Count(plates) .. " ; nom seul : " .. Count(nameOnlyFrames)
        .. " ; verrouillees signalees : " .. Count(forbidden) .. ".")
    Say("Couleur de classe sur les noms seuls : " .. (db.classColorsOnly and "oui" or "non") .. ".")
    for _, setting in ipairs(CVARS) do
        local value = GetValue(setting.name)
        Say(setting.name .. " = " .. tostring(value or "indisponible"))
    end
    if pendingCVars then Say("Reglages en attente : quitte le combat, puis /sfn on ou /sfn off.") end
    if lastError then Say("Dernier probleme : " .. lastError) end
    Say("Les barres amicales verrouillees en donjon/raid restent celles de Blizzard.")
end

local function DescribeFlag(fn, ...)
    local value = Flag(fn, ...)
    if value == nil then return "indisponible" end
    return value and "oui" or "non"
end

local function DebugTarget()
    if Flag(UnitExists, "target") ~= true then
        Say("Cible un joueur amical, puis /sfn debug.")
        return
    end
    Say("Cible : joueur=" .. DescribeFlag(UnitIsPlayer, "target")
        .. ", amical=" .. DescribeFlag(UnitIsFriend, "player", "target")
        .. ", groupe=" .. DescribeFlag(UnitInParty, "target")
        .. ", raid=" .. DescribeFlag(UnitInRaid, "target")
        .. ", son combat=" .. DescribeFlag(UnitAffectingCombat, "target") .. ".")
    Say("Decision pour la cible : " .. (ShouldShowNameOnly("target") and "nom seul" or "affichage normal")
        .. " (si une barre accessible existe).")
end

SLASH_FRIENDLYGROUPCOMBAT1 = "/sfn"
SLASH_FRIENDLYGROUPCOMBAT2 = "/bgc"
SLASH_FRIENDLYGROUPCOMBAT3 = "/fgc"
SlashCmdList.FRIENDLYGROUPCOMBAT = function(input)
    if not db then return end
    local command, argument = (input or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if command == "on" or command == "off" then
        db.enabled = command == "on"
        if not db.enabled then RestoreAll() end
        ApplyCVars()
        UpdateAll()
        Say(db.enabled and "Filtre actif : groupe/raid OU combat de chaque joueur."
            or "Filtre desactive ; restauration des reglages precedents.")
        if pendingCVars then Say("La modification des reglages attend la fin du combat.") end
    elseif command == "colors" and (argument == "on" or argument == "off") then
        db.classColorsOnly = argument == "on"
        if not db.classColorsOnly then
            for name in pairs(nameColors) do RestoreNameColor(name) end
        end
        ApplyCVars()
        UpdateAll()
        Say(db.classColorsOnly and "Couleur de classe uniquement sur les noms seuls."
            or "Couleurs natives restaurees.")
    elseif command == "status" then
        Status()
    elseif command == "debug" then
        DebugTarget()
    else
        Say("/sfn on | off | status | debug | colors on | colors off. Actif par defaut.")
    end
end

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit ~= ADDON_NAME then return end
        FriendlyGroupCombatDB = type(FriendlyGroupCombatDB) == "table" and FriendlyGroupCombatDB or {}
        db = FriendlyGroupCombatDB
        if type(db.enabled) ~= "boolean" then db.enabled = true end
        if type(db.classColorsOnly) ~= "boolean" then db.classColorsOnly = true end
        if type(db.originalCVars) ~= "table" then db.originalCVars = {} end
        driver:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
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
    elseif event == "UNIT_FLAGS" or event == "UNIT_FACTION" then
        if plates[unit] then UpdatePlate(unit) else UpdateAll() end
    else
        UpdateAll()
    end
end)

driver:SetScript("OnUpdate", function(_, elapsed)
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
}) do
    driver:RegisterEvent(event)
end
