-- Guildhall - sync over the guild addon channel.
--
-- Every character publishes only its own profile, so there are never edit conflicts:
-- the highest revision from the owner wins.
--
--   HI  (GUILD)    I'm online, my profile is at rev N.     Others: YO back + GET if they're behind.
--   YO  (WHISPER)  reply to HI with my own rev.            The first YO also triggers MQ.
--   GET (WHISPER)  send me your profile.                   -> PRO
--   PRO (GUILD/WHISPER) a full profile.                    Direct if owner == sender, else a relay.
--   MQ  (WHISPER)  what profiles do you hold?              -> MF (owner/rev list)
--   RQ  (WHISPER)  relay these owners' profiles to me.     -> PRO per owner (for offline guildies)
--
-- A relayed copy is marked "via" and replaced as soon as the owner sends their own.
local ADDON, GH = ...
local C = GH.Codec
local Sync = {}
GH.Sync = Sync

local PREFIX = "Guildhall"
local PROTO = 2   -- 2: recipes shared as recipe spell IDs, professions as skill line IDs
Sync.PROTO = PROTO

LibStub("AceComm-3.0"):Embed(Sync)

Sync.peers = {}           -- ["Name-Realm"] = { version, seen } - guildies seen running Guildhall this session
local helloSent = false
local manifestAsked = false
local pendingGet = {}
local lastServed = {}     -- rate limits: [kind .. sender] = time
local versionNudged = false

local function join(...) return table.concat({ ... }, "\t") end

-- Messages held back while chat messaging lockdown blocks addon chat; flushed when it lifts.
local held = {}
local MAX_HELD = 60

local function FlushHeld()
    if GH.InChatLockdown() or #held == 0 then return end
    local queue = held
    held = {}
    for _, m in ipairs(queue) do
        Sync:SendCommMessage(PREFIX, m.text, m.dist, m.target, m.prio)
    end
end

function Sync.Send(header, body, dist, target, prio)
    if not IsInGuild() then return end
    local text = body and (header .. "\n" .. body) or header
    prio = prio or "NORMAL"
    if GH.InChatLockdown() then
        if #held < MAX_HELD then held[#held + 1] = { text = text, dist = dist, target = target, prio = prio } end
        return
    end
    Sync:SendCommMessage(PREFIX, text, dist, target, prio)
end

C_Timer.NewTicker(10, FlushHeld)

local function RateLimited(kind, sender, seconds)
    local k = kind .. sender
    local now = GetTime()
    if lastServed[k] and now - lastServed[k] < seconds then return true end
    lastServed[k] = now
    return false
end

local function Jitter(lo, hi) return lo + math.random() * (hi - lo) end

-- ---------------------------------------------------------------------------
-- Versions
-- ---------------------------------------------------------------------------
local function VersionNum(v)
    local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.?(%d*)")
    if not a then return 0 end
    return tonumber(a) * 10000 + tonumber(b) * 100 + (tonumber(c) or 0)
end

local function SeePeer(sender, version)
    Sync.peers[sender] = { version = version, seen = GH.Now() }
    if not versionNudged and VersionNum(version) > VersionNum(GH.VERSION) then
        versionNudged = true
        GH.msg("a guildie is running Guildhall %s - you have %s. Update to stay in sync.", version, GH.VERSION)
    end
    GH.Fire("PEER_SEEN", sender)
end

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
local function MyPayload()
    local d = GH.MyData()
    return C.EncodeProfile(d, GH.Listings.Publishable(), GH.Listings.PublishableWants())
end

-- A profile we can hand to others: a guildie's stored copy, or one of my own alts in this guild.
local function HeldProfile(owner)
    local g = GH.GuildDB()
    local p = g and g.members[owner]
    local alt = GH.DB().chars[owner]
    if alt and owner ~= GH.Me() and GH.IsGuildie(owner) and (not p or (alt.rev or 0) >= (p.rev or 0)) then
        return alt
    end
    return p
end

