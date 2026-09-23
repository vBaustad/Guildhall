-- Guildhall - scanning (modern client): profession ranks and known recipes.
-- Runs silently at login and whenever a recipe is learned, without opening any window: every recipe in
-- the static data is checked with IsPlayerSpell. Opening a profession window adds anything the static
-- data doesn't know. Nobody has to enter anything by hand.
-- Professions are keyed by skill line ID (e.g. 164 Blacksmithing), recipes by recipe spell ID.
local ADDON, GH = ...
local C = GH.Codec
local S = {}
GH.Scan = S

-- Base profession skill lines (Forever / Classic numbering; retail uses the same parent IDs).
local PROFESSION_LINES = {
    [164] = true, [165] = true, [171] = true, [182] = true, [185] = true, [186] = true,
    [197] = true, [202] = true, [333] = true, [356] = true, [393] = true, [129] = true,
}
local GATHERING_LINES = { [182] = true, [186] = true, [393] = true, [356] = true }
S.GATHERING_LINES = GATHERING_LINES

local function SameSet(a, b)
    if not a or not b then return a == b end
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

local function CountSet(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end
S.CountSet = CountSet

-- The client can name a skill line even when we've never opened it: ask it once, then remember.
local function AskClientForName(id)
    local name = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
        and C_TradeSkillUI.GetTradeSkillDisplayName(id)
    if (not name or name == "") and C_SpellBook and C_SpellBook.GetSkillLineInfo then
        local info = C_SpellBook.GetSkillLineInfo(id)
        name = info and info.name
    end
    if name and name ~= "" then return name end
    return nil
end

-- A name for a skill line, or nil when even the client can't tell us. Callers decide what to show.
function GH.ProfNameOrNil(id)
    local db = GH.DB()
    local cached = db.profNames and db.profNames[id]
    if cached then return cached end
    -- The game knows the real, localised name; our shipped list is only there when it doesn't answer.
    local ok, name = pcall(AskClientForName, id)
    if ok and name then
        db.profNames = db.profNames or {}
        db.profNames[id] = name
        return name
    end
    return GH.Data and GH.Data.professions and GH.Data.professions[id] or nil
end

function GH.ProfName(id)
    return GH.ProfNameOrNil(id) or ("Profession " .. tostring(id))
end

local function RememberName(id, name)
    if not id or not name or name == "" then return end
    local db = GH.DB()
    db.profNames = db.profNames or {}
    db.profNames[id] = name
end

-- ---------------------------------------------------------------------------
-- Ranks for every profession (gathering included), without opening windows
-- ---------------------------------------------------------------------------
local function CollectRanks()
    local found = {}
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
        for i = 1, C_SkillInfo.GetNumSkillLines() do
            local s = C_SkillInfo.GetSkillLineInfo(i)
            if s and not s.isHeader then
                local id = s.skillID
                if not PROFESSION_LINES[id] and s.parentSkillLineID and PROFESSION_LINES[s.parentSkillLineID] then
                    id = s.parentSkillLineID
                end
                if PROFESSION_LINES[id] then
                    found[id] = { rank = s.rank, max = s.maxRank, name = s.name }
                end
            end
        end
        return found, true
    end
    return found, false
end

function S.ScanRanks()
    local d = GH.MyData()
    if not d then return end
    local found, complete = CollectRanks()
    local structural, rankOnly = false, false
    for id, info in pairs(found) do
        RememberName(id, info.name)
        local p = d.profs[id]
        if not p then
            p = {}
            d.profs[id] = p
            structural = true
        end
        if p.rank ~= info.rank or p.max ~= info.max then
            p.rank, p.max = info.rank, info.max
            rankOnly = true
        end
    end
    if complete then
        for id in pairs(d.profs) do
            if not found[id] then
                d.profs[id] = nil
                structural = true
            end
        end
    end
    if structural then
        GH.BumpRev("profs")
    elseif rankOnly then
        GH.BumpRev("rank")
    end
end

-- ---------------------------------------------------------------------------
-- Known recipes of the open profession window
-- ---------------------------------------------------------------------------
local function ViewingOwnProfession()
    local T = C_TradeSkillUI
    if not T or not T.IsTradeSkillReady or not T.IsTradeSkillReady() then return false end
    if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return false end
    if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return false end
    if T.IsTradeSkillGuildMember and T.IsTradeSkillGuildMember() then return false end
    if T.IsNPCCrafting and T.IsNPCCrafting() then return false end
    return true
end

-- The open profession window, read on TRADE_SKILL_SHOW and kept until TRADE_SKILL_CLOSE.
-- GetChildProfessionInfo is the call Blizzard's own profession UI makes first, but on Forever (no
-- expansion tiers) it can return professionID 0; Blizzard then falls back to GetBaseProfessionInfo,
-- which pops the "blocked" dialog for addons. Blizzard's window keeps the info it settled on in
-- ProfessionsFrame.professionInfo, so use that as the fallback.
local openInfo
local ScanOpenProfession   -- defined below

