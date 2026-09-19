-- Guildhall - core: namespace, saved variables, events, timers, guild roster and slash commands.
-- Everything cross-file hangs off the GH table (the addon's second vararg).
local ADDON, GH = ...
_G.Guildhall = GH

GH.VERSION = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "0.0.0"

GH.CREAM = "ffebdec2"
GH.GRAY = "ff8a8a8a"

-- Recognised professions (enUS names, as GetSkillLineInfo / GetTradeSkillLine return them).
GH.PROFESSIONS = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring",
    "Cooking", "First Aid", "Herbalism", "Mining", "Skinning", "Fishing",
}
GH.PROF_ICON = {
    Alchemy = "Interface\\Icons\\Trade_Alchemy",
    Blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
    Enchanting = "Interface\\Icons\\Trade_Engraving",
    Engineering = "Interface\\Icons\\Trade_Engineering",
    Herbalism = "Interface\\Icons\\Trade_Herbalism",
    Leatherworking = "Interface\\Icons\\Trade_LeatherWorking",
    Mining = "Interface\\Icons\\Trade_Mining",
    Skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    Tailoring = "Interface\\Icons\\Trade_Tailoring",
    Cooking = "Interface\\Icons\\INV_Misc_Food_15",
    ["First Aid"] = "Interface\\Icons\\INV_Misc_Bandage_08",
    Fishing = "Interface\\Icons\\Trade_Fishing",
}
-- Gathering professions have no recipes to share, only a skill rank.
GH.GATHERING = { Herbalism = true, Mining = true, Skinning = true, Fishing = true }
function GH.ProfIcon(name) return GH.PROF_ICON[name] or "Interface\\Icons\\INV_Misc_QuestionMark" end

function GH.msg(fmt, ...)
    local text = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cffe6b34dGuildhall|r: " .. text)
end

function GH.Now() return GetServerTime() end

-- ---------------------------------------------------------------------------
-- Events and internal callbacks
-- ---------------------------------------------------------------------------
local handlers = {}
local evFrame = CreateFrame("Frame")
evFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do list[i](...) end
end)

-- GH.On("EVENT", fn): fn receives the event's payload (not the event name).
function GH.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        evFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

