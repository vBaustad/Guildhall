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
-- Which skill lines are which, by ID: names can be missing for a line we've never seen, and a card
-- must never be decided by a name like "Profession 356". Fishing is secondary, not gathering, so it
-- follows the "Show secondary professions" tick like Cooking and First Aid.
GH.GATHERING_LINE = { [182] = true, [186] = true, [393] = true }
GH.SECONDARY_LINE = { [185] = true, [129] = true, [356] = true }
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

-- Whispers and addon whispers must use the plain name for someone on our own realm: the server
-- doesn't know "Name-OurRealm". Names from other realms keep their suffix. Storage and comparisons
-- always use the full "Name-Realm" form.
-- LibForever does the same, and its realm match ignores case, spaces, hyphens and apostrophes.
local LIB = LibStub and LibStub("LibForever-1.0", true)
local function plainRealm(s) return (s or ""):gsub("[%s%-']", ""):lower() end
function GH.WhisperName(full)
    if not full then return nil end
    if LIB and LIB.WhisperName then return LIB.WhisperName(full) end
    local name, realm = full:match("^(.-)%-(.+)$")
    if not name then return full end
    return plainRealm(realm) == plainRealm(GH.Realm()) and name or full
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

-- "1 recipe" / "5 recipes". Pass the plural when it isn't just an added s.
function GH.Count(n, singular, plural)
    return ("%d %s"):format(n, n == 1 and singular or (plural or singular .. "s"))
end

-- Copper as short gold/silver/copper: "3g", "3g 50s", "45s 20c".
function GH.Money(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    if copper == 0 then return "free" end
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- A clickable "[Open in Guildhall]" for chat lines; clicking it shows the wanted item.
function GH.WantLink(key)
    return ("|cffe6b34d|Haddon:Guildhall:want:%s|h[Open in Guildhall]|h|r"):format(tostring(key))
end

local function OnLink(link)
    local key = type(link) == "string" and link:match("^addon:Guildhall:want:(.+)$")
    if not key then return false end
    if GH.ShowWanted then GH.ShowWanted(tonumber(key) or key) end
    return true
end
-- The modern client hands "addon:" links to EventRegistry; older paths go through SetItemRef.
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link) OnLink(link) end, GH)
elseif SetItemRef then
    hooksecurefunc("SetItemRef", function(link) OnLink(link) end)
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
    db.blocked = db.blocked or {}    -- ["Name-Realm"] = time blocked. Local only: nobody is told.
    db.noShare = db.noShare or {}    -- [itemID] = true: never offered to the guild
    -- Data version 2 (recipe spell IDs instead of crafted item IDs) has been the only format all
    -- through the beta, so nothing is wiped here any more: a wipe on a table that merely looks
    -- unversioned would throw away every guildie profile. Old v1 profiles are simply replaced as
    -- their owners publish again.
    db.dataVersion = 2
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
        -- A brand-new record: first use, or saved data that didn't load. Until guildies send back
        -- their copy of my posts (Sync.RestoreSelf) or I post or remove something myself, my profile
        -- goes out marked fresh, so it can't replace the posts they hold. Saved, so it survives a
        -- session where nobody with a copy was online.
        d.restorePending = true
    end
    GH.freshSelf = d.restorePending or nil
    d.owner = me
    local _, classFile = UnitClass("player")
    d.class = classFile
    d.level = UnitLevel("player")
    return d
end

-- Something in my own data changed: bump the revision so guildies know to fetch it.
local function Sync_PeerCount()
    return GH.Sync and GH.Sync.PeerCount and GH.Sync.PeerCount() or 0
end

-- The client sometimes starts a session without reading any saved variables at all (a known WoW:
-- Forever bug), and then writes the empty tables back over the good ones on exit. LibForever can tell
-- us when that happened; until we know otherwise we assume our data is fine.
function GH.StoreTrusted()
    if LIB and LIB.SavedVariablesLoaded then return LIB.SavedVariablesLoaded() end
    return true
end

function GH.BumpRev(reason)
    local d = GH.MyData()
    if not d then return end
    d.rev = math.max((d.rev or 0) + 1, GH.Now())
    -- Posting or removing something myself makes my own list the truth - but not while guildies are
    -- still expected to send back what they hold, or one new post would wipe the rest of my old ones.
    if (reason == "listings" or reason == "wants")
        and (GH.restoredThisSession or not GH.Sync or Sync_PeerCount() == 0) then
        d.restorePending, GH.freshSelf = nil, nil
        GH.restoreClosed = true
    elseif reason == "restore" then
        d.restorePending, GH.freshSelf = nil, nil
    end
    GH.Fire("MY_DATA_CHANGED", reason)
    GH.Fire("DATA_CHANGED")
