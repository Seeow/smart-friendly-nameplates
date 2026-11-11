-- Integration checks with a simulated WoW event loop. Lua 5.1+ / Fengari.
local source = "FriendlyGroupCombat/FriendlyGroupCombat.lua"
local SECRET, API_ERROR = {}, {}
local tests, passed = 0, 0

local function BarVisible(frame)
    local bar = frame.HealthBarsContainer.healthBar
    return bar.shown and frame.HealthBarsContainer.alpha > 0 and bar.alpha > 0 and 1 or 0
end

local function equal(actual, expected, message)
    assert(actual == expected, (message or "unexpected value")
        .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function Context(previous)
    local ctx = {
        units = {}, plates = {}, messages = {}, combat = false, writes = {},
        cvars = previous and previous.cvars or {
            nameplateShowFriendlyPlayers = "0",
            nameplateShowOnlyNameForFriendlyPlayerUnits = "0",
            nameplateUseClassColorForFriendlyPlayerUnitNames = "0",
            nameplateShowEnemies = "1",
            nameplateShowFriendlyNpcs = "0",
        },
    }
    local env = setmetatable({}, { __index = _G })
    ctx.env = env
    env.FriendlyGroupCombatDB = previous and previous.env.FriendlyGroupCombatDB or nil
    env.SlashCmdList = {}
    env.NamePlateSetupOptions = {}
    env.print = function(message) ctx.messages[#ctx.messages + 1] = message end
    env.issecretvalue = function(value) return value == SECRET end
    env.GetBuildInfo = function() return "1.60.1", "70888", "", 16001 end
    env.InCombatLockdown = function() return ctx.combat end
    env.CreateFrame = function()
        local frame = { scripts = {}, events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(kind, fn) self.scripts[kind] = fn end
        ctx.driver = frame
        return frame
    end
    local function ReadUnit(unit, key)
        local value = ctx.units[unit] and ctx.units[unit][key]
        if value == API_ERROR then error("simulated restricted API") end
        return value
    end
    env.UnitExists = function(unit) return ctx.units[unit] ~= nil end
    env.UnitIsPlayer = function(unit) return ReadUnit(unit, "player") end
    env.UnitIsFriend = function(_, unit) return ReadUnit(unit, "friendly") end
    env.UnitIsUnit = function(unit) return ReadUnit(unit, "self") end
    env.UnitInParty = function(unit) return ReadUnit(unit, "party") end
    env.UnitInRaid = function(unit) return ReadUnit(unit, "raid") end
    env.UnitAffectingCombat = function(unit) return ReadUnit(unit, "combat") end
    env.UnitClassBase = function(unit) return ReadUnit(unit, "class") end
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.C_CVar = {
        GetCVar = function(name) return ctx.cvars[name] end,
        SetCVar = function(name, value)
            assert(not ctx.combat, "CVar write attempted in combat")
            ctx.writes[#ctx.writes + 1] = name
            if not ctx.failWrite then
                ctx.cvars[name] = value
                if name == "nameplateShowOnlyNameForFriendlyPlayerUnits" then
                    for _, plate in pairs(ctx.plates) do
                        local frame = plate.UnitFrame
                        if not plate.forbidden and frame and not frame.forbidden and frame.unit then
                            ctx:nativeRefresh(frame)
                        end
                    end
                elseif name == "nameplateUseClassColorForFriendlyPlayerUnitNames" then
                    for _, plate in pairs(ctx.plates) do
                        local frame = plate.UnitFrame
                        if not plate.forbidden and frame and not frame.forbidden then
                            frame.name:SetVertexColor(0, 1, 0, 1)
                        end
                    end
                end
            end
        end,
    }
    env.C_NamePlate = {
        GetNamePlateForUnit = function(unit, includeForbidden)
            assert(not includeForbidden, "must never request forbidden frames")
            return ctx.plates[unit]
        end,
        GetNamePlates = function()
            local result = {}
            for _, plate in pairs(ctx.plates) do result[#result + 1] = plate end
            return result
        end,
    }
    function ctx:emit(event, unit)
        self.driver.scripts.OnEvent(self.driver, event, unit)
    end
    function ctx:tick()
        self.driver.scripts.OnUpdate(self.driver, 0.21)
    end
    function ctx:command(command)
        env.SlashCmdList.FRIENDLYGROUPCOMBAT(command)
    end
    function ctx:nativeRefresh(frame)
        local unit = ctx.units[frame.unit]
        local mode = unit and unit.friendly == true and unit.player == true
            and ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == "1" or false
        frame.showOnlyName = mode
        frame.HealthBarsContainer.healthBar.shown = not mode
    end
    function ctx:unit(token, properties, frame)
        local unit = { player = true, friendly = true, self = false,
            party = false, raid = nil, combat = false }
        for key, value in pairs(properties or {}) do unit[key] = value end
        self.units[token] = unit
        frame = frame or { alpha = 1, forbidden = false, changes = 0 }
        frame.unit = token
        function frame:IsForbidden() return self.forbidden end
        function frame:GetAlpha()
            assert(not self.forbidden, "read forbidden frame")
            return self.alpha
        end
        function frame:SetAlpha(alpha)
            error("must never fade the parent or its name")
        end
        if not frame.HealthBarsContainer then
            frame.name = { shown = true, alpha = 1, text = "Native name", colour = "native", centered = false }
            function frame.name:SetAlpha() error("must never fade the name") end
            frame.name.vertexColor = { 0, 1, 0, 1 }
            function frame.name:IsForbidden() return frame.forbidden end
            function frame.name:GetVertexColor()
                local color = self.vertexColor
                return color[1], color[2], color[3], color[4]
            end
            function frame.name:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
            frame.showOnlyName = false
            local function Component()
                local piece = { showOnlyName = false, shown = true, alpha = 1 }
                function piece:IsForbidden() return frame.forbidden end
                function piece:GetAlpha() return self.alpha end
                function piece:SetAlpha(alpha)
                    assert(not frame.forbidden, "modified forbidden frame")
                    self.alpha = alpha
                    frame.changes = frame.changes + 1
                end
                function piece:SetShowOnlyName() error("unsafe Blizzard Lua helper") end
                return piece
            end
            frame.HealthBarsContainer = Component()
            frame.HealthBarsContainer.healthBar = Component()
            frame.CastBarsContainer = Component()
            frame.CastBarsContainer.castBar = Component()
            frame.AurasFrame = Component()
            frame.ClassificationFrame = Component()
            frame.RaidTargetFrame = Component()
            frame.PlayerLevelDiffFrame = Component()
            frame.PlayerLevelDiffFrame.alpha = 0.8
            frame.decoration = Component()
            frame.WidgetContainer = Component()
            frame.hitTestEnabled = true
            function frame:GetChildren()
                return self.HealthBarsContainer, self.CastBarsContainer, self.AurasFrame,
                    self.ClassificationFrame, self.RaidTargetFrame, self.PlayerLevelDiffFrame,
                    self.WidgetContainer
            end
            function frame:GetRegions() return self.name, self.decoration end
            function frame:UpdateAnchors() error("unsafe Blizzard Lua layout") end
            function frame:UpdateHitTestArea() error("unsafe Blizzard Lua hit-test helper") end
            function frame:UpdateShowOnlyName() error("unsafe Blizzard Lua name-only helper") end
            frame.nativeHealthValue = SECRET
            function frame:GetHealth()
                error("addon must not read health")
            end
        end
        local plate = { UnitFrame = frame, unitToken = token, forbidden = false }
        function plate:IsForbidden() return self.forbidden end
        function plate:GetUnit() return self.unitToken end
        self.plates[token] = plate
        return unit, frame, plate
    end
    local chunk
    if setfenv then
        chunk = assert(loadfile(source))
        setfenv(chunk, env)
    else
        chunk = assert(loadfile(source, "t", env))
    end
    chunk("FriendlyGroupCombat")
    ctx:emit("ADDON_LOADED", "FriendlyGroupCombat")
    return ctx
end

local function test(name, fn)
    tests = tests + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

test("truth table: party OR raid OR individual combat", function()
    for party = 0, 1 do
        for raid = 0, 1 do
            for combat = 0, 1 do
                local ctx = Context()
                local _, frame = ctx:unit("nameplate1", {
                    party = party == 1, raid = raid == 1 and 2 or false, combat = combat == 1,
                })
                ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
                equal(BarVisible(frame), party + raid + combat > 0 and 1 or 0)
            end
        end
    end
end)

test("another player's combat changes while our combat stays false", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 0)
    unit.combat = true
    ctx:tick()
    equal(BarVisible(frame), 1)
    unit.combat = false
    ctx:tick()
    equal(BarVisible(frame), 0)
    equal(ctx.combat, false)
end)

test("our own combat does not reveal unrelated idle players", function()
    local ctx = Context()
    ctx.combat = true
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 0)
end)

test("roster updates reveal and hide a party member", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    unit.party = true
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(BarVisible(frame), 1)
    unit.party = false
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(BarVisible(frame), 0)
end)

test("enemy, NPC and personal bar are untouched", function()
    for _, properties in ipairs({ { friendly = false }, { player = false }, { self = true } }) do
        local ctx = Context()
        local _, frame = ctx:unit("nameplate1", properties)
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(frame.changes, 0)
    end
end)

test("becoming hostile restores a previously hidden frame", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    unit.friendly = false
    ctx:emit("UNIT_FACTION", "nameplate1")
    equal(BarVisible(frame), 1)
end)

test("secret or errored data never hides a player", function()
    for _, key in ipairs({ "player", "friendly", "self", "party", "raid", "combat" }) do
        for _, unknown in ipairs({ SECRET, API_ERROR }) do
            local ctx = Context()
            local _, frame = ctx:unit("nameplate1", { [key] = unknown })
            ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
            equal(BarVisible(frame), 1, key)
        end
    end
end)

test("known membership is sufficient even with secret combat data", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1", { party = true, combat = SECRET })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 1)
end)

test("unknown data restores a previously hidden frame", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    unit.combat = SECRET
    ctx:tick()
    equal(BarVisible(frame), 1)
end)

test("forbidden events do not retrieve or modify a frame", function()
    local ctx = Context()
    ctx.env.C_NamePlate.GetNamePlateForUnit = function() error("forbidden lookup") end
    ctx:emit("FORBIDDEN_NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:tick()
    ctx:command("status")
    ctx:emit("FORBIDDEN_NAME_PLATE_UNIT_REMOVED", "nameplate1")
end)

test("forbidden base and forbidden unit frames are not inspected", function()
    for _, forbiddenBase in ipairs({ true, false }) do
        local ctx = Context()
        local _, frame, plate = ctx:unit("nameplate1")
        plate.forbidden = forbiddenBase
        frame.forbidden = not forbiddenBase
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        ctx:tick()
        equal(frame.changes, 0)
    end
end)

test("removed frames are restored before pool reuse for an enemy", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(BarVisible(frame), 1)
    ctx:unit("nameplate2", { friendly = false }, frame)
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(BarVisible(frame), 1)
end)

test("UnitFrame replacement restores the old frame", function()
    local ctx = Context()
    local _, old, plate = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local _, replacement = ctx:unit("unused")
    plate.UnitFrame = replacement
    ctx:tick()
    equal(BarVisible(old), 1)
    equal(BarVisible(replacement), 0)
end)

test("name-only mode keeps native name and parent alpha; off restores the bar", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1")
    frame.alpha = 0.65
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 0)
    equal(frame.alpha, 0.65)
    equal(frame.name.alpha, 1)
    equal(frame.name.shown, true)
    equal(frame.name.text, "Native name")
    equal(frame.name.colour, "native")
    equal(frame.name.centered, false)
    equal(frame.PlayerLevelDiffFrame.alpha, 0)
    equal(frame.CastBarsContainer.alpha, 0)
    equal(frame.AurasFrame.alpha, 0)
    equal(frame.ClassificationFrame.alpha, 0)
    equal(frame.RaidTargetFrame.alpha, 0)
    equal(frame.WidgetContainer.alpha, 0)
    equal(frame.decoration.alpha, 0)
    ctx:command("off")
    equal(BarVisible(frame), 1)
    equal(frame.alpha, 0.65)
    equal(frame.PlayerLevelDiffFrame.alpha, 0.8)
    equal(frame.name.centered, false)
    equal(frame.hitTestEnabled, true)
    ctx:tick()
    equal(BarVisible(frame), 1)
end)

test("zone entry scans already existing plates", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("PLAYER_ENTERING_WORLD")
    equal(BarVisible(frame), 0)
end)

test("only the two required friendly CVars change, then restore", function()
    local ctx = Context()
    ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = "1"
    ctx:emit("PLAYER_ENTERING_WORLD")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "1")
    equal(ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "0")
    equal(ctx.cvars.nameplateShowEnemies, "1")
    equal(ctx.cvars.nameplateShowFriendlyNpcs, "0")
    equal(#ctx.writes, 2)
    ctx:command("off")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0")
    equal(ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "1")
end)

test("original CVars survive reload and later off", function()
    local first = Context()
    first.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = "1"
    first:emit("PLAYER_ENTERING_WORLD")
    local reloaded = Context(first)
    reloaded:emit("PLAYER_ENTERING_WORLD")
    reloaded:command("off")
    equal(reloaded.cvars.nameplateShowFriendlyPlayers, "0")
    equal(reloaded.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "1")
end)

test("manual CVar edits are respected on off", function()
    local ctx = Context()
    ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = "2"
    ctx:emit("PLAYER_ENTERING_WORLD")
    ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = "1"
    ctx:command("off")
    equal(ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "1")
end)

test("activation during combat defers CVar writes", function()
    local ctx = Context()
    ctx:command("off")
    ctx.combat = true
    ctx:command("on")
    equal(#ctx.writes, 0)
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "1")
end)

test("deactivation during combat restores frames now and CVars later", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx.combat = true
    ctx:command("off")
    equal(BarVisible(frame), 1)
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "1")
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0")
end)

test("failed CVar writes are diagnosed and can be retried", function()
    local ctx = Context()
    ctx.failWrite = true
    ctx:emit("PLAYER_ENTERING_WORLD")
    ctx:command("status")
    assert(#ctx.messages > 0)
    ctx.failWrite = false
    ctx:command("on")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "1")
    ctx:command("off")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0")
end)

test("disabled state survives reload", function()
    local first = Context()
    first:command("off")
    local reloaded = Context(first)
    local _, frame = reloaded:unit("nameplate1")
    reloaded:emit("PLAYER_ENTERING_WORLD")
    equal(frame.changes, 0)
    equal(#reloaded.writes, 0)
end)

test("debug output tolerates secret target values", function()
    local ctx = Context()
    ctx:unit("target", { combat = SECRET, raid = API_ERROR })
    ctx:command("debug")
    assert(ctx.messages[1]:find("indisponible", 1, true))
end)

test("Blizzard refresh while filtered is reconciled without hiding the name", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 0)
    ctx:nativeRefresh(frame)
    frame.HealthBarsContainer.alpha = 1 -- Simulate an engine visual reset.
    equal(BarVisible(frame), 1)
    ctx:tick()
    equal(BarVisible(frame), 0)
    equal(frame.name.shown, true)
    equal(frame.alpha, 1)
end)

test("a released frame is restored without layout against a cleared unit", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    frame.unit = nil
    frame.UpdateAnchors = function() error("released-frame layout") end
    ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(BarVisible(frame), 1)
    equal(frame.PlayerLevelDiffFrame.alpha, 0.8)
end)

test("visual filter does not depend on the unsafe component name-only helper", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1")
    frame.AurasFrame.SetShowOnlyName = nil
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 0)
    equal(frame.name.shown, true)
    equal(frame.alpha, 1)
end)

test("regression: native frame state is read-only and native health helpers are never called", function()
    local ctx = Context()
    local unit, native, plate = ctx:unit("nameplate1")
    local proxy = setmetatable({}, {
        __index = native,
        __newindex = function(_, key) error("tainting native field: " .. key) end,
    })
    plate.UnitFrame = proxy
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(proxy), 0)
    equal(native.showOnlyName, false)
    equal(native.HealthBarsContainer.healthBar.showOnlyName, false)
    equal(native.nativeHealthValue, SECRET)
    equal(native.name.shown, true)
    unit.party = true
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(BarVisible(proxy), 1)
    equal(native.showOnlyName, false)
    equal(#ctx.messages, 0)
end)

test("off restores a pre-existing global name-only preference", function()
    local ctx = Context()
    ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = "1"
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, frame = ctx:unit("nameplate1", { party = true })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 1)
    ctx:command("off")
    equal(ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "1")
    equal(BarVisible(frame), 0)
    equal(frame.name.shown, true)
end)

