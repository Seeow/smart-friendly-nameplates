-- Integration checks with a simulated WoW event loop. Lua 5.1+ / Fengari.
local sources = {
    "SmartFriendlyNameplates/Localization.lua", "SmartFriendlyNameplates/LocalesEurope.lua",
    "SmartFriendlyNameplates/LocalesAsia.lua", "SmartFriendlyNameplates/DiagnosticsLocalization.lua",
    "SmartFriendlyNameplates/OptionsLocalization.lua", "SmartFriendlyNameplates/SmartFriendlyNameplates.lua",
    "SmartFriendlyNameplates/Options.lua",
}
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

local function Context(previous, options)
    local ctx = {
        units = {}, plates = {}, messages = {}, combat = false, writes = {}, nameHooks = {},
        widgets = {}, categories = {}, healthReads = 0, guildReads = 0, tooltipReads = 0,
        groupMembers = 0, inRaid = false, ownerChecks = 0,
        cvars = previous and previous.cvars or {
            nameplateShowFriendlyPlayers = "0",
            nameplateShowOnlyNameForFriendlyPlayerUnits = "0",
            nameplateUseClassColorForFriendlyPlayerUnitNames = "0",
            nameplateShowFriendlyPlayerMinions = "0",
            nameplateShowEnemies = "1",
            nameplateShowFriendlyNpcs = "0",
            colorblindmode = "0",
        },
    }
    local env = setmetatable({}, { __index = _G })
    ctx.env = env
    env.SmartFriendlyNameplatesDB = previous and previous.env.SmartFriendlyNameplatesDB or nil
    env.SmartFriendlyNameplatesGlobalDB = previous and previous.env.SmartFriendlyNameplatesGlobalDB or nil
    env.SlashCmdList = {}
    env.NamePlateSetupOptions = {}
    env.print = function(message) ctx.messages[#ctx.messages + 1] = message end
    env.issecretvalue = function(value) return value == SECRET end
    env.GetBuildInfo = function() return "1.60.1", "70888", "", 16001 end
    env.GetLocale = function() return options and options.locale or "enUS" end
    env.InCombatLockdown = function() return ctx.combat end
    env.UIParent = {}
    env.UISpecialFrames = {}
    local function Widget()
        local widget = { scripts = {}, events = {}, shown = false, alpha = 1, enabled = true,
            visualWrites = { point = 0, text = 0, color = 0, font = 0, show = 0, hide = 0 } }
        function widget:SetPoint(...)
            self.visualWrites.point = self.visualWrites.point + 1
            self.point = { ... }
        end
        function widget:ClearAllPoints() self.point = nil end
        function widget:SetAllPoints(frame) self.allPoints = frame end
        function widget:SetSize(width, height) self.width, self.height = width, height end
        function widget:SetWidth(width) self.width = width end
        function widget:GetWidth() return self.width or 500 end
        function widget:SetHeight(height) self.height = height end
        function widget:GetStringHeight()
            return math.max(1, math.ceil(#(self.text or "") * 7 / self:GetWidth())) * 14
        end
        function widget:GetStringWidth() return #(self.text or "") * 7 end
        function widget:SetScrollChild(child) self.scrollChild = child end
        function widget:SetVerticalScroll(value) self.verticalScroll = value end
        function widget:SetJustifyH() end
        function widget:SetFontObject(object) self.fontObject = object end
        function widget:GetFont() return self.fontPath or "Fonts/FRIZQT__.TTF", self.fontSize or 12, self.fontFlags or "" end
        function widget:SetFont(path, size, flags)
            self.visualWrites.font = self.visualWrites.font + 1
            self.fontPath, self.fontSize, self.fontFlags = path, size, flags
            return true
        end
        function widget:SetTextColor(r, g, b, a)
            self.visualWrites.color = self.visualWrites.color + 1
            self.textColor = { r, g, b, a }
        end
        function widget:SetColorTexture(...) self.colorTexture = { ... } end
        function widget:SetWordWrap() end
        function widget:IsForbidden() return false end
        function widget:GetAlpha() return self.alpha end
        function widget:SetAlpha(alpha) self.alpha = alpha end
        function widget:SetText(text)
            self.visualWrites.text = self.visualWrites.text + 1
            self.text = text
            if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
        end
        function widget:GetText() return self.text or "" end
        function widget:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
        function widget:SetValueStep(step) self.valueStep = step end
        function widget:SetObeyStepOnDrag(value) self.obeyStep = value end
        function widget:SetValue(value)
            self.value = value
            if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
        end
        function widget:GetValue() return self.value end
        function widget:SetEnabled(value) self.enabled = value end
        function widget:IsEnabled() return self.enabled end
        function widget:Enable() self.enabled = true end
        function widget:Disable() self.enabled = false end
        function widget:SetMultiLine(value) self.multiline = value end
        function widget:SetAutoFocus(value) self.autoFocus = value end
        function widget:SetMaxLetters(value) self.maxLetters = value end
        function widget:SetTextInsets(...) self.textInsets = { ... } end
        function widget:HighlightText() self.highlighted = true end
        function widget:SetFocus() self.focused = true end
        function widget:ClearFocus() self.focused = false end
        function widget:SetFrameStrata(value) self.frameStrata = value end
        function widget:SetClampedToScreen(value) self.clampedToScreen = value end
        function widget:EnableMouse(value) self.mouseEnabled = value end
        function widget:SetMovable(value) self.movable = value end
        function widget:RegisterForDrag(...) self.dragButtons = { ... } end
        function widget:StartMoving() self.moving = true end
        function widget:StopMovingOrSizing() self.moving = false end
        function widget:SetBackdrop(value) self.backdrop = value end
        function widget:SetBackdropColor(...) self.backdropColor = { ... } end
        function widget:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
        function widget:SetChecked(checked) self.checked = checked end
        function widget:GetChecked() return self.checked end
        function widget:IsShown() return self.shown end
        function widget:Hide()
            self.visualWrites.hide = self.visualWrites.hide + 1
            self.shown = false
            if self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function widget:Show()
            self.visualWrites.show = self.visualWrites.show + 1
            self.shown = true
            if self.scripts.OnShow then self.scripts.OnShow(self) end
        end
        function widget:SetScript(kind, fn) self.scripts[kind] = fn end
        function widget:Click()
            if self.kind == "CheckButton" then self.checked = not self.checked end
            if self.scripts.OnClick then self.scripts.OnClick(self) end
        end
        ctx.widgets[#ctx.widgets + 1] = widget
        return widget
    end
    env.CreateFrame = function(kind, name, parent, template)
        local frame = Widget()
        frame.kind, frame.template, frame.parent = kind, template, parent
        function frame:GetFontString()
            self.fontString = self.fontString or Widget()
            self.fontString.text = self.text
            return self.fontString
        end
        if kind == "CheckButton" then frame.Text = Widget() end
        if kind == "Slider" then frame.Low, frame.High, frame.Text = Widget(), Widget(), Widget() end
        if template == "BasicFrameTemplateWithInset" then frame.TitleText = Widget() end
        if name then env[name] = frame end
        function frame:CreateFontString() return Widget() end
        function frame:CreateTexture()
            local texture = Widget()
            texture.parent = self
            return texture
        end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        if not ctx.driver then ctx.driver = frame end
        return frame
    end
    env.GameTooltip = Widget()
    function env.GameTooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor; self.lines = {} end
    function env.GameTooltip:SetText(text, r, g, b, alpha, wrap)
        assert(type(alpha) == "number", "tooltip alpha must be numeric")
        self.text, self.wrap = text, wrap
    end
    function env.GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
    local settings = {
        RegisterCanvasLayoutCategory = function(panel, title)
            local category = { panel = panel, name = title }
            function category:GetID() return 42 end
            return category
        end,
        RegisterAddOnCategory = function(category)
            ctx.categories[#ctx.categories + 1] = category
        end,
        OpenToCategory = function(id)
            assert(not ctx.combat, "settings opened in combat")
            equal(id, 42, "use category ID to open options")
            ctx.openedCategory = id
            ctx.categories[1].panel:Show()
        end,
    }
    if not (options and options.lateSettings) then env.Settings = settings end
    ctx.settings = settings
    function ctx:widget(text)
        for _, widget in ipairs(self.widgets) do
            if widget.text == text or (widget.Text and widget.Text.text == text) then return widget end
        end
        error("missing widget: " .. text)
    end
    function ctx:click(text)
        local widget = self:widget(text)
        if widget.kind == "CheckButton" then widget.checked = not widget.checked end
        widget.scripts.OnClick(widget)
    end
    function ctx:hasText(text)
        for _, widget in ipairs(self.widgets) do
            if widget.text and widget.text:find(text, 1, true) then return true end
        end
        return false
    end
    local function UnitRecord(unit)
        return ctx.units[unit] or (ctx[unit] and ctx.units[ctx[unit]])
    end
    local function ReadUnit(unit, key)
        local record = UnitRecord(unit)
        local value = record and record[key]
        if value == API_ERROR then error("simulated restricted API") end
        return value
    end
    env.UnitExists = function(unit) return UnitRecord(unit) ~= nil end
    env.UnitIsPlayer = function(unit) return ReadUnit(unit, "player") end
    env.UnitIsMinion = function(unit) return ReadUnit(unit, "minion") end
    env.UnitIsFriend = function(_, unit) return ReadUnit(unit, "friendly") end
    env.UnitIsUnit = function(unit, other)
        if other == "target" or other == "focus" or other == "mouseover" then
            local override = ReadUnit(unit, other)
            if override ~= nil then return override end
            return ctx[other] == unit or (ctx[unit] ~= nil and ctx[unit] == ctx[other])
        end
        if other == "player" then return ReadUnit(unit, "self") end
        return unit == other or ctx[unit] == other or ctx[other] == unit
            or (ctx[unit] ~= nil and ctx[unit] == ctx[other])
    end
    env.GetGuildInfo = function(unit)
        ctx.guildReads = ctx.guildReads + 1
        return ReadUnit(unit, "guild")
    end
    env.Enum = { TooltipDataLineType = { None = 0, UnitName = 2, UnitLevel = 47, UnitType = 48 } }
    env.C_TooltipInfo = { GetUnit = function(unit)
        ctx.tooltipReads = ctx.tooltipReads + 1
        return ReadUnit(unit, "tooltip")
    end }
    env.UnitInParty = function(unit) return ReadUnit(unit, "party") end
    env.UnitInRaid = function(unit) return ReadUnit(unit, "raid") end
    env.UnitPlayerOrPetInParty = function(unit) return ReadUnit(unit, "petParty") end
    env.UnitPlayerOrPetInRaid = function(unit) return ReadUnit(unit, "petRaid") end
    env.IsInGroup = function() return ctx.groupMembers > 0 end
    env.IsInRaid = function() return ctx.inRaid end
    env.GetNumGroupMembers = function() return ctx.groupMembers end
    env.UnitIsOwnerOrControllerOfUnit = function(owner, unit)
        ctx.ownerChecks = ctx.ownerChecks + 1
        local actualOwner = ReadUnit(unit, "owner")
        if actualOwner == SECRET then return SECRET end
        return actualOwner == owner
    end
    env.UnitAffectingCombat = function(unit) return ReadUnit(unit, "combat") end
    env.UnitHealth = function(unit)
        ctx.healthReads = ctx.healthReads + 1
        return ReadUnit(unit, "health")
    end
    env.UnitHealthMax = function(unit)
        ctx.healthReads = ctx.healthReads + 1
        return ReadUnit(unit, "maxHealth")
    end
    env.UnitClassBase = function(unit) return ReadUnit(unit, "class") end
    env.UnitSelectionColor = function(unit)
        local color = ReadUnit(unit, "selectionColor")
        if color == SECRET then return SECRET, SECRET, SECRET end
        if color == false then return nil end
        color = color or { 0, 1, 0 }
        return color[1], color[2], color[3]
    end
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    ctx.nativeNameUpdater = function(frame) frame.name:SetVertexColor(1, 1, 1, 1) end
    if not (options and options.lateNameUpdater) then
        env.CompactUnitFrame_UpdateName = ctx.nativeNameUpdater
    end
    env.hooksecurefunc = function(name, callback)
        equal(name, "CompactUnitFrame_UpdateName")
        assert(type(env[name]) == "function", "native updater is not loaded")
        ctx.nameHooks[#ctx.nameHooks + 1] = callback
    end
    env.C_CVar = {
        GetCVar = function(name) return ctx.cvars[name] end,
        SetCVar = function(name, value)
            assert(not ctx.combat, "CVar write attempted in combat")
            ctx.writes[#ctx.writes + 1] = name
            if not ctx.failWrite then
                ctx.cvars[name] = value
                ctx:emit("CVAR_UPDATE", name, value)
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
            return ctx.plates[unit] or (ctx[unit] and ctx.plates[ctx[unit]])
        end,
        GetNamePlates = function()
            local result = {}
            for _, plate in pairs(ctx.plates) do result[#result + 1] = plate end
            return result
        end,
    }
    function ctx:emit(event, ...)
        self.driver.scripts.OnEvent(self.driver, event, ...)
    end
    function ctx:tick()
        self.driver.scripts.OnUpdate(self.driver, 0.21)
    end
    function ctx:command(command)
        env.SlashCmdList.SMARTFRIENDLYNAMEPLATES(command)
    end
    function ctx:nativeNameUpdate(frame)
        env.CompactUnitFrame_UpdateName(frame)
        for _, callback in ipairs(self.nameHooks) do callback(frame) end
    end
    function ctx:nativeRefresh(frame)
        local unit = ctx.units[frame.unit]
        local mode = unit and unit.friendly == true and unit.player == true
            and ctx.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == "1" or false
        frame.showOnlyName = mode
        frame.HealthBarsContainer.healthBar.shown = not mode
    end
    function ctx:unit(token, properties, frame)
        local unit = { player = true, friendly = true, self = false, minion = false,
            party = false, raid = nil, combat = false, health = 100, maxHealth = 100,
            petParty = false, petRaid = nil }
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
            function frame.name:IsShown() return self.shown end
            function frame.name:GetVertexColor()
                local color = self.vertexColor
                return color[1], color[2], color[3], color[4]
            end
            frame.name.colorWrites = 0
            function frame.name:SetVertexColor(r, g, b, a)
                self.colorWrites = self.colorWrites + 1
                self.vertexColor = { r, g, b, a }
            end
            function frame.name:GetJustifyH() return self.justification or "CENTER" end
            frame.extraRegions = {}
            function frame:CreateFontString()
                local label = Widget()
                function label:IsForbidden() return frame.forbidden end
                frame.extraRegions[#frame.extraRegions + 1] = label
                return label
            end
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
            function frame:GetRegions()
                local unpackValues = unpack or table.unpack
                return self.name, self.decoration, unpackValues(self.extraRegions)
            end
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
    local addon = {}
    ctx.addon = addon
    for _, source in ipairs(sources) do
        local chunk
        if setfenv then
            chunk = assert(loadfile(source))
            setfenv(chunk, env)
        else
            chunk = assert(loadfile(source, "t", env))
        end
        chunk("SmartFriendlyNameplates", addon)
    end
    ctx:emit("ADDON_LOADED", "SmartFriendlyNameplates")
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
    assert(ctx.messages[1]:find("unavailable", 1, true))
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

test("only the public command is registered", function()
    local ctx = Context()
    equal(ctx.env.SLASH_SMARTFRIENDLYNAMEPLATES1, "/sfn")
    equal(ctx.env.SLASH_SMARTFRIENDLYNAMEPLATES2, nil)
    equal(ctx.env.SLASH_SMARTFRIENDLYNAMEPLATES3, nil)
end)

test("mouseover colour refresh is corrected synchronously without a polling tick", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    for _ = 1, 3 do
        ctx:nativeNameUpdate(frame)
        equal(frame.name.vertexColor[1], 0.25)
        equal(frame.name.vertexColor[2], 0.78)
        equal(BarVisible(frame), 0)
    end
    equal(#ctx.messages, 0)
    equal(ctx.env.CompactUnitFrame_UpdateName, ctx.nativeNameUpdater)
end)

test("hovering an NPC does not recolour it or flash other filtered player names", function()
    local ctx = Context()
    local _, player = ctx:unit("nameplate1", { class = "MAGE" })
    local _, npc = ctx:unit("nameplate2", { player = false, class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    ctx:nativeNameUpdate(npc)
    ctx:nativeNameUpdate(player)
    equal(npc.name.vertexColor[1], 1)
    equal(npc.name.vertexColor[2], 1)
    equal(player.name.vertexColor[1], 0.25)
    equal(npc.changes, 0)
end)

test("post-hook leaves full bars alone and stops after disabling colours or filter", function()
    local ctx = Context()
    local _, player = ctx:unit("nameplate1", { class = "MAGE" })
    local _, party = ctx:unit("nameplate2", { class = "MAGE", party = true })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    ctx:nativeNameUpdate(party)
    equal(party.name.vertexColor[1], 1)
    ctx:command("colors off")
    ctx:nativeNameUpdate(player)
    equal(player.name.vertexColor[1], 1)
    ctx:command("colors on")
    ctx:command("off")
    ctx:nativeNameUpdate(player)
    equal(player.name.vertexColor[1], 1)
end)

test("post-hook rechecks live identity when a pooled frame becomes an NPC", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    unit.player = false
    ctx:nativeNameUpdate(frame)
    equal(frame.name.vertexColor[1], 1)
    equal(frame.name.vertexColor[2], 1)
end)

test("post-hook tolerates secret class data and never writes native frame state", function()
    local ctx = Context()
    local unit, frame, plate = ctx:unit("nameplate1", { class = "MAGE" })
    local proxy = setmetatable({}, {
        __index = frame,
        __newindex = function(_, key) error("tainting native field: " .. key) end,
    })
    plate.UnitFrame = proxy
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:nativeNameUpdate(proxy)
    equal(frame.name.vertexColor[1], 0.25)
    unit.class = SECRET
    ctx:nativeNameUpdate(proxy)
    equal(frame.name.vertexColor[1], 1)
    equal(frame.showOnlyName, false)
    equal(frame.nativeHealthValue, SECRET)
    equal(#ctx.messages, 0)
end)

test("late-loaded native updater installs one hook and preserves existing settings", function()
    local ctx = Context(nil, { lateNameUpdater = true })
    equal(#ctx.nameHooks, 0)
    ctx:command("colors off")
    ctx.env.CompactUnitFrame_UpdateName = ctx.nativeNameUpdater
    ctx:emit("ADDON_LOADED", "Blizzard_UnitFrame")
    ctx:emit("PLAYER_ENTERING_WORLD")
    ctx:emit("PLAYER_ENTERING_WORLD")
    equal(#ctx.nameHooks, 1)
    equal(ctx.env.SmartFriendlyNameplatesDB.classColorsOnly, false)
end)

test("post-hook does not inspect untracked forbidden frames", function()
    local ctx = Context()
    equal(#ctx.nameHooks, 1)
    local forbidden = setmetatable({}, { __index = function() error("forbidden frame inspected") end })
    ctx.nameHooks[1](forbidden)
end)

local FILTER = "Enable friendly nameplate filtering"
local COLOURS = "Use class colours for names without health bars"
local GROUP = "Show health bars for group members"
local COMBAT = "Show health bars for units in combat"
local MINIONS = "Apply filtering to friendly player minions"
local TARGET = "Show health bar for current target"
local GUILD = "Show guild below name-only players"

test("options register once under Add-ons without applying game settings at registration", function()
    local ctx = Context()
    equal(#ctx.categories, 1)
    equal(ctx.categories[1].name, "Smart Friendly Nameplates")
    equal(ctx.categories[1].panel.shown, false)
    equal(ctx:widget(FILTER):GetChecked(), true)
    equal(ctx:widget(COLOURS):GetChecked(), true)
    equal(#ctx.writes, 0)
    ctx:emit("PLAYER_ENTERING_WORLD")
    ctx:emit("PLAYER_ENTERING_WORLD")
    equal(#ctx.categories, 1)
end)

test("filter checkbox uses the same restoration path as slash commands", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:click(FILTER)
    equal(ctx.env.SmartFriendlyNameplatesDB.enabled, false)
    equal(BarVisible(frame), 1)
    equal(frame.name.vertexColor[1], 0)
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0")
    ctx:click(FILTER)
    equal(BarVisible(frame), 0)
    equal(frame.name.vertexColor[1], 0.25)
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "1")
end)

test("colour checkbox changes live names and preserves filtering", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:click(COLOURS)
    equal(ctx.env.SmartFriendlyNameplatesDB.classColorsOnly, false)
    equal(BarVisible(frame), 0)
    equal(frame.name.vertexColor[1], 0)
    ctx:click(COLOURS)
    equal(frame.name.vertexColor[1], 0.25)
    equal(ctx:widget(FILTER):GetChecked(), true)
end)

test("slash commands keep an open panel in sync and panel refresh does not write CVars", function()
    local ctx = Context()
    ctx:command("options")
    ctx:command("off")
    ctx:command("colors off")
    equal(ctx:widget(FILTER):GetChecked(), false)
    equal(ctx:widget(COLOURS):GetChecked(), false)
    local writes = #ctx.writes
    ctx.categories[1].panel.OnRefresh()
    equal(#ctx.writes, writes)
    ctx:command("on")
    equal(ctx:widget(FILTER):GetChecked(), true)
end)

test("panel changes survive reload and a colour preference is editable while disabled", function()
    local first = Context()
    first:click(FILTER)
    first:click(COLOURS)
    local reloaded = Context(first)
    equal(reloaded:widget(FILTER):GetChecked(), false)
    equal(reloaded:widget(COLOURS):GetChecked(), false)
    reloaded:click(COLOURS)
    equal(reloaded.env.SmartFriendlyNameplatesDB.enabled, false)
    equal(reloaded.env.SmartFriendlyNameplatesDB.classColorsOnly, true)
    equal(#reloaded.writes, 0)
end)

test("panel toggles in combat defer CVars and refresh their pending message after combat", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local writes = #ctx.writes
    ctx.combat = true
    ctx:click(FILTER)
    equal(BarVisible(frame), 1)
    equal(#ctx.writes, writes)
    equal(ctx.addon.GetHealthState(), "combat")
    assert(ctx:hasText(ctx.addon.L.HEALTH_COMBAT))
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0")
    equal(ctx.addon.GetHealthState(), "disabled")
    assert(ctx:hasText(ctx.addon.L.HEALTH_DISABLED))
    equal(ctx:hasText(ctx.addon.L.HEALTH_COMBAT), false)
    ctx.combat = true
    ctx:click(FILTER)
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0")
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "1")
    equal(ctx.addon.GetHealthState(), "ready")
    assert(ctx:hasText(ctx.addon.L.HEALTH_READY))
end)

test("default actions restore both preferences and diagnostic buttons print in chat", function()
    local ctx = Context()
    ctx:command("off")
    ctx:command("colors off")
    ctx:click("Restore defaults")
    equal(ctx:widget(FILTER):GetChecked(), true)
    equal(ctx:widget(COLOURS):GetChecked(), true)
    ctx:command("off")
    ctx:command("colors off")
    ctx.categories[1].panel.OnDefault()
    equal(ctx.env.SmartFriendlyNameplatesDB.enabled, true)
    equal(ctx.env.SmartFriendlyNameplatesDB.classColorsOnly, true)
    local messages = #ctx.messages
    ctx:click("Print status")
    assert(#ctx.messages > messages)
    ctx:unit("target")
    ctx:click("Inspect target")
    assert(ctx.messages[#ctx.messages - 1]:find("Target display:", 1, true))
    assert(ctx.messages[#ctx.messages]:find("Reason:", 1, true))
end)

test("bare sfn and options open the registered category; combat prevents opening", function()
    local ctx = Context()
    ctx:command("")
    equal(ctx.openedCategory, 42)
    ctx.openedCategory = nil
    ctx:command("options")
    equal(ctx.openedCategory, 42)
    ctx.openedCategory = nil
    ctx.combat = true
    ctx:command("")
    equal(ctx.openedCategory, nil)
    assert(ctx.messages[#ctx.messages]:find("after leaving combat", 1, true))
end)

test("late settings registration retries without interrupting the filter", function()
    local ctx = Context(nil, { lateSettings = true })
    equal(#ctx.categories, 0)
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 0)
    ctx:command("options")
    assert(ctx.messages[#ctx.messages]:find("Options > Add-ons", 1, true))
    ctx.env.Settings = ctx.settings
    ctx:emit("PLAYER_ENTERING_WORLD")
    equal(#ctx.categories, 1)
end)

test("group and combat switches are independent across membership/combat combinations", function()
    for groupRule = 0, 1 do
        for combatRule = 0, 1 do
            local ctx = Context()
            if groupRule == 0 then ctx:click(GROUP) end
            if combatRule == 0 then ctx:click(COMBAT) end
            for party = 0, 1 do
                for raid = 0, 1 do
                    for combat = 0, 1 do
                        local _, frame = ctx:unit("nameplate1", {
                            party = party == 1, raid = raid == 1 and 2 or false, combat = combat == 1,
                        })
                        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
                        local visible = (groupRule == 1 and (party == 1 or raid == 1))
                            or (combatRule == 1 and combat == 1)
                        equal(BarVisible(frame), visible and 1 or 0)
                        ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
                    end
                end
            end
        end
    end
end)

test("disabled criteria do not consult restricted group, combat or health APIs", function()
    local ctx = Context()
    ctx:click(GROUP)
    ctx:click(COMBAT)
    local calls = 0
    local function Disallowed() calls = calls + 1; error("disabled rule consulted") end
    ctx.env.UnitInParty, ctx.env.UnitInRaid, ctx.env.UnitAffectingCombat = Disallowed, Disallowed, Disallowed
    local _, frame = ctx:unit("nameplate1", { health = SECRET, maxHealth = API_ERROR })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:tick()
    equal(BarVisible(frame), 0)
    equal(calls, 0)
    equal(ctx.healthReads, 0)
    ctx:click(FILTER)
    equal(BarVisible(frame), 1)
end)

test("minion option filters pets/guardians/totems only and preserves their native name colours", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, minion = ctx:unit("nameplate1", { player = false, minion = true, class = "MAGE" })
    local _, npc = ctx:unit("nameplate2", { player = false })
    local _, enemy = ctx:unit("nameplate3", { player = false, minion = true, friendly = false })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate3")
    equal(minion.changes, 0)
    equal(ctx.cvars.nameplateShowFriendlyPlayerMinions, "0")
    ctx:click(MINIONS)
    equal(ctx.cvars.nameplateShowFriendlyPlayerMinions, "1")
    equal(BarVisible(minion), 0)
    equal(minion.name.vertexColor[1], 0)
    equal(npc.changes, 0)
    equal(enemy.changes, 0)
    ctx:nativeNameUpdate(minion)
    equal(minion.name.vertexColor[1], 1)
    ctx:click(MINIONS)
    equal(BarVisible(minion), 1)
    equal(ctx.cvars.nameplateShowFriendlyPlayerMinions, "0")
    equal(ctx.cvars.nameplateShowFriendlyNpcs, "0")
end)

test("minions use pet group membership and their own combat", function()
    local ctx = Context()
    ctx:click(MINIONS)
    local unit, frame = ctx:unit("nameplate1", { player = false, minion = true, petParty = true })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 1)
    ctx:click(GROUP)
    equal(BarVisible(frame), 0)
    unit.combat = true
    ctx:tick()
    equal(BarVisible(frame), 1)
    ctx:click(COMBAT)
    equal(BarVisible(frame), 0)
    ctx:click(GROUP)
    unit.petParty, unit.petRaid = false, true
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(BarVisible(frame), 1)
end)

test("guardian/totem membership checks group owners and safely handles restricted ownership", function()
    for _, inRaid in ipairs({ false, true }) do
        local ctx = Context()
        ctx:click(MINIONS)
        ctx.groupMembers, ctx.inRaid = 2, inRaid
        local unit, frame = ctx:unit("nameplate1", {
            player = false, minion = true, owner = inRaid and "raid2" or "party1",
        })
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(BarVisible(frame), 1)
        unit.owner = "somebodyElse"
        ctx:emit("GROUP_ROSTER_UPDATE")
        equal(BarVisible(frame), 0)
        unit.owner = SECRET
        ctx:tick()
        equal(BarVisible(frame), 1)
        unit.owner = API_ERROR
        ctx:tick()
        equal(BarVisible(frame), 1)
        ctx:click(GROUP)
        equal(BarVisible(frame), 0)
    end
end)

test("uncertain minion identity leaves NPCs untouched", function()
    for _, value in ipairs({ SECRET, API_ERROR, false }) do
        local ctx = Context()
        ctx:click(MINIONS)
        local _, frame = ctx:unit("nameplate1", { player = false, minion = value })
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(frame.changes, 0)
    end
end)

test("supported options and diagnostics never query protected health APIs", function()
    local ctx = Context()
    ctx:click(MINIONS)
    local _, player = ctx:unit("nameplate1", { class = "MAGE", health = SECRET })
    local _, minion = ctx:unit("nameplate2", { player = false, minion = true, health = SECRET })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    ctx:tick()
    ctx:nativeNameUpdate(player)
    ctx:nativeNameUpdate(minion)
    ctx:unit("target", { health = SECRET })
    ctx:command("debug")
    ctx:command("status")
    ctx:click("Restore defaults")
    equal(ctx.healthReads, 0)
end)

test("minion CVar ownership survives reload and respects manual changes", function()
    local first = Context()
    first:click(MINIONS)
    local reload = Context(first)
    reload:emit("PLAYER_ENTERING_WORLD")
    equal(reload.cvars.nameplateShowFriendlyPlayerMinions, "1")
    reload:command("off")
    equal(reload.cvars.nameplateShowFriendlyPlayerMinions, "0")
    reload:command("on")
    reload.cvars.nameplateShowFriendlyPlayerMinions = "2"
    reload:click(MINIONS)
    equal(reload.cvars.nameplateShowFriendlyPlayerMinions, "2")
end)

test("minion activation and deactivation in combat defer only game-setting writes", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, frame = ctx:unit("nameplate1", { player = false, minion = true })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx.combat = true
    local writes = #ctx.writes
    ctx:click(MINIONS)
    equal(BarVisible(frame), 0)
    equal(#ctx.writes, writes)
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.cvars.nameplateShowFriendlyPlayerMinions, "1")
    ctx.combat = true
    ctx:click(MINIONS)
    equal(BarVisible(frame), 1)
    equal(ctx.cvars.nameplateShowFriendlyPlayerMinions, "1")
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.cvars.nameplateShowFriendlyPlayerMinions, "0")
end)

test("new preferences persist and defaults preserve the original behaviour", function()
    local first = Context()
    first:click(GROUP)
    first:click(COMBAT)
    first:click(MINIONS)
    local reload = Context(first)
    equal(reload:widget(GROUP):GetChecked(), false)
    equal(reload:widget(COMBAT):GetChecked(), false)
    equal(reload:widget(MINIONS):GetChecked(), true)
    reload:click("Restore defaults")
    equal(reload:widget(GROUP):GetChecked(), true)
    equal(reload:widget(COMBAT):GetChecked(), true)
    equal(reload:widget(MINIONS):GetChecked(), false)
    equal(reload:widget(FILTER):GetChecked(), true)
end)

test("old saved preferences survive migration and new defaults are filled in", function()
    local previous = { env = { SmartFriendlyNameplatesDB = { enabled = false, classColorsOnly = false } } }
    local ctx = Context(previous)
    equal(ctx:widget(FILTER):GetChecked(), false)
    equal(ctx:widget(COLOURS):GetChecked(), false)
    equal(ctx:widget(GROUP):GetChecked(), true)
    equal(ctx:widget(COMBAT):GetChecked(), true)
    equal(ctx:widget(MINIONS):GetChecked(), false)
end)

test("all options remain in a scrollable canvas and reflow on a narrower viewport", function()
    local ctx = Context()
    local scroll
    for _, widget in ipairs(ctx.widgets) do
        if widget.kind == "ScrollFrame" then scroll = widget end
    end
    assert(scroll and scroll.scrollChild)
    assert(scroll.scrollChild.height > 500)
    local height = scroll.scrollChild.height
    scroll.scripts.OnSizeChanged(scroll, 300)
    equal(scroll.scrollChild.width, 300)
    assert(scroll.scrollChild.height > height)
    assert(ctx:widget("Inspect target").point[5] < ctx:widget("Restore defaults").point[5])
end)

test("current target shows its bar immediately and previous target returns to name-only", function()
    local ctx = Context()
    ctx:click(TARGET)
    ctx:click(GUILD)
    local _, first = ctx:unit("nameplate1", { class = "MAGE", guild = "First Guild" })
    local _, second = ctx:unit("nameplate2", { guild = "Second Guild" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    ctx.target = "nameplate1"
    ctx:emit("PLAYER_TARGET_CHANGED")
    equal(BarVisible(first), 1)
    equal(first.name.vertexColor[1], 0)
    equal(first.extraRegions[1].shown, false)
    equal(BarVisible(second), 0)
    ctx.target = "nameplate2"
    ctx:emit("PLAYER_TARGET_CHANGED")
    equal(BarVisible(first), 0)
    equal(first.extraRegions[1].shown, true)
    equal(BarVisible(second), 1)
    ctx.target = nil
    ctx:emit("PLAYER_TARGET_CHANGED")
    equal(BarVisible(second), 0)
    ctx.target = "nameplate1"
    ctx:click(TARGET)
    equal(BarVisible(first), 0)
end)

test("target condition respects minion scope, NPC exclusion and unavailable comparisons", function()
    local ctx = Context()
    ctx:click(TARGET)
    ctx:click(MINIONS)
    local unit, pet = ctx:unit("nameplate1", { player = false, minion = true })
    local _, npc = ctx:unit("nameplate2", { player = false })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(BarVisible(pet), 0)
    ctx.target = "nameplate1"
    ctx:emit("PLAYER_TARGET_CHANGED")
    equal(BarVisible(pet), 1)
    equal(npc.changes, 0)
    ctx.target = nil
    for _, unknown in ipairs({ SECRET, API_ERROR }) do
        unit.target = unknown
        ctx:tick()
        equal(BarVisible(pet), 1)
    end
    ctx:click(TARGET)
    equal(BarVisible(pet), 0)
end)

test("guild labels preserve the alignment of native names", function()
    for _, justify in ipairs({ "LEFT", "RIGHT" }) do
        local ctx = Context()
        ctx:click(GUILD)
        local _, frame = ctx:unit("nameplate1", { guild = "Example" })
        frame.name.justification = justify
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(frame.extraRegions[1].point[1], "TOP" .. justify)
        equal(frame.extraRegions[1].point[3], "BOTTOM" .. justify)
        ctx:command("off")
    end
end)

test("guild labels appear only in name-only mode and are not faded on later updates", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1", { guild = "Example Guild" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(#frame.extraRegions, 0)
    equal(ctx.guildReads, 0)
    ctx:click(GUILD)
    local label = frame.extraRegions[1]
    equal(label.text, "<Example Guild>")
    equal(label.shown, true)
    equal(label.point[2], frame.name)
    for _ = 1, 3 do ctx:tick(); ctx:nativeNameUpdate(frame) end
    equal(label.alpha, 1)
    equal(label.shown, true)
    equal(#frame.extraRegions, 1)
    unit.party = true
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(label.text, "")
    equal(label.shown, false)
    unit.party = false
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(label.shown, true)
    ctx:click(GUILD)
    equal(label.text, "")
    equal(label.shown, false)
end)

test("late guild data and guild changes refresh without leaving stale text", function()
    local ctx = Context()
    ctx:click(GUILD)
    local unit, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(#frame.extraRegions, 0)
    unit.guild = "First"
    ctx:emit("UNIT_NAME_UPDATE", "nameplate1")
    local label = frame.extraRegions[1]
    equal(label.text, "<First>")
    unit.guild = "Second"
    ctx:emit("PLAYER_GUILD_UPDATE")
    equal(label.text, "<Second>")
    for _, unknown in ipairs({ SECRET, API_ERROR, false, "" }) do
        unit.guild = unknown
        ctx:tick()
        equal(label.text, "")
        equal(label.shown, false)
    end
end)

test("guild label follows native name visibility instead of appearing alone", function()
    local ctx = Context()
    ctx:click(GUILD)
    local _, frame = ctx:unit("nameplate1", { guild = "Example" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local label = frame.extraRegions[1]
    equal(label.shown, true)
    frame.name.shown = false
    ctx:nativeNameUpdate(frame)
    equal(label.shown, false)
    frame.name.shown = true
    ctx:nativeNameUpdate(frame)
    equal(label.shown, true)
    frame.name.IsShown = function() return SECRET end
    ctx:tick()
    equal(label.shown, false)
end)

test("guild lookup excludes minions, NPCs, enemies and forbidden frames", function()
    local ctx = Context()
    ctx:click(GUILD)
    ctx:click(MINIONS)
    for _, properties in ipairs({ { player = false, minion = true }, { player = false }, { friendly = false } }) do
        local _, frame = ctx:unit("nameplate1", properties)
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(#frame.extraRegions, 0)
    end
    ctx:unit("nameplate2")
    ctx:emit("FORBIDDEN_NAME_PLATE_UNIT_ADDED", "nameplate2")
    ctx:tick()
    equal(ctx.guildReads, 0)
end)

test("pool reuse clears the old guild before another player or NPC", function()
    local ctx = Context()
    ctx:click(GUILD)
    local _, frame = ctx:unit("nameplate1", { guild = "Previous" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local label = frame.extraRegions[1]
    ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(label.text, "")
    equal(label.shown, false)
    ctx:unit("nameplate2", { player = false }, frame)
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(label.text, "")
    ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate2")
    ctx:unit("nameplate3", { guild = "New" }, frame)
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate3")
    equal(label.text, "<New>")
end)

test("removed width setting is cleared and native name geometry is untouched", function()
    local previous = { env = { SmartFriendlyNameplatesDB = {
        enabled = true, nameWidthPercent = 500, showGuild = true, showTarget = true,
    } } }
    local ctx = Context(previous)
    equal(ctx.env.SmartFriendlyNameplatesDB.nameWidthPercent, nil)
    equal(ctx:widget(GUILD):GetChecked(), true)
    equal(ctx:widget(TARGET):GetChecked(), true)
    ctx.addon.SetOption("nameWidthPercent", 500)
    equal(ctx.env.SmartFriendlyNameplatesDB.nameWidthPercent, nil)
    for _, widget in ipairs(ctx.widgets) do
        assert(widget.kind ~= "Slider" or widget.minimum ~= 100 or widget.maximum ~= 500,
            "retired name-width slider still exists")
    end
    local _, frame = ctx:unit("nameplate1", { guild = "Example" })
    local function Untouched() error("native name geometry must not be accessed") end
    frame.name.GetWidth, frame.name.SetWidth = Untouched, Untouched
    frame.name.GetPoint, frame.name.SetPoint, frame.name.ClearAllPoints = Untouched, Untouched, Untouched
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:tick()
    ctx:nativeNameUpdate(frame)
    equal(BarVisible(frame), 0)
    equal(frame.extraRegions[1].text, "<Example>")
    ctx:command("off")
    equal(BarVisible(frame), 1)
    equal(frame.extraRegions[1].shown, false)
end)

test("guild and target preferences survive reload and restore defaults", function()
    local first = Context()
    first:click(GUILD)
    first:click(TARGET)
    local reload = Context(first)
    equal(reload:widget(GUILD):GetChecked(), true)
    equal(reload:widget(TARGET):GetChecked(), true)
    reload:click("Restore defaults")
    equal(reload:widget(GUILD):GetChecked(), false)
    equal(reload:widget(TARGET):GetChecked(), false)
end)

test("name visuals do not write native frame state or call health/layout helpers", function()
    local ctx = Context()
    ctx:click(GUILD)
    local _, frame, plate = ctx:unit("nameplate1", { guild = "Example", class = "MAGE" })
    local proxy = setmetatable({}, {
        __index = frame,
        __newindex = function(_, key) error("tainting native field: " .. key) end,
    })
    plate.UnitFrame = proxy
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:nativeNameUpdate(proxy)
    equal(frame.extraRegions[1].text, "<Example>")
    ctx:command("off")
    equal(frame.extraRegions[1].shown, false)
    equal(frame.showOnlyName, false)
    equal(ctx.healthReads, 0)
    equal(#ctx.messages, 1) -- The command acknowledgement only.
end)

test("French client localizes the panel and retains stable setting keys and commands", function()
    local ctx = Context(nil, { locale = "frFR" })
    local L = ctx.addon.L
    equal(L.UI_ENABLE, "Activer le filtre des barres d’info amicales")
    equal(ctx:widget(L.UI_ENABLE):GetChecked(), true)
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:click(L.UI_ENABLE)
    equal(ctx.env.SmartFriendlyNameplatesDB.enabled, false)
    equal(BarVisible(frame), 1)
    ctx:command("on")
    equal(ctx.env.SmartFriendlyNameplatesDB.enabled, true)
    equal(BarVisible(frame), 0)
    ctx:click(L.UI_COLORS)
    equal(ctx.env.SmartFriendlyNameplatesDB.classColorsOnly, false)
    ctx:command("colors on")
    equal(ctx.env.SmartFriendlyNameplatesDB.classColorsOnly, true)
    equal(ctx.messages[#ctx.messages], "|cff66ccffSmart Friendly Nameplates:|r " .. L.CMD_COLORS_ON)
    ctx:command("help")
    assert(ctx.messages[#ctx.messages]:find(L.CMD_HELP, 1, true))
    equal(ctx.env.SLASH_SMARTFRIENDLYNAMEPLATES1, "/sfn")
end)

test("French status, target diagnostics and combat deferral use localized text", function()
    local ctx = Context(nil, { locale = "frFR" })
    local L = ctx.addon.L
    ctx:emit("PLAYER_ENTERING_WORLD") -- establish settings that actually need restoring
    ctx:unit("target", { combat = SECRET })
    ctx:command("debug")
    assert(ctx.messages[1]:find("Cible : joueur=oui", 1, true))
    assert(ctx.messages[1]:find("son combat=indisponible", 1, true))
    ctx.combat = true
    ctx:command("off")
    assert(ctx:hasText(L.HEALTH_COMBAT))
    equal(ctx.messages[#ctx.messages], "|cff66ccffSmart Friendly Nameplates:|r " .. L.CMD_PENDING)
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    assert(ctx:hasText(L.HEALTH_DISABLED))
    ctx:command("status")
    assert(ctx.messages[#ctx.messages]:find(L.UI_RESTRICTIONS, 1, true))
end)

test("unsupported locales and missing translation keys fall back to English", function()
    local unknown = Context(nil, { locale = "xxXX" })
    equal(unknown.addon.L.UI_ENABLE, FILTER)
    equal(unknown:widget(FILTER):GetChecked(), true)
    local british = Context(nil, { locale = "enGB" })
    equal(british.addon.L.UI_ENABLE, FILTER)
    local french = Context(nil, { locale = "frFR" })
    french.addon.L.UI_ENABLE = nil
    equal(french.addon.L.UI_ENABLE, FILTER)
end)

test("French warnings and protected-error labels are localized", function()
    local ctx = Context(nil, { locale = "frFR" })
    ctx.failWrite = true
    ctx:emit("PLAYER_ENTERING_WORLD")
    assert(ctx.messages[1]:find("Impossible de modifier nameplateShowFriendlyPlayers", 1, true))
    local _, frame = ctx:unit("nameplate1")
    frame.decoration.SetAlpha = function(self, alpha)
        if alpha == 0 then error(SECRET) end
        self.alpha = alpha
    end
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    assert(ctx.messages[#ctx.messages]:find("Filtre suspendu pour cette barre d’info : erreur protégée", 1, true))
    ctx:command("status")
    local historyFound = false
    for _, message in ipairs(ctx.messages) do
        if message:find("Dernier problème :", 1, true) and message:find(ctx.addon.L.HISTORY_NOTE, 1, true) then
            historyFound = true
        end
    end
    equal(historyFound, true, "the localized historical error remains available in status")
end)

local clientLocales = { "enUS", "enGB", "frFR", "deDE", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }

test("every translated locale has all keys and valid matching format placeholders", function()
    local english = getmetatable(Context().addon.L).__index
    for _, locale in ipairs(clientLocales) do
        local ctx = Context(nil, { locale = locale })
        local L = ctx.addon.L
        for key, original in pairs(english) do
            if locale ~= "enUS" and locale ~= "enGB" then
                assert(type(rawget(L, key)) == "string", locale .. " lacks " .. key)
            end
            local signature, translatedSignature, arguments = {}, {}, {}
            for specifier in original:gmatch("%%([sd])") do
                signature[#signature + 1] = specifier
                arguments[#arguments + 1] = specifier == "d" and 1 or "test"
            end
            for specifier in L[key]:gmatch("%%([sd])") do
                translatedSignature[#translatedSignature + 1] = specifier
            end
            equal(table.concat(translatedSignature), table.concat(signature), locale .. "/" .. key)
            local unpackValues = unpack or table.unpack
            assert(pcall(string.format, L[key], unpackValues(arguments)), locale .. "/" .. key .. " cannot be formatted")
        end
        ctx:unit("target", { combat = SECRET })
        ctx:command("debug")
        ctx:command("status")
        ctx:command("help")
        ctx:command("off")
        ctx:command("on")
        assert(ctx:widget(L.UI_ENABLE):GetChecked())
    end
end)

test("translated buttons fit a narrow panel and can wrap onto more than one line", function()
    for _, locale in ipairs(clientLocales) do
        local ctx = Context(nil, { locale = locale })
        local scroll
        for _, widget in ipairs(ctx.widgets) do
            if widget.kind == "ScrollFrame" then scroll = widget end
        end
        scroll.scripts.OnSizeChanged(scroll, 300)
        for _, key in ipairs({ "UI_DEFAULTS", "UI_STATUS", "UI_INSPECT", "UI_SUBTITLE_COLOR_DEFAULT" }) do
            local button = ctx:widget(ctx.addon.L[key])
            assert(button.width <= 252, locale .. " button exceeds content width")
            assert(button.height >= button:GetFontString():GetStringHeight() + 12,
                locale .. " button clips its translated label")
        end
    end
end)

test("settings keep labels and controls in separate aligned columns in every locale", function()
    for _, locale in ipairs(clientLocales) do
        local ctx = Context(nil, { locale = locale })
        local scroll
        for _, widget in ipairs(ctx.widgets) do
            if widget.kind == "ScrollFrame" then scroll = widget end
        end
        for _, width in ipairs({ 300, 500, 780 }) do
            scroll.scripts.OnSizeChanged(scroll, width)
            local column = ctx:widget(ctx.addon.L.UI_GROUP).point[4]
            for _, widget in ipairs(ctx.widgets) do
                if widget.kind == "CheckButton" then
                    local row, label = widget.parent, widget.Text
                    equal(widget.point[4], column, locale .. " checkbox column")
                    equal(label.point[2], row, "label anchored to the setting row")
                    assert(label.point[4] + label.width < widget.point[4], "label overlaps the checkbox")
                    assert(row.height >= label:GetStringHeight() + 12, locale .. " clipped label")
                    assert(widget.point[4] + widget.width <= row.width, "checkbox outside its row")
                end
            end
            local default = ctx:widget(ctx.addon.L.UI_SUBTITLE_COLOR_DEFAULT)
            assert(default.point[4] + default.width <= default.parent.width,
                locale .. " colour default button outside its row")
        end
    end
end)

test("setting hover shows localized help and live prerequisites; row clicks toggle once", function()
    local ctx = Context(nil, { locale = "frFR" })
    local L, tooltip = ctx.addon.L, ctx.env.GameTooltip
    local check = ctx:widget(L.UI_NPC_BARS)
    local row = check.parent
    local highlight
    for _, widget in ipairs(ctx.widgets) do
        if widget.parent == row and widget.allPoints == row then highlight = widget end
    end
    assert(highlight)
    equal(ctx:hasText(L.UI_NPC_BARS_DESC), false, "help is not printed under every setting")
    row.scripts.OnEnter(row)
    equal(highlight.shown, true)
    equal(tooltip.shown, true)
    equal(tooltip.text, L.UI_NPC_BARS)
    equal(tooltip.owner, check, "row tooltip stays beside its control, not the panel edge")
    equal(tooltip.lines[1], L.UI_NPC_BARS_DESC)
    equal(tooltip.lines[2], L.UI_REQUIRES_NPCS)
    equal(tooltip.wrap, true)
    check.scripts.OnEnter(check)
    row.scripts.OnLeave(row)
    equal(tooltip.shown, true, "moving onto the control retains its tooltip")
    equal(tooltip.owner, check, "label and control hover use the same nearby anchor")
    ctx.addon.SetOption("includeNPCs", true)
    equal(tooltip.lines[2], nil, "prerequisites update while the row is hovered")
    row:Click()
    equal(ctx.addon.GetOptions().showNPCBars, true)
    row:Click()
    equal(ctx.addon.GetOptions().showNPCBars, false)
    check.scripts.OnLeave(check)
    equal(tooltip.shown, false)
    equal(highlight.shown, false)
    check.scripts.OnEnter(check)
    row:Hide()
    equal(tooltip.shown, false, "hiding the settings clears hover help")
end)

local function NPCTooltip(title, colorblind)
    local lines = { { type = 2, leftText = "NPC name" } }
    if colorblind then lines[#lines + 1] = { type = 0, leftText = "Friendly" } end
    if title then lines[#lines + 1] = { type = 0, leftText = title } end
    lines[#lines + 1] = { type = 47, leftText = "Level 60" }
    return { lines = lines }
end

test("NPC modes are independent of player rules, minions and class colours", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    ctx.addon.SetOption("showTarget", true)
    local unit, npc = ctx:unit("nameplate1", {
        player = false, combat = true, target = true, party = true, class = "MAGE",
        tooltip = NPCTooltip("Weaponsmith"),
    })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(npc), 0)
    equal(npc.name.vertexColor[1], 0, "NPC keeps native colour")
    equal(npc.extraRegions[1].text, "<Weaponsmith>")
    ctx.addon.SetOption("showNPCBars", true)
    equal(BarVisible(npc), 1)
    equal(npc.extraRegions[1].shown, false)
    ctx.addon.SetOption("showNPCBars", false)
    equal(BarVisible(npc), 0)
    equal(npc.extraRegions[1].shown, true)
    ctx.addon.SetOption("includeNPCs", false)
    equal(BarVisible(npc), 1)
    equal(npc.extraRegions[1].shown, false)
    equal(ctx.healthReads, 0)
end)

test("NPC inclusion excludes enemies, minions, players and unknown identities", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    for _, properties in ipairs({
        { player = false, friendly = false }, { player = false, minion = true },
        { player = SECRET }, { player = false, minion = SECRET },
        { player = false, minion = API_ERROR }, { player = false, friendly = SECRET },
        { player = false, self = true },
    }) do
        local _, frame = ctx:unit("nameplate1", properties)
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(BarVisible(frame), 1)
        equal(#frame.extraRegions, 0)
    end
    local _, player = ctx:unit("nameplate2")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(BarVisible(player), 0, "existing player filter still applies")
    equal(ctx.tooltipReads, 0)
end)

test("NPC support and minion support remain separate", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    ctx.addon.SetOption("showNPCBars", true)
    ctx.addon.SetOption("includeMinions", true)
    local _, npc = ctx:unit("nameplate1", { player = false })
    local _, pet = ctx:unit("nameplate2", { player = false, minion = true })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(BarVisible(npc), 1)
    equal(BarVisible(pet), 0)
    ctx.addon.SetOption("includeMinions", false)
    ctx.addon.SetOption("showNPCBars", false)
    equal(BarVisible(npc), 0)
    equal(BarVisible(pet), 1)
end)

test("NPC titles support colourblind tooltips and follow native name visibility", function()
    for _, colorblind in ipairs({ false, true }) do
        local ctx = Context()
        ctx.cvars.colorblindmode = colorblind and "1" or "0"
        ctx.addon.SetOption("includeNPCs", true)
        local _, frame = ctx:unit("nameplate1", { player = false,
            tooltip = NPCTooltip("Marchand d’armes", colorblind) })
        frame.name.justification = "LEFT"
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        local label = frame.extraRegions[1]
        equal(label.text, "<Marchand d’armes>")
        equal(label.point[1], "TOPLEFT")
        frame.name.shown = false
        ctx:nativeNameUpdate(frame)
        equal(label.shown, false)
        frame.name.shown = true
        ctx:nativeNameUpdate(frame)
        equal(label.shown, true)
        ctx:tick()
        equal(label.alpha, 1)
        ctx.addon.SetOption("showNPCTitle", false)
        equal(label.shown, false)
    end
end)

test("NPC title lookup rejects missing, secret, malformed and non-title lines", function()
    local samples = { false, SECRET, API_ERROR, {}, { lines = SECRET },
        { lines = { SECRET } }, { lines = { { type = SECRET } } },
        NPCTooltip(nil), NPCTooltip(SECRET), NPCTooltip(""),
        { lines = { { type = 2 }, { type = SECRET, leftText = "No" } } },
        { lines = { { type = 2 }, { type = 48, leftText = "Humanoid" } } },
        { lines = { { type = 2 }, { type = 0, leftText = SECRET } } },
    }
    for _, sample in ipairs(samples) do
        local ctx = Context()
        ctx.addon.SetOption("includeNPCs", true)
        local _, frame = ctx:unit("nameplate1", { player = false, tooltip = sample })
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(BarVisible(frame), 0)
        equal(#frame.extraRegions, 0)
        equal(#ctx.messages, 0, "unavailable titles are normal, not filter errors")
    end
end)

test("missing tooltip APIs or enum keep NPC names available without titles", function()
    for _, missing in ipairs({ "C_TooltipInfo", "Enum" }) do
        local ctx = Context()
        ctx.env[missing] = nil
        ctx.addon.SetOption("includeNPCs", true)
        local _, frame = ctx:unit("nameplate1", { player = false, tooltip = NPCTooltip("Vendor") })
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(BarVisible(frame), 0)
        equal(#frame.extraRegions, 0)
    end
end)

test("NPC tooltip cache retries late data and invalidates on name changes and removal", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    local unit, frame = ctx:unit("nameplate1", { player = false })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(ctx.tooltipReads, 1)
    for _ = 1, 5 do ctx:tick(); ctx:nativeNameUpdate(frame) end
    equal(ctx.tooltipReads, 1, "unavailable titles are throttled")
    unit.tooltip = NPCTooltip("First")
    for _ = 1, 5 do ctx:tick() end
    equal(ctx.tooltipReads, 2)
    local label = frame.extraRegions[1]
    equal(label.text, "<First>")
    for _ = 1, 15 do ctx:tick(); ctx:nativeNameUpdate(frame) end
    equal(ctx.tooltipReads, 2, "known title is cached for this plate lifetime")
    unit.tooltip = NPCTooltip("Second")
    ctx:emit("UNIT_NAME_UPDATE", "nameplate1")
    equal(label.text, "<Second>")
    ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(label.shown, false)
    ctx:unit("nameplate1", { player = false, tooltip = NPCTooltip("Third") }, frame)
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(label.text, "<Third>")
end)

test("NPC subtitle restores cleanly when pooled for a player, enemy or forbidden frame", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    ctx.addon.SetOption("showGuild", true)
    local unit, frame, plate = ctx:unit("nameplate1", { player = false, tooltip = NPCTooltip("Vendor") })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local label = frame.extraRegions[1]
    unit.player, unit.guild = true, "Player Guild"
    ctx:nativeNameUpdate(frame)
    equal(label.text, "<Player Guild>")
    unit.friendly = false
    ctx:emit("UNIT_FACTION", "nameplate1")
    equal(label.shown, false)
    equal(BarVisible(frame), 1)
    ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    local reads = ctx.tooltipReads
    plate.forbidden, frame.forbidden = true, true
    ctx:emit("FORBIDDEN_NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:tick()
    equal(ctx.tooltipReads, reads)
end)

test("NPC CVar ownership survives reload, respects manual edits and defers in combat", function()
    local ctx = Context()
    ctx.combat = true
    ctx.addon.SetOption("includeNPCs", true)
    equal(ctx.cvars.nameplateShowFriendlyNpcs, "0")
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.cvars.nameplateShowFriendlyNpcs, "1")
    local reload = Context(ctx)
    reload:emit("PLAYER_ENTERING_WORLD")
    reload.combat = true
    reload.addon.SetOption("includeNPCs", false)
    equal(reload.cvars.nameplateShowFriendlyNpcs, "1")
    reload.combat = false
    reload:emit("PLAYER_REGEN_ENABLED")
    equal(reload.cvars.nameplateShowFriendlyNpcs, "0")
    reload.addon.SetOption("includeNPCs", true)
    reload.cvars.nameplateShowFriendlyNpcs = "0"
    local writes = #reload.writes
    reload:command("off")
    equal(reload.cvars.nameplateShowFriendlyNpcs, "0")
    for index = writes + 1, #reload.writes do
        assert(reload.writes[index] ~= "nameplateShowFriendlyNpcs", "manual edit overwritten")
    end
end)

test("NPC preferences are translated, persist and return to safe defaults", function()
    for _, locale in ipairs(clientLocales) do
        local ctx = Context(nil, { locale = locale })
        local L = ctx.addon.L
        equal(ctx.env.SmartFriendlyNameplatesDB.includeNPCs, false)
        ctx:click(L.UI_NPCS)
        ctx:click(L.UI_NPC_BARS)
        ctx:click(L.UI_NPC_TITLE)
        local reload = Context(ctx, { locale = locale })
        equal(reload.env.SmartFriendlyNameplatesDB.includeNPCs, true)
        equal(reload.env.SmartFriendlyNameplatesDB.showNPCBars, true)
        equal(reload.env.SmartFriendlyNameplatesDB.showNPCTitle, false)
        reload:click(L.UI_DEFAULTS)
        equal(reload.env.SmartFriendlyNameplatesDB.includeNPCs, false)
        equal(reload.env.SmartFriendlyNameplatesDB.showNPCBars, false)
        equal(reload.env.SmartFriendlyNameplatesDB.showNPCTitle, true)
        reload:command("status")
    end
end)

test("name-only NPCs use native selection colours and retain their vertex alpha", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    local unit, frame = ctx:unit("nameplate1", { player = false })
    frame.name.vertexColor = { 1, 1, 1, 0.6 }
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(frame.name.vertexColor[1], 0)
    equal(frame.name.vertexColor[2], 1)
    equal(frame.name.vertexColor[3], 0)
    equal(frame.name.vertexColor[4], 0.6)
    ctx:nativeNameUpdate(frame)
    equal(frame.name.vertexColor[1], 0, "hover keeps the native friendly colour")
    unit.selectionColor = { 0.1, 0.8, 0.2 }
    ctx:tick()
    equal(frame.name.vertexColor[1], 0.1, "read the client's colour rather than hardcoding green")
    equal(frame.name.vertexColor[2], 0.8)
    ctx.addon.SetOption("npcNameColors", false)
    equal(frame.name.vertexColor[1], 1, "restore latest native nameplate colour")
    equal(BarVisible(frame), 0, "colour switch does not change NPC visibility")
    ctx:nativeNameUpdate(frame)
    equal(frame.name.vertexColor[1], 1)
end)

test("NPC colour is independent of player class colours and restores on full bars or off", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    ctx.addon.SetOption("classColorsOnly", false)
    local _, frame = ctx:unit("nameplate1", { player = false })
    frame.name.vertexColor = { 1, 1, 1, 1 }
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(frame.name.vertexColor[1], 0)
    ctx.addon.SetOption("showNPCBars", true)
    equal(frame.name.vertexColor[1], 1)
    ctx.addon.SetOption("showNPCBars", false)
    equal(frame.name.vertexColor[1], 0)
    ctx:command("off")
    equal(frame.name.vertexColor[1], 1)
end)

test("restricted, missing or malformed NPC selection colours preserve native name colours", function()
    for _, color in ipairs({ SECRET, API_ERROR, false, { 0, SECRET, 0 }, { "0", 1, 0 }, { 0, 1 } }) do
        local ctx = Context()
        ctx.addon.SetOption("includeNPCs", true)
        local _, frame = ctx:unit("nameplate1", { player = false, selectionColor = color })
        frame.name.vertexColor = { 1, 1, 1, 1 }
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(frame.name.vertexColor[1], 1)
        equal(BarVisible(frame), 0)
    end
    local ctx = Context()
    ctx.env.UnitSelectionColor = nil
    ctx.addon.SetOption("includeNPCs", true)
    local _, frame = ctx:unit("nameplate1", { player = false })
    frame.name.vertexColor = { 1, 1, 1, 1 }
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(frame.name.vertexColor[1], 1)
end)

test("NPC green is removed on hostility or frame reuse for players and minions", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    ctx.addon.SetOption("includeMinions", true)
    local unit, frame = ctx:unit("nameplate1", { player = false })
    frame.name.vertexColor = { 1, 1, 1, 1 }
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(frame.name.vertexColor[1], 0)
    unit.friendly = false
    ctx:emit("UNIT_FACTION", "nameplate1")
    equal(frame.name.vertexColor[1], 1)
    unit.friendly, unit.player, unit.class = true, true, "MAGE"
    ctx:tick()
    equal(frame.name.vertexColor[1], 0.25, "player uses class colour")
    unit.player, unit.minion = false, true
    ctx:nativeNameUpdate(frame)
    equal(frame.name.vertexColor[1], 1, "minion keeps native nameplate colour")
end)

test("NPC colour preference is translated, saved and enabled by restore defaults", function()
    for _, locale in ipairs(clientLocales) do
        local ctx = Context(nil, { locale = locale })
        equal(ctx.env.SmartFriendlyNameplatesDB.npcNameColors, true)
        ctx:click(ctx.addon.L.UI_NPC_COLORS)
        local reload = Context(ctx, { locale = locale })
        equal(reload.env.SmartFriendlyNameplatesDB.npcNameColors, false)
        reload:click(reload.addon.L.UI_DEFAULTS)
        equal(reload.env.SmartFriendlyNameplatesDB.npcNameColors, true)
    end
end)

test("profile migration keeps existing character preferences and CVar originals", function()
    local original = { nameplateShowFriendlyPlayers = { before = "0", applied = "1" } }
    local ctx = Context({ env = { SmartFriendlyNameplatesDB = {
        enabled = false, classColorsOnly = false, includeNPCs = true, originalCVars = original,
    } } })
    equal(ctx.addon.GetProfile(), "character")
    equal(ctx.addon.GetOptions(), ctx.env.SmartFriendlyNameplatesDB)
    equal(ctx.addon.GetOptions().includeNPCs, true)
    equal(ctx.addon.GetOptions().classColorsOnly, false)
    equal(ctx.env.SmartFriendlyNameplatesDB.originalCVars, original)
    equal(ctx.env.SmartFriendlyNameplatesGlobalDB.profile, nil, "global is seeded on first use only")
    equal(#ctx.writes, 0, "registration does not change game settings")
end)

test("first global selection copies preferences once and preserves an independent character profile", function()
    local ctx = Context()
    ctx.addon.SetOption("showGuild", true)
    ctx.addon.SetOption("includeNPCs", true)
    ctx.addon.SetProfile("global")
    local shared = ctx.env.SmartFriendlyNameplatesGlobalDB.profile
    equal(ctx.addon.GetOptions(), shared)
    for key in pairs(ctx.addon.DEFAULTS) do equal(shared[key], ctx.env.SmartFriendlyNameplatesDB[key], key) end
    equal(shared.originalCVars, nil)
    equal(shared.profileScope, nil)
    ctx.addon.SetOption("showGuild", false)
    ctx.addon.SetOption("includeNPCs", false)
    ctx.addon.SetProfile("character")
    equal(ctx.addon.GetOptions().showGuild, true)
    equal(ctx.addon.GetOptions().includeNPCs, true)
    ctx.addon.SetOption("showTarget", true)
    ctx.addon.SetProfile("global")
    equal(ctx.addon.GetOptions().showGuild, false)
    equal(ctx.addon.GetOptions().includeNPCs, false)
    equal(ctx.addon.GetOptions().showTarget, false)
    equal(ctx.env.SmartFriendlyNameplatesGlobalDB.profile, shared, "later switches do not reseed")
end)

test("different characters can share the global profile without overwriting their own preferences", function()
    local first = Context()
    first.addon.SetOption("showGuild", true)
    first.addon.SetProfile("global")
    first.addon.SetOption("showTarget", true)
    local second = Context({ env = {
        SmartFriendlyNameplatesGlobalDB = first.env.SmartFriendlyNameplatesGlobalDB,
        SmartFriendlyNameplatesDB = { showGroup = false, showGuild = false },
    } })
    equal(second.addon.GetProfile(), "character")
    equal(second.addon.GetOptions().showTarget, false)
    second.addon.SetProfile("global")
    equal(second.addon.GetOptions().showTarget, true)
    equal(second.addon.GetOptions().showGuild, true)
    equal(second.addon.GetOptions().showGroup, true, "second character does not replace global settings")
    second.addon.SetOption("showCombat", false)
    second.addon.SetProfile("character")
    equal(second.addon.GetOptions().showGroup, false)
    equal(second.addon.GetOptions().showCombat, true)
    local firstAgain = Context(first)
    equal(firstAgain.addon.GetProfile(), "global")
    equal(firstAgain.addon.GetOptions().showCombat, false)
end)

test("global selection, panel edits and slash-command edits survive reload", function()
    local ctx = Context()
    ctx:click(ctx.addon.L.UI_PROFILE_GLOBAL)
    ctx:click(GUILD)
    ctx:command("off")
    ctx:command("colors off")
    equal(ctx.env.SmartFriendlyNameplatesDB.enabled, true, "personal master switch is preserved")
    equal(ctx.env.SmartFriendlyNameplatesDB.showGuild, false)
    local reload = Context(ctx)
    equal(reload.addon.GetProfile(), "global")
    equal(reload:widget(reload.addon.L.UI_PROFILE_GLOBAL):GetChecked(), true)
    equal(reload:widget(FILTER):GetChecked(), false)
    equal(reload:widget(COLOURS):GetChecked(), false)
    equal(reload:widget(GUILD):GetChecked(), true)
    reload:click(reload.addon.L.UI_PROFILE_GLOBAL)
    equal(reload:widget(FILTER):GetChecked(), true)
    equal(reload:widget(COLOURS):GetChecked(), true)
    equal(reload:widget(GUILD):GetChecked(), false)
end)

test("Restore defaults only resets the active profile without changing its selection", function()
    local ctx = Context()
    ctx.addon.SetOption("showCombat", false)
    ctx.addon.SetProfile("global")
    ctx.addon.SetOption("includeNPCs", true)
    ctx:click(ctx.addon.L.UI_DEFAULTS)
    equal(ctx.addon.GetProfile(), "global")
    equal(ctx.addon.GetOptions().showCombat, true)
    equal(ctx.addon.GetOptions().includeNPCs, false)
    equal(ctx.env.SmartFriendlyNameplatesDB.showCombat, false)
    ctx.addon.SetOption("showGuild", true)
    ctx.addon.SetProfile("character")
    ctx.categories[1].panel.OnDefault()
    equal(ctx.addon.GetProfile(), "character")
    equal(ctx.addon.GetOptions().showCombat, true)
    equal(ctx.env.SmartFriendlyNameplatesGlobalDB.profile.showGuild, true)
end)

test("profile switches preserve CVar ownership across enabled profiles and restore on disable", function()
    local ctx = Context()
    ctx.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames = "1"
    ctx:emit("PLAYER_ENTERING_WORLD")
    local originals = ctx.env.SmartFriendlyNameplatesDB.originalCVars
    ctx.addon.SetProfile("global")
    ctx.addon.SetOption("includeNPCs", true)
    equal(ctx.cvars.nameplateShowFriendlyNpcs, "1")
    ctx.addon.SetProfile("character")
    equal(ctx.cvars.nameplateShowFriendlyNpcs, "0")
    ctx.addon.SetProfile("global")
    equal(ctx.cvars.nameplateShowFriendlyNpcs, "1")
    equal(ctx.env.SmartFriendlyNameplatesDB.originalCVars, originals)
    local reload = Context(ctx)
    reload:emit("PLAYER_ENTERING_WORLD")
    reload:command("off")
    equal(reload.cvars.nameplateShowFriendlyPlayers, "0")
    equal(reload.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames, "1")
    equal(reload.cvars.nameplateShowFriendlyNpcs, "0")
    equal(next(reload.env.SmartFriendlyNameplatesDB.originalCVars), nil)
    equal(reload.env.SmartFriendlyNameplatesGlobalDB.profile.originalCVars, nil)
end)

test("shared preferences never share another character's CVar restoration baseline", function()
    local first = Context()
    first.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames = "1"
    first:emit("PLAYER_ENTERING_WORLD")
    first.addon.SetProfile("global")
    local second = Context({ env = { SmartFriendlyNameplatesGlobalDB = first.env.SmartFriendlyNameplatesGlobalDB } })
    second:emit("PLAYER_ENTERING_WORLD")
    second.addon.SetProfile("global")
    second:command("off")
    equal(second.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames, "0")
    equal(first.env.SmartFriendlyNameplatesDB.originalCVars.nameplateUseClassColorForFriendlyPlayerUnitNames.before, "1")
    local firstAgain = Context(first)
    firstAgain:emit("PLAYER_ENTERING_WORLD")
    equal(firstAgain.cvars.nameplateUseClassColorForFriendlyPlayerUnitNames, "1")
end)

test("profile switches in combat apply visuals now and reconcile only the final CVar state later", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    ctx.addon.SetProfile("global")
    ctx.addon.SetOption("enabled", false)
    ctx.addon.SetProfile("character")
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 0)
    ctx.combat = true
    local writes = #ctx.writes
    ctx.addon.SetProfile("global")
    equal(BarVisible(frame), 1)
    equal(#ctx.writes, writes)
    ctx.addon.SetProfile("character")
    equal(BarVisible(frame), 0)
    ctx.addon.SetProfile("global")
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0")
    equal(ctx.addon.GetProfile(), "global")
    local _, pending = ctx.addon.GetOptions()
    equal(pending, false)
end)

test("switching profiles refreshes player and NPC rules, colours and subtitles immediately", function()
    local ctx = Context()
    local _, player = ctx:unit("nameplate1", { party = true, guild = "Guild", class = "MAGE" })
    local _, npc = ctx:unit("nameplate2", { player = false, tooltip = NPCTooltip("Vendor") })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(BarVisible(player), 1)
    equal(BarVisible(npc), 1)
    ctx.addon.SetProfile("global")
    ctx.addon.SetOption("showGroup", false)
    ctx.addon.SetOption("showGuild", true)
    ctx.addon.SetOption("includeNPCs", true)
    equal(BarVisible(player), 0)
    equal(player.extraRegions[1].text, "<Guild>")
    equal(player.name.vertexColor[1], 0.25)
    equal(BarVisible(npc), 0)
    equal(npc.extraRegions[1].text, "<Vendor>")
    ctx.addon.SetProfile("character")
    equal(BarVisible(player), 1)
    equal(BarVisible(npc), 1)
    equal(player.extraRegions[1].shown, false)
    equal(npc.extraRegions[1].shown, false)
end)

test("invalid saved profile data is repaired without losing valid character preferences", function()
    local ctx = Context({ env = {
        SmartFriendlyNameplatesDB = { showGuild = true, profileScope = "unknown" },
        SmartFriendlyNameplatesGlobalDB = false,
    } })
    equal(ctx.addon.GetProfile(), "character")
    equal(ctx.addon.GetOptions().showGuild, true)
    ctx.addon.SetProfile("global")
    equal(ctx.addon.GetOptions().showGuild, true)
    local invalid = Context({ env = {
        SmartFriendlyNameplatesDB = { profileScope = "global", showTarget = true },
        SmartFriendlyNameplatesGlobalDB = { profile = "broken" },
    } })
    equal(invalid.addon.GetOptions().showTarget, true)
    local incomplete = Context({ env = {
        SmartFriendlyNameplatesDB = { profileScope = "global" },
        SmartFriendlyNameplatesGlobalDB = { profile = { enabled = false, showTarget = "wrong" } },
    } })
    equal(incomplete.addon.GetOptions().enabled, false)
    equal(incomplete.addon.GetOptions().showTarget, false)
end)

test("no-op and invalid profile selections do not write settings", function()
    local ctx = Context()
    ctx.addon.SetProfile("character")
    ctx.addon.SetProfile("invalid")
    ctx.addon.SetProfile(false)
    equal(ctx.addon.GetProfile(), "character")
    equal(#ctx.writes, 0)
    equal(ctx.env.SmartFriendlyNameplatesGlobalDB.profile, nil)
end)

test("all locales expose the active profile in the panel and diagnostics", function()
    for _, locale in ipairs(clientLocales) do
        local ctx = Context(nil, { locale = locale })
        local L = ctx.addon.L
        assert(ctx:hasText(string.format(L.UI_PROFILE_CURRENT, L.VALUE_PROFILE_CHARACTER)))
        ctx:click(L.UI_PROFILE_GLOBAL)
        assert(ctx:hasText(string.format(L.UI_PROFILE_CURRENT, L.VALUE_PROFILE_GLOBAL)))
        ctx:command("status")
        local expected = string.format(L.STATUS_PROFILE, L.VALUE_PROFILE_GLOBAL)
        local found = false
        for _, message in ipairs(ctx.messages) do if message:find(expected, 1, true) then found = true end end
        equal(found, true)
    end
end)

test("unchanged polling avoids duplicate visual writes while repairing a native alpha reset", function()
    local ctx = Context()
    ctx.addon.SetOption("showGuild", true)
    local _, frame = ctx:unit("nameplate1", { class = "MAGE", guild = "Example" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local label = frame.extraRegions[1]
    local alphas, colors = frame.changes, frame.name.colorWrites
    local text, points = label.visualWrites.text, label.visualWrites.point
    for _ = 1, 8 do ctx:tick() end
    equal(frame.changes, alphas, "unchanged children need no alpha writes")
    equal(frame.name.colorWrites, colors, "unchanged name needs no colour writes")
    equal(label.visualWrites.text, text, "unchanged subtitle needs no text writes")
    equal(label.visualWrites.point, points, "unchanged subtitle needs no anchor writes")
    frame.HealthBarsContainer.alpha = 1
    ctx:tick()
    equal(BarVisible(frame), 0, "the native engine may reset alpha without changing the desired mode")
    equal(frame.changes, alphas + 1, "only the reset component is rewritten")
end)

test("unrelated unit events do not rescan all tracked nameplates", function()
    local ctx = Context()
    ctx.addon.SetMetricsEnabled(true)
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx.addon.ResetMetrics()
    for _, event in ipairs({ "UNIT_FLAGS", "UNIT_FACTION", "UNIT_NAME_UPDATE" }) do
        ctx:emit(event, "unrelatedUnit")
    end
    equal(ctx.addon.GetMetrics().updates, 0)
    equal(BarVisible(frame), 0)
    ctx.units.nameplate1.combat = true
    ctx:emit("UNIT_FLAGS", "nameplate1")
    equal(BarVisible(frame), 1, "relevant events stay immediate")
    ctx.party1 = "nameplate1"
    ctx.units.nameplate1.combat = false
    ctx:emit("UNIT_FLAGS", "party1")
    equal(BarVisible(frame), 0, "an alternate token for a tracked unit is still relevant")
end)

test("focus and mouseover bar rules act independently and default to disabled", function()
    for _, item in ipairs({ { "showFocus", "focus", "PLAYER_FOCUS_CHANGED" },
        { "showMouseover", "mouseover", "UPDATE_MOUSEOVER_UNIT" } }) do
        local ctx = Context()
        equal(ctx.addon.GetOptions()[item[1]], false)
        local _, first = ctx:unit("nameplate1")
        local _, second = ctx:unit("nameplate2")
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
        ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
        ctx[item[2]] = "nameplate1"
        ctx:emit(item[3])
        equal(BarVisible(first), 0, "disabled rule leaves names only")
        ctx.addon.SetOption(item[1], true)
        equal(BarVisible(first), 1)
        equal(BarVisible(second), 0)
        ctx[item[2]] = "nameplate2"
        ctx:emit(item[3])
        equal(BarVisible(first), 0)
        equal(BarVisible(second), 1)
        ctx[item[2]] = nil
        ctx:emit(item[3])
        equal(BarVisible(second), 0)
    end
end)

test("new comparison rules exclude unsupported units and tolerate restricted comparisons", function()
    local ctx = Context()
    ctx.addon.SetOption("showFocus", true)
    ctx.addon.SetOption("showMouseover", true)
    local unit, frame = ctx:unit("nameplate1", { focus = SECRET })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(frame), 1, "unknown comparison preserves native bar")
    unit.focus, unit.mouseover = false, API_ERROR
    ctx:tick()
    equal(BarVisible(frame), 1)
    unit.focus, unit.mouseover = false, false
    ctx:tick()
    equal(BarVisible(frame), 0)
    local _, minion = ctx:unit("nameplate2", { player = false, minion = true })
    ctx.focus = "nameplate2"
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(minion.changes, 0, "excluded minion remains native")
    ctx.addon.SetOption("includeMinions", true)
    equal(BarVisible(minion), 1)
    ctx.focus = nil
    ctx:emit("PLAYER_FOCUS_CHANGED")
    equal(BarVisible(minion), 0)
    equal(ctx.healthReads, 0)
end)

test("NPC target exception is independent of player target focus and combat rules", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    ctx.addon.SetOption("showTarget", true)
    ctx.addon.SetOption("showFocus", true)
    ctx.addon.SetOption("showMouseover", true)
    local unit, npc = ctx:unit("nameplate1", { player = false, combat = true })
    ctx.target, ctx.focus, ctx.mouseover = "nameplate1", "nameplate1", "nameplate1"
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(BarVisible(npc), 0, "player conditions do not alter NPC mode")
    ctx.addon.SetOption("npcShowTarget", true)
    equal(BarVisible(npc), 1)
    ctx.target = nil
    ctx:emit("PLAYER_TARGET_CHANGED")
    equal(BarVisible(npc), 0)
    unit.target = SECRET
    ctx:tick()
    equal(BarVisible(npc), 1, "unknown target comparison stays conservative")
    ctx.addon.SetOption("showNPCBars", true)
    unit.target = false
    ctx:tick()
    equal(BarVisible(npc), 1)
end)

test("live game-setting conflicts are reported without automatic write battles", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    equal(ctx.addon.GetHealthState(), "ready")
    local writes = #ctx.writes
    ctx.cvars.nameplateShowFriendlyPlayers = "0"
    ctx:emit("CVAR_UPDATE", "nameplateShowFriendlyPlayers", "0")
    equal(ctx.addon.GetHealthState(), "conflict")
    equal(#ctx.writes, writes, "external changes are observed without forcibly writing back")
    local report = ctx.addon.BuildReport()
    assert(report:find("nameplateShowFriendlyPlayers", 1, true))
    ctx.addon.Repair()
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "1")
    equal(ctx.addon.GetHealthState(), "ready")
    ctx:command("off")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0", "repair retains the original restoration baseline")
end)

test("out-of-combat CVar failures and unavailable settings have truthful health states", function()
    local ctx = Context()
    ctx.failWrite = true
    ctx:emit("PLAYER_ENTERING_WORLD")
    equal(ctx.addon.GetHealthState(), "error")
    assert(ctx.addon.GetHealthSummary() ~= ctx.addon.L.UI_PENDING,
        "a refused setting is not described as waiting for combat")
    ctx.failWrite = false
    ctx.addon.Repair()
    equal(ctx.addon.GetHealthState(), "ready")
    ctx.cvars.nameplateShowFriendlyPlayers = nil
    ctx:emit("CVAR_UPDATE", "nameplateShowFriendlyPlayers")
    equal(ctx.addon.GetHealthState(), "unavailable")
    ctx.cvars.nameplateShowFriendlyPlayers = "1"
    ctx:emit("CVAR_UPDATE", "nameplateShowFriendlyPlayers", "1")
    equal(ctx.addon.GetHealthState(), "ready")
    ctx.combat = true
    ctx.addon.SetOption("includeNPCs", true)
    equal(ctx.addon.GetHealthState(), "combat")
    ctx.combat = false
    ctx:emit("PLAYER_REGEN_ENABLED")
    equal(ctx.addon.GetHealthState(), "ready")
end)

test("manual repair recovers a latched visual failure without retrying every tick", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    local originalSetAlpha = frame.decoration.SetAlpha
    local calls = 0
    frame.decoration.SetAlpha = function(self, alpha)
        if alpha == 0 then calls = calls + 1; error("temporary visual refusal") end
        return originalSetAlpha(self, alpha)
    end
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    for _ = 1, 5 do ctx:tick() end
    equal(calls, 1)
    equal(BarVisible(frame), 1)
    local before = ctx.addon.BuildReport()
    assert(before:find("temporary visual refusal", 1, true))
    frame.decoration.SetAlpha = originalSetAlpha
    ctx.addon.Repair()
    equal(BarVisible(frame), 0)
    equal(frame.name.vertexColor[1], 0.25)
    equal(ctx.healthReads, 0)
end)

test("explicit profile copies preserve selectors and per-character game-setting ownership", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local character = ctx.env.SmartFriendlyNameplatesDB
    local originals = character.originalCVars
    ctx.addon.SetOption("showFocus", true)
    ctx.addon.SetOption("subtitleSize", 18)
    ctx.addon.CopyProfile("global")
    equal(ctx.addon.GetProfile(), "character")
    local global = ctx.env.SmartFriendlyNameplatesGlobalDB.profile
    for key in pairs(ctx.addon.DEFAULTS) do equal(global[key], character[key], key) end
    equal(global.originalCVars, nil)
    equal(global.profileScope, nil)
    equal(character.originalCVars, originals)
    ctx.addon.SetProfile("global")
    ctx.addon.SetOption("showFocus", false)
    ctx.addon.SetOption("subtitleSize", 14)
    ctx.addon.CopyProfile("character")
    equal(ctx.addon.GetProfile(), "global")
    equal(character.showFocus, false)
    equal(character.subtitleSize, 14)
    equal(character.profileScope, "global")
    equal(character.originalCVars, originals)
    ctx.addon.SetProfile("character")
    equal(ctx.addon.GetOptions().subtitleSize, 14)
    ctx:command("off")
    equal(ctx.cvars.nameplateShowFriendlyPlayers, "0")
end)

test("subtitle appearance applies live to addon labels and survives frame recycling", function()
    local ctx = Context()
    ctx.addon.SetOption("showGuild", true)
    local unit, frame = ctx:unit("nameplate1", { guild = "Guild" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local label = frame.extraRegions[1]
    ctx.addon.SetOption("subtitleSize", 18)
    ctx.addon.SetOption("subtitleOffset", 7)
    ctx.addon.SetOption("subtitleRed", 0.2)
    ctx.addon.SetOption("subtitleGreen", 0.4)
    ctx.addon.SetOption("subtitleBlue", 0.6)
    ctx.addon.SetOption("subtitleBrackets", false)
    equal(label.fontSize, 18)
    equal(label.point[5], -7)
    equal(label.textColor[1], 0.2)
    equal(label.textColor[2], 0.4)
    equal(label.textColor[3], 0.6)
    equal(label.text, "Guild")
    unit.party = true
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(label.shown, false)
    ctx:emit("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    local _, nextFrame = ctx:unit("nameplate2", { guild = "Next" }, frame)
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate2")
    equal(nextFrame.extraRegions[1].text, "Next")
    equal(nextFrame.extraRegions[1].fontSize, 18)
    ctx.addon.RestoreDefaults()
    equal(nextFrame.extraRegions[1].shown, false)
    ctx.addon.SetOption("showGuild", true)
    equal(nextFrame.extraRegions[1].text, "<Next>")
    equal(nextFrame.extraRegions[1].fontSize, 12)
    equal(nextFrame.extraRegions[1].point[5], -2)
end)

local function SubtitlePicker(ctx)
    -- Match native setup's synchronous callback and Classic OK's hide-before-save.
    local picker = { shown = false }
    function picker:Hide() self.shown = false end
    function picker:GetColorRGB() return self.r, self.g, self.b end
    function picker:Select(r, g, b)
        self.r, self.g, self.b = r, g, b
        self.swatchFunc()
    end
    function picker:SetupColorPickerAndShow(info)
        self.info, self.swatchFunc, self.cancelFunc = info, info.swatchFunc, info.cancelFunc
        self:Select(info.r, info.g, info.b)
        self.shown = true
    end
    function picker:Cancel()
        self.cancelFunc({ r = self.info.r, g = self.info.g, b = self.info.b })
        self:Hide()
    end
    function picker:Okay()
        self:Hide()
        self.swatchFunc()
    end
    ctx.env.ColorPickerFrame = picker
    for _, widget in ipairs(ctx.widgets) do
        if widget.colorTexture and widget.parent and widget.parent.template == "UIPanelButtonTemplate" then
            return picker, widget.parent, widget
        end
    end
    error("missing subtitle colour swatch")
end

test("native subtitle picker previews all channels together, cancels and saves across reload", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    ctx.addon.SetOption("showGuild", true)
    local _, frame = ctx:unit("nameplate1", { guild = "Guild" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local picker, button, swatch = SubtitlePicker(ctx)
    button.scripts.OnClick()
    equal(picker.shown, true)
    equal(picker.info.r, 0.7)
    equal(picker.info.g, 0.85)
    equal(picker.info.b, 0.7)
    equal(picker.info.hasOpacity, false)
    ctx.addon.SetMetricsEnabled(true)
    ctx.addon.ResetMetrics()
    local writes = #ctx.writes
    ctx.combat = true
    picker:Select(0.123, 0.456, 0.789)
    equal(ctx.addon.GetMetrics().fullUpdates, 1, "one reconciliation per colour change")
    equal(#ctx.writes, writes, "colour previews require no CVar writes")
    for index, expected in ipairs({ 0.123, 0.456, 0.789 }) do
        equal(frame.extraRegions[1].textColor[index], expected)
        equal(swatch.colorTexture[index], expected)
    end
    picker:Cancel()
    equal(ctx.addon.GetOptions().subtitleRed, 0.7)
    equal(frame.extraRegions[1].textColor[2], 0.85)
    equal(swatch.colorTexture[3], 0.7)
    button.scripts.OnClick()
    picker:Select(0.2, 0.4, 0.6)
    picker:Okay()
    local reload = Context(ctx)
    equal(reload.addon.GetOptions().subtitleRed, 0.2)
    equal(reload.addon.GetOptions().subtitleGreen, 0.4)
    equal(reload.addon.GetOptions().subtitleBlue, 0.6)
end)

test("colour-only defaults preserve other preferences and invalidate any pending cancel", function()
    local ctx = Context()
    ctx.addon.SetOption("subtitleSize", 18)
    ctx.addon.SetOption("subtitleOffset", 7)
    ctx.addon.SetOption("subtitleBrackets", false)
    ctx.addon.SetSubtitleColor(0.2, 0.4, 0.6)
    local picker, button, swatch = SubtitlePicker(ctx)
    equal(button.alpha, 0.5, "inactive subtitle colour stays editable")
    button.scripts.OnClick()
    picker:Select(0.7, 0.85, 0.7)
    local staleCancel = picker.cancelFunc
    ctx:click(ctx.addon.L.UI_SUBTITLE_COLOR_DEFAULT)
    equal(picker.shown, false)
    staleCancel()
    local db = ctx.addon.GetOptions()
    equal(db.subtitleRed, 0.7)
    equal(db.subtitleGreen, 0.85)
    equal(db.subtitleBlue, 0.7)
    equal(swatch.colorTexture[2], 0.85)
    equal(db.subtitleSize, 18)
    equal(db.subtitleOffset, 7)
    equal(db.subtitleBrackets, false)
    equal(db.showGuild, false)
end)

test("profile switches and defaults invalidate picker callbacks without closing another addon's picker", function()
    local ctx = Context()
    local picker, button = SubtitlePicker(ctx)
    button.scripts.OnClick()
    picker:Select(0.2, 0.4, 0.6)
    local staleChange, staleCancel = picker.swatchFunc, picker.cancelFunc
    ctx.addon.SetProfile("global")
    equal(picker.shown, false)
    ctx.addon.SetSubtitleColor(0.1, 0.3, 0.5)
    staleChange()
    staleCancel()
    equal(ctx.addon.GetOptions().subtitleRed, 0.1)
    ctx.addon.SetProfile("character")
    equal(ctx.addon.GetOptions().subtitleRed, 0.2)
    button.scripts.OnClick()
    picker:Select(0.3, 0.5, 0.7)
    staleCancel = picker.cancelFunc
    ctx.addon.RestoreDefaults()
    equal(picker.shown, false)
    staleCancel()
    equal(ctx.addon.GetOptions().subtitleRed, 0.7)
    button.scripts.OnClick()
    picker.swatchFunc = function() end -- another addon takes ownership
    ctx.addon.SetProfile("global")
    equal(picker.shown, true)
end)

test("numeric preferences reject invalid values and repair malformed saved data", function()
    local ctx = Context()
    for key, values in pairs({
        subtitleSize = { 7, 25, false, "18", 0 / 0, math.huge },
        subtitleOffset = { -1, 13, false, "4" },
        subtitleRed = { -0.1, 1.1, "0.5" },
    }) do
        local original = ctx.addon.GetOptions()[key]
        for _, value in ipairs(values) do
            ctx.addon.SetOption(key, value)
            equal(ctx.addon.GetOptions()[key], original, key)
        end
    end
    local reload = Context({ env = { SmartFriendlyNameplatesDB = {
        subtitleSize = -100, subtitleOffset = math.huge, subtitleBlue = 0 / 0,
    } } })
    equal(reload.addon.GetOptions().subtitleSize, 12)
    equal(reload.addon.GetOptions().subtitleOffset, 2)
    equal(reload.addon.GetOptions().subtitleBlue, 0.7)
end)

test("optional performance counters measure operations and can be reset independently of profiles", function()
    local ctx = Context()
    equal(ctx.addon.MetricsEnabled(), false)
    ctx.addon.SetMetricsEnabled(true)
    local _, frame = ctx:unit("nameplate1", { class = "MAGE" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local metrics = ctx.addon.GetMetrics()
    assert(metrics.updates >= 1)
    assert(metrics.alphaWrites >= 1)
    assert(metrics.colorWrites >= 1)
    ctx.addon.ResetMetrics()
    ctx:tick()
    metrics = ctx.addon.GetMetrics()
    assert(metrics.updates >= 1)
    equal(metrics.alphaWrites, 0)
    equal(metrics.colorWrites, 0)
    equal(BarVisible(frame), 0)
    ctx.addon.SetMetricsEnabled(false)
    ctx.addon.ResetMetrics()
    ctx:tick()
    equal(ctx.addon.GetMetrics().updates, 0)
    equal(ctx.addon.GetOptions().metricsEnabled, nil, "instrumentation is session-only")
end)

test("explanations distinguish visibility rules and report remains safe for restricted units", function()
    local ctx = Context()
    local unit, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local idle = ctx.addon.ExplainUnit("nameplate1")
    assert(type(idle) == "string" and idle ~= "")
    unit.party = true
    ctx:emit("GROUP_ROSTER_UPDATE")
    local grouped = ctx.addon.ExplainUnit("nameplate1")
    assert(type(grouped) == "string" and grouped ~= idle)
    ctx.target = "nameplate1"
    local report = ctx.addon.BuildReport()
    assert(type(report) == "string" and report:find(ctx.addon.VERSION, 1, true))
    assert(report:find("nameplateShowFriendlyPlayers", 1, true))
    unit.party, unit.combat = SECRET, API_ERROR
    assert(pcall(ctx.addon.BuildReport))
    equal(ctx.healthReads, 0)
    equal(frame.alpha, 1)
end)

test("copyable report dialog opens with current text and escape releases keyboard focus", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    ctx.addon.ShowReport()
    local dialog = ctx.env.SmartFriendlyNameplatesReport
    assert(dialog and dialog:IsShown())
    local edit
    for _, widget in ipairs(ctx.widgets) do
        if widget.kind == "EditBox" and widget.text and widget.text:find(ctx.addon.VERSION, 1, true) then edit = widget end
    end
    assert(edit and edit.multiline and edit.highlighted and edit.focused)
    edit.scripts.OnEscapePressed(edit)
    equal(dialog:IsShown(), false)
    equal(edit.focused, false)
end)

test("known guardian owner is revalidated with one lookup instead of rescanning the raid", function()
    local ctx = Context()
    ctx.addon.SetOption("includeMinions", true)
    ctx.groupMembers, ctx.inRaid = 40, true
    local unit, frame = ctx:unit("nameplate1", { player = false, minion = true, owner = "raid40" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(ctx.ownerChecks, 40)
    equal(BarVisible(frame), 1)
    local checks = ctx.ownerChecks
    ctx:tick()
    equal(ctx.ownerChecks - checks, 1, "a cached owner still gets a fresh safety check")
    equal(BarVisible(frame), 1)
    unit.owner = "outsideGroup"
    ctx:tick()
    equal(BarVisible(frame), 0, "ownership changes invalidate a previous success")
    unit.owner = SECRET
    ctx:tick()
    equal(BarVisible(frame), 1, "an inaccessible owner is never treated as outside the group")
    unit.owner = "raid40"
    ctx:tick()
    equal(BarVisible(frame), 1)
    ctx.groupMembers = 2
    ctx:emit("GROUP_ROSTER_UPDATE")
    equal(BarVisible(frame), 0, "removed group tokens cannot satisfy a cached match")
end)

test("unit flag events preserve NPC title cache and missing-title retry throttle", function()
    local ctx = Context()
    ctx.addon.SetOption("includeNPCs", true)
    local _, frame = ctx:unit("nameplate1", { player = false, tooltip = NPCTooltip("Vendor") })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(ctx.tooltipReads, 1)
    for _ = 1, 4 do
        ctx:emit("UNIT_FLAGS", "nameplate1")
        ctx:emit("UNIT_FLAGS", "unrelatedUnit")
        ctx:tick()
    end
    equal(ctx.tooltipReads, 1, "a cached title does not depend on combat flags")
    equal(frame.extraRegions[1].text, "<Vendor>")
    local unit = ctx.units.nameplate1
    unit.tooltip = NPCTooltip(nil)
    ctx:emit("UNIT_NAME_UPDATE", "nameplate1")
    equal(ctx.tooltipReads, 2, "name changes legitimately invalidate the title")
    for _ = 1, 4 do ctx:emit("UNIT_FLAGS", "nameplate1"); ctx:tick() end
    equal(ctx.tooltipReads, 2, "flag events do not bypass the retry delay for a missing title")
end)

test("a native child added while filtered is hidden and retains its own restoration alpha", function()
    local ctx = Context()
    local _, frame = ctx:unit("nameplate1")
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local child = { alpha = 0.6 }
    function child:IsForbidden() return false end
    function child:GetAlpha() return self.alpha end
    function child:SetAlpha(value) self.alpha = value end
    local originalChildren = frame.GetChildren
    function frame:GetChildren() return child, originalChildren(self) end
    ctx:tick()
    equal(child.alpha, 0, "new native regions must not escape optimized updates")
    ctx:command("off")
    equal(child.alpha, 0.6, "the original alpha is captured at discovery")
    equal(frame.name.shown, true)
end)

test("new controls use live profile values and render localized effective states", function()
    for _, locale in ipairs(clientLocales) do
        local ctx = Context(nil, { locale = locale })
        local L = ctx.addon.L
        ctx:emit("PLAYER_ENTERING_WORLD")
        assert(ctx:hasText(L.UI_SUBTITLE_COLOR))
        assert(ctx:widget(L.UI_SUBTITLE_COLOR_DEFAULT))
        assert(ctx:hasText(L.UI_AUTO_SETUP))
        assert(ctx:hasText(L.HEALTH_READY))
        ctx:click(L.UI_FOCUS)
        equal(ctx.addon.GetOptions().showFocus, true)
        ctx:click(L.UI_MOUSEOVER)
        equal(ctx.addon.GetOptions().showMouseover, true)
        ctx:click(L.UI_METRICS)
        equal(ctx.addon.MetricsEnabled(), true)
        local slider
        for _, widget in ipairs(ctx.widgets) do
            if widget.kind == "Slider" and widget.minimum == 8 and widget.maximum == 24 then slider = widget end
        end
        assert(slider)
        slider:SetValue(16)
        equal(ctx.addon.GetOptions().subtitleSize, 16)
        ctx.cvars.nameplateShowFriendlyPlayers = "0"
        ctx:emit("CVAR_UPDATE", "nameplateShowFriendlyPlayers", "0")
        assert(ctx:hasText(L.HEALTH_CONFLICT))
        ctx:click(L.UI_REPAIR)
        assert(ctx:hasText(L.HEALTH_READY))
        ctx:click(L.UI_COPY_GLOBAL)
        equal(ctx.env.SmartFriendlyNameplatesGlobalDB.profile.subtitleSize, 16)
    end
end)

test("disabling a failed plate reports disabled after successful visual restoration", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    local _, frame = ctx:unit("nameplate1")
    local nativeSetAlpha = frame.decoration.SetAlpha
    frame.decoration.SetAlpha = function(self, alpha)
        if alpha == 0 then error("temporary hide refusal") end
        nativeSetAlpha(self, alpha)
    end
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(ctx.addon.GetHealthState(), "error")
    ctx:command("off")
    equal(ctx.addon.GetHealthState(), "disabled")
    equal(BarVisible(frame), 1)
end)

test("appearance-only changes in combat do not invent pending game settings", function()
    local ctx = Context()
    ctx:emit("PLAYER_ENTERING_WORLD")
    ctx.addon.SetOption("showGuild", true)
    local _, frame = ctx:unit("nameplate1", { guild = "Example" })
    ctx:emit("NAME_PLATE_UNIT_ADDED", "nameplate1")
    ctx.combat = true
    local writes = #ctx.writes
    ctx.addon.SetOption("subtitleRed", 0.2)
    ctx.addon.SetOption("showFocus", true)
    equal(#ctx.writes, writes)
    local _, pending = ctx.addon.GetOptions()
    equal(pending, false)
    equal(ctx.addon.GetHealthState(), "ready")
    equal(frame.extraRegions[1].textColor[1], 0.2)
    ctx.cvars.nameplateShowFriendlyPlayers = nil
    ctx:emit("CVAR_UPDATE", "nameplateShowFriendlyPlayers")
    ctx.addon.SetOption("subtitleGreen", 0.3)
    equal(ctx.addon.GetHealthState(), "unavailable", "unavailable is distinct from waiting for combat")
end)

test("repair preserves forbidden observations and missing plates are diagnosed explicitly", function()
    local ctx = Context()
    local _, _, protected = ctx:unit("nameplate1")
    protected.forbidden = true
    ctx:emit("FORBIDDEN_NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(ctx.addon.ExplainUnit("nameplate1"), "forbidden")
    ctx.addon.Repair()
    equal(ctx.addon.ExplainUnit("nameplate1"), "forbidden")
    local report = ctx.addon.BuildReport()
    assert(report:find(ctx.addon.L.REASON_FORBIDDEN, 1, true))
    ctx:unit("target")
    equal(ctx.addon.ExplainUnit("target"), "no-plate")
    ctx:emit("FORBIDDEN_NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(ctx.addon.ExplainUnit("nameplate1"), "no-plate")
end)

print(string.format("%d/%d integration checks passed", passed, tests))
if passed ~= tests then os.exit(1) end
