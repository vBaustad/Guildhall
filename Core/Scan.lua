-- Guildhall - scanning (modern client): profession ranks and known recipes.
-- Runs silently whenever a profession window opens; nobody has to enter anything by hand.
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

function GH.ProfName(id)
    if GH.Data and GH.Data.professions and GH.Data.professions[id] then return GH.Data.professions[id] end
    local cached = GH.DB().profNames and GH.DB().profNames[id]
    if cached then return cached end
    return "Profession " .. tostring(id)
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

local function ScanOpenProfession()
    if not ViewingOwnProfession() then return end
    local d = GH.MyData()
    if not d then return end
    local T = C_TradeSkillUI
    local info = T.GetBaseProfessionInfo()
    if not info or not info.professionID or info.professionID == 0 then return end
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
        if not recipes[spellID] then
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
        for k in pairs(p.recipes) do recipes[k] = true end
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

-- The current character's known recipe spell IDs across all professions.
function S.MyRecipes()
    local d = GH.MyData()
    local set = {}
    if not d then return set end
    for _, p in pairs(d.profs) do
        if p.recipes then for k in pairs(p.recipes) do set[k] = true end end
    end
    return set
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

GH.On("TRADE_SKILL_SHOW", function() GH.Debounce("scanTrade", 1, ScanOpenProfession) end)
GH.On("TRADE_SKILL_LIST_UPDATE", function() GH.Debounce("scanTrade", 1.5, ScanOpenProfession) end)
GH.On("NEW_RECIPE_LEARNED", function() GH.Debounce("scanTrade", 1.5, ScanOpenProfession) end)
GH.On("SKILL_LINES_CHANGED", function() GH.Debounce("scanRanks", 2, S.ScanRanks) end)
GH.On("TRADE_SKILL_CLOSE", function() GH.Debounce("scanRanks", 1, S.ScanRanks) end)
GH.Listen("LOGIN", function() C_Timer.After(3, S.ScanRanks) end)