test("a failed visual operation restores the bar and is not retried every tick", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1")
    local calls = 0
    function frame.decoration:SetAlpha(alpha)
        if alpha == 0 then
            calls = calls + 1
            error("simulated unsupported visual operation")
        end
        self.alpha = alpha
    end
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    for _ = 1, 10 do ctx:tick() end
    equal(calls, 1)
    equal(BarVisible(frame), 1)
    equal(frame.name.shown, true)
    equal(#ctx.messages, 1)
    assert(ctx.messages[1]:find("simulated unsupported visual operation", 1, true))
end)

test("class colour applies only to a filtered name and restores with group or combat", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 0)
    equal(frame.name.vertexColor[1], 0.25)
    equal(frame.name.vertexColor[2], 0.78)
    unit.party = true
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(BarVisible(frame), 1)
    equal(frame.name.vertexColor[1], 0)
    equal(frame.name.vertexColor[2], 1)
    unit.party = false
    ctx:tick()
    equal(frame.name.vertexColor[1], 0.25)
    unit.combat = true
    ctx:tick()
    equal(BarVisible(frame), 1)
    equal(frame.name.vertexColor[1], 0)
end)

test("class colour preserves vertex alpha and off restores the original colour", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    frame.name.vertexColor = { 0.1, 0.9, 0.2, 0.6 }
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(frame.name.vertexColor[4], 0.6)
    ctx:command("off")
    equal(frame.name.vertexColor[1], 0.1)
    equal(frame.name.vertexColor[2], 0.9)
    equal(frame.name.vertexColor[4], 0.6)
end)