local function StoreProfile(p, sender)
    local g = GH.GuildDB()
    if not g or not p.owner then return end
    if p.owner == GH.Me() then return end
    if GH.rosterComplete and not GH.IsGuildie(p.owner) then return end
    local direct = (p.owner == sender)
    local cur = g.members[p.owner]
    if cur then
        if direct and p.rev < (cur.rev or 0) then return end
        if not direct and p.rev <= (cur.rev or 0) then return end
    end
    p.received = GH.Now()
    p.via = (not direct) and sender or nil
    g.members[p.owner] = p
    pendingGet[p.owner] = nil
    GH.dbg("stored %s rev %d%s", p.owner, p.rev, p.via and (" via " .. p.via) or "")
    GH.Fire("DATA_CHANGED")
    if direct then GH.Listings.NotifyWants(p) end
end

-- Someone's rev is N: fetch their profile if ours is older (or only a relay).
local function NoteRev(owner, rev)
    if not rev then return end
    local g = GH.GuildDB()
    if not g then return end
    local cur = g.members[owner]
    if cur and (cur.rev or 0) >= rev and not cur.via then return end
    if pendingGet[owner] then return end
    pendingGet[owner] = true
    C_Timer.After(Jitter(1, 8), function()
        Sync.Send(join("GET", PROTO), nil, "WHISPER", owner)
    end)
    C_Timer.After(90, function() pendingGet[owner] = nil end)
end

function Sync.Hello()
    local d = GH.MyData()
    if not d or not IsInGuild() or not GH.GuildDB() then return end
    helloSent = true
    Sync.Send(join("HI", PROTO, GH.VERSION, d.rev), nil, "GUILD")
    GH.dbg("hello sent (rev %d)", d.rev)
end

function Sync.Publish()
    if not helloSent or not IsInGuild() then return end
    Sync.Send(join("PRO", PROTO), MyPayload(), "GUILD", nil, "BULK")
    GH.dbg("published profile")
end

-- ---------------------------------------------------------------------------
-- Message handlers
-- ---------------------------------------------------------------------------
local H = {}

H.HI = function(f, _, sender)
    SeePeer(sender, f[3])
    NoteRev(sender, tonumber(f[4]))
    local d = GH.MyData()
    if d and helloSent then
        C_Timer.After(Jitter(2, 12), function()
            Sync.Send(join("YO", PROTO, GH.VERSION, d.rev), nil, "WHISPER", sender)
        end)
    end
end

H.YO = function(f, _, sender)
    SeePeer(sender, f[3])
    NoteRev(sender, tonumber(f[4]))
    if not manifestAsked then
        manifestAsked = true
        C_Timer.After(3, function()
            Sync.Send(join("MQ", PROTO), nil, "WHISPER", sender)
        end)
    end
end

H.GET = function(_, _, sender)
    if RateLimited("GET", sender, 30) then return end
    Sync.Send(join("PRO", PROTO), MyPayload(), "WHISPER", sender, "BULK")
end

H.PRO = function(_, body, sender)
    local p = C.DecodeProfile(body)
    if p then StoreProfile(p, sender) end
end