local function Valid(info) return type(info) == "table" and (info.professionID or 0) ~= 0 and info or nil end

local function ReadOpenInfo()
    local T = C_TradeSkillUI
    local info = Valid(T and T.GetChildProfessionInfo and T.GetChildProfessionInfo())
    if not info and ProfessionsFrame then info = Valid(ProfessionsFrame.professionInfo) end
    return info
end

-- The window may not have its info yet right at TRADE_SKILL_SHOW: try again for a moment.
local function CaptureOpenInfo(tries)
    openInfo = ReadOpenInfo()
    if openInfo then
        GH.Debounce("scanTrade", 1, ScanOpenProfession)
    elseif tries > 0 then
        C_Timer.After(0.3, function() CaptureOpenInfo(tries - 1) end)
    else
        GH.dbg("couldn't tell which profession window is open")
    end
end

function ScanOpenProfession()
    if not ViewingOwnProfession() then return end
    local d = GH.MyData()
    if not d then return end
    local T = C_TradeSkillUI
    local info = openInfo or ReadOpenInfo()
    if not info then return end
    openInfo = info
    local profID = info.professionID
    if not PROFESSION_LINES[profID] and info.parentProfessionID and PROFESSION_LINES[info.parentProfessionID] then
        profID = info.parentProfessionID
    end
    local displayName = (info.parentProfessionName and info.parentProfessionName ~= "") and info.parentProfessionName or info.professionName
    RememberName(profID, displayName)

    local recipes = {}
    local staticCount = 0
    -- 1) Every recipe the static data lists for this profession: ask the client if it's learned.
    if GH.Data and GH.Data.recipes then
        local prefix = tostring(profID) .. "|"
        for spellID, raw in pairs(GH.Data.recipes) do
            if raw:sub(1, #prefix) == prefix then
                staticCount = staticCount + 1
                local r = T.GetRecipeInfo(spellID)
                if r and r.learned then recipes[spellID] = true end
            end
        end
    end
    -- 2) Whatever the window lists (covers recipes the static data doesn't know about).
    local listed = (T.GetFilteredRecipeIDs and T.GetFilteredRecipeIDs()) or (T.GetAllRecipeIDs and T.GetAllRecipeIDs()) or {}
    local db = GH.DB()
    for _, spellID in ipairs(listed) do
        local known = C.Recipe(spellID)
        -- The window can list recipes belonging to another profession; the static data has the say,
        -- otherwise one character's Cooking ends up "crafting" a Blacksmithing item.
        if not recipes[spellID] and not (known and known.prof and known.prof ~= profID) then
            local r = T.GetRecipeInfo(spellID)
            if r and r.learned and not r.isDummyRecipe and not r.isGatheringRecipe and not r.isSalvageRecipe then
                recipes[spellID] = true
                if not C.Recipe(spellID) and not db.outputs[spellID] and T.GetRecipeSchematic then
                    local schematic = T.GetRecipeSchematic(spellID, false)
                    if schematic and schematic.outputItemID and schematic.outputItemID > 0 then
                        db.outputs[spellID] = schematic.outputItemID
                    end
                end
            end
        end
    end
    -- Without static data for this profession the window's filters could hide recipes: merge instead of replace.
    local partial = staticCount == 0

    local p = d.profs[profID]
    local isNew = not p
    if not p then
        p = {}
        d.profs[profID] = p
    end
    if partial and p.recipes then
        for k in pairs(p.recipes) do
            local known = C.Recipe(k)
            if not (known and known.prof and known.prof ~= profID) then recipes[k] = true end
        end
    end
    local changed = isNew or not SameSet(p.recipes, recipes)
    local rankChanged = p.rank ~= info.skillLevel or p.max ~= info.maxSkillLevel
    p.recipes = recipes
    p.rank, p.max = info.skillLevel, info.maxSkillLevel
    p.scanned = GH.Now()
    p.partial = partial or nil
    GH.dbg("scanned %s: %d recipes%s", GH.ProfName(profID), CountSet(recipes), partial and " (merged)" or "")
    if changed then
        GH.BumpRev("recipes")
    elseif rankChanged then
        GH.BumpRev("rank")
    else
        GH.Fire("MY_SCANNED")
    end
end

-- ---------------------------------------------------------------------------
-- Known recipes without opening a window
-- ---------------------------------------------------------------------------
-- IsPlayerSpell / C_SpellBook.IsSpellKnown answer for profession recipes (verified in the Forever beta);
-- the old IsSpellKnown does not.
local function Knows(spellID)
    if IsPlayerSpell then return IsPlayerSpell(spellID) end
    return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) or false
end