test("unknown or secret class never indexes the colour table or recolours the name", function()
    for _, class in ipairs({ SECRET, API_ERROR, false, "UNKNOWN" }) do
        local ctx = Context()
        local _, frame = ctx:unit("nameplate1", { class = class })
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(BarVisible(frame), 0)
        equal(frame.name.vertexColor[1], 0)
        equal(frame.name.vertexColor[2], 1)
    end
end)

test("native colour changes while filtered are preserved on restoration", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    frame.name:SetVertexColor(0.1, 0.7, 0.1, 1)
    ctx:tick()
    equal(frame.name.vertexColor[1], 0.25)
    unit.party = true
    ctx:tick()
    equal(frame.name.vertexColor[1], 0.1)
    equal(frame.name.vertexColor[2], 0.7)
end)

test("the global class-colour setting is held off and its original survives reload", function()
    local first = Context()
    first.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames = "1"
    first:emit("PLAYER_ENTERING_WORLD")
    equal(first.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames, "0")
    local reloaded = Context(first)
    reloaded:emit("PLAYER_ENTERING_WORLD")
    reloaded:command("off")
    equal(reloaded.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames, "1")
end)

test("colors off disables only recolouring, keeping the filter active", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:command("colors off")
    equal(BarVisible(frame), 0)
    equal(frame.name.vertexColor[1], 0)
    ctx:command("colors on")
    equal(frame.name.vertexColor[1], 0.25)
    equal(BarVisible(frame), 0)
end)

test("frame reuse for an enemy restores the name colour", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(frame.name.vertexColor[1], 0)
    ctx:unit("nameplate2", { friendly = false }, frame)
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(frame.name.vertexColor[1], 0)
    equal(BarVisible(frame), 1)
end)

test("public command retains both prototype aliases", function()
    local ctx = Context()
    equal(ctx.env.SLASH_FRIENDLYGROUPCOMBAT1, "/sfn")
    equal(ctx.env.SLASH_FRIENDLYGROUPCOMBAT2, "/bgc")
    equal(ctx.env.SLASH_FRIENDLYGROUPCOMBAT3, "/fgc")
end)

print(string.format("%d/%d integration checks passed", passed, tests))
if passed ~= tests then os.exit(1) end
