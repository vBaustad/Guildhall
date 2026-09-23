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

-- Addon messages are NOT part of the chat messaging lockdown: C_ChatInfo.SendAddonMessage carries no
-- such restriction in the API docs (only "no secret values"); the lockdown silences real chat.
-- Guildhall used to queue every message while it was on, and then never send them.
-- The client can still refuse a message (Enum.SendAddonMessageResult, e.g. in restricted content);
-- that only shows after the fact, per chunk. Count it, and send lockdown refusals again once the
-- restriction changes.
Sync.stats = { sent = 0, received = 0, refused = {}, restoredPosts = 0, restoredOrders = 0 }
local RESULT = Enum and Enum.SendAddonMessageResult or {}
local RESULT_NAME = {}
for name, value in pairs(RESULT) do RESULT_NAME[value] = name end
local LOCKDOWN = RESULT.AddOnMessageLockdown or 11
local retry = {}
local MAX_RETRY = 30

local function Dispatch(m)
    Sync:SendCommMessage(PREFIX, m.text, m.dist, m.target, m.prio, function(msg, sent, bytes, result)
        if not sent and not msg.refusal then msg.refusal = result or -1 end
        if (bytes or 0) < #msg.text then return end   -- not the last chunk yet
        if not msg.refusal then
            Sync.stats.sent = Sync.stats.sent + 1
            return
        end
        local reason = RESULT_NAME[msg.refusal] or tostring(msg.refusal)
        Sync.stats.refused[reason] = (Sync.stats.refused[reason] or 0) + 1
        if msg.refusal == LOCKDOWN and #retry < MAX_RETRY then
            msg.refusal = nil
            retry[#retry + 1] = msg
        end
    end, m)
end

function Sync.Send(header, body, dist, target, prio)
    if not IsInGuild() then return end
    local text = body and (header .. "\n" .. body) or header
    -- Whispers go to the name the server knows (no realm suffix on our own realm).
    if dist == "WHISPER" then target = GH.WhisperName(target) end
    Dispatch({ text = text, dist = dist, target = target, prio = prio or "NORMAL" })
end

local function FlushRetry()
    if #retry == 0 then return end
    local queue = retry
    retry = {}
    for _, m in ipairs(queue) do Dispatch(m) end
end
if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("ADDON_RESTRICTION_STATE_CHANGED") then
    GH.On("ADDON_RESTRICTION_STATE_CHANGED", function() GH.Debounce("commRetry", 1, FlushRetry) end)
end

local function RateLimited(kind, sender, seconds)
    local k = kind .. sender
    local now = GetTime()
    if lastServed[k] and now - lastServed[k] < seconds then return true end
    lastServed[k] = now
    return false
end

local function Jitter(lo, hi) return lo + math.random() * (hi - lo) end

-- How many guildies with Guildhall have answered so far.
function Sync.PeerCount()
    local n = 0
    for full in pairs(Sync.peers) do if GH.IsOnline(full) then n = n + 1 end end
    return n
end

-- Guildhall is "syncing" from login until the first round of profiles has had time to arrive.
-- The UI shows that instead of pretending the guild has shared nothing.
Sync.syncing = false
local function SetSyncing(on)
    if Sync.syncing == on then return end
    Sync.syncing = on
    GH.Fire("SYNC_STATE")
end

function Sync.DoneSoon(seconds)
    C_Timer.After(seconds or 25, function() SetSyncing(false) end)
end

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
    if alt and owner ~= GH.Me() and GH.KnownGuildie(owner) and (not p or (alt.rev or 0) >= (p.rev or 0)) then
        return alt
    end
    return p
end

-- A guildie sent back their copy of MY profile, because this character's record had to start from
-- scratch this session (see GH.freshSelf). Only listings and wants are taken - professions come back
-- from the scan anyway - and only what isn't there already. A live profile is never overwritten.
function Sync.RestoreSelf(p, sender)
    local d = GH.MyData()
    if not d or GH.restoreClosed then return end
    -- More guildies can answer the same hello: keep merging their copies for the rest of the session.
    if not (d.restorePending or GH.restoredThisSession) then return end
    local haveListing, haveWant = {}, {}
    for _, l in ipairs(d.listings) do haveListing[l.item] = true end
    for _, w in ipairs(d.wants) do haveWant[C.ItemIdFromString(w.item) or w.item] = true end
    local added = 0
    for _, l in ipairs(p.listings or {}) do
        if not haveListing[l.item] and #d.listings < C.MAX_LISTINGS then
            d.listings[#d.listings + 1] = { id = GH.NextId(), item = l.item, count = l.count, note = l.note,
                posted = l.posted }
            haveListing[l.item] = true
            added = added + 1
        end
    end
    for _, w in ipairs(p.wants or {}) do
        local key = C.ItemIdFromString(w.item) or w.item
        if not haveWant[key] and #d.wants < C.MAX_WANTS then
            d.wants[#d.wants + 1] = { id = GH.NextId(), item = w.item, note = w.note, posted = w.posted,
                qty = w.qty, price = w.price }
            haveWant[key] = true
            added = added + 1
        end
    end
    if added > 0 then
        Sync.stats.restoredPosts = Sync.stats.restoredPosts + added
        GH.restoredThisSession = true
        GH.msg("restored %s from %s's copy.", GH.Count(added, "listing or wanted post", "listings and wanted posts"),
            GH.Short(sender))
        GH.BumpRev("restore")
    end
end

-- fresh: the owner's record started from scratch (see GH.freshSelf), so its posts may just be missing.
local function StoreProfile(p, sender, fresh)
    local g = GH.GuildDB()
    if not g or not p.owner then return end
    -- Revisions are timestamps: one from the future would lock out the owner's real updates.
    if (p.rev or 0) > GH.Now() + 86400 then return end
    if p.owner == GH.Me() then
        Sync.RestoreSelf(p, sender)
        return
    end
    -- With a roster we can tell strangers apart; without one, the guild channel vouches for them.
    if GH.rosterComplete and not GH.KnownGuildie(p.owner) then return end
    local direct = (p.owner == sender)
    local cur = g.members[p.owner]
    if cur then
        -- The owner always wins over a copy passed on by someone else, whatever the revisions say:
        -- otherwise one bad relay could keep the real profile out for good.
        if direct and cur.via then
            -- take it
        elseif direct and p.rev < (cur.rev or 0) then return
        elseif not direct and p.rev <= (cur.rev or 0) then return end
    elseif not direct then
        -- Relayed profile for someone new: only up to a sane number of them.
        local n = 0
        for _ in pairs(g.members) do n = n + 1 end
        if n >= C.MAX_MEMBERS then return end
    end
    -- A fresh profile brings professions and rev, but never wipes the posts we hold for them. Kept as
    -- fresh (and relayed as such) until the owner publishes normally again.
    p.fresh = fresh or nil
    if fresh and cur and (#(cur.listings or {}) > 0 or #(cur.wants or {}) > 0) then
        p.listings, p.wants = cur.listings, cur.wants
    end
    p.received = GH.Now()
    p.stale = nil
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
    -- A handful of guildies online can all answer at once; spread it out in bigger guilds.
    local wait = Sync.PeerCount() < 10 and Jitter(0.5, 2) or Jitter(1, 8)
    C_Timer.After(wait, function()
        Sync.Send(join("GET", PROTO), nil, "WHISPER", owner)
    end)
    C_Timer.After(90, function() pendingGet[owner] = nil end)
end

function Sync.Hello()
    local d = GH.MyData()
    if not d or not IsInGuild() or not GH.GuildDB() then return end
    helloSent = true
    SetSyncing(true)
    Sync.DoneSoon(25)
    -- A fifth field "1" asks guildies holding a copy of my profile to send it back (fresh record).
    Sync.Send(join("HI", PROTO, GH.VERSION, d.rev, GH.freshSelf and "1" or "0"), nil, "GUILD")
    GH.dbg("hello sent (rev %d)", d.rev)
end

function Sync.Publish()
    if not helloSent or not IsInGuild() then return end
    Sync.Send(join("PRO", PROTO, GH.freshSelf and "F" or ""), MyPayload(), "GUILD", nil, "BULK")
    GH.dbg("published profile")
end

-- ---------------------------------------------------------------------------
-- Message handlers
-- ---------------------------------------------------------------------------
local H = {}

-- Their record is new this session (HI/YO field 5 = "1"): send back what we hold of it, before we
-- ask for their profile - that request would replace our copy with their empty one.
local function SendBackCopy(f, sender)
    if f[5] ~= "1" or RateLimited("COPY", sender, 300) then return end
    local g = GH.GuildDB()
    local copy = g and g.members[sender]
    if copy and (#(copy.listings or {}) > 0 or #(copy.wants or {}) > 0) then
        Sync.Send(join("PRO", PROTO), C.EncodeProfile(copy, copy.listings, copy.wants), "WHISPER", sender)
    end
end

H.HI = function(f, _, sender)
    SendBackCopy(f, sender)
    SeePeer(sender, f[3])
    NoteRev(sender, tonumber(f[4]))
    local d = GH.MyData()
    -- One reply per sender per 30 s: a peer repeating hellos can't turn into a whisper storm.
    if d and helloSent and not RateLimited("YO", sender, 30) then
        C_Timer.After(Sync.PeerCount() < 10 and Jitter(0.5, 3) or Jitter(2, 12), function()
            Sync.Send(join("YO", PROTO, GH.VERSION, d.rev, GH.freshSelf and "1" or "0"), nil, "WHISPER", sender)
        end)
    end
end

H.YO = function(f, _, sender)
    SendBackCopy(f, sender)
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
    Sync.Send(join("PRO", PROTO, GH.freshSelf and "F" or ""), MyPayload(), "WHISPER", sender, "BULK")
end

H.PRO = function(f, body, sender)
    local p = C.DecodeProfile(body)
    if p then StoreProfile(p, sender, f[3] == "F") end
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
        if p and GH.KnownGuildie(owner) then lines[#lines + 1] = join(owner, p.rev or 0) end
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
        if owner and rev and owner ~= GH.Me() and GH.KnownGuildie(owner) and not GH.IsOnline(owner) then
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
        if p and GH.KnownGuildie(owner) then
            served = served + 1
            Sync.Send(join("PRO", PROTO, (p.fresh or p.restorePending) and "F" or ""), C.EncodeProfile(p, p.listings, p.wants),
                "WHISPER", sender, "BULK")
        end
    end
    lastServed["RQn" .. sender] = served
    C_Timer.After(300, function() lastServed["RQn" .. sender] = nil end)
end

-- Other modules (craft requests) add their own message kinds.
function Sync.Handle(kind, fn) H[kind] = fn end

-- A sender gets a budget of messages per window; past that we stop reading them. Normal syncing is
-- a handful of messages, so this only ever bites a flood.
local budget = {}
local BUDGET, WINDOW = 40, 10
local function Flooding(sender)
    local now, b = GetTime(), budget[sender]
    if not b or now - b.start > WINDOW then
        budget[sender] = { start = now, n = 1 }
        return false
    end
    b.n = b.n + 1
    if b.n == BUDGET + 1 then GH.dbg("ignoring a flood of messages from %s", sender) end
    return b.n > BUDGET
end

function Sync:OnCommReceived(prefix, message, dist, sender)
    if prefix ~= PREFIX then return end
    Sync.stats.received = Sync.stats.received + 1
    -- Any message means they're online right now (the roster may not know).
    local known = Sync.peers[GH.FullName(sender) or ""]
    if known then known.seen = GH.Now() end
    sender = GH.FullName(sender)
    if not sender or sender == GH.Me() then return end
    if dist ~= "GUILD" and dist ~= "WHISPER" then return end
    -- Whispers can come from anyone; only guildies get an answer.
    if dist == "WHISPER" and not GH.KnownGuildie(sender) then return end
    if Flooding(sender) then return end

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

-- AceComm registers the prefix itself; doing it again is harmless and lets /gh status show whether
-- the server accepted it.
GH.Listen("LOGIN", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        Sync.prefixRegistered = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
end)

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
-- The guild addon channel works without the roster, so don't wait for it.
GH.Listen("LOGIN", function()
    if IsInGuild() then C_Timer.After(Jitter(2, 6), Sync.Hello) end
end)

GH.Listen("ROSTER", function(first)
    -- Backstop: if the roster turns up before we said hello (rare), say it now.
    if first and not helloSent then
        C_Timer.After(Jitter(2, 6), Sync.Hello)
    end
    -- Stored profiles are never pruned: the roster can be empty or partial, and losing a guildie's
    -- data because they weren't listed is worse than keeping one of someone who left.
end)

-- Profiles saved last session are shown right away, marked until a fresh copy arrives.
GH.Listen("LOGIN", function()
    for _, g in pairs(GH.DB().guilds) do
        for _, p in pairs(g.members or {}) do p.stale = true end
    end
end)

GH.Listen("GUILD_CHANGED", function()
    if IsInGuild() and not helloSent then
        C_Timer.After(Jitter(2, 6), function()
            if GH.rosterReady then Sync.Hello() end
        end)
    elseif not IsInGuild() then
        helloSent, manifestAsked = false, false
    end
end)

GH.Listen("MY_DATA_CHANGED", function(reason)
    if not helloSent then return end
    if reason == "rank" or reason == "bags" or reason == "autoscan" then
        -- Skill-ups and bag-driven listing updates come in bursts; share them at most every two
        -- minutes. Changes the player makes by hand still go out after 10 seconds.
        GH.Coalesce("publishSlow", 120, Sync.Publish)
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
    GH.msg("v%s, %s stored (%d relayed), %d online with Guildhall. Your rev: %d.",
        GH.VERSION, GH.Count(members, "guildie profile"), relays, peers, d and d.rev or 0)
    local roster = 0
    for _ in pairs(GH.roster) do roster = roster + 1 end
    local refused, parts = 0, {}
    for reason, n in pairs(Sync.stats.refused) do
        refused = refused + n
        parts[#parts + 1] = ("%s %d"):format(reason, n)
    end
    GH.msg("messages sent %d, received %d, refused %d%s, waiting %d; prefix registered: %s.",
        Sync.stats.sent, Sync.stats.received, refused,
        #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or "", #retry, tostring(Sync.prefixRegistered))
    local oldest
    for _, p in pairs(g.members) do
        if p.received and (not oldest or p.received < oldest) then oldest = p.received end
    end
    GH.msg("stored profiles: %d%s.", members, oldest and (" (oldest seen " .. GH.Ago(oldest) .. ")") or "")
    local orders, open = 0, 0
    for _, tbl in pairs({ g.incoming or {}, g.outgoing or {} }) do
        for _, o in pairs(tbl) do
            orders = orders + 1
            if not GH.Orders.FINISHED[o.status] then open = open + 1 end
        end
    end
    GH.msg("stored requests: %d (%d open). Restored from guildies this session: %d posts, %d requests.",
        orders, open, Sync.stats.restoredPosts, Sync.stats.restoredOrders)
    if roster == 0 then
        GH.msg("roster: 0 members - it fills in when the client provides it; sharing works without it.")
    else
        GH.msg("roster: %s.", GH.Count(roster, "member"))
    end
end
