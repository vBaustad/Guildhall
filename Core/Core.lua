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
-- One spelling of a realm, whatever the game hands us: GetGuildInfo returns it raw ("Bleeding
-- Hollow"), GetNormalizedRealmName returns it packed ("BleedingHollow"). Keys are built from the
-- packed form only, or the same guild ends up stored twice.
-- Temporary: both helpers go away for LIB.NormalizeRealm / LIB.Realm once LibForever 1.0.6 is
-- tagged and embedded here.
local function NormalizeRealm(realm)
    -- The parentheses matter: gsub also returns a count, which would leak into every caller.
    return (tostring(realm or ""):gsub("[%s%-']", ""))
end
GH.NormalizeRealm = NormalizeRealm

function GH.Realm()
    return GetNormalizedRealmName() or NormalizeRealm(GetRealmName())
end

-- Always "Name-Realm", the form addon messages and the guild roster use.
function GH.FullName(name)
    if not name or name == "" then return nil end
    if not name:find("-", 1, true) then name = name .. "-" .. GH.Realm() end
    return name
end

-- Who I am, as "Name-Realm". UnitName's second value is a SURNAME on Forever, not a realm, so a key
-- built from the first value alone drops half the name - and the guild channel uses the whole of it.
-- The library owns that composition (LIB.Me -> LIB.UnitKey); ours is only for a client without it.
function GH.Me()
    if not GH._me then
        if LIB and LIB.Me then
            GH._me = LIB.Me()
            if GH._me then return GH._me end
        end
        local n = UnitName("player")
        if not n or n == UNKNOWNOBJECT then return nil end
        GH._me = GH.FullName(n)
    end
    return GH._me
end

-- Name for display: drops our own realm, and the surname when the player has chosen to hide those.
-- Display only - what gets stored and compared is always the full "Name-Realm".
function GH.Short(full)
    if not full then return "?" end
    local LIB = LibStub and LibStub("LibForever-1.0", true)
    if LIB and LIB.ShortName then return LIB.ShortName(full) end
    local short = Ambiguate(full, "none")
    if C_PlayerInfo and C_PlayerInfo.ShouldDisplaySurname and not C_PlayerInfo.ShouldDisplaySurname() then
        short = short:match("^(%S+)") or short
    end
    return short
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

-- How long after login a guildie's copy of my posts may still turn up. Until then my own edits
-- don't end "fresh" mode; after it, they do.
local RESTORE_WINDOW = 120

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

-- Can this client lose saved variables at all? On a fixed one (build 70009 and up) an empty store
-- means a new player, not lost data - and a new player must not be treated as a victim. The library
-- owns the build check; an unreadable build counts as fixed, so we stay quiet rather than lie.
function GH.CanLoseData()
    return LIB ~= nil and LIB.SavedVariablesBugPossible ~= nil and LIB.SavedVariablesBugPossible()
end

function GH.BumpRev(reason)
    local d = GH.MyData()
    if not d then return end
    d.rev = math.max((d.rev or 0) + 1, GH.Now())
    -- Posting or removing something myself makes my own list the truth - but not in the first
    -- minutes after login, while guildies may still be sending back what they hold, or one new post
    -- would wipe the rest of my old ones. After that window nothing more is coming: a brand-new
    -- install looks the same from in here, and its owner must be able to remove a post again.
    local waited = GH.loginAt and (GetTime() - GH.loginAt) > RESTORE_WINDOW
    if (reason == "listings" or reason == "wants")
        and (GH.restoredThisSession or waited or not GH.Sync or Sync_PeerCount() == 0) then
        d.restorePending, GH.freshSelf, d.takedowns = nil, nil, nil
        GH.restoreClosed = true
    elseif reason == "restore" then
        d.restorePending, GH.freshSelf, d.takedowns = nil, nil, nil
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

-- While my record is fresh, my silence about a post means "I may not know about it", so guildies
-- keep their copy. Taking a post down is not silence: it's the clearest thing I can say about my own
-- data, and it must always win. These are the item IDs I removed by hand while fresh; they travel
-- with my profile so guildies drop exactly those and keep the rest.
local MAX_TAKEDOWNS = 20

function GH.NoteTakedown(itemID)
    if not itemID or not GH.freshSelf then return end
    local d = GH.MyData()
    if not d then return end
    d.takedowns = d.takedowns or {}
    if d.takedowns[itemID] then return end
    local n = 0
    for _ in pairs(d.takedowns) do n = n + 1 end
    if n >= MAX_TAKEDOWNS then return end
    d.takedowns[itemID] = true
end

-- They are only needed until the guild has seen them, which is as long as fresh mode lasts.
function GH.ClearTakedowns()
    local d = GH.MyData()
    if d then d.takedowns = nil end
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
    -- GetGuildInfo gives the realm raw and only for a guild from another realm; GH.Realm() gives it
    -- packed. Both go through the same normaliser, so one guild is always one key.
    return name .. "-" .. NormalizeRealm(realm or GH.Realm())
end

-- Guild stores saved under a raw-realm key by an older build ("Name-Bleeding Hollow"): fold them
-- into the packed key. A merge, never a replace - whichever copy knows more about a guildie or a
-- request wins, and nothing the player still has is thrown away.
function GH.MergeGuildKeys()
    local guilds = GH.DB().guilds
    local mine = GH.GuildName()
    for key, src in pairs(guilds) do
        -- Split off the realm. For the guild we're in, the guild's own name says where to cut, so a
        -- realm with a hyphen in it ("Kirin-Tor") is handled too; otherwise cut at the last hyphen.
        local name, realm
        if mine and key:sub(1, #mine + 1) == mine .. "-" then
            name, realm = mine, key:sub(#mine + 2)
        else
            name, realm = key:match("^(.*)%-([^%-]+)$")
        end
        local packed = name and (name .. "-" .. NormalizeRealm(realm))
        if packed and packed ~= key then
            local dst = guilds[packed]
            if not dst then
                guilds[packed] = src
            else
                dst.members = dst.members or {}
                for owner, p in pairs(src.members or {}) do
                    local cur = dst.members[owner]
                    if not cur or (p.rev or 0) > (cur.rev or 0) then dst.members[owner] = p end
                end
                for _, side in ipairs({ "incoming", "outgoing" }) do
                    dst[side] = dst[side] or {}
                    for oid, o in pairs(src[side] or {}) do
                        local cur = dst[side][oid]
                        if not cur or (o.updated or 0) > (cur.updated or 0) then dst[side][oid] = o end
                    end
                end
            end
            guilds[key] = nil
            GH.dbg("merged guild store %s into %s", key, packed)
        end
    end
end


-- ---------------------------------------------------------------------------
-- One character, one record
-- ---------------------------------------------------------------------------
-- Everyone on Forever is "First Last", and UnitName hands the surname back as a second value - the
-- slot a realm used to sit in. A build that read only the first value saved this character as
-- "Duplo-Realm" while the guild channel called them "Duplo Bonk-Realm", so the same character ended
-- up with two records and each session wrote to whichever one the code of the day produced.
-- This folds the short one into the full one. It pairs ONLY when a short name has exactly one full
-- counterpart on the same realm: "Duplo" next to both "Duplo Bonk" and "Duplo Svend" is two real
-- characters, and merging the wrong person's guild data is worse than leaving both alone.
-- GH.ambiguousNames lists whatever it refused to touch, and /gh selftest reports it.
GH.ambiguousNames = {}

local function NewerOf(a, b)
    if (a.rev or 0) >= (b.rev or 0) then return a, b end
    return b, a
end

-- Core.lua is the FIRST file the .toc loads, so nothing from another file exists while it loads:
-- the codec has to be looked up when this runs, not captured at the top the way later files do.
local function MergeCharRecord(short, full)
    local C = GH.Codec
    local newer, older = NewerOf(short, full)
    local out = {}
    for k, v in pairs(older) do out[k] = v end
    for k, v in pairs(newer) do out[k] = v end
    out.nextId = math.max(short.nextId or 1, full.nextId or 1)
    out.rev = math.max(short.rev or 0, full.rev or 0)
    -- Professions: keep every profession either record knows, and every recipe within it. Recipes are
    -- only ever learned, so a union can't resurrect something the character has forgotten.
    out.profs = {}
    for _, src in ipairs({ older.profs or {}, newer.profs or {} }) do
        for id, prof in pairs(src) do
            local have = out.profs[id]
            if not have then
                out.profs[id] = prof
            else
                if (prof.scanned or 0) >= (have.scanned or 0) then
                    prof.recipes = prof.recipes or have.recipes
                    for spell in pairs(have.recipes or {}) do
                        if prof.recipes then prof.recipes[spell] = true end
                    end
                    out.profs[id] = prof
                else
                    for spell in pairs(prof.recipes or {}) do
                        if have.recipes then have.recipes[spell] = true end
                    end
                end
            end
        end
    end
    -- Posts: everything both records hold, once each, under the caps.
    for _, field in ipairs({ "listings", "wants" }) do
        local cap = field == "listings" and C.MAX_LISTINGS or C.MAX_WANTS
        local list, seen = {}, {}
        for _, src in ipairs({ newer[field] or {}, older[field] or {} }) do
            for _, e in ipairs(src) do
                local id = C.ItemIdFromString(e.item) or e.item
                if not seen[id] and #list < cap then
                    seen[id] = true
                    list[#list + 1] = e
                end
            end
        end
        out[field] = list
    end
    -- "Waiting for guildies to send my posts back" belongs to the record that is being written now.
    -- The split is why it never ended on the abandoned one; it must not be inherited.
    out.restorePending = newer.restorePending
    out.takedowns = newer.restorePending and newer.takedowns or nil
    return out
end

-- Another of MY characters whose first name matches, and who has a surname of their own: then the
-- short record could belong to either of us, and nobody should guess.
local function SharedFirstName(db, key, me)
    -- Split the realm off first: a key is "First Last-Realm", and the realm has no space in it, so
    -- looking for a first name in the whole key would just find the key.
    local function parts(full)
        local name, realm = full:match("^(.*)%-([^%-]+)$")
        return name or full, realm or ""
    end
    local name, realm = parts(key)
    local first = name:match("^%S+")
    for other in pairs(db.chars) do
        local otherName, otherRealm = parts(other)
        if other ~= key and other ~= me and otherRealm == realm
            and otherName:match("^%S+") == first and otherName:find(" ", 1, true) then
            return other
        end
    end
    return nil
end

-- Anything of mine still filed under another spelling of my name: a leftover record, a profile a
-- guildie relayed back under the old key, or a craft request whose id carries it. Empty is the
-- answer we want after the library started building the key; /gh names prints it.
-- What the SERVER calls this character, if it has told us: the guild roster is the server's own
-- spelling, so an entry that is recognisably us but spelled differently means our own name is wrong -
-- not the roster's. This is the only check here that can catch a mistake in GH.Me() itself; every
-- other one compares against GH.Me() and so can only prove we are consistent, not correct.
function GH.ServerName()
    local me = GH.Me()
    if not me or not (LIB and LIB.IsMyStoredName) then return nil end
    for key in pairs(GH.roster) do
        if key ~= me and LIB.IsMyStoredName(key) then return key end
    end
    return nil
end

function GH.MyOtherNames()
    local me, out, seen = GH.Me(), {}, {}
    if not me or not (LIB and LIB.IsMyStoredName) then return out end
    local function note(where, key)
        if key and key ~= me and not seen[where .. key] and LIB.IsMyStoredName(key) then
            seen[where .. key] = true
            out[#out + 1] = where .. " " .. key
        end
    end
    for key in pairs(GH.DB().chars) do note("saved character", key) end
    for _, g in pairs(GH.DB().guilds) do
        for key in pairs(g.members or {}) do note("stored profile", key) end
        for _, side in ipairs({ "incoming", "outgoing" }) do
            for _, o in pairs(g[side] or {}) do
                note("craft request from", o.requester)
                note("craft request to", o.crafter)
            end
        end
    end
    return out
end

function GH.MergeCharNames()
    -- Fail closed: without the codec we can't compare posts by item, and a migration that throws at
    -- login is worse than one that waits for the next one.
    if not (GH.Codec and GH.Codec.ItemIdFromString) then
        GH.dbg("codec not ready - character merge skipped this session")
        return
    end
    local db = GH.DB()
    wipe(GH.ambiguousNames)
    local me = GH.Me()
    -- The library knows which stored keys are the character we are playing, including the short form
    -- older builds wrote. Only ever used on our OWN records: "Duplo" and "Duplo Bonk" can be two
    -- different players, and that is a guess only safe to make about yourself.
    if me and LIB and LIB.IsMyStoredName then
        for key, rec in pairs(db.chars) do
            if key ~= me and LIB.IsMyStoredName(key) then
                local clash = SharedFirstName(db, key, me)
                if clash then
                    GH.ambiguousNames[#GH.ambiguousNames + 1] = key .. " -> " .. me .. " / " .. clash
                else
                    db.chars[me] = db.chars[me] and MergeCharRecord(rec, db.chars[me]) or rec
                    db.chars[me].owner = me
                    db.chars[key] = nil
                    GH.RenameOwner(key, me)
                    GH.dbg("merged %s into %s", key, me)
                end
            end
        end
        return
    end
    -- Without the library: pair a short name with its one full counterpart, and nothing else.
    for key, short in pairs(db.chars) do
        local name, realm = key:match("^(.*)%-([^%-]+)$")
        if name and realm and not name:find(" ", 1, true) then
            local matches = {}
            for other in pairs(db.chars) do
                if other ~= key and other:sub(1, #name + 1) == name .. " "
                    and other:match("%-([^%-]+)$") == realm then
                    matches[#matches + 1] = other
                end
            end
            if #matches == 1 then
                local full = matches[1]
                db.chars[full] = MergeCharRecord(short, db.chars[full])
                db.chars[full].owner = full
                db.chars[key] = nil
                GH.RenameOwner(key, full)
                GH.dbg("merged %s into %s", key, full)
            elseif #matches > 1 then
                GH.ambiguousNames[#GH.ambiguousNames + 1] = key .. " -> " .. table.concat(matches, " / ")
            end
        end
    end
end

-- Everything else that stores a character by name: a profile a guildie relayed back to us, and the
-- craft requests, whose id carries the requester's name.
function GH.RenameOwner(from, to)
    for _, g in pairs(GH.DB().guilds) do
        local mine = g.members and g.members[from]
        if mine then
            local cur = g.members[to]
            if not cur or (mine.rev or 0) > (cur.rev or 0) then
                mine.owner = to
                g.members[to] = mine
            end
            g.members[from] = nil
        end
        for _, side in ipairs({ "incoming", "outgoing" }) do
            for oid, o in pairs(g[side] or {}) do
                if o.requester == from or o.crafter == from then
                    if o.requester == from then o.requester = to end
                    if o.crafter == from then o.crafter = to end
                    local newOid = o.requester .. "#" .. tostring(o.id)
                    if newOid ~= oid then
                        local cur = g[side][newOid]
                        if not cur or (o.updated or 0) > (cur.updated or 0) then
                            o.oid = newOid
                            g[side][newOid] = o
                        end
                        g[side][oid] = nil
                    end
                end
            end
        end
    end
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
        g = { members = {} }
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
    GH.loginAt = GetTime()
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
    GH.MergeGuildKeys()
    GH.MergeCharNames()
    GH.MyData()
    -- Let LibForever compare our table with the other YippYapp addons': if none of them loaded, the
    -- client dropped them all. It says so once for the whole family, so we stay quiet then.
    if LIB and LIB.RegisterSavedTable then LIB.RegisterSavedTable(GuildhallDB) end
    -- Two questions, two sources. The marker decides WHAT we say: it is written at every login, so
    -- only a character that has been here before can have lost anything, and a first login sees
    -- nothing. The client build decides HOW we say it: telling someone to restart a client where a
    -- restart cannot help is how a message becomes one people learn to ignore.
    if lost and GH.StoreTrusted() then
        if GH.CanLoseData() then
            GH.msg("|cffff6060saved data didn't load - fully restart the game (not /reload). Guildies online will send back what they have.|r")
        else
            GH.msg("|cffff6060your saved Guildhall data is gone. Guildies online will send back what they have.|r")
        end
    end
    -- An empty record has two very different meanings. "Lost" only counts when this character has
    -- been here before, or when the client is one that drops saved variables. Otherwise this is
    -- someone's first login: publish normally, ask nobody for anything, and let the guild see a new
    -- member rather than a member who thinks they lost something.
    local d = GH.MyData()
    if d and d.restorePending and not lost and not GH.CanLoseData() then
        d.restorePending, GH.freshSelf = nil, nil
        GH.dbg("new here: nothing to restore, publishing normally")
    end
    -- A store the client never read is not the truth about what I share: keep publishing as "fresh"
    -- so guildies keep their copy of my posts, and take back what they hold.
    -- After the library's check has run, and after our own hello has gone out with the old flag.
    C_Timer.After(8, function()
        if not GH.StoreTrusted() and GH.CanLoseData() then
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
    elseif cmd == "names" then
        -- What each source calls people: the client, the guild roster and the addon channel have to
        -- agree, or the same guildie is stored twice (surnames can be hidden on Forever).
        local shown = C_PlayerInfo and C_PlayerInfo.ShouldDisplaySurname
        GH.msg("you are %s; the game calls you %s; surnames shown: %s.", tostring(GH.Me()),
            tostring(UnitName("player")),
            shown and tostring(C_PlayerInfo.ShouldDisplaySurname()) or "unknown")
        local roster, peers = {}, {}
        for full in pairs(GH.roster) do
            roster[#roster + 1] = full
            if #roster >= 3 then break end
        end
        for full in pairs(GH.Sync and GH.Sync.peers or {}) do
            peers[#peers + 1] = full
            if #peers >= 3 then break end
        end
        GH.msg("roster says: %s", #roster > 0 and table.concat(roster, ", ") or "nothing yet")
        GH.msg("the addon channel says: %s", #peers > 0 and table.concat(peers, ", ") or "nobody yet")
        local others = GH.MyOtherNames()
        local server = GH.ServerName()
        if not (LIB and LIB.IsMyStoredName) then
            GH.msg("older library: can't check whether anything is saved under another spelling.")
        elseif #others == 0 then
            GH.msg("|cff60d060everything of yours is saved under one name|r - the one above, which is "
                .. "the name we use. |cffffd100/yippyapp debug|r says whether that matches the server.")
        else
            GH.msg("|cffff6060still saved under another spelling:|r %s", table.concat(others, ", "))
        end
        if server then
            GH.msg("|cffff6060the guild roster calls you %s|r - we are using the wrong name, and "
                .. "everything saved under ours moves across once that is fixed.", server)
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
