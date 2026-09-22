-- Guildhall - codec: recipe keys, item links, text sanitising and the wire format for profiles.
local ADDON, GH = ...
local C = {}
GH.Codec = C

-- ---------------------------------------------------------------------------
-- Item and spell API shortcuts
-- ---------------------------------------------------------------------------
local API = {}
GH.API = API
API.GetItemInfo = C_Item.GetItemInfo
API.GetItemInfoInstant = C_Item.GetItemInfoInstant
API.GetItemIcon = C_Item.GetItemIconByID
API.GetItemCount = C_Item.GetItemCount
API.RequestItem = C_Item.RequestLoadItemDataByID
API.SpellName = C_Spell.GetSpellName
API.SpellTexture = C_Spell.GetSpellTexture

-- ---------------------------------------------------------------------------
-- Can it be handed over at all?
-- ---------------------------------------------------------------------------
-- Quest items and items that bind when you pick them up can never reach a guildie.
-- Bind-on-equip gear that is already worn (soulbound) can't either, but only the copy in your bags
-- knows that, so it is checked separately.
local QUEST_CLASS = 12

-- "quest" / "bop" / nil, from the item type alone (no bag instance needed).
function C.UntradableType(id)
    if not id then return nil end
    local _, _, _, _, _, classID = API.GetItemInfoInstant(id)
    if classID == QUEST_CLASS then return "quest" end
    local bind = select(14, API.GetItemInfo(id))
    if bind == 1 then return "bop" end
    return nil
end

-- The first copy of the item in your bags, as bag, slot, info.
function C.FindInBags(id)
    if not (C_Container and C_Container.GetContainerNumSlots) then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == id then return bag, slot, info end
        end
    end
end

-- Is the copy in your bags soulbound? Uses the item's own tooltip, which is the only place a
-- bind-on-equip item that has been worn says so.
function C.IsBoundInBags(id)
    local bag, slot, info = C.FindInBags(id)
    if not bag then return false end
    if info and info.isBound ~= nil then return info.isBound and true or false end
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
    local data = C_TooltipInfo.GetBagItem(bag, slot)
    for _, line in ipairs(data and data.lines or {}) do
        local text = line.leftText
        if type(text) == "string" and (text == ITEM_SOULBOUND or text == ITEM_BIND_ON_PICKUP) then return true end
    end
    return false
end

C.MAX_PROFS = 16
C.MAX_RECIPES = 1200
C.MAX_LISTINGS = 40
C.MAX_WANTS = 25
C.NOTE_LEN = 80

-- ---------------------------------------------------------------------------
-- Numbers
-- ---------------------------------------------------------------------------
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