H.MQ = function(_, _, sender)
    if RateLimited("MQ", sender, 300) then return end
    local g = GH.GuildDB()
    if not g then return end
    local lines, seen = {}, {}
    local function add(owner)
        if seen[owner] or owner == sender or owner == GH.Me() then return end
        seen[owner] = true
        local p = HeldProfile(owner)
        if p and GH.IsGuildie(owner) then lines[#lines + 1] = join(owner, p.rev or 0) end
    end
    for owner in pairs(g.members) do add(owner) end
    for owner in pairs(GH.DB().chars) do add(owner) end
    if #lines > 0 then
        Sync.Send(join("MF", PROTO), table.concat(lines, "\n"), "WHISPER", sender, "BULK")
    end
end

H.MF = function(_, body, sender)
    local g = GH.GuildDB()
    if not g then return end
    local want = {}
    for line in (body .. "\n"):gmatch("(.-)\n") do
        local owner, rev = strsplit("\t", line)
        rev = tonumber(rev)
        if owner and rev and owner ~= GH.Me() and GH.IsGuildie(owner) and not GH.IsOnline(owner) then
            local cur = g.members[owner]
            if not cur or (cur.rev or 0) < rev then want[#want + 1] = owner end
        end
    end
    -- Ask in batches; each batch is answered with one PRO per owner.
    for i = 1, #want, 10 do
        local batch = { "RQ", PROTO }
        for j = i, math.min(i + 9, #want) do batch[#batch + 1] = want[j] end
        C_Timer.After((i - 1) / 10 * 4, function()
            Sync.Send(table.concat(batch, "\t"), nil, "WHISPER", sender)
        end)
    end
end

H.RQ = function(f, _, sender)
    local served = lastServed["RQn" .. sender] or 0
    for i = 3, #f do
        if served >= 80 then break end
        local owner = f[i]
        local p = owner and HeldProfile(owner)
        if p and GH.IsGuildie(owner) then
            served = served + 1
            Sync.Send(join("PRO", PROTO), C.EncodeProfile(p, p.listings, p.wants), "WHISPER", sender, "BULK")
        end
    end
    lastServed["RQn" .. sender] = served
    C_Timer.After(300, function() lastServed["RQn" .. sender] = nil end)
end

-- Other modules (craft requests) add their own message kinds.
function Sync.Handle(kind, fn) H[kind] = fn end

function Sync:OnCommReceived(prefix, message, dist, sender)
    if prefix ~= PREFIX then return end
    sender = GH.FullName(sender)
    if not sender or sender == GH.Me() then return end
    if dist ~= "GUILD" and dist ~= "WHISPER" then return end
    -- Whispers can come from anyone; only guildies get an answer.
    if dist == "WHISPER" and not GH.IsGuildie(sender) then return end

    local header, body = message:match("^([^\n]*)\n?(.*)$")
    if not header then return end
    local f = { strsplit("\t", header) }
    local kind, proto = f[1], tonumber(f[2])
    if proto ~= PROTO then
        if (kind == "HI" or kind == "YO") and proto and proto > PROTO then SeePeer(sender, f[3]) end
        return
    end
    local fn = H[kind]
    if fn then
        local ok, err = pcall(fn, f, body, sender, dist)
        if not ok then GH.dbg("error handling %s from %s: %s", kind, sender, tostring(err)) end
    end
end
Sync:RegisterComm(PREFIX)

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
GH.Listen("ROSTER", function(first)
    if first and not helloSent then
        C_Timer.After(Jitter(5, 12), Sync.Hello)
    end
    -- Forget guildies who left (only when the roster includes offline members).
    local g = GH.GuildDB()
    if g and GH.rosterComplete then
        local now, changed = GH.Now(), false
        for owner, p in pairs(g.members) do
            if GH.IsGuildie(owner) then
                p.missingSince = nil
            else
                p.missingSince = p.missingSince or now
                if now - p.missingSince > 3 * 86400 then
                    g.members[owner] = nil
                    changed = true
                end
            end
        end
        if changed then GH.Fire("DATA_CHANGED") end
    end
end)

GH.Listen("GUILD_CHANGED", function()
    if IsInGuild() and not helloSent then
        C_Timer.After(Jitter(5, 12), function()
            if GH.rosterReady then Sync.Hello() end
        end)
    elseif not IsInGuild() then
        helloSent, manifestAsked = false, false
    end
end)

GH.Listen("MY_DATA_CHANGED", function(reason)
    if not helloSent then return end
    if reason == "rank" then
        -- Skill-ups come in bursts while leveling; share them at most every two minutes.
        GH.Coalesce("publishRank", 120, Sync.Publish)
    else
        GH.Debounce("publish", 10, Sync.Publish)
    end
end)

function GH.PrintStatus()
    local g = GH.GuildDB()
    if not g then
        GH.msg("not in a guild.")
        return
    end
    local members, relays = 0, 0
    for _, p in pairs(g.members) do
        members = members + 1
        if p.via then relays = relays + 1 end
    end
    local peers = 0
    for full in pairs(Sync.peers) do if GH.IsOnline(full) then peers = peers + 1 end end
    local d = GH.MyData()
    GH.msg("v%s, %d guildie profiles stored (%d relayed), %d online with Guildhall. Your rev: %d.",
        GH.VERSION, members, relays, peers, d and d.rev or 0)
end
