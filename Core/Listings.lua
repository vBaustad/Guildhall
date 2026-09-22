-- Guildhall - listings (items you have for guildies) and wanted posts (items you're looking for).
local ADDON, GH = ...
local C = GH.Codec
local L = {}
GH.Listings = L

local WANT_DAYS = 30
local MISSING_GRACE = 3 * 86400   -- an item out of bags/bank (mailed, traded) hides for this long before the listing is dropped

local function TTL() return (GH.Settings().listingDays or 14) * 86400 end

-- ---------------------------------------------------------------------------
-- Listings
-- ---------------------------------------------------------------------------
function L.Add(link, count, note)
    local d = GH.MyData()
    if not d then return false end
    local item = C.ItemStringFromLink(link)
    local id = C.ItemIdFromString(item)
    if not id then return false, "That isn't an item." end
    local have = GH.API.GetItemCount(id, true) or 0
    if have == 0 then return false, "You don't have that item in your bags or bank." end
    local blocked = C.UntradableType(id)
    if blocked == "quest" then return false, "Quest items can't be traded." end
    if blocked == "bop" or C.IsBoundInBags(id) then
        return false, "That one is soulbound, so it can't be traded."
    end
    count = math.max(1, math.min(tonumber(count) or have, have))
    note = C.Clean(note)

    for _, l in ipairs(d.listings) do
        if l.item == item then
            l.count, l.note, l.posted, l.missing = count, note, GH.Now(), nil
            GH.BumpRev("listings")
            return true
        end
    end
    if #d.listings >= C.MAX_LISTINGS then
        return false, ("You can have at most %d listings."):format(C.MAX_LISTINGS)
    end
    table.insert(d.listings, { id = GH.NextId(), item = item, count = count, note = note, posted = GH.Now() })
    GH.BumpRev("listings")
    return true
end

function L.Remove(id)
    local d = GH.MyData()
    if not d then return end
    for i, l in ipairs(d.listings) do
        if l.id == id then
            table.remove(d.listings, i)
            GH.BumpRev("listings")
            return
        end
    end
end

-- What guildies get to see: no expired listings, none whose item has left my bags.
function L.Publishable()
    local d = GH.MyData()
    local out = {}
    if not d then return out end
    local now, ttl = GH.Now(), TTL()
    for _, l in ipairs(d.listings) do
        if not l.missing and now - (l.posted or 0) <= ttl then out[#out + 1] = l end
    end
    return out
end

-- "100x Copper Bar - 3g each (300g total)" for a wanted post; the name is passed in.
function L.WantText(w, name)
    local qty = w.qty or 1
    local text = ("%dx %s"):format(qty, name or "?")
    if (w.price or 0) > 0 then
        text = text .. (" - %s each"):format(GH.Money(w.price))
        if qty > 1 then text = text .. (" (%s total)"):format(GH.Money(w.price * qty)) end
    end
    return text
end

-- "I'll make it": answer a guildie's wanted post. For now it opens a whisper with the item, amount
-- and price filled in; mail delivery will hang off this same entry point later.
function L.OfferWant(owner, key, w)
    local link = GH.Codec.KeyLink(key) or ("item " .. tostring(key))
    local qty = w and w.qty or 1
    local text
    if w and (w.price or 0) > 0 then
        text = ("I can make %s for you - %dx for %s each?"):format(link, qty, GH.Money(w.price))
    else
        text = ("I can make %s for you - %dx?"):format(link, qty)
    end
    GH.UI.WhisperText(owner, text)
end

-- Do I have a wanted post up for this item?
function L.MyWantFor(key)
    local d = GH.MyData()
    for _, w in ipairs(d and d.wants or {}) do
        if C.ItemIdFromString(w.item) == key then return w end
    end
end

-- ---------------------------------------------------------------------------
-- Wanted posts
-- ---------------------------------------------------------------------------
function L.AddWant(linkOrKey, note, qty, price)
    local d = GH.MyData()
    if not d then return false end
    local item
    if type(linkOrKey) == "number" then
        item = "item:" .. linkOrKey
    else
        item = C.ItemStringFromLink(linkOrKey)
    end
    local id = C.ItemIdFromString(item)
    if not id then return false, "That isn't an item." end
    -- Only the item type is known here (there's no copy to look at), so block what can never be traded.
    local blocked = C.UntradableType(id)
    if blocked == "quest" then return false, "Quest items can't be traded, so nobody could hand you one." end
    if blocked == "bop" then return false, "Soulbound items can't be traded, so nobody could hand you one." end
    note = C.Clean(note)
    qty = math.max(1, math.min(math.floor(tonumber(qty) or 1), 9999))
    price = math.max(0, math.min(math.floor(tonumber(price) or 0), 99999999))
    for _, w in ipairs(d.wants) do
        if C.ItemIdFromString(w.item) == C.ItemIdFromString(item) then
            w.note, w.posted, w.qty, w.price = note, GH.Now(), qty, price
            GH.BumpRev("wants")
            return true
        end
    end
    if #d.wants >= C.MAX_WANTS then
        return false, ("You can have at most %d wanted posts."):format(C.MAX_WANTS)
    end
    table.insert(d.wants, { id = GH.NextId(), item = item, note = note, posted = GH.Now(), qty = qty, price = price })
    GH.BumpRev("wants")
    return true
end

function L.RemoveWant(id)
    local d = GH.MyData()
    if not d then return end
    for i, w in ipairs(d.wants) do
        if w.id == id then
            table.remove(d.wants, i)
            GH.BumpRev("wants")
            return
        end
    end
end

function L.PublishableWants()
    local d = GH.MyData()
    return d and d.wants or {}
end

-- Stored profiles from guildies: hide anything older than any sane listing lifetime.
function L.IsFresh(entry, isWant)
    local limit = (isWant and WANT_DAYS or 30) * 86400
    return GH.Now() - (entry.posted or 0) <= limit
end

-- ---------------------------------------------------------------------------
-- Housekeeping: counts follow your bags, old posts expire.
-- ---------------------------------------------------------------------------
function L.Check()
    local d = GH.MyData()
    if not d then return end
    local now, ttl = GH.Now(), TTL()
    local changed = false
    for i = #d.listings, 1, -1 do
        local l = d.listings[i]
        local id = C.ItemIdFromString(l.item)
        local have = id and GH.API.GetItemCount(id, true) or 0
        if now - (l.posted or 0) > ttl then
            table.remove(d.listings, i)
            changed = true
        elseif have == 0 then
            if not l.missing then
                l.missing = now
                changed = true
            elseif now - l.missing > MISSING_GRACE then
                table.remove(d.listings, i)
                changed = true
            end
        else
            if l.missing then
                l.missing = nil
                changed = true
            end
            if have < (l.count or 1) then
                l.count = have
                changed = true
            end
        end
    end
    for i = #d.wants, 1, -1 do
        if now - (d.wants[i].posted or 0) > WANT_DAYS * 86400 then
            table.remove(d.wants, i)
            changed = true
        end
    end
    -- "bags": automatic bag/expiry housekeeping, published on the slow schedule (see Sync).
    if changed then GH.BumpRev("bags") end
end

-- A guildie posted a wanted item I can craft: say so once.
function L.NotifyWants(profile)
    if not GH.Settings().notifyWanted then return end
    local db = GH.DB()
    local now = GH.Now()
    for _, w in ipairs(profile.wants or {}) do
        local id = C.ItemIdFromString(w.item)
        local tag = profile.owner .. "#" .. tostring(w.id)
        if id and not db.notified[tag] and L.IsFresh(w, true) then
            local prof = GH.Scan.MyProfessionFor(id)
            if prof then
                db.notified[tag] = now
                local link = C.KeyLink(id) or ("item " .. id)
                GH.msg("%s is looking for %s - you can make it (%s). %s",
                    GH.ColorName(profile.owner, profile.class), link, prof, GH.WantLink(id))
            end
        end
    end
    for tag, t in pairs(db.notified) do
        if now - t > 60 * 86400 then db.notified[tag] = nil end
    end
end

GH.On("BAG_UPDATE_DELAYED", function() GH.Debounce("listingCheck", 3, L.Check) end)
GH.Listen("LOGIN", function() C_Timer.After(15, L.Check) end)
