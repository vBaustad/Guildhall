-- Guildhall - Browse tab: search everything the guild can make, has, or wants.
local ADDON, GH = ...
local U, C, I = GH.UI, GH.Codec, GH.Index

local state = { query = "", source = "all", prof = nil, online = false, selected = nil }
local view      -- the tab frame
local LIST_ROWS, LIST_ROW_H = 15, 22
-- Tall enough that the note below the name clears the buttons. At 36 the buttons sat in the
-- middle of the row, which is exactly where the second line of text is, so the note had to be
-- truncated at their left edge - "offline - requests wait until they log in (fro...". The buttons
-- now take the top line beside the name and the note has the whole width underneath.
local DETAIL_ROW_H = 44
-- The skill-or-quantity column in a detail row, measured from the buttons so it lines up down the
-- list whatever the names beside it are doing.
local META_COL_W = 96
local FILTER_LABELS = { all = "Everything", crafts = "Crafts", listings = "Guildies have", wants = "Wanted" }
local CARD_W, CARD_H, GRID_GAP, CHIP_W = 340, 64, 10, 120
-- Cooking, First Aid and Fishing sit apart from the crafting professions.
local SECONDARY = { Cooking = true, ["First Aid"] = true, Fishing = true }

local function Prefs()
    local st = GH.Settings()
    st.browse = st.browse or {}
    return st.browse
end

-- ---------------------------------------------------------------------------
-- Request popup
-- ---------------------------------------------------------------------------
local popup
local function BuildPopup()
    if popup then return end
    popup = U.Window("GuildhallRequestPopup", UIParent, 340, 216)
    popup:SetPoint("CENTER", 0, 80)
    popup:SetFrameStrata("DIALOG")
    -- Esc closes this popup first, then the window behind it: one per press.
    local LIB = LibStub and LibStub("LibForever-1.0", true)
    if LIB and LIB.RegisterPopup then LIB.RegisterPopup(popup) end
    popup.title = popup.NineSlice.Text

    popup.icon = U.KeyIcon(popup, 28)
    popup.icon:SetPoint("TOPLEFT", 20, -40)
    popup.item = U.Text(popup, "GameFontHighlight")
    popup.item:SetPoint("LEFT", popup.icon, "RIGHT", 8, 0)
    popup.item:SetPoint("RIGHT", -18, 0)

    local ql = U.Text(popup, "GameFontNormalSmall")
    ql:SetPoint("TOPLEFT", 20, -84)
    ql:SetText("Quantity")
    popup.qty = U.EditBox(popup, 40, nil, true)
    popup.qty:SetPoint("LEFT", ql, "RIGHT", 10, 0)

    popup.note = U.EditBox(popup, 296, "Note (optional) - e.g. I have the mats")
    popup.note:SetPoint("TOPLEFT", 24, -110)

    -- Some things can't be handed over even when someone can craft them.
    popup.warn = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    popup.warn:SetPoint("TOPLEFT", 20, -138)
    popup.warn:SetPoint("RIGHT", -18, 0)
    popup.warn:SetJustifyH("LEFT")
    popup.warn:SetTextColor(1, 0.4, 0.4)

    popup.send = U.Button(popup, "Send request", 110, 22)
    popup.send:SetPoint("BOTTOMRIGHT", -16, 16)
    local cancel = U.Button(popup, "Cancel", 80, 22)
    cancel:SetPoint("RIGHT", popup.send, "LEFT", -6, 0)
    cancel:SetScript("OnClick", function() popup:Hide() end)

    popup.send:SetScript("OnClick", function()
        local ok, err = GH.Orders.Request(popup.crafter, popup.key, popup.qty:GetNumber(), popup.note:GetText())
        if ok then
            -- The request is stored either way: it is (re)sent whenever the crafter is online.
            if GH.IsOnline(popup.crafter) then
                GH.msg("asked %s to craft it - see |cffffd100/gh requests|r.", GH.Short(popup.crafter))
            else
                GH.msg("%s is offline - your request will be delivered when they log in.", GH.Short(popup.crafter))
            end
            popup:Hide()
        else
            GH.msg(err or "couldn't send that request.")
        end
    end)
    popup:Hide()
end

function GH.OpenRequest(crafter, key)
    BuildPopup()
    popup.crafter, popup.key = crafter, key
    popup.title:SetText("Ask " .. GH.Short(crafter) .. " to craft")
    popup.icon:SetKey(key)
    popup.item:SetText(C.KeyColor(key) .. (I.Name(key) or "...") .. "|r")
    popup.qty:SetNumber(1)
    popup.note:SetText("")
    local blocked = type(key) == "number" and C.UntradableType(key)
    if blocked == "bop" then
        popup.warn:SetText("This item is soulbound when crafted, so " .. GH.Short(crafter)
            .. " can't hand it over. Ask them to craft it from your own materials instead.")
    elseif blocked == "quest" then
        popup.warn:SetText("Quest items can't be traded.")
    else
        popup.warn:SetText("")
    end
    popup:Show()
end

-- ---------------------------------------------------------------------------
-- Detail pane
-- ---------------------------------------------------------------------------
local function MakeDetailRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(DETAIL_ROW_H)
    r:EnableMouse(true)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, 0.03)
    r.name = U.Text(r, "GameFontHighlight")
    r.name:SetPoint("TOPLEFT", 6, -4)
    r.meta = U.Text(r, "GameFontHighlightSmall")
    r.note = U.Text(r, "GameFontDisableSmall")
    r.note:SetPoint("TOPLEFT", 6, -25)
    r.b1 = U.Button(r, "Whisper", 62, 18)
    r.b1:SetPoint("TOPRIGHT", -4, -4)
    r.b2 = U.Button(r, "Request", 62, 18)
    r.b2:SetPoint("TOPRIGHT", r.b1, "TOPLEFT", -3, 0)
    -- The skill and the quantity line up because THEY have a fixed column against the buttons,
    -- not because the name does. A fixed name column aligned them too, but it spent its full
    -- width on "Lorr Den" and left the skill with nothing - which is how "skill 156" became "...".
    -- The name takes whatever is left over and is only cut when it is genuinely too long; the
    -- row's tooltip carries it in full either way.
    r.meta:SetPoint("TOPRIGHT", r.b2, "TOPLEFT", -8, -2)
    r.meta:SetWidth(META_COL_W)
    r.name:SetPoint("RIGHT", r.meta, "LEFT", -8, 0)
    r.note:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    -- The skill line needs the same right edge as the note below it. Without one it has only a
    -- LEFT anchor, so it grows rightwards for ever and prints straight through the buttons -
    -- "Enchanting 181" under "Request". Anchoring the right edge only bounds the width; the
    -- vertical still comes from the LEFT point, so it stays on the name's line.
    r.meta:SetPoint("RIGHT", r.b2, "LEFT", -6, 0)
    r:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i, line in ipairs(self.tip) do
            if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then U.PersonMenu(self, self.owner) end
    end)
    return r
