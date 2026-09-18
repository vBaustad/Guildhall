-- Guildhall - search index over every stored profile, item-name loading, and tooltip lines.
local ADDON, GH = ...
local C = GH.Codec
local I = {}
GH.Index = I

local index = {}      -- [key] = { key, crafters = {...}, listings = {...}, wants = {...} }
local dirty = true

GH.Listen("DATA_CHANGED", function() dirty = true end)
GH.Listen("GUILD_CHANGED", function() dirty = true end)
GH.Listen("ROSTER", function() dirty = true end)

local function Entry(key)
    local e = index[key]
    if not e then
        e = { key = key, crafters = {}, listings = {}, wants = {} }
        index[key] = e
    end
    return e
end

local function AddProfile(p, listings, wants)
    for skillLine, prof in pairs(p.profs or {}) do
        if prof.recipes then
            local profName = GH.ProfName(skillLine)
            for spellID in pairs(prof.recipes) do
                local list = Entry(C.RecipeOutputKey(spellID)).crafters
                list[#list + 1] = { owner = p.owner, class = p.class, prof = profName, profID = skillLine, rank = prof.rank, spell = spellID }
            end
        end
    end
    for _, l in ipairs(listings or {}) do
        local id = C.ItemIdFromString(l.item)
        if id and GH.Listings.IsFresh(l) then
            local list = Entry(id).listings
            list[#list + 1] = { owner = p.owner, class = p.class, l = l }
        end
    end
    for _, w in ipairs(wants or {}) do
        local id = C.ItemIdFromString(w.item)
        if id and GH.Listings.IsFresh(w, true) then
            local list = Entry(id).wants
            list[#list + 1] = { owner = p.owner, class = p.class, w = w }
        end
    end
end

function I.Build()
    wipe(index)
    dirty = false
    local g = GH.GuildDB()
    if not g then return end
    local me = GH.Me()
    local added = {}
    local mine = GH.MyData()
    if mine then
        AddProfile(mine, GH.Listings.Publishable(), GH.Listings.PublishableWants())
        added[me] = true
    end
    -- My alts in this guild: my own saved copy is the freshest there is.
    for owner, alt in pairs(GH.DB().chars) do
        if not added[owner] and GH.IsGuildie(owner) then
            local stored = g.members[owner]
            if not stored or (alt.rev or 0) >= (stored.rev or 0) then
                AddProfile(alt, alt.listings, alt.wants)
                added[owner] = true
            end
        end
    end
    for owner, p in pairs(g.members) do
        if not added[owner] and (GH.IsGuildie(owner) or not GH.rosterComplete) then
            AddProfile(p, p.listings, p.wants)
        end
    end
    GH.Fire("INDEX_BUILT")
end

function I.Get(key)
    if dirty then I.Build() end
    return index[key]
end

-- ---------------------------------------------------------------------------
-- Item names arrive from the server a few at a time.
-- ---------------------------------------------------------------------------
local queue, queued = {}, {}
local loader

local function LoadTick()
    for _ = 1, 25 do
        local key = table.remove(queue)
        if not key then
            loader:Cancel()
            loader = nil
            return
        end
        GH.API.RequestItem(key)
    end
end

function I.Name(key)
    local name = C.KeyName(key)
    if not name and type(key) == "number" and not queued[key] then
        queued[key] = true
        queue[#queue + 1] = key
        if not loader then loader = C_Timer.NewTicker(0.25, LoadTick) end
    end
    return name
end

GH.On("GET_ITEM_INFO_RECEIVED", function()
    GH.Coalesce("namesLoaded", 0.5, function() GH.Fire("NAMES_LOADED") end)
end)

-- ---------------------------------------------------------------------------
-- Search
-- ---------------------------------------------------------------------------
-- opts: source = "all" | "crafts" | "listings" | "wants"; prof = profession name or nil; online = bool
function I.Search(query, opts)
    if dirty then I.Build() end
    opts = opts or {}
    local q = strtrim(query or ""):lower()
    local source = opts.source or "all"
    local results, loading = {}, 0

    local function keep(owner) return not opts.online or GH.IsOnline(owner) end

    for key, e in pairs(index) do
        local name = I.Name(key)
        if not name then
            loading = loading + 1
        elseif q == "" or name:lower():find(q, 1, true) then
            local crafters, listings, wants = {}, {}, {}
            if source == "all" or source == "crafts" then
                for _, c in ipairs(e.crafters) do
                    if keep(c.owner) and (not opts.prof or c.prof == opts.prof) then crafters[#crafters + 1] = c end
                end
            end
            if not opts.prof and (source == "all" or source == "listings") then
                for _, l in ipairs(e.listings) do
                    if keep(l.owner) then listings[#listings + 1] = l end
                end
            end
            if not opts.prof and (source == "all" or source == "wants") then
                for _, w in ipairs(e.wants) do
                    if keep(w.owner) then wants[#wants + 1] = w end
                end
            end
            if #crafters + #listings + #wants > 0 then
                results[#results + 1] = {
                    key = key, name = name, crafters = crafters, listings = listings, wants = wants,
                }
            end
        end
    end
    table.sort(results, function(a, b) return a.name < b.name end)
    return results, loading
end

-- Online people first, then by name. Works on crafter / listing / want entries.
function I.SortPeople(list)
    table.sort(list, function(a, b)
        local oa, ob = GH.IsOnline(a.owner), GH.IsOnline(b.owner)
        if oa ~= ob then return oa end
        if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) > (b.rank or 0) end
        return a.owner < b.owner
    end)
    return list
end

-- ---------------------------------------------------------------------------
-- Tooltips
-- ---------------------------------------------------------------------------
local function NameList(entries, max)
    local copy = {}
    for i, e in ipairs(entries) do copy[i] = e end
    I.SortPeople(copy)
    local parts = {}
    for i = 1, math.min(#copy, max) do
        local who = copy[i].owner
        local color = GH.IsOnline(who) and GH.ClassColor(copy[i].class) or GH.GRAY
        parts[i] = "|c" .. color .. GH.Short(who) .. "|r"
    end
    local text = table.concat(parts, ", ")
    if #copy > max then text = text .. (" +%d"):format(#copy - max) end
    return text
end

-- ---------------------------------------------------------------------------
-- Recipes by what they make (static data + anything guildies know)
-- ---------------------------------------------------------------------------
local byOutput

-- All known recipe spell IDs that produce this item/enchant key.
function I.RecipesFor(key)
    if not byOutput then
        byOutput = {}
        if GH.Data and GH.Data.recipes then
            for spellID in pairs(GH.Data.recipes) do
                local k = C.RecipeOutputKey(spellID)
                byOutput[k] = byOutput[k] or {}
                table.insert(byOutput[k], spellID)
            end
        end
    end
    local list = byOutput[key]
    if list then return list end
    local e = I.Get(key)
    if e and e.crafters[1] and e.crafters[1].spell then return { e.crafters[1].spell } end
    return nil
end

-- The recipe details (reagents, skill, station) for an item/enchant key, from the static data.
function I.RecipeInfoFor(key)
    for _, spellID in ipairs(I.RecipesFor(key) or {}) do
        local r = C.Recipe(spellID)
        if r then return r, spellID end
    end
end

-- Reagents for a key as {{itemID, count}, ...}, or nil.
function I.ReagentsFor(key)
    local r = I.RecipeInfoFor(key)
    if r and #r.reagents > 0 then return r.reagents end
    return C.DecodeReagents(GH.DB().reagents[key])
end

local function AddTooltipLines(tt, itemID)
    if tt.guildhallDone then return end
    if not GH.Settings().tooltip or not IsInGuild() then return end
    local id = itemID
    if not id and tt.GetItem then
        local _, link = tt:GetItem()
        id = link and tonumber(link:match("item:(%d+)"))
    end
    if not id then return end
    local e = I.Get(id)
    if not e then return end
    tt.guildhallDone = true
    local shown = false
    if #e.crafters > 0 then
        tt:AddLine("|cffe6b34dGuild crafters:|r " .. NameList(e.crafters, 4), 1, 1, 1, true)
        shown = true
    end
    if #e.listings > 0 then
        tt:AddLine("|cffe6b34dGuild has it:|r " .. NameList(e.listings, 3), 1, 1, 1, true)
        shown = true
    end
    if #e.wants > 0 then
        tt:AddLine("|cffe6b34dWanted by:|r " .. NameList(e.wants, 3), 1, 1, 1, true)
        shown = true
    end
    if shown then tt:Show() end
end

local isSecret = issecretvalue or function() return false end

-- One post-call for every item tooltip in the game.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local id = data and data.id
    if not id or isSecret(id) then return end
    tt.guildhallDone = nil
    AddTooltipLines(tt, id)
end)