end

-- ---------------------------------------------------------------------------
-- Personal lists
-- ---------------------------------------------------------------------------
-- Blocked players: their posts and craft requests are hidden from me. Their profile is still stored
-- and passed on to guildies who ask, so blocking never costs anyone else data.
function GH.IsBlocked(full)
    return full ~= nil and GH.DB().blocked[full] ~= nil
end

function GH.SetBlocked(full, on)
    if not full or full == GH.Me() then return end
    GH.DB().blocked[full] = on and GH.Now() or nil
    GH.msg(on and "blocked %s. Their posts and craft requests are hidden - they aren't told. Unblock in Settings."
        or "unblocked %s.", GH.Short(full))
    GH.Fire("DATA_CHANGED")
    GH.Fire("ORDERS_CHANGED")
end

function GH.BlockedList()
    local list = {}
    for full in pairs(GH.DB().blocked) do list[#list + 1] = full end
    table.sort(list)
    return list
end

-- Items I never offer: a listing for one stays on my list but isn't published.
function GH.IsNoShare(itemID)
    return itemID ~= nil and GH.DB().noShare[itemID] ~= nil
end

function GH.SetNoShare(itemID, on)
    if not itemID then return end
    GH.DB().noShare[itemID] = on and true or nil
    -- My own choice: publish normally, so guildies drop (or get back) the listing.
    GH.BumpRev("listings")
end

function GH.NoShareList()
    local list = {}
    for id in pairs(GH.DB().noShare) do list[#list + 1] = id end
    table.sort(list)
    return list
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

-- The roster says who is online, but it can be empty for a whole session (we never request it). A guildie
-- who has sent us an addon message in the last hour counts as online too, so requests and status
-- updates still get delivered.
local PEER_FRESH = 3600
function GH.IsOnline(full)
    if full == GH.Me() then return true end
    local r = GH.roster[full]
    if r then return r.online and true or false end
    local peer = GH.Sync and GH.Sync.peers[full]
    return peer ~= nil and (GH.Now() - (peer.seen or 0)) < PEER_FRESH
end

-- The roster can be empty for a long time (we never request it), so anyone who talked to us on the
-- guild addon channel counts as a guildie too: only guildies can reach it.
function GH.KnownGuildie(full)
    if not full then return false end
    if GH.roster[full] then return true end
    return GH.Sync and GH.Sync.peers[full] ~= nil
end

-- No roster-only "is this a guildie" test any more: the roster can be empty or partial on Forever,
-- and nothing may depend on it. Sync notices a refused message and retries instead of asking the
-- game whether chat is locked down.

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
    -- The client sometimes skips loading saved variables after an addon's .toc changes, until the
    -- game is fully restarted. If this character has used Guildhall before but the account-wide data
    -- is missing, say so once; guildies' copies fill in what they can (Sync.RestoreSelf, order replay).
    GuildhallCharDB = type(GuildhallCharDB) == "table" and GuildhallCharDB or {}
    local lost = GuildhallDB == nil and GuildhallCharDB.used
    GuildhallCharDB.used = true
    GH.DB()
    GH.MyData()
    -- Let LibForever compare our table with the other YippYapp addons': if none of them loaded, the
    -- client dropped them all. It says so once for the whole family, so we stay quiet then.
    if LIB and LIB.RegisterSavedTable then LIB.RegisterSavedTable(GuildhallDB) end
    if lost and GH.StoreTrusted() then
        GH.msg("|cffff6060saved data didn't load - fully restart the game (not /reload). Guildies online will send back what they have.|r")
    end
    -- A store the client never read is not the truth about what I share: keep publishing as "fresh"
    -- so guildies keep their copy of my posts, and take back what they hold.
    -- After the library's check has run, and after our own hello has gone out with the old flag.
    C_Timer.After(8, function()
        if not GH.StoreTrusted() then
            local d = GH.MyData()
            if d and not GH.restoreClosed then
                d.restorePending, GH.freshSelf = true, true
                GH.dbg("saved data never loaded - asking guildies for my posts")
                if GH.Sync and GH.Sync.Hello then GH.Sync.Hello() end
            end
        end
    end)
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
    elseif cmd == "selftest" then
        if GH.SelfTest then GH.SelfTest() end
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
