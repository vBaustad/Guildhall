-- Guildhall - craft requests between guildies.
--
--   ORD (requester -> crafter)  id, item key, quantity, note
--   ACK (crafter -> requester)  id, crafter's status, reagents - confirms delivery
--   OST (either way)            requester, id, new status
--   OSY (either way)            every request between the two of us, so a side that lost its copy
--                               gets it back; each status is only set by the side that owns it
--
-- A request made while the crafter is offline waits and is delivered when they come online.
-- No gold or items move through the addon; you still trade or mail as usual.
local ADDON, GH = ...
local C = GH.Codec
local Sync = GH.Sync
local O = {}
GH.Orders = O

local PROTO = Sync.PROTO
local MAX_INCOMING = 100
local MAX_OUTGOING = 50
local FINISHED = { declined = true, done = true, cancelled = true }
O.FINISHED = FINISHED

local function join(...) return table.concat({ ... }, "\t") end

local function Store()
    local g = GH.GuildDB()
    if not g then return nil end
    g.incoming = g.incoming or {}
    g.outgoing = g.outgoing or {}
    return g
end

local function Changed() GH.Fire("ORDERS_CHANGED") end

-- ---------------------------------------------------------------------------
-- Queries for the UI
-- ---------------------------------------------------------------------------
local function Sorted(tbl, who, field)
    local list = {}
    for _, o in pairs(tbl or {}) do
        if o[field] == who and not o.removed and not GH.IsBlocked(o.requester) then list[#list + 1] = o end
    end
    table.sort(list, function(a, b)
        local fa, fb = FINISHED[a.status] and 1 or 0, FINISHED[b.status] and 1 or 0
        if fa ~= fb then return fa < fb end
        return (a.updated or 0) > (b.updated or 0)
    end)
    return list
end

function O.Incoming()
    local g = Store()
    return g and Sorted(g.incoming, GH.Me(), "crafter") or {}
end

function O.Outgoing()
    local g = Store()
    return g and Sorted(g.outgoing, GH.Me(), "requester") or {}
end

function O.NewCount()
    local n = 0
    for _, o in ipairs(O.Incoming()) do
        if o.status == "new" then n = n + 1 end
    end
    return n
end

function O.Reagents(o)
    -- Static recipe data first; a crafter's ACK can still fill in recipes the data doesn't know.
    return GH.Index.ReagentsFor(o.item) or C.DecodeReagents(o.reagents)
end

-- ---------------------------------------------------------------------------
-- Requester side
-- ---------------------------------------------------------------------------
local function TrySend(o)
    if o.status ~= "sending" then return end
    if not GH.IsOnline(o.crafter) then return end
    if (o.tries or 0) >= 10 then return end
    o.tries = (o.tries or 0) + 1
    o.lastTry = GH.Now()
    Sync.Send(join("ORD", PROTO, o.id, C.KeyToWire(o.item), o.qty, C.Clean(o.note)), nil, "WHISPER", o.crafter)
end

function O.Request(crafter, key, qty, note)
    local g = Store()
    local me = GH.Me()
    if not g or not me then return false, "You need to be in a guild." end
    if crafter == me then return false, "That's you." end
    if not C.KeyToWire(key) then return false, "Unknown item." end
    local open = 0
    for _, o in pairs(g.outgoing) do
        if o.requester == me and not FINISHED[o.status] then open = open + 1 end
    end
    if open >= MAX_OUTGOING then return false, "You have too many open requests." end

    local id = GH.NextId()
    local o = {
        oid = me .. "#" .. id, id = id, requester = me, crafter = crafter,
        item = key, qty = math.max(1, math.min(tonumber(qty) or 1, 999)), note = C.Clean(note),
        status = "sending", created = GH.Now(), updated = GH.Now(),
    }
    g.outgoing[o.oid] = o
    TrySend(o)
    Changed()
    return true
end

function O.Cancel(oid)
    local g = Store()
    local o = g and g.outgoing[oid]
    if not o or FINISHED[o.status] then return end
    local wasDelivered = o.status ~= "sending"
    o.status, o.updated = "cancelled", GH.Now()
    if wasDelivered then
        o.dirty = true
        O.Flush(o.crafter)
    end
    Changed()
end

-- ---------------------------------------------------------------------------
-- Crafter side
-- ---------------------------------------------------------------------------
function O.SetStatus(oid, status)
    local g = Store()
    local o = g and g.incoming[oid]
    if not o or o.status == "cancelled" then return end
    if status ~= "accepted" and status ~= "declined" and status ~= "done" then return end
    o.status, o.updated, o.dirty = status, GH.Now(), true
    O.Flush(o.requester)
    Changed()
end

-- Remove a finished request from my list. It's only hidden: the record stays as a tombstone until
-- housekeeping drops it after 30 days, so the other side's replay can't bring it back.
function O.Remove(oid)
    local g = Store()
    if not g then return end
    local o = g.incoming[oid] or g.outgoing[oid]
    if o and (FINISHED[o.status] or o.status == "sending") then
        if o.status == "sending" then o.status = "cancelled" end
        o.removed, o.updated = true, GH.Now()
        Changed()
    end
end

-- Send any status changes the other side hasn't heard about yet.
-- seenRunning: we just heard from them over the addon channel, so retry even after many failed tries.
function O.Flush(who, seenRunning)
    local g = Store()
    if not g or not GH.IsOnline(who) then return end
    local me = GH.Me()
    for _, o in pairs(g.incoming) do
        if o.dirty and o.requester == who and o.crafter == me then
            Sync.Send(join("OST", PROTO, o.requester, o.id, o.status), nil, "WHISPER", who)
            o.dirty = nil
        end
    end
    for _, o in pairs(g.outgoing) do
        if o.requester == me and o.crafter == who then
            if o.dirty then
                Sync.Send(join("OST", PROTO, o.requester, o.id, o.status), nil, "WHISPER", who)
                o.dirty = nil
            elseif o.status == "sending" then
                if seenRunning then o.tries = 0 end
                TrySend(o)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Messages
-- ---------------------------------------------------------------------------
local STATUS_WORDS = { accepted = "accepted", declined = "declined", done = "finished" }

Sync.Handle("ORD", function(f, _, sender)
    local g = Store()
    local me = GH.Me()
    if not g or not me then return end
    local id, key, qty = tonumber(f[3]), C.WireToKey(f[4]), tonumber(f[5])
    if not id or not key then return end
    local oid = sender .. "#" .. id
    local o = g.incoming[oid]
    if not o and GH.IsBlocked(sender) then
        -- Blocked: answer like any delivered request, so their side just shows it as waiting.
        Sync.Send(join("ACK", PROTO, id, "new", ""), nil, "WHISPER", sender)
        return
    end
    if not o then
        local count = 0
        for _ in pairs(g.incoming) do count = count + 1 end
        if count >= MAX_INCOMING then return end
        o = {
            oid = oid, id = id, requester = sender, crafter = me, item = key,
            qty = math.max(1, math.min(qty or 1, 999)), note = C.Clean(f[6]),
            status = "new", created = GH.Now(), updated = GH.Now(),
        }
        g.incoming[oid] = o
        if GH.Settings().notifyRequests then
            local roster = GH.roster[sender]
            local link = C.KeyLink(key) or C.KeyName(key) or "an item"
            GH.msg("%s asks you to craft %s x%d. |cffffd100/gh requests|r", GH.ColorName(sender, roster and roster.class), link, o.qty)
            PlaySound(SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081)
        end
        Changed()
    end
    Sync.Send(join("ACK", PROTO, id, o.status, C.EncodeReagents(GH.Index.ReagentsFor(key))), nil, "WHISPER", sender)
end)

Sync.Handle("ACK", function(f, _, sender)
    local g = Store()
    local me = GH.Me()
    if not g or not me then return end
    local o = g.outgoing[me .. "#" .. tostring(f[3])]
    if not o or o.crafter ~= sender then return end
    local status = f[4]
    if o.status == "sending" then
        o.status = (status == "new") and "pending" or (STATUS_WORDS[status] and status) or "pending"
        o.updated = GH.Now()
    end
    if f[5] and f[5] ~= "" and C.DecodeReagents(f[5]) then
        o.reagents = f[5]
        local cache = GH.DB().reagents
        if not cache[o.item] then cache[o.item] = f[5] end
    end
    Changed()
end)

Sync.Handle("OST", function(f, _, sender)
    local g = Store()
    local me = GH.Me()
    if not g or not me then return end
    local requester, id, status = f[3], f[4], f[5]
    if not requester or not id then return end
    local oid = requester .. "#" .. id
    if requester == me then
        -- The crafter updated a request I made.
        local o = g.outgoing[oid]
        if o and o.crafter == sender and STATUS_WORDS[status] and o.status ~= "cancelled" then
            o.status, o.updated = status, GH.Now()
            local roster = GH.roster[sender]
            if not GH.IsBlocked(sender) then GH.msg("%s %s your request for %s.", GH.ColorName(sender, roster and roster.class),
                STATUS_WORDS[status], C.KeyLink(o.item) or C.KeyName(o.item) or "an item") end
            Changed()
        end
    elseif requester == sender then
        -- The requester cancelled.
        local o = g.incoming[oid]
        if o and o.crafter == me and status == "cancelled" and not FINISHED[o.status] then
            o.status, o.updated = "cancelled", GH.Now()
            Changed()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Replay: when we see each other, both sides send every request between us. Whoever lost theirs
-- (saved data that didn't load) gets it back. Statuses only move forward on the side that owns them:
-- the requester cancels, the crafter accepts, declines or finishes.
-- ---------------------------------------------------------------------------
local REQUESTER_SETS = { cancelled = true }
local CRAFTER_SETS = { accepted = true, declined = true, done = true }
local KNOWN_STATUS = { sending = true, pending = true, new = true, accepted = true, declined = true,
    done = true, cancelled = true }
local replayed = {}   -- [who] = time, so a chatty peer doesn't trigger a replay every message

function O.Replay(who)
    local g = Store()
    local me = GH.Me()
    if not g or not me or not who then return end
    if replayed[who] and GH.Now() - replayed[who] < 120 then return end
    replayed[who] = GH.Now()
    local lines = {}
    local function add(o)
        lines[#lines + 1] = join(o.requester, o.id, C.KeyToWire(o.item) or "", o.qty or 1, o.status,
            o.created or 0, o.updated or 0, C.Clean(o.note))
    end
    for _, o in pairs(g.outgoing) do
        if o.requester == me and o.crafter == who then add(o) end
    end
    for _, o in pairs(g.incoming) do
        if o.crafter == me and o.requester == who then add(o) end
    end
    if #lines > 0 then
        Sync.Send(join("OSY", PROTO), table.concat(lines, "\n"), "WHISPER", who, "BULK")
    end
end

local function Int(s) return s and s:match("^%d+$") and tonumber(s) or nil end

Sync.Handle("OSY", function(_, body, sender)
    local g = Store()
    local me = GH.Me()
    if not g or not me or type(body) ~= "string" then return end
    local changed = false
    for line in (body .. "\n"):gmatch("(.-)\n") do
        local f = { strsplit("\t", line) }
        local requester, id, key = f[1], Int(f[2]), C.WireToKey(f[3])
        local qty, status, created, updated = Int(f[4]), f[5], Int(f[6]), Int(f[7])
        -- Strict: a damaged line is skipped, never half-applied, and the numbers stay in range so a
        -- peer can't hand us a quantity, an id or a date out of thin air.
        if #f == 8 and requester and id and id <= 10000000 and key and qty and KNOWN_STATUS[status]
            and created and updated then
            local limit = GH.Now() + 86400
            qty = math.max(1, math.min(qty, 999))
            created, updated = math.min(created, limit), math.min(updated, limit)
            local oid = requester .. "#" .. id
            if requester == me then
                -- Their copy of a request I made to them.
                local o = g.outgoing[oid]
                local mine = (status == "new" or status == "sending") and "pending" or status
                if not o and not FINISHED[mine] then
                    g.outgoing[oid] = {
                        oid = oid, id = id, requester = me, crafter = sender, item = key, qty = qty,
                        note = C.Clean(f[8]), status = mine, created = created, updated = updated,
                    }
                    Sync.stats.restoredOrders = Sync.stats.restoredOrders + 1
                    if id >= (GH.MyData().nextId or 1) then GH.MyData().nextId = id + 1 end
                    changed = true
                elseif o and o.crafter == sender then
                    if CRAFTER_SETS[status] and not FINISHED[o.status] and o.status ~= status then
                        o.status, o.updated = status, math.max(updated, o.updated or 0)
                        changed = true
                    elseif o.status == "sending" then
                        o.status, o.updated = "pending", GH.Now()
                        changed = true
                    elseif REQUESTER_SETS[o.status] and not REQUESTER_SETS[status] then
                        o.dirty = true   -- they missed my cancel: tell them again
                    end
                end
            elseif requester == sender then
                -- Their copy of a request they made to me.
                local o = g.incoming[oid]
                if not o and not GH.IsBlocked(sender) then
                    local count = 0
                    for _ in pairs(g.incoming) do count = count + 1 end
                    if not FINISHED[status] and status ~= "sending" and count < MAX_INCOMING then
                        g.incoming[oid] = {
                            oid = oid, id = id, requester = sender, crafter = me, item = key, qty = qty,
                            note = C.Clean(f[8]), status = (status == "pending") and "new" or status,
                            created = created, updated = updated,
                        }
                        Sync.stats.restoredOrders = Sync.stats.restoredOrders + 1
                        changed = true
                    end
                elseif o and o.crafter == me then
                    if REQUESTER_SETS[status] and not FINISHED[o.status] then
                        o.status, o.updated = status, math.max(updated, o.updated or 0)
                        changed = true
                    elseif CRAFTER_SETS[o.status] and not CRAFTER_SETS[status] and not REQUESTER_SETS[status] then
                        o.dirty = true   -- they never heard my answer: tell them again
                    end
                end
            end
        end
    end
    if changed then Changed() end
    O.Flush(sender, true)
end)

-- Deliver waiting requests / status changes when the other side shows up.
GH.Listen("PEER_SEEN", function(who)
    C_Timer.After(3, function()
        O.Flush(who, true)
        O.Replay(who)
    end)
end)
GH.Listen("MEMBER_ONLINE", function(who) C_Timer.After(20, function() O.Flush(who) end) end)

local function Housekeeping()
    local g = Store()
    if not g then return end
    local now = GH.Now()
    for _, tbl in pairs({ g.incoming, g.outgoing }) do
        for oid, o in pairs(tbl) do
            local age = now - (o.updated or 0)
            -- Open requests never expire. Finished ones stay 30 days as tombstones, so a stale copy
            -- replayed by the other side can't bring a cancelled request back.
            if FINISHED[o.status] and age > 30 * 86400 then
                tbl[oid] = nil
            end
        end
    end
    -- Retry undelivered requests to crafters who are online.
    for _, o in pairs(g.outgoing) do
        if o.status == "sending" and now - (o.lastTry or 0) > 90 then TrySend(o) end
    end
end

GH.Listen("LOGIN", function()
    C_Timer.After(30, Housekeeping)
    C_Timer.NewTicker(90, Housekeeping)
end)