end

local function PersonLabel(owner, class)
    if owner == GH.Me() then
        return "|c" .. GH.ClassColor(class) .. GH.Short(owner) .. "|r |cff7fc8ff(you)|r"
    end
    if GH.IsOnline(owner) then return GH.ColorName(owner, class) end
    return "|cff8a8a8a" .. GH.Short(owner) .. "|r"
end

-- The skill a recipe needs, or nil when the data does not say. A zero is the generated data having
-- no threshold for that recipe, not a recipe you can make at skill zero - and zero is TRUTHY in
-- Lua, so "learn or yellow" hands it straight through and the panel states it as fact. Two Forever
-- recipes currently carry 0 and would read as "First Aid 0".
local function Skill(n)
    return (type(n) == "number" and n > 0) and n or nil
end

-- One reagent, as a button that behaves like an item everywhere else in the game does.
local function MaterialButton(parent, i, pool)
    local b = pool[i]
    if b then return b end
    b = CreateFrame("Button", nil, parent)
    b:SetHeight(16)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", 0, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.text = U.Text(b, "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 3, 0)
    b:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
        self.text:SetTextColor(1, 0.82, 0.3)
    end)
    b:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self.text:SetTextColor(1, 1, 1)
    end)
    -- Shift-click links it in chat, ctrl-click dresses it up: HandleModifiedItemClick is the one
    -- the game uses everywhere, so the modifiers are whatever the player already has them set to.
    b:SetScript("OnClick", function(self)
        if not self.itemID then return end
        -- HandleModifiedItemClick decides for itself which modifier does what, and does nothing
        -- when none is held, so asking first would only be a second opinion about the player's
        -- own keybindings.
        local link = select(2, GH.API.GetItemInfo(self.itemID))
        if link then HandleModifiedItemClick(link) end
    end)
    pool[i] = b
    return b
end

-- Lay the reagents out left to right, wrapping. Returns how far down they reached, so what comes
-- after can start below them however many lines they took.
local function LayoutMaterials(d, reagents)
    local pool = d.mats
    for _, b in ipairs(pool) do b:Hide() end
    if not reagents or #reagents == 0 then
        d.matsLabel:Hide()
        return 0
    end
    d.matsLabel:Show()
    local width = d.name:GetParent():GetWidth() - 24
    if width < 120 then width = 120 end
    local x, y, line = 0, -16, 0
    for i, rg in ipairs(reagents) do
        local b = MaterialButton(d.matsLabel:GetParent(), i, pool)
        local id, need = rg[1], rg[2]
        b.itemID = id
        b.icon:SetTexture(C.KeyIcon(id))
        b.text:SetText(("%s%dx %s|r"):format(C.KeyColor(id), need, I.Name(id) or "..."))
        b.text:SetTextColor(1, 1, 1)
        local w = 14 + 3 + (b.text:GetStringWidth() or 60) + 12
        if x > 0 and x + w > width then
            x, y = 0, y - 17
            line = line + 1
        end
        -- One reagent longer than the whole pane still has to stay inside it: the wrap above only
        -- moves things to a new line, and a new line is no help when the thing does not fit on one.
        if w - 12 > width then
            b.text:SetWidth(width - 17)
            w = width + 12
        else
            b.text:SetWidth(0)
        end
        b:SetWidth(w - 12)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", d.matsLabel, "TOPLEFT", x, y)
        b:Show()
        x = x + w
    end
    return -y + 18
end