local listeners = {}
function GH.Listen(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
end
function GH.Fire(name, ...)
    local list = listeners[name]
    if not list then return end
    for i = 1, #list do list[i](...) end
end

-- Restart the timer on every call (runs once things go quiet).
local debounces = {}
function GH.Debounce(key, delay, fn)
    if debounces[key] then debounces[key]:Cancel() end
    debounces[key] = C_Timer.NewTimer(delay, function()
        debounces[key] = nil
        fn()
    end)
end

-- Run at most once per window: later calls while one is pending are folded into it.
local coalesced = {}
function GH.Coalesce(key, delay, fn)
    if coalesced[key] then return end
    coalesced[key] = C_Timer.NewTimer(delay, function()
        coalesced[key] = nil
        fn()
    end)
end

-- ---------------------------------------------------------------------------
-- Names
-- ---------------------------------------------------------------------------
function GH.Realm()
    return GetNormalizedRealmName() or (GetRealmName() or ""):gsub("[%s%-]", "")
end

-- Always "Name-Realm", the form addon messages and the guild roster use.
function GH.FullName(name)
    if not name or name == "" then return nil end
    if not name:find("-", 1, true) then name = name .. "-" .. GH.Realm() end
    return name
end

function GH.Me()
    if not GH._me then
        local n = UnitName("player")
        if not n or n == UNKNOWNOBJECT then return nil end
        GH._me = GH.FullName(n)
    end
    return GH._me
end

-- Drop the realm for display when it is our own.
function GH.Short(full)
    if not full then return "?" end
    return Ambiguate(full, "none")
end

function GH.ClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not c then return "ffcccccc" end
    if c.colorStr then return c.colorStr end
    return ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

-- Class-coloured short name.
function GH.ColorName(full, classFile)
    return "|c" .. GH.ClassColor(classFile) .. GH.Short(full) .. "|r"
end

function GH.Ago(t)
    if not t or t == 0 then return "never" end
    local d = GH.Now() - t
    if d < 60 then return "just now" end
    if d < 3600 then return ("%dm ago"):format(d / 60) end
    if d < 86400 then return ("%dh ago"):format(d / 3600) end
    return ("%dd ago"):format(d / 86400)
end

-- ---------------------------------------------------------------------------
-- Saved variables
-- ---------------------------------------------------------------------------
local SETTING_DEFAULTS = {
    tooltip = true,          -- guild crafters / listings on item tooltips
    -- The minimap button lives in settings.minimap (LibDBIcon's format). Old minimapAngle/hideMinimap
    -- values are migrated once by UI/Minimap.lua, so they have no defaults here.
    notifyRequests = true,   -- chat + sound when someone asks you to craft
    notifyWanted = true,     -- chat line when a guildie wants something you can make
    listingDays = 14,        -- listings expire after this many days
}

function GH.DB()
    GuildhallDB = GuildhallDB or {}
    local db = GuildhallDB
    db.settings = db.settings or {}
    for k, v in pairs(SETTING_DEFAULTS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    db.chars = db.chars or {}
    db.guilds = db.guilds or {}
    db.reagents = db.reagents or {}
    db.notified = db.notified or {}
    db.outputs = db.outputs or {}    -- [recipeSpellID] = crafted itemID, for recipes not in the static data
    -- Data version 2: recipes are stored as recipe spell IDs (v1 stored crafted item IDs).
    -- Old profiles can't be converted, so drop them; they are rebuilt on the next scan / sync.
    if (db.dataVersion or 1) < 2 then
        for _, d in pairs(db.chars) do d.profs = {} end
        for _, g in pairs(db.guilds) do g.members = {} end
        db.dataVersion = 2
    end
    return db
end

function GH.Settings() return GH.DB().settings end

-- This character's own shareable data. Kept per character, independent of guild.
function GH.MyData()
    local me = GH.Me()
    if not me then return nil end
    local chars = GH.DB().chars
    local d = chars[me]
    if not d then
        d = { rev = 0, profs = {}, listings = {}, wants = {}, nextId = 1 }
        chars[me] = d
    end
    d.owner = me
    local _, classFile = UnitClass("player")
    d.class = classFile
    d.level = UnitLevel("player")
    return d
end

-- Something in my own data changed: bump the revision so guildies know to fetch it.
function GH.BumpRev(reason)
    local d = GH.MyData()
    if not d then return end
    d.rev = math.max((d.rev or 0) + 1, GH.Now())
    GH.Fire("MY_DATA_CHANGED", reason)
    GH.Fire("DATA_CHANGED")
end

function GH.NextId()
    local d = GH.MyData()
    local id = d.nextId or 1
    d.nextId = id + 1
    return id
end

-- ---------------------------------------------------------------------------
-- Guild and roster
-- ---------------------------------------------------------------------------
GH.roster = {}        -- ["Name-Realm"] = { online, class, level, rankIndex, zone }
GH.rosterReady = false

function GH.GuildKey()
    if not IsInGuild() then return nil end
    local name, _, _, realm = GetGuildInfo("player")
    if not name then return nil end
    return name .. "-" .. (realm or GH.Realm())
end

function GH.GuildName()
    return IsInGuild() and GetGuildInfo("player") or nil
end

-- Per-guild store: other members' profiles and my craft requests.
function GH.GuildDB()
    local key = GH.GuildKey()
    if not key then return nil end
    local guilds = GH.DB().guilds
    local g = guilds[key]
    if not g then
        g = { members = {}, orders = {} }
        guilds[key] = g
    end
    return g
end

function GH.IsOnline(full)
    if full == GH.Me() then return true end
    local r = GH.roster[full]
    return r and r.online or false
end

function GH.IsGuildie(full)
    return GH.roster[full] ~= nil
end

-- Chat messaging lockdown (a Midnight-era restriction that is active in Forever): addon chat
-- can be blocked in restricted content. Senders hold their messages until it lifts.
function GH.InChatLockdown()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

local function RebuildRoster()
    local total = GetNumGuildMembers()
    if not total or total == 0 then return end
    local old = GH.roster
    local new = {}
    local cameOnline = {}
    local membersChanged = false
    for i = 1, total do
        local name, _, rankIndex, level, _, zone, _, _, online, _, classFile = GetGuildRosterInfo(i)
        if name then
            local full = GH.FullName(name)
            new[full] = { online = online and true or false, class = classFile, level = level, rankIndex = rankIndex, zone = zone }
            if not old[full] then membersChanged = true end
            if online and old[full] and not old[full].online then
                cameOnline[#cameOnline + 1] = full
            end
        end
    end
    if not membersChanged then
        for full in pairs(old) do
            if not new[full] then membersChanged = true break end
        end
    end
    GH.roster = new
    local first = not GH.rosterReady
    GH.rosterReady = true
    GH.rosterComplete = true  -- the modern client always lists offline members too
    -- ROSTER(first, membersChanged): membersChanged is false when only online flags or zones moved.
    GH.Fire("ROSTER", first, membersChanged)
    for _, full in ipairs(cameOnline) do GH.Fire("MEMBER_ONLINE", full) end
end

GH.On("GUILD_ROSTER_UPDATE", function()
    GH.Coalesce("roster", 1, RebuildRoster)
end)

-- We never ask for the roster: C_GuildInfo.GuildRoster() pops the "blocked" dialog on Forever. The
-- server pushes GUILD_ROSTER_UPDATE on its own, and whatever the client already holds is read here.
GH.On("PLAYER_GUILD_UPDATE", function()
    GH.Coalesce("roster", 1, RebuildRoster)
    GH.Fire("GUILD_CHANGED")
end)

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------
GH.On("PLAYER_LOGIN", function()
    if not C_Weather then
        GH.msg("|cffff6060made for WoW: Forever only - it won't work properly in this version of the game.|r")
    end
    GH.DB()
    GH.MyData()
    GH.Fire("LOGIN")
    -- In case the roster arrived before we were listening: read what the client holds.
    -- We never request it (that's blocked), so until the client has some roster data, look again every
    -- few seconds: it arrives with the server's GUILD_ROSTER_UPDATE or when the guild UI loads it.
    local ticker
    ticker = C_Timer.NewTicker(5, function()
        if GH.rosterReady or not IsInGuild() then
            ticker:Cancel()
            return
        end
        RebuildRoster()
    end)
    C_Timer.After(2, function() if not GH.rosterReady then RebuildRoster() end end)
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
SLASH_GUILDHALL1 = "/guildhall"
SLASH_GUILDHALL2 = "/gh"
SlashCmdList.GUILDHALL = function(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        if GH.ToggleWindow then GH.ToggleWindow() end
    elseif cmd == "config" or cmd == "options" then
        if GH.OpenOptions then GH.OpenOptions() end
    elseif cmd == "search" or cmd == "find" then
        if GH.ShowSearch then GH.ShowSearch(rest) end
    elseif cmd == "mine" then
        if GH.ShowTab then GH.ShowTab("mine") end
    elseif cmd == "requests" then
        if GH.ShowTab then GH.ShowTab("requests") end
    elseif cmd == "status" then
        if GH.PrintStatus then GH.PrintStatus() end
    elseif cmd == "sync" then
        -- A forced hello asks every online guildie for data, so allow it once a minute.
        local now = GetTime()
        if GH.lastForcedSync and now - GH.lastForcedSync < 60 then
            GH.msg("sync was just requested - try again in %d s.", 60 - (now - GH.lastForcedSync))
        elseif GH.Sync and GH.Sync.Hello then
            GH.lastForcedSync = now
            GH.Sync.Hello(true)
        end
    elseif cmd == "debug" then
        GH.debug = not GH.debug
        GH.msg("debug %s", GH.debug and "on" or "off")
    else
        GH.msg("|cffffd100/gh|r window, |cffffd100/gh search <item>|r, |cffffd100/gh mine|r, |cffffd100/gh requests|r, |cffffd100/gh status|r, |cffffd100/gh sync|r, |cffffd100/gh config|r")
    end
end

function GH.dbg(fmt, ...)
    if GH.debug then GH.msg("|cff888888" .. fmt .. "|r", ...) end
end