function C.To36(n)
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then return "0" end
    local out = {}
    while n > 0 do
        local d = n % 36
        out[#out + 1] = DIGITS:sub(d + 1, d + 1)
        n = (n - d) / 36
    end
    return string.reverse(table.concat(out))
end

function C.From36(s)
    return s and tonumber(s, 36) or nil
end

-- ---------------------------------------------------------------------------
-- Recipe keys: a crafted item is its itemID (number); a recipe with no item
-- (most enchants) is "s" .. spellID (string).
-- ---------------------------------------------------------------------------
function C.KeyFromLink(link)
    if type(link) ~= "string" then return nil end
    local id = link:match("|Hitem:(%d+)") or link:match("^item:(%d+)")
    if id then return tonumber(id) end
    id = link:match("|Henchant:(%d+)") or link:match("|Hspell:(%d+)")
    if id then return "s" .. id end
    return nil
end

function C.KeyToWire(key)
    if type(key) == "number" then return C.To36(key) end
    local sid = type(key) == "string" and key:match("^s(%d+)$")
    if sid then return "_" .. C.To36(tonumber(sid)) end
    return nil
end

function C.WireToKey(w)
    if not w or w == "" then return nil end
    if w:sub(1, 1) == "_" then
        local n = C.From36(w:sub(2))
        return n and ("s" .. n) or nil
    end
    return C.From36(w)
end

function C.SpellId(key) return tonumber(key:match("^s(%d+)$")) end

function C.KeyName(key)
    if type(key) == "number" then
        return (API.GetItemInfo(key))
    elseif type(key) == "string" then
        local sid = C.SpellId(key)
        return sid and API.SpellName(sid) or nil
    end
end

function C.KeyIcon(key)
    if type(key) == "number" then
        local icon = API.GetItemIcon and API.GetItemIcon(key)
        if not icon and API.GetItemInfoInstant then icon = select(5, API.GetItemInfoInstant(key)) end
        return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    local sid = C.SpellId(key)
    return (sid and API.SpellTexture(sid)) or "Interface\\Icons\\Spell_Holy_GreaterHeal"
end

function C.KeyQuality(key)
    if type(key) ~= "number" then return 1 end
    local q = select(3, API.GetItemInfo(key))
    return q or 1
end

-- ---------------------------------------------------------------------------
-- Static recipe data (Data/Recipes.lua, generated from the client's game data).
-- Profiles share recipe SPELL IDs; this turns them into what players search for.
-- ---------------------------------------------------------------------------
local parsed = {}

-- Returns { prof, learn, yellow, grey, item, qty, reagents = {{item, count}...}, station, recipeItems, camp, enchant, trainer }
-- or nil when the recipe isn't in the static data.
function C.Recipe(spellID)
    local cached = parsed[spellID]
    if cached ~= nil then return cached or nil end
    local raw = GH.Data and GH.Data.recipes and GH.Data.recipes[spellID]
    if not raw then
        parsed[spellID] = false
        return nil
    end
    local f = { strsplit("|", raw) }
    local r = {
        prof = tonumber(f[1]), learn = tonumber(f[2]), yellow = tonumber(f[3]), grey = tonumber(f[4]),
        item = tonumber(f[5]), qty = tonumber(f[6]) or 1, reagents = {}, station = tonumber(f[8]), recipeItems = {},
    }
    for id, n in (f[7] or ""):gmatch("(%d+)%*(%d+)") do r.reagents[#r.reagents + 1] = { tonumber(id), tonumber(n) } end
    for id in (f[9] or ""):gmatch("%d+") do r.recipeItems[#r.recipeItems + 1] = tonumber(id) end
    local flags = f[10] or ""
    r.camp, r.enchant, r.trainer = flags:find("c", 1, true) ~= nil, flags:find("e", 1, true) ~= nil, flags:find("t", 1, true) ~= nil
    parsed[spellID] = r
    return r
end

-- What a recipe produces, as a search key: the crafted item ID, or "s"..spellID for enchants
-- and recipes the static data doesn't know (then a locally learned output is used if we have one).
function C.RecipeOutputKey(spellID)
    local r = C.Recipe(spellID)
    if r and r.item and r.item > 0 and not r.enchant then return r.item end
    local learned = GH.DB().outputs[spellID]
    if learned then return learned end
    return "s" .. spellID
end

function C.StationName(id)
    return id and GH.Data and GH.Data.stations and GH.Data.stations[id] or nil
end

function C.KeyColor(key)
    local q = C.KeyQuality(key)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c and c.hex then return c.hex end
    return "|cffffffff"
end

-- A chat link for a key, or nil if the item isn't cached yet.
function C.KeyLink(key)
    if type(key) == "number" then
        return select(2, API.GetItemInfo(key))
    end
    local sid = C.SpellId(key)
    local name = sid and API.SpellName(sid)
    if not name then return nil end
    return ("|cffffd000|Henchant:%d|h[%s]|h|r"):format(sid, name)
end

-- Point a tooltip at a key (item or enchant spell).
function C.SetTooltip(tt, key, itemString)
    if itemString then
        tt:SetHyperlink(itemString)
    elseif type(key) == "number" then
        tt:SetHyperlink("item:" .. key)
    else
        local sid = C.SpellId(key)
        if sid then tt:SetHyperlink("enchant:" .. sid) end
    end
end

-- "item:1234:0:..." out of a full item link (keeps random-suffix fields).
function C.ItemStringFromLink(link)
    if type(link) ~= "string" then return nil end
    local s = link:match("|H(item:[%-%d:]+)|h") or link:match("^(item:[%-%d:]+)$")
    if not s or #s > 96 then return nil end
    return s
end

function C.ItemIdFromString(s)
    return s and tonumber(s:match("^item:(%d+)")) or nil
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------
-- Strip anything that could break the wire format or inject UI escape codes.
function C.Clean(s, maxLen)
    s = tostring(s or "")
    s = s:gsub("[%c]", " "):gsub("|", "/")
    s = strtrim(s)
    maxLen = maxLen or C.NOTE_LEN
    if #s > maxLen then
        s = s:sub(1, maxLen):gsub("[\192-\255][\128-\191]*$", "")
    end
    return s
end

-- ---------------------------------------------------------------------------
-- Profile wire format (one record per line, tab separated):
--   P  owner  rev  class  level
--   F  skillLineID  rank  max  scanned36  recipes (comma separated base36 recipe spell IDs, or "-" for none)
--   L  id  itemString  count  posted36  note
--   W  id  itemString  posted36  note  qty  copperEach   (qty/price appended later; may be missing)
-- ---------------------------------------------------------------------------
local function join(...) return table.concat({ ... }, "\t") end

function C.EncodeProfile(p, listings, wants)
    local lines = {}
    lines[#lines + 1] = join("P", p.owner, tostring(p.rev or 0), p.class or "", tostring(p.level or 0))
    local nprof = 0
    for skillLine, prof in pairs(p.profs or {}) do
        nprof = nprof + 1
        if nprof > C.MAX_PROFS then break end
        local keys = "-"
        if prof.recipes then
            local parts, n = {}, 0
            for spellID in pairs(prof.recipes) do
                if type(spellID) == "number" then
                    n = n + 1
                    if n > C.MAX_RECIPES then break end
                    parts[n] = C.To36(spellID)
                end
            end
            keys = table.concat(parts, ",")
        end
        lines[#lines + 1] = join("F", tostring(skillLine), tostring(prof.rank or 0), tostring(prof.max or 0),
            C.To36(prof.scanned or 0), keys)
    end
    for i, l in ipairs(listings or {}) do
        if i > C.MAX_LISTINGS then break end
        lines[#lines + 1] = join("L", tostring(l.id), l.item, tostring(l.count or 1), C.To36(l.posted or 0), C.Clean(l.note))
    end
    for i, w in ipairs(wants or {}) do
        if i > C.MAX_WANTS then break end
        lines[#lines + 1] = join("W", tostring(w.id), w.item, C.To36(w.posted or 0), C.Clean(w.note),
            tostring(w.qty or 1), tostring(w.price or 0))
    end
    return table.concat(lines, "\n")
end

-- Returns a profile table, or nil if the payload is malformed.
-- Returns a profile table, or nil if the payload is malformed. Strict on purpose: a multi-part
-- message with a refused middle part arrives glued together and corrupt, and a half-read profile
-- must never replace a good stored one. One bad line rejects the whole profile.
local function Int(s) return s and s:match("^%d+$") and tonumber(s) or nil end
local function B36(s) return s and s:match("^[%w]+$") and tonumber(s, 36) or nil end

function C.DecodeProfile(text)
    if type(text) ~= "string" or text == "" then return nil end
    local p = { profs = {}, listings = {}, wants = {} }
    local nprof, header = 0, 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            local f = { strsplit("\t", line) }
            local kind = f[1]
            if kind == "P" then
                header = header + 1
                p.owner = f[2]
                p.rev = Int(f[3])
                p.class = (f[4] ~= "" and f[4]) or nil
                p.level = Int(f[5])
                if not (p.owner and p.owner:match("^[^%-%s][^%-]*%-.+$") and p.rev and #f == 5) then return nil end
            elseif kind == "F" then
                local skillLine, rank, max = Int(f[2]), Int(f[3]), Int(f[4])
                if not (skillLine and rank and max and B36(f[5]) and f[6] and #f == 6) then return nil end
                nprof = nprof + 1
                if nprof > C.MAX_PROFS then return nil end
                local prof = { rank = rank, max = max, scanned = B36(f[5]) }
                if f[6] ~= "-" then
                    prof.recipes = {}
                    local n = 0
                    for w in f[6]:gmatch("[^,]*") do
                        if w ~= "" then
                            local spellID = B36(w)
                            if not spellID then return nil end
                            n = n + 1
                            if n > C.MAX_RECIPES then return nil end
                            prof.recipes[spellID] = true
                        end
                    end
                end
                p.profs[skillLine] = prof
            elseif kind == "L" then
                local item = C.ItemStringFromLink(f[3])
                if not (Int(f[2]) and item and Int(f[4]) and B36(f[5]) and #f == 6) then return nil end
                if #p.listings >= C.MAX_LISTINGS then return nil end
                p.listings[#p.listings + 1] = {
                    id = Int(f[2]), item = item, count = math.max(1, Int(f[4])),
                    posted = B36(f[5]), note = C.Clean(f[6]),
                }
            elseif kind == "W" then
                -- qty and price were added later: 5 fields from older clients, 7 from newer ones.
                local item = C.ItemStringFromLink(f[3])
                if not (Int(f[2]) and item and B36(f[4]) and (#f == 5 or #f == 7)) then return nil end
                if #f == 7 and not (Int(f[6]) and Int(f[7])) then return nil end
                if #p.wants >= C.MAX_WANTS then return nil end
                p.wants[#p.wants + 1] = {
                    id = Int(f[2]), item = item, posted = B36(f[4]), note = C.Clean(f[5]),
                    qty = math.max(1, math.min(Int(f[6]) or 1, 9999)),
                    price = math.max(0, math.min(Int(f[7]) or 0, 99999999)),
                }
            else
                return nil   -- unknown record: most likely two messages glued together
            end
        end
    end
    if header ~= 1 then return nil end
    return p
end

-- Reagents ("k36*count,k36*count") - crafters send these back when a request arrives.
function C.EncodeReagents(list)
    if not list then return "" end
    local parts = {}
    for _, r in ipairs(list) do
        local w = C.KeyToWire(r[1])
        if w then parts[#parts + 1] = w .. "*" .. tostring(r[2] or 1) end
    end
    return table.concat(parts, ",")
end

function C.DecodeReagents(s)
    if not s or s == "" then return nil end
    local list = {}
    for w, n in s:gmatch("([^,*]+)%*(%d+)") do
        local key = C.WireToKey(w)
        if key and #list < 12 then list[#list + 1] = { key, tonumber(n) } end
    end
    return #list > 0 and list or nil
end