local byProfession   -- [skillLineID] = { recipe spell IDs from the static data }
local function StaticRecipes(profID)
    if not byProfession then
        byProfession = {}
        for spellID, raw in pairs(GH.Data and GH.Data.recipes or {}) do
            local prof = tonumber(raw:match("^(%d+)|"))
            if prof then
                local list = byProfession[prof]
                if not list then list = {}; byProfession[prof] = list end
                list[#list + 1] = spellID
            end
        end
    end
    return byProfession[profID]
end

-- Check one profession; merge with what window scans found (recipes the static data doesn't list).
local function ScanKnownProfession(d, profID)
    local list = StaticRecipes(profID)
    local p = d.profs[profID]
    if not list or not p then return false end
    local recipes = {}
    local static = {}
    for _, spellID in ipairs(list) do
        static[spellID] = true
        if Knows(spellID) then recipes[spellID] = true end
    end
    for spellID in pairs(p.recipes or {}) do
        local known = C.Recipe(spellID)
        if not static[spellID] and not (known and known.prof and known.prof ~= profID) then
            recipes[spellID] = true
        end
    end
    local changed = not SameSet(p.recipes, recipes)
    p.recipes = recipes
    p.scanned = GH.Now()
    p.partial = nil
    return changed
end

-- Recipes saved under the wrong profession by an older scan: move them where they belong, or drop
-- them if this character doesn't have that profession. Returns true when something changed.
function S.Tidy()
    local d = GH.MyData()
    if not d then return false end
    local changed = false
    for profID, p in pairs(d.profs) do
        for spellID in pairs(p.recipes or {}) do
            local r = C.Recipe(spellID)
            if r and r.prof and r.prof ~= profID then
                p.recipes[spellID] = nil
                local home = d.profs[r.prof]
                if home then
                    home.recipes = home.recipes or {}
                    home.recipes[spellID] = true
                end
                changed = true
            end
        end
    end
    if changed then GH.dbg("tidied recipes filed under the wrong profession") end
    return changed
end

-- All crafting professions, one per frame so a long list never causes a hitch.
local scanning
function S.ScanKnown()
    if scanning then return end
    local d = GH.MyData()
    if not d then return end
    local queue = {}
    S.Tidy()
    for id in pairs(d.profs) do
        if not GATHERING_LINES[id] then queue[#queue + 1] = id end
    end
    scanning = true
    local changed = false
    local function step()
        local id = table.remove(queue)
        if id then
            if ScanKnownProfession(d, id) then changed = true end
            C_Timer.After(0, step)
            return
        end
        scanning = nil
        GH.dbg("recipe check done%s", changed and " (changed)" or "")
        -- "autoscan" publishes on Sync's slow schedule, so logging in doesn't flood the guild channel.
        if changed then GH.BumpRev("autoscan") else GH.Fire("MY_SCANNED") end
    end
    step()
end

-- Is there static recipe data for this profession? Without it only a window scan finds recipes.
function S.HasStaticRecipes(profID)
    return StaticRecipes(profID) ~= nil
end

-- Has this character shared any recipes at all?
function GH.HasSharedRecipes()
    local d = GH.MyData()
    for _, p in pairs(d and d.profs or {}) do
        if p.recipes and next(p.recipes) then return true end
    end
    return false
end

-- Which of my professions makes this item/enchant key: (profession name, rank) or nil.
function S.MyProfessionFor(key)
    local d = GH.MyData()
    if not d then return nil end
    for id, p in pairs(d.profs) do
        if p.recipes then
            for spellID in pairs(p.recipes) do
                if C.RecipeOutputKey(spellID) == key then return GH.ProfName(id), p.rank end
            end
        end
    end
end

GH.On("TRADE_SKILL_SHOW", function() CaptureOpenInfo(10) end)
GH.On("TRADE_SKILL_LIST_UPDATE", function() GH.Debounce("scanTrade", 1.5, ScanOpenProfession) end)
GH.On("NEW_RECIPE_LEARNED", function()
    GH.Debounce("scanTrade", 1.5, ScanOpenProfession)
    GH.Debounce("scanKnown", 2, S.ScanKnown)
end)
GH.On("SKILL_LINES_CHANGED", function()
    GH.Debounce("scanRanks", 2, S.ScanRanks)
    GH.Debounce("scanKnown", 3, S.ScanKnown)   -- after the ranks, so a new profession is in d.profs
end)
if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("LEARNED_SPELL_IN_SKILL_LINE") then
    GH.On("LEARNED_SPELL_IN_SKILL_LINE", function() GH.Debounce("scanKnown", 2, S.ScanKnown) end)
end
GH.On("TRADE_SKILL_CLOSE", function()
    openInfo = nil
    GH.Debounce("scanRanks", 1, S.ScanRanks)
end)
GH.Listen("LOGIN", function()
    C_Timer.After(3, function()
        S.ScanRanks()
        S.ScanKnown()
    end)
end)