local function RenderDetail()
    local d = view.detail
    local content = d.content
    for _, r in ipairs(d.rows) do r:Hide() end
    for _, h in ipairs(d.headings) do h:Hide(); h.line:Hide() end

    local e = state.selected and I.Get(state.selected)
    if not e then
        d.icon:Hide()
        d.name:SetText("")
        d.sub:SetText("")
        d.wantBtn:Hide()
        -- d.mats is the pool of reagent buttons, not a line of text: clearing it means putting
        -- them away. LayoutMaterials with nothing to lay out does exactly that, and keeping the
        -- one path means there is no second place to forget.
        LayoutMaterials(d, nil)
        d.empty:Show()
        content:SetHeight(10)
        return
    end
    d.empty:Hide()
    local key = e.key
    d.icon:Show()
    d.icon:SetKey(key)
    d.name:SetText(C.KeyColor(key) .. (I.Name(key) or "Loading...") .. "|r")
    -- No "I want this" for things you can craft yourself; your own post shows as a remove link.
    local canMake = GH.Scan.MyProfessionFor(key) ~= nil
    local myWant = type(key) == "number" and GH.Listings.MyWantFor(key)
    if myWant then
        d.wantBtn:SetLabel("You want this - remove")
        d.wantBtn:Show()
    elseif type(key) == "number" and not canMake then
        d.wantBtn:SetLabel("I want this")
        d.wantBtn:Show()
    else
        d.wantBtn:Hide()
    end

    local matsBottom = LayoutMaterials(d, I.ReagentsFor(key))

    -- One item's crafters, as real rows: the detail pane sorts them and reads every field, and a
    -- single item's worth is bounded. Nothing else in the UI may do this - see I.CrafterList.
    local crafters = I.SortPeople(I.CrafterList(e))
    local listings = I.SortPeople({ unpack(e.listings) })
    local wants = I.SortPeople({ unpack(e.wants) })
    -- Only what there is. "1 crafter, 0 have one, 0 want one" is two thirds nothing, on every item
    -- you click, and the list rows next to it already say it this way.
    local bits = { GH.Count(#crafters, "crafter") }
    if #listings > 0 then
        bits[#bits + 1] = ("%d %s one"):format(#listings, #listings == 1 and "has" or "have")
    end
    if #wants > 0 then
        bits[#bits + 1] = ("%d %s one"):format(#wants, #wants == 1 and "wants" or "want")
    end
    local sub = table.concat(bits, ", ")
    local recipe = I.RecipeInfoFor(key)
    if recipe then
        local req = { ("%s %s"):format(GH.ProfName(recipe.prof),
            Skill(recipe.learn) or Skill(recipe.yellow) or "?") }
        local station = C.StationName(recipe.station)
        if station then req[#req + 1] = recipe.camp and ("|cffff9d3f" .. station .. "|r") or station end
        if recipe.qty and recipe.qty > 1 then req[#req + 1] = ("makes %d"):format(recipe.qty) end
        sub = sub .. "  |cff8a8a8a-|r  " .. table.concat(req, ", ")
    end
    d.sub:SetText(sub)
    -- Everything below the title follows the title, because the title is now one line or two
    -- depending on the item's name. The materials used to sit at a fixed offset and a long name
    -- simply printed over them.
    -- Vertical from the subtitle, horizontal from the PANE - the same split the scroll area below
    -- needs, and for the same reason. Anchored to the subtitle it inherited the title's indent,
    -- so it started level with the item's name while the heading below it started at the pane's
    -- edge, and the width it was given to wrap in was measured from the pane it was not aligned
    -- to. The reagents ran off the right-hand side by exactly that difference.
    local pane = d.matsLabel:GetParent()
    local paneTop, subBottom = pane:GetTop(), d.sub:GetBottom()
    d.matsLabel:ClearAllPoints()
    if paneTop and subBottom then
        d.matsLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", 10, -(paneTop - subBottom) - 8)
    else
        d.matsLabel:SetPoint("TOPLEFT", d.sub, "BOTTOMLEFT", 0, -8)
    end
    -- Vertical from the materials, horizontal from the PANE. Anchoring both to the materials put
    -- every row below them in line with the item's title - indented by the width of the icon - and
    -- that stolen width is exactly what was truncating the note on each row.
    local pane = d.scroll:GetParent()
    local paneTop, labelTop = pane:GetTop(), d.matsLabel:GetTop()
    if paneTop and labelTop then
        d.scroll:ClearAllPoints()
        d.scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 6, -(paneTop - labelTop) - matsBottom)
        d.scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -28, 6)
    end

    local y, ri, hi = -4, 0, 0
    local function heading(text)
        hi = hi + 1
        local h = d.headings[hi]
        if not h then
            h = U.Heading(content, "")
            d.headings[hi] = h
        end
        h:SetText(text)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 4, y - 4)
        h:Show(); h.line:Show()
        y = y - 24
    end
    local function row()
        ri = ri + 1
        local r = d.rows[ri]
        if not r then
            r = MakeDetailRow(content)
            d.rows[ri] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, y)
        r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        r.bg:SetShown(ri % 2 == 0)
        r.b1:SetScript("OnClick", nil)
        r.b2:SetScript("OnClick", nil)
        r.owner = nil
        r:Show()
        y = y - DETAIL_ROW_H
        return r
    end

    if #crafters > 0 then
        heading("Can craft it")
        for _, c in ipairs(crafters) do
            local r = row()
            local isMe = c.owner == GH.Me()
            r.owner = c.owner
            r.name:SetText(PersonLabel(c.owner, c.class))
            -- Their skill, not their profession: the line above the list already says
            -- "Blacksmithing 40" for this item, so printing "Blacksmithing" again on every row
            -- spends the width that was truncating it on a word the reader just read.
            r.meta:SetText(("|cff8a8a8askill %d|r"):format(c.rank or 0))
            local note = isMe and "" or (GH.IsOnline(c.owner) and "|cff60d060online|r" or "offline - requests wait until they log in")
            if c.stale then note = note .. " |cff8a8a8a(from your last session)|r" end
            r.note:SetText(note)
            r.tip = { GH.LongName(c.owner), ("%s, skill %d"):format(c.prof, c.rank or 0) }
            r.b1:SetShown(not isMe)
            r.b2:SetShown(not isMe)
            r.b2:SetText("Request")
            r.b1:SetEnabled(GH.IsOnline(c.owner))
            r.b1:SetScript("OnClick", function() U.Whisper(c.owner, key) end)
            r.b2:SetScript("OnClick", function() GH.OpenRequest(c.owner, key) end)
        end
    end
    if #listings > 0 then
        heading("Guildies have it")
        for _, l in ipairs(listings) do
            local r = row()
            local isMe = l.owner == GH.Me()
            r.owner = l.owner
            r.name:SetText(PersonLabel(l.owner, l.class))
            r.meta:SetText(("|cffffffffx%d|r  |cff8a8a8a%s%s|r"):format(l.l.count or 1,
                l.stale and "last confirmed " or "", GH.Ago(l.l.posted)))
            r.note:SetText(l.stale and "|cff8a8a8aold - ask before counting on it|r"
                or (l.l.note ~= "" and l.l.note or "|cff6a6a6ano note|r"))
            r.tip = { GH.LongName(l.owner), l.l.note ~= "" and l.l.note or nil }
            r.b1:SetShown(not isMe)
            r.b1:SetEnabled(GH.IsOnline(l.owner))
            r.b2:Hide()
            r.b1:SetScript("OnClick", function() U.Whisper(l.owner, key) end)
        end
    end
    if #wants > 0 then
        heading("Wanted by")
        for _, w in ipairs(wants) do
            local r = row()
            local isMe = w.owner == GH.Me()
            r.owner = w.owner
            r.name:SetText(PersonLabel(w.owner, w.class))
            local want = w.w
            r.meta:SetText(("|cffffffffx%d|r  %s|cff8a8a8a%s|r"):format(want.qty or 1,
                (want.price or 0) > 0 and ("|cffffd100" .. GH.Money(want.price) .. " each|r  ") or "",
                GH.Ago(want.posted)))
            r.note:SetText(want.note ~= "" and want.note or "|cff6a6a6ano note|r")
            r.tip = { GH.LongName(w.owner), GH.Listings.WantText(want, I.Name(key)),
                want.note ~= "" and want.note or nil }
            r.b1:SetShown(not isMe)
            r.b1:SetEnabled(GH.IsOnline(w.owner))
            r.b1:SetScript("OnClick", function() U.Whisper(w.owner, key) end)
            -- You can craft it: say so in one click (the whisper comes pre-written).
            if canMake and not isMe then
                r.b2:SetText("I'll make it")
                r.b2:SetScript("OnClick", function() GH.Listings.OfferWant(w.owner, key, want) end)
                r.b2:Show()
            else
                r.b2:Hide()
            end
        end
    end
    content:SetHeight(-y + 8)
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Grouping: one collapsible heading per profession, then "Guildies have" and "Wanted"
-- ---------------------------------------------------------------------------
local HAVE_GROUP, WANT_GROUP = "Guildies have", "Wanted"
local GROUP_ICON = {
    [HAVE_GROUP] = "Interface\\Icons\\INV_Misc_Bag_08",
    [WANT_GROUP] = "Interface\\Icons\\INV_Misc_Note_01",
}

local function Collapsed()
    local st = GH.Settings()
    st.collapsed = st.collapsed or {}
    return st.collapsed
end

-- Which heading an item belongs under: the profession that makes it, else where it was posted.
local function GroupOf(r)
    local recipe = I.RecipeInfoFor(r.key)
    if recipe and recipe.prof then return GH.ProfName(recipe.prof) end
    if #r.crafters > 0 then
        local src = I.Source(r.crafters[1])
        if src then return src.prof end
    end
    if #r.listings > 0 then return HAVE_GROUP end
    return WANT_GROUP
end

-- Professions this character has come first, then the rest alphabetically; posts last.
local function GroupOrder(name)
    if name == HAVE_GROUP then return 3 end
    if name == WANT_GROUP then return 4 end
    local d = GH.MyData()
    for id in pairs(d and d.profs or {}) do
        if GH.ProfName(id) == name then return 1 end
    end
    return 2
end

-- Turns the search results into rows: heading, then its items unless it is collapsed.
local function Grouped(results, expandAll)
    if state.source == "listings" or state.source == "wants" then return results end
    local groups, order = {}, {}
    for _, r in ipairs(results) do
        local name = GroupOf(r)
        local g = groups[name]
        if not g then
            g = { name = name, items = {} }
            groups[name] = g
            order[#order + 1] = g
        end
        g.items[#g.items + 1] = r
    end
    table.sort(order, function(a, b)
        local oa, ob = GroupOrder(a.name), GroupOrder(b.name)
        if oa ~= ob then return oa < ob end
        return a.name < b.name
    end)
    local collapsed = Collapsed()
    local rows = {}
    -- One group needs no heading. A single "Enchanting (39)" over a list that is all Enchanting
    -- says nothing you did not already know from the breadcrumb, and costs a row of the list.
    local headings = #order > 1
    for _, g in ipairs(order) do
        local shut = headings and not expandAll and collapsed[g.name]
        if headings then
            rows[#rows + 1] = { header = true, group = g.name, count = #g.items, collapsed = shut }
        end
        if not shut then
            for _, r in ipairs(g.items) do rows[#rows + 1] = r end
        end
    end
    return rows
end

-- One card per profession: who has it, how far, and the best crafters.
local function ProfessionCards()
    local groups = I.Professions()
    local have, missing = {}, {}
    local showSecondary = Prefs().showSecondary
    local seen = {}
    for id, g in pairs(groups) do
        -- By skill line, not by name: gathering and secondary lines are known by ID, and a line we
        -- can't even name is skipped rather than shown as "Profession 356".
        local name = GH.ProfNameOrNil(id)
        if name then seen[name] = true end
        local secondary = GH.SECONDARY_LINE[id] or SECONDARY[name]
        if name and not GH.GATHERING_LINE[id] and (showSecondary or not secondary) then
            have[#have + 1] = { prof = name, id = id, people = g.people, best = g.best }
        end
    end
    for _, name in ipairs(GH.PROFESSIONS) do
        if not seen[name] and not GH.GATHERING[name] and (showSecondary or not SECONDARY[name]) then
            missing[#missing + 1] = { prof = name, missing = true }
        end
    end
    table.sort(have, function(a, b)
        if #a.people ~= #b.people then return #a.people > #b.people end
        return a.prof < b.prof
    end)
    table.sort(missing, function(a, b) return a.prof < b.prof end)
    return have, missing
end

-- The item list is for searching and for one profession; otherwise you get the overview.
-- Picking "Crafts", "Guildies have" or "Wanted" also opens the list: on the overview those filters
-- had nothing to show them, so a wanted post could only be found by searching for it.
local function ShowingOverview()
    return state.query == "" and not state.prof and state.source == "all"
end

-- Exactly one of three screens is ever visible: "noguild", "overview" or "items". Every widget
-- belongs to one or more of them, so two screens can never show at the same time.
local MODE_WIDGETS = {
    noguild  = { "noGuild" },
    overview = { "search", "source", "online", "secondary", "cardBox" },
    items    = { "search", "source", "online", "crumbBack", "profLabel", "quality", "listBox",
                 "detailBox", "loading" },
}

local function SetMode(mode)
    if view.mode == mode then return end
    view.mode = mode
    local on = {}
    for _, key in ipairs(MODE_WIDGETS[mode]) do on[key] = true end
    for _, list in pairs(MODE_WIDGETS) do
        for _, key in ipairs(list) do
            if view[key] then view[key]:SetShown(on[key] or false) end
        end
    end
    for _, b in ipairs(view.profButtons) do b:SetShown(mode == "items") end
end

local function Refresh()
    if not view then return end
    if not GH.GuildDB() then
        SetMode("noguild")
        return
    end
    -- Counts per filter for the same search, so every filter shows what it holds.
    local all, loading = I.Search(state.query, { source = "all", prof = state.prof, online = state.online })
    local counts = { all = #all, crafts = 0, listings = 0, wants = 0 }
    for _, r in ipairs(all) do
        if #r.crafters > 0 then counts.crafts = counts.crafts + 1 end
        if #r.listings > 0 then counts.listings = counts.listings + 1 end
        if #r.wants > 0 then counts.wants = counts.wants + 1 end
    end
    for value, label in pairs(FILTER_LABELS) do
        view.source:SetLabel(value, ("%s (%d)"):format(label, counts[value]))
        view.source:SetDim(value, counts[value] == 0)
    end

    local results = state.source == "all" and all or I.Search(state.query, state)
    -- Minimum quality: Poor keeps everything, Epic keeps only epics. A row whose quality we cannot
    -- read - an item still loading, an enchant that makes no item - is kept, never dropped.
    local minQuality = Prefs().minQuality or 0
    if minQuality > 0 then
        local kept = {}
        for _, r in ipairs(results) do
            if C.KeyAtLeastQuality(r.key, minQuality) then kept[#kept + 1] = r end
        end
        results = kept
    end
    view.results = results

    local overview = ShowingOverview()
    SetMode(overview and "overview" or "items")
    if view.UpdateCrumb then view.UpdateCrumb() end
    if overview then
        view.RenderOverview()
        view.loading:SetText("")
        return
    end
    -- A search or a profession filter always shows its hits: nothing hides behind a collapsed heading.
    view.list:SetData(Grouped(results, state.query ~= "" or state.prof ~= nil))
    if loading > 0 then
        view.loading:SetText(("|cff8a8a8aloading %s...|r"):format(GH.Count(loading, "item name")))
    elseif #results == 0 then
        local text
        if GH.Sync.syncing then
            text = "syncing with your guild..."
        elseif state.query ~= "" or state.prof or state.online then
            text = "no matches"
        elseif state.source == "listings" then
            text = "Nobody has posted items yet - offer one from My Guildhall"
        elseif state.source == "wants" then
            text = "Nothing wanted yet - post a want from My Guildhall"
        elseif GH.HasSharedRecipes and GH.HasSharedRecipes() then
            text = "nothing to show yet"
        else
            text = "nothing shared yet - your recipes are added shortly after you log in"
        end
        view.loading:SetText("|cff8a8a8a" .. text .. "|r")
    else
        -- The filter buttons above already say "Everything (39)". Saying 39 again in the corner is
        -- the same fact twice, and the corner is where "loading" and "no matches" need to be seen.
        view.loading:SetText("")
    end
    RenderDetail()
end

local function Build(f)
    view = f

    -- Search + filters
    local search = U.EditBox(f, 200, "Search items...")
    search:SetPoint("TOPLEFT", 6, -2)
    search:SetScript("OnTextChanged", function(self)
        state.query = self:GetText()
        GH.Debounce("browseSearch", 0.25, Refresh)
    end)
    f.search = search

    local source = U.Segmented(f, {
        { value = "all", label = FILTER_LABELS.all, tip = "Everything the guild can craft, has to spare or is looking for." },
        { value = "crafts", label = FILTER_LABELS.crafts, tip = "Items and enchants a guildie with Guildhall can craft." },
        { value = "listings", label = FILTER_LABELS.listings, tip = "Items guildies have posted as available, from their bags." },
        { value = "wants", label = FILTER_LABELS.wants, tip = "Items guildies are looking for." },
    }, 420, function(v)
        state.source = v
        Refresh()
    end)
    source:SetPoint("LEFT", search, "RIGHT", 14, 0)
    f.source = source

    local online = U.Checkbox(f, "Online only")
    f.online = online
    online:SetPoint("LEFT", source, "RIGHT", 12, 0)
    online:SetScript("OnClick", function(self)
        state.online = self:GetChecked() and true or false
        Refresh()
    end)

    -- Where you are, top left, reading the way you read. The button that used to do this said
    -- "< All professions" in the top RIGHT corner - the loudest thing on the screen, on the least
    -- important action, in the corner every WoW window puts a close button. It told you where you
    -- could go and never where you were. A breadcrumb answers both, in four words, where the eye
    -- starts.
    -- An arrow, in the top left, with the page's name beside it. This is the third thing to
    -- live here: a red "< All professions" button in the top right read as a close button, and a
    -- breadcrumb did not read as "back" either. Both of those asked the reader to work out that
    -- some text was a way out. Blizzard's own journals put a left arrow in this corner and players
    -- already know it, which beats anything I can invent that is cleverer.
    f.crumbBack = CreateFrame("Button", nil, f)
    f.crumbBack:SetSize(22, 22)
    f.crumbBack:SetPoint("TOPLEFT", 4, -33)
    f.crumbBack:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    f.crumbBack:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    f.crumbBack:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    f.crumbBack:SetScript("OnClick", function()
        f.search:SetText("")
        state.query = ""
        f.SetProfession(nil)
    end)
    U.Tooltip(f.crumbBack, "Back", "Back to all professions.")
    local lbl = U.Text(f, "GameFontNormal")
    f.profLabel = lbl
    lbl:SetPoint("LEFT", f.crumbBack, "RIGHT", 4, 0)

    -- Profession filter icons, anchored from the RIGHT edge. The breadcrumb beside them changes
    -- length with the profession's name, and a row of icons that slides left and right as you
    -- browse is a row you have to re-find every time.
    f.profButtons = {}
    local prev
    for _, name in ipairs(GH.PROFESSIONS) do
        if not GH.GATHERING[name] then
            local b = CreateFrame("Button", nil, f, "BackdropTemplate")
            b:SetSize(22, 22)
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) end
            b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetPoint("TOPLEFT", 1, -1)
            t:SetPoint("BOTTOMRIGHT", -1, 1)
            t:SetTexture(GH.ProfIcon(name))
            t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.tex, b.prof = t, name
            b:SetScript("OnClick", function()
                f.SetProfession((state.prof ~= name) and name or nil)
            end)
            b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            U.Tooltip(b, name, "Click to show only " .. name .. " crafts. Click again to clear.")
            f.profButtons[#f.profButtons + 1] = b
            prev = b
        end
    end
    -- 22 wide and 3 apart, so the row is n*25 - 3; pin the first one that far in from the edge.
    if f.profButtons[1] then
        f.profButtons[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(#f.profButtons * 25 - 3) - 6, -36)
    end

    -- The breadcrumb, from whatever the screen is showing. It never needs to ask whether there is
    -- somewhere to go back to: the whole row belongs to the item screen (see MODE_WIDGETS), and
    -- you only reach that screen by searching or by picking a profession.
    -- A profession AND a search are both possible at once, so both are named rather than one
    -- hiding the other - "where am I" has two answers there and the trail should say so.
    function f.UpdateCrumb()
        local trail = {}
        if state.prof then trail[#trail + 1] = state.prof end
        if state.query ~= "" then trail[#trail + 1] = ("\"%s\""):format(state.query) end
        -- Where you are, beside the way out. Both when both apply: a search inside a profession
        -- has two answers to "where am I" and naming one of them would be a half-truth.
        f.profLabel:SetText("|cffebdec2" .. table.concat(trail, "|r |cff8a8a8a/|r |cffebdec2") .. "|r")
    end

    -- One way in and out of a profession, used by the icon row, the cards and the breadcrumb.
    function f.SetProfession(name)
        -- Whatever you had open belonged to the profession you just left. Leaving it on screen
        -- while the list beside it is a different profession reads as though it is in this one.
        state.selected = nil
        state.prof = name
        for _, other in ipairs(f.profButtons) do
            local on = other.prof == name
            other:SetBackdropBorderColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0.3 or 0.3, 1)
            other.tex:SetDesaturated(name ~= nil and not on)
            -- Dim the ones you did not pick as well as colouring the one you did: a gold hairline
            -- at 22 pixels is not enough on its own to say which of ten is selected.
            other.tex:SetAlpha((name == nil or on) and 1 or 0.45)
        end
        Refresh()
    end

    -- Without a guild there is nothing to browse: one message instead of empty lists.
    f.noGuild = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.noGuild:SetPoint("CENTER", 0, 20)
    f.noGuild:SetWidth(460)
    f.noGuild:SetJustifyH("CENTER")
    f.noGuild:SetSpacing(4)
    f.noGuild:SetText("Guildhall works with your guild.\n\n|cff8a8a8aJoin a guild to see who can craft what, what "
        .. "guildies have to spare and what they're looking for.|r")
    f.noGuild:Hide()

    f.loading = U.Text(f, "GameFontHighlightSmall", "RIGHT")
    f.loading:SetPoint("TOPRIGHT", -6, -62)   -- the filter row above it holds the back button

    -- Minimum quality for the item list.
    f.quality = U.Segmented(f, {
        { value = 0, label = "All", tip = "Show items of every quality." },
        { value = 2, label = "|cff1eff00Uncommon+|r",
            tip = "Hide poor and common items. Enchants make no item, so they always show." },
        { value = 3, label = "|cff0070ddRare+|r",
            tip = "Show only rare and epic items, and enchants, which have no item quality." },
        { value = 4, label = "|cffa335eeEpic|r",
            tip = "Show only epic items, and enchants, which have no item quality." },
    }, 260, function(v)
        Prefs().minQuality = v
        Refresh()
    end)
    f.quality:SetPoint("TOPLEFT", 6, -58)
    f.quality:Select(Prefs().minQuality or 0)

    -- Overview: one card per profession.
    f.secondary = U.Checkbox(f, "Show secondary professions")
    f.secondary:SetPoint("TOPLEFT", 4, -36)   -- the profession row is hidden on the overview
    f.secondary:SetChecked(Prefs().showSecondary and true or false)
    f.secondary:SetScript("OnClick", function(self)
        Prefs().showSecondary = self:GetChecked() and true or nil
        Refresh()
    end)
    U.Tooltip(f.secondary, "Secondary professions", "Cooking, First Aid and Fishing.")

    local cardBox = U.Inset(f)
    cardBox:SetPoint("TOPLEFT", 0, -62)
    cardBox:SetPoint("BOTTOMRIGHT", 0, 0)
    f.cardBox = cardBox

    local cardScroll = CreateFrame("ScrollFrame", nil, cardBox, "UIPanelScrollFrameTemplate")
    cardScroll:SetPoint("TOPLEFT", 8, -8)
    cardScroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local canvas = CreateFrame("Frame", nil, cardScroll)
    canvas:SetSize(10, 10)
    cardScroll:SetScrollChild(canvas)

    f.overviewEmpty = U.Text(cardBox, "GameFontDisable", "CENTER")
    f.overviewEmpty:SetPoint("TOPLEFT", 20, -30)
    f.overviewEmpty:SetPoint("RIGHT", -20, 0)
    f.overviewEmpty:SetWordWrap(true)
    f.overviewEmpty:SetText("Nobody has shared a profession yet. Yours is shared automatically - guildies "
        .. "with Guildhall show up here.")

    -- One real card per covered profession: icon, name, a skill bar and the best crafters.
    local cards, chips = {}, {}
    local function Card(i)
        local card = cards[i]
        if card then return card end
        card = CreateFrame("Button", nil, canvas, "BackdropTemplate")
        card:SetSize(CARD_W, CARD_H)
        U.InsetLook(card)
        local hl = card:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(40, 40)
        card.icon:SetPoint("LEFT", 10, 0)
        card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        card.name = U.Text(card, "GameFontNormal")
        card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, 0)
        card.name:SetPoint("RIGHT", -10, 0)
        -- Skill bar: how far the guild's best has come towards 300.
        card.barBg = card:CreateTexture(nil, "ARTWORK")
        card.barBg:SetSize(120, 6)
        card.barBg:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
        card.barBg:SetColorTexture(0, 0, 0, 0.5)
        card.bar = card:CreateTexture(nil, "OVERLAY")
        card.bar:SetHeight(6)
        card.bar:SetPoint("TOPLEFT", card.barBg, "TOPLEFT", 0, 0)
        card.bar:SetColorTexture(0.82, 0.67, 0.38, 0.9)
        card.sub = U.Text(card, "GameFontHighlightSmall")
        card.sub:SetPoint("LEFT", card.barBg, "RIGHT", 8, 0)
        card.sub:SetPoint("RIGHT", -10, 0)
        card.who = U.Text(card, "GameFontDisableSmall")
        card.who:SetPoint("TOPLEFT", card.barBg, "BOTTOMLEFT", 0, -5)
        card.who:SetPoint("RIGHT", -10, 0)
        card:SetScript("OnClick", function(self) f.SetProfession(self.prof) end)
        card:SetScript("OnEnter", function(self)
            if not self.people then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.prof, 1, 0.82, 0.3)
            for _, person in ipairs(self.people) do
                local label = GH.ColorName(person.owner, person.class)
                    .. (person.owner == GH.Me() and " |cff7fc8ff(you)|r" or "")
                GameTooltip:AddDoubleLine(label, ("skill %d"):format(person.rank), 1, 1, 1, 0.8, 0.8, 0.8)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to see what they can make.", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        card:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cards[i] = card
        return card
    end

    -- Professions nobody has: small dimmed chips, so the gaps take one line, not five cards.
    local function Chip(i)
        local chip = chips[i]
        if chip then return chip end
        chip = CreateFrame("Frame", nil, canvas)
        chip:SetSize(CHIP_W, 26)
        chip.icon = chip:CreateTexture(nil, "ARTWORK")
        chip.icon:SetSize(20, 20)
        chip.icon:SetPoint("LEFT", 2, 0)
        chip.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        chip.icon:SetDesaturated(true)
        chip.icon:SetAlpha(0.5)
        chip.name = U.Text(chip, "GameFontDisableSmall")
        chip.name:SetPoint("LEFT", chip.icon, "RIGHT", 5, 0)
        chip.name:SetPoint("RIGHT", -2, 0)
        chips[i] = chip
        return chip
    end

    f.missingHead = U.Heading(canvas, "Not covered yet - nobody in the guild has shared these.")
    f.missingHead:SetTextColor(0.6, 0.6, 0.6)

    -- Lay the cards out in as many columns as fit, then the chips below a divider.
    function f.RenderOverview()
        local have, missing = ProfessionCards()
        local width = cardScroll:GetWidth()
        if width < 10 then width = 700 end
        local columns = math.max(1, math.floor((width + GRID_GAP) / (CARD_W + GRID_GAP)))
        f.overviewEmpty:SetShown(#have == 0)
        local y = 0
        for i, data in ipairs(have) do
            local card = Card(i)
            local col, rowIndex = (i - 1) % columns, math.floor((i - 1) / columns)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", col * (CARD_W + GRID_GAP), -rowIndex * (CARD_H + GRID_GAP))
            card.prof, card.people = data.prof, data.people
            card.icon:SetTexture(GH.ProfIcon(data.prof))
            card.name:SetText("|c" .. GH.CREAM .. data.prof .. "|r")
            card.bar:SetWidth(math.max(1, 120 * math.min(1, (data.best or 0) / 300)))
            card.sub:SetText(("|cff8a8a8a%s - up to %d|r"):format(GH.Count(#data.people, "guildie"), data.best))
            local names = {}
            for n = 1, math.min(2, #data.people) do
                local person = data.people[n]
                names[#names + 1] = ("%s%s %d"):format(GH.Short(person.owner),
                    person.owner == GH.Me() and " (you)" or "", person.rank)
            end
            if #data.people > 2 then names[#names + 1] = ("+%d more"):format(#data.people - 2) end
            card.who:SetText(table.concat(names, "  |cff4a4a4a-|r  "))
            card:Show()
        end
        for i = #have + 1, #cards do cards[i]:Hide() end
        if #have > 0 then
            y = -(math.ceil(#have / columns) * (CARD_H + GRID_GAP)) - 6
        end

        f.missingHead:SetShown(#missing > 0)
        f.missingHead.line:SetShown(#missing > 0)
        if #missing > 0 then
            f.missingHead:ClearAllPoints()
            f.missingHead:SetPoint("TOPLEFT", 2, y - 8)
            y = y - 30
            local perRow = math.max(1, math.floor((width + 6) / (CHIP_W + 6)))
            for i, data in ipairs(missing) do
                local chip = Chip(i)
                local col, rowIndex = (i - 1) % perRow, math.floor((i - 1) / perRow)
                chip:ClearAllPoints()
                chip:SetPoint("TOPLEFT", col * (CHIP_W + 6), y - rowIndex * 26)
                chip.icon:SetTexture(GH.ProfIcon(data.prof))
                chip.name:SetText(data.prof)
                chip:Show()
            end
            y = y - math.ceil(#missing / perRow) * 26
        end
        for i = #missing + 1, #chips do chips[i]:Hide() end
        canvas:SetSize(math.max(10, width), math.max(10, -y + 10))
    end

    -- Results list
    local listBox = U.Inset(f)
    f.listBox = listBox
    listBox:SetPoint("TOPLEFT", 0, -84)
    listBox:SetSize(330, LIST_ROWS * LIST_ROW_H + 8)
    f.list = U.ScrollList(listBox, LIST_ROW_H, LIST_ROWS,
        function(row)
            row.hl = row:CreateTexture(nil, "HIGHLIGHT")
            row.hl:SetAllPoints()
            row.hl:SetColorTexture(1, 1, 1, 0.08)
            row.sel = row:CreateTexture(nil, "BACKGROUND")
            row.sel:SetAllPoints()
            row.sel:SetColorTexture(0.82, 0.67, 0.38, 0.18)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(18, 18)
            row.icon:SetPoint("LEFT", 4, 0)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.name = U.Text(row, "GameFontHighlightSmall")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.info = U.Text(row, "GameFontHighlightSmall", "RIGHT")
            row.info:SetPoint("RIGHT", -4, 0)
            row.name:SetPoint("RIGHT", row.info, "LEFT", -6, 0)
            row:SetScript("OnClick", function(self)
                if self.group then
                    local collapsed = Collapsed()
                    collapsed[self.group] = not collapsed[self.group] or nil
                    Refresh()
                    return
                end
                if IsModifiedClick() then
                    local link = C.KeyLink(self.key)
                    if link then HandleModifiedItemClick(link) end
                    return
                end
                state.selected = self.key
                f.list:Refresh()
                RenderDetail()
            end)
            row:SetScript("OnEnter", function(self)
                if self.group then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                C.SetTooltip(GameTooltip, self.key)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end,
        function(row, r)
            if r.header then
                row.key, row.group = nil, r.group
                row.icon:SetTexture(GROUP_ICON[r.group] or GH.ProfIcon(r.group))
                -- Blizzard's own collapse buttons rather than a "+" or a "-": a bare hyphen in
                -- front of a heading reads as a typo, and these exist in every client, which a
                -- triangle glyph in the game's font does not reliably.
                row.name:SetText(("|T%s:14|t |cffe6b34d%s|r |cff8a8a8a(%d)|r"):format(
                    r.collapsed and "Interface\\Buttons\\UI-PlusButton-Up"
                    or "Interface\\Buttons\\UI-MinusButton-Up", r.group, r.count))
                row.info:SetText("")
                row.sel:Hide()
                return
            end
            row.key, row.group = r.key, nil
            row.icon:SetTexture(C.KeyIcon(r.key))
            row.name:SetText(C.KeyColor(r.key) .. r.name .. "|r")
            -- Say who, not just how many: "1 craft" read as "I can craft one".
            local parts = {}
            if #r.crafters > 0 then
                local on = 0
                for i = 1, #r.crafters do
                    local src = I.Source(r.crafters[i])
                    if src and GH.IsOnline(src.owner) then on = on + 1 end
                end
                local who
                if #r.crafters == 1 then
                    local src = I.Source(r.crafters[1]) or {}
                    who = src.owner == GH.Me() and "you" or GH.Short(src.owner)
                else
                    who = GH.Count(#r.crafters, "crafter")
                end
                -- Your own crafts stay in the list - hiding them would make an item you can make
                -- yourself look like one nobody can - but they are dimmed, because every other
                -- entry here is something to go and ask somebody for and this one is not.
                local mineOnly = #r.crafters == 1 and (I.Source(r.crafters[1]) or {}).owner == GH.Me()
                parts[#parts + 1] = (mineOnly and "|cff6a6a6a" or on > 0 and "|cff60d060"
                    or "|cff8a8a8a") .. who .. "|r"
            end
            if #r.listings > 0 then
                parts[#parts + 1] = ("|cffe6b34d%d %s one|r"):format(#r.listings, #r.listings == 1 and "has" or "have")
            end
            if #r.wants > 0 then
                parts[#parts + 1] = ("|cff7da5ff%d %s one|r"):format(#r.wants, #r.wants == 1 and "wants" or "want")
            end
            row.info:SetText(table.concat(parts, "  "))
            row.sel:SetShown(r.key == state.selected)
        end)
    f.list:SetPoint("TOPLEFT", 4, -4)
    f.list:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Detail pane
    local detailBox = U.Inset(f)
    f.detailBox = detailBox
    detailBox:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 10, 0)
    detailBox:SetPoint("BOTTOMRIGHT", 0, 0)
    local d = { rows = {}, headings = {} }
    f.detail = d

    d.icon = U.KeyIcon(detailBox, 36)
    d.icon:SetPoint("TOPLEFT", 10, -10)
    d.name = U.Text(detailBox, "GameFontNormalLarge")
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2)
    d.name:SetPoint("RIGHT", -110, 0)
    -- Two lines, because the pane below is empty and the item's name is the one thing on this
    -- screen that must not be guessed at. "Enchant 2H Weapon - Lesser..." is not a name.
    d.name:SetWordWrap(true)
    d.name:SetMaxLines(2)
    d.sub = U.Text(detailBox, "GameFontHighlightSmall")
    d.sub:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
    -- A quiet link, not a main button: only offered when asking the guild makes sense.
    d.wantBtn = U.LinkButton(detailBox, "I want this")
    d.wantBtn:SetPoint("TOPRIGHT", -12, -14)
    d.wantBtn:SetScript("OnClick", function(self)
        if not state.selected then return end
        local mine = GH.Listings.MyWantFor(state.selected)
        if mine then
            GH.Listings.RemoveWant(mine.id)
        elseif GH.StartWant then
            GH.StartWant(state.selected)
        end
    end)
    U.Tooltip(d.wantBtn, "Wanted posts", "Lets the guild know you're looking for this item.")
    -- Materials, as the items they are. This was one line of text that said
    -- "8x Medium Leather, 2x Cured Medium Hide, 4x Pristine Leathe..." - truncated at the pane's
    -- edge, with no way to see what the last one was, let alone what it looks like or where it
    -- comes from. Each reagent is its own small button now: it wraps rather than being cut, it
    -- shows the game's own tooltip on hover, and shift-clicking it links the item into chat the
    -- way every other item in the game does.
    d.matsLabel = U.Text(detailBox, "GameFontNormalSmall")
    d.matsLabel:SetText("|cffe6b34dMaterials|r")
    d.mats = {}
    d.empty = U.Text(detailBox, "GameFontDisable", "CENTER")
    d.empty:SetPoint("CENTER")
    d.empty:SetText("Pick an item to see who can make it.")

    local scroll = CreateFrame("ScrollFrame", nil, detailBox, "UIPanelScrollFrameTemplate")
    d.scroll = scroll
    scroll:SetPoint("TOPLEFT", 6, -72)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    d.content = content
    d.scroll = scroll
end

GH.RegisterTab("browse", "Browse", Build, Refresh)

-- From a chat link or the Requests tab: the Wanted list with this item picked.
function GH.ShowWanted(key)
    GH.ShowTab("browse")
    if not view then return end
    view.search:SetText("")
    state.query = ""
    state.source = "wants"
    view.source:Select("wants")
    view.SetProfession(nil)
    state.selected = key
    Refresh()
end

function GH.ShowSearch(text)
    GH.ShowTab("browse")
    if view and text and text ~= "" then
        view.search:SetText(text)
    end
end
