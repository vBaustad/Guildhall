-- Guildhall - "My Guildhall" tab: what you share (professions), offer (items) and want.
local ADDON, GH = ...
local U, C, I, L = GH.UI, GH.Codec, GH.Index, GH.Listings

local view
local composer = { mode = "offer", link = nil, key = nil }
local LIST_ROWS, LIST_ROW_H = 9, 26

-- ---------------------------------------------------------------------------
-- Composer (offer / want an item)
-- ---------------------------------------------------------------------------
local function UpdateComposer()
    if not view then return end
    local c = view.composer
    local offer = composer.mode == "offer"
    c.slot:SetKey(composer.key, composer.link and C.ItemStringFromLink(composer.link))
    if composer.key then
        local have = GH.API.GetItemCount(composer.key, true) or 0
        c.itemName:SetText(C.KeyColor(composer.key) .. (I.Name(composer.key) or "...") .. "|r")
        c.itemInfo:SetText(offer and ("|cff8a8a8ayou have %d|r"):format(have) or "")
    else
        c.itemName:SetText("|cff8a8a8aNo item picked|r")
        c.itemInfo:SetText(offer and "|cff8a8a8aDrag an item here, or shift-click one in your bags.|r"
            or "|cff8a8a8aDrag or shift-click an item, or use \"I want this\" in Browse.|r")
    end
    -- Both halves have a price. An offer without one is a thing you are giving away or
    -- haggling over in whispers, which is fine - but "what do you want for it" was the first
    -- question anybody was going to ask, and it was being answered in a free-text note or not
    -- at all.
    c.priceLabel:SetShown(true)
    for _, w in ipairs(c.priceBoxes) do w:Show() end
    -- Your own bags are the only place an OFFER can come from, and almost never where a WANT
    -- comes from - you are asking for something you do not have. So the bag list belongs to one
    -- mode and a search belongs to the other.
    c.pick:SetShown(offer)
    c.find:SetShown(not offer)
    -- Clear sits beside whichever of those two is up, and the item's name stops where the cluster
    -- begins. Clear was anchored to the pick button's left edge full stop, so in the other mode it
    -- sat under the search box - which is wider, and so reached further left than the thing Clear
    -- was measuring against. Anchoring to "the control that is actually there" is the only version
    -- of this that cannot drift when one of them changes size.
    local side = offer and c.pick or c.find
    c.clear:ClearAllPoints()
    c.clear:SetPoint("RIGHT", side, "LEFT", -4, 0)
    local edge = composer.key and c.clear or side
    c.itemName:SetPoint("RIGHT", edge, "LEFT", -8, 0)
    c.itemInfo:SetPoint("RIGHT", edge, "LEFT", -8, 0)
    c.post:SetText(offer and "List it" or "Post wanted")
    c.post:SetEnabled(composer.key ~= nil)
    c.clear:SetShown(composer.key ~= nil)
end

local function SetComposerItem(link)
    local key = C.KeyFromLink(link)
    if type(key) ~= "number" then return end
    composer.link, composer.key = link, key
    if view then
        -- Offers default to everything you have; wanted posts start at one.
        local have = GH.API.GetItemCount(key, true) or 0
        view.composer.count:SetNumber(composer.mode == "offer" and math.max(1, have) or 1)
    end
    UpdateComposer()
end

local function ClearComposer()
    composer.link, composer.key = nil, nil
    if view then
        view.composer.note:SetText("")
        view.composer.count:SetText("")
        view.composer.priceG:SetText("")
        view.composer.priceS:SetText("")
        view.composer.priceC:SetText("")
    end
    UpdateComposer()
end

-- From Browse: "I want this".
function GH.StartWant(key)
    GH.ShowTab("mine")
    composer.mode = "want"
    view.composer.mode:Select("want")
    composer.key = key
    composer.link = select(2, GH.API.GetItemInfo(key)) or ("item:" .. key)
    UpdateComposer()
    -- Deliberately NOT focusing the note: its placeholder is the only label it has, and
    -- focus hides the placeholder. Arriving here from "I want this" the item is already
    -- filled in and the next thing most people do is press the button.
end

-- Shift-clicking an item in your bags while this tab is open picks it (unless you're typing in chat).
hooksecurefunc("HandleModifiedItemClick", function(link)
    if not GH.WindowShown("mine") or not IsModifiedClick("CHATLINK") then return end
    local chatOpen = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow())
        or (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
    if chatOpen then return end
    if C.ItemStringFromLink(link) then SetComposerItem(link) end
end)

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------
-- Item classes, as the groups a player would sort their own bags into. The numbers are
-- GetItemInfoInstant's classID, which is the only grouping the client gives us for free.
local BAG_GROUPS = {
    [7] = "Materials",      -- trade goods
    [0] = "Consumables",
    [2] = "Gear",           -- weapon
    [4] = "Gear",           -- armour
}
local BAG_ORDER = { "Materials", "Gear", "Consumables", "Other" }

local function BagCollapsed()
    local st = GH.Settings()
    st.bagGroups = st.bagGroups or {}
    return st.bagGroups
end

-- Your bags as rows for the list: group headings, then the items under them, best first.
local function BagRows()
    local byGroup = {}
    for _, it in ipairs(C.BagItems()) do
        local name = I.Name(it.id)
        if name then
            local classID = select(6, GH.API.GetItemInfoInstant(it.id))
            local group = BAG_GROUPS[classID] or "Other"
            byGroup[group] = byGroup[group] or {}
            table.insert(byGroup[group], { id = it.id, count = it.count, name = name,
                quality = C.KeyQuality(it.id) or 1 })
        end
    end
    local rows = {}
    for _, group in ipairs(BAG_ORDER) do
        local list = byGroup[group]
        if list then
            -- Best first inside a group: an epic you are offering is the thing you are looking
            -- for, and twenty stacks of linen are not.
            table.sort(list, function(a, b)
                if a.quality ~= b.quality then return a.quality > b.quality end
                return a.name < b.name
            end)
            local shut = BagCollapsed()[group]
            rows[#rows + 1] = { header = group, count = #list, collapsed = shut }
            if not shut then
                for _, it in ipairs(list) do rows[#rows + 1] = it end
            end
        end
    end
    return rows
end

local function RefreshProfessions()
    local d = GH.MyData()
    local ids = {}
    if d then for id in pairs(d.profs) do ids[#ids + 1] = id end end
    local gathering = GH.Scan.GATHERING_LINES
    table.sort(ids, function(a, b)
        local ga, gb = gathering[a] and 1 or 0, gathering[b] and 1 or 0
        if ga ~= gb then return ga < gb end
        return GH.ProfName(a) < GH.ProfName(b)
    end)
    local names = ids
    -- One line saying it is working, and a row ONLY where something needs doing. Five static
    -- rows of skill numbers told you nothing you could not read in the game's own UI, and making
    -- them clickable just meant a profession window landed on top of Guildhall when you brushed
    -- one. What is worth a row is the profession whose recipes we cannot see.
    local recipes, needs = 0, {}
    for _, id in ipairs(ids) do
        local p = d.profs[id]
        if not gathering[id] then
            if GH.Scan.HasStaticRecipes(id) or p.recipes then
                recipes = recipes + GH.Scan.CountSet(p.recipes)
            else
                needs[#needs + 1] = id
            end
        end
    end
    if #ids == 0 then
        view.profSummary:SetText("")
    else
        view.profSummary:SetText(("|cff60d060%s and %s shared with your guild|r"):format(
            GH.Count(#ids, "profession"), GH.Count(recipes, "recipe")))
    end

    for i, row in ipairs(view.profRows) do
        local id = needs[i]
        if id then
            local name = GH.ProfName(id)
            row.profID, row.profName = id, name
            row.icon:SetTexture(GH.ProfIcon(name))
            row.name:SetText(("|c%s%s|r"):format(GH.CREAM, name))
            row.status:SetText("|cffffb040open its window once to share recipes|r")
            row:Show()
        else
            row.profID, row.profName = nil, nil
            row:Hide()
        end
    end
    view.noProfs:SetShown(#ids == 0)

    -- The bags start below the summary and whatever needed saying, which is usually nothing.
    view.bagHead:ClearAllPoints()
    view.bagHead:SetPoint("TOPLEFT", 10, -52 - #needs * 30)
    view.bagHead:SetPoint("RIGHT", -10, 0)
    -- Grow into the panel before filling it: how tall the list is depends on how many
    -- professions needed a row above it, which is not known until here.
    view.bagList:FitToHeight()
    view.bagList:SetData(BagRows())
end

local function Refresh()
    if not view then return end
    RefreshProfessions()
    UpdateComposer()

    local d = GH.MyData()
    local data = {}
    if d then
        for _, l in ipairs(d.listings) do data[#data + 1] = { kind = "offer", e = l } end
        for _, w in ipairs(d.wants) do data[#data + 1] = { kind = "want", e = w } end
    end
    view.list:SetData(data)
    view.listEmpty:SetShown(#data == 0)
    -- Your professions are scanned either way; offering and asking only mean something in a guild.
    local inGuild = GH.GuildDB() ~= nil
    view.right:SetShown(inGuild)
    view.noGuild:SetShown(not inGuild)
    view.guildNote:SetText(inGuild and "" or "|cff8a8a8aNot in a guild - nothing is being shared yet.|r")
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------
local function Build(f)
    view = f

    -- Left: professions
    local left = U.Inset(f)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(300)
    local h1 = U.Heading(left, "Your professions")
    h1:SetPoint("TOPLEFT", 10, -10)

    f.profRows = {}
    for i = 1, 8 do
        local row = CreateFrame("Button", nil, left)
        row:SetHeight(30)
        row:SetPoint("TOPLEFT", 8, -50 - (i - 1) * 30)
        row:SetPoint("RIGHT", -8, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", 0, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.name = U.Text(row, "GameFontHighlightSmall")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
        row.status = U.Text(row, "GameFontHighlightSmall")
        row.status:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
        row.status:SetPoint("RIGHT", 0, 0)
        row.hl = row:CreateTexture(nil, "HIGHLIGHT")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(1, 1, 1, 0.06)
        -- The one thing this panel ever asks of you is "open your Enchanting window once". Asking
        -- is all it did; now the row that asks is the button that does it.
        row:SetScript("OnClick", function(self)
            if not self.profID then return end
            -- No CastSpellByName fallback. OpenTradeSkill is present on Forever - checked in
            -- the probe's own globals - and casting a profession by name is an Era-era trick I
            -- have not seen work here. One path I have evidence for beats two where the second
            -- is a guess that only runs on clients we do not ship to.
            if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
                C_TradeSkillUI.OpenTradeSkill(self.profID)
            end
        end)
        row:SetScript("OnEnter", function(self)
            if not self.profName then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.profName, 1, 0.82, 0.3)
            GameTooltip:AddLine("Click to open it.", 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.profRows[i] = row
    end
    f.profSummary = U.Text(left, "GameFontHighlightSmall")
    f.profSummary:SetPoint("TOPLEFT", 12, -34)
    f.profSummary:SetPoint("RIGHT", -10, 0)
    f.noProfs = U.Text(left, "GameFontDisableSmall")
    f.noProfs:SetPoint("TOPLEFT", 12, -40)
    f.noProfs:SetText("No professions found yet.")

    -- Your bags, in the bottom half of this panel - which was empty. The professions above it
    -- stay: they carry the only live warning Guildhall has ("open your Enchanting window once"),
    -- and there was no need to choose between them when half the panel was unused.
    f.bagHead = U.Heading(left, "In your bags")
    f.bagList = U.ScrollList(left, 20, 11,
        function(row)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(16, 16)
            row.icon:SetPoint("LEFT", 2, 0)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.name = U.Text(row, "GameFontHighlightSmall")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.count = U.Text(row, "GameFontDisableSmall", "RIGHT")
            row.count:SetPoint("RIGHT", -4, 0)
            row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
            row.hl = row:CreateTexture(nil, "HIGHLIGHT")
            row.hl:SetAllPoints()
            row.hl:SetColorTexture(1, 1, 1, 0.08)
            -- A heading in the game's own idiom: gold text with a divider running off to the
            -- right, which is exactly what U.Heading draws everywhere else in this addon. It was
            -- a filled stripe, and a flat modern bar under Blizzard's chunky collapse button was
            -- two design languages arguing in the same twenty pixels. Its own font string,
            -- anchored LEFT only, so it is as wide as its text and the line can start after it.
            row.headText = U.Text(row, "GameFontNormalSmall")
            row.headText:SetPoint("LEFT", 2, 0)
            row.headLine = row:CreateTexture(nil, "ARTWORK")
            row.headLine:SetAtlas("Options_HorizontalDivider")
            row.headLine:SetHeight(1)
            row.headLine:SetPoint("LEFT", row.headText, "RIGHT", 6, 0)
            row.headLine:SetPoint("RIGHT", -6, 0)
            row:SetScript("OnEnter", function(self)
                if not self.itemID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.headText:Hide()
            row.headLine:Hide()
            row:SetScript("OnClick", function(self)
                if self.group then
                    local shut = BagCollapsed()
                    shut[self.group] = not shut[self.group] or nil
                    Refresh()
                    return
                end
                if not self.itemID then return end
                -- Shift-click links it, like an item anywhere else; a plain click loads it into
                -- the form beside the list, which is what the list is for.
                local link = C.KeyLink(self.itemID) or ("item:" .. self.itemID)
                if IsModifiedClick() then HandleModifiedItemClick(link) else SetComposerItem(link) end
            end)
        end,
        function(row, r)
            if r.header then
                row.itemID, row.group = nil, r.header
                row.icon:SetTexture(nil)
                row.name:SetText("")
                row.count:SetText("")
                -- The same collapse buttons Browse uses, for the same reason: they exist in every
                -- client, and a bare "+" in front of a heading reads as a typo.
                row.headText:SetText(("|T%s:12|t |cffe6b34d%s|r |cff8a8a8a(%d)|r"):format(
                    r.collapsed and "Interface\\Buttons\\UI-PlusButton-Up"
                    or "Interface\\Buttons\\UI-MinusButton-Up", r.header, r.count))
                row.headText:Show()
                row.headLine:Show()
                return
            end
            row.itemID, row.group = r.id, nil
            row.headText:Hide()
            row.headLine:Hide()
            row.icon:SetTexture(C.KeyIcon(r.id))
            row.name:SetText(C.KeyColor(r.id) .. r.name .. "|r")
            row.count:SetText(r.count > 1 and ("|cff8a8a8ax%d|r"):format(r.count) or "")
        end)
    f.bagList:SetPoint("TOPLEFT", f.bagHead, "BOTTOMLEFT", 0, -4)

    local hint = left:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 10, 10)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Your professions and recipes are shared with the guild automatically, and updated whenever you learn something new.")
    f.guildNote = U.Text(left, "GameFontHighlightSmall")
    f.guildNote:SetPoint("BOTTOMLEFT", hint, "TOPLEFT", 0, 6)
    f.bagHead:SetPoint("TOPLEFT", 10, -40)
    f.bagHead:SetPoint("RIGHT", -10, 0)
    -- Anchored to `hint`, which has a LEFT and a RIGHT point and therefore a real width, and NOT
    -- to guildNote, which has only a BOTTOMLEFT and so is exactly as wide as whatever text it is
    -- holding - nothing, most of the time. The list inherited that nothing: no width, so no room
    -- for a name, and the counts rendered off the left edge of the panel. Third time this week I
    -- have anchored a box to a piece of text and been given the text's width.
    f.bagList:SetPoint("BOTTOMRIGHT", hint, "TOPRIGHT", 0, 26)

    -- Right: composer
    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    f.right = right

    -- Shown in place of the composer and your posts when you're not in a guild.
    f.noGuild = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.noGuild:SetPoint("TOPLEFT", left, "TOPRIGHT", 30, -40)
    f.noGuild:SetPoint("RIGHT", -20, 0)
    f.noGuild:SetJustifyH("LEFT")
    f.noGuild:SetSpacing(4)
    f.noGuild:SetText("Offering items and posting what you want works with your guild.\n\n"
        .. "|cff8a8a8aJoin a guild and your guildies will see what you can craft, what you have to spare "
        .. "and what you're looking for.|r")
    f.noGuild:Hide()

    local comp = U.Inset(right)
    comp:SetPoint("TOPLEFT")
    comp:SetPoint("TOPRIGHT")
    comp:SetHeight(146)
    local c = {}
    f.composer = c

    c.mode = U.Segmented(comp, {
        { value = "offer", label = "Offer an item" },
        -- "Ask the guild", because that is what posting a want does and it is the thing
        -- that distinguishes it from a craft order aimed at one person.
        { value = "want", label = "Ask the guild" },
    }, 250, function(v)
        composer.mode = v
        UpdateComposer()
    end)
    c.mode:SetPoint("TOPLEFT", 10, -10)

    c.slot = U.KeyIcon(comp, 38)
    c.slot:SetPoint("TOPLEFT", 10, -42)
    -- A plain hairline, the same as the profession icons in Browse. This was UI-Quickslot2,
    -- the action-bar slot art, stretched 12 pixels past the icon on every side: that texture
    -- is mostly transparent padding around a ring drawn for a 36-pixel button, so at this
    -- size the ring landed inside the icon and the icon spilled out through it.
    -- Drawn rather than set as a backdrop: U.KeyIcon is a plain Button with no
    -- BackdropTemplate, so SetBackdrop is not a method on it. Guarding on "if it has one"
    -- would have left no border at all and looked like a styling choice.
    local frame = c.slot:CreateTexture(nil, "BACKGROUND")
    frame:SetPoint("TOPLEFT", -2, 2)
    frame:SetPoint("BOTTOMRIGHT", 2, -2)
    frame:SetColorTexture(0.45, 0.4, 0.35, 1)
    c.slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function takeCursor()
        local kind, _, link = GetCursorInfo()
        if kind == "item" and link then
            SetComposerItem(link)
            ClearCursor()
            return true
        end
    end
    c.slot:SetScript("OnReceiveDrag", takeCursor)
    c.slot:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ClearComposer()
        elseif not takeCursor() and composer.key and IsModifiedClick() then
            local link = C.KeyLink(composer.key)
            if link then HandleModifiedItemClick(link) end
        end
    end)

    c.itemName = U.Text(comp, "GameFontHighlight")
    c.itemName:SetPoint("TOPLEFT", c.slot, "TOPRIGHT", 10, -2)
    c.itemName:SetPoint("RIGHT", -10, 0)
    c.itemInfo = U.Text(comp, "GameFontHighlightSmall")
    c.itemInfo:SetPoint("TOPLEFT", c.itemName, "BOTTOMLEFT", 0, -4)
    c.itemInfo:SetPoint("RIGHT", -10, 0)

    -- A way IN. Dragging onto the slot and shift-clicking both need your bags open, so with them
    -- shut there was no way to put an item in this form at all - which made the whole tab
    -- something you could only reach from somewhere else.
    c.pick = U.Button(comp, "Choose an item", 110, 20)
    c.pick:SetPoint("TOPRIGHT", -10, -42)
    c.pick:SetScript("OnClick", function(self)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then
            GH.msg("drag an item onto the slot, or shift-click one in your bags.")
            return
        end
        local bags = C.BagItems()
        if #bags == 0 then
            GH.msg("your bags are empty.")
            return
        end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle("From your bags")
            for _, it in ipairs(bags) do
                local name = I.Name(it.id)
                if name then
                    local label = ("|T%s:14|t %s%s|r%s"):format(C.KeyIcon(it.id), C.KeyColor(it.id),
                        name, it.count > 1 and (" |cff8a8a8ax" .. it.count .. "|r") or "")
                    root:CreateButton(label, function()
                        SetComposerItem(C.KeyLink(it.id) or ("item:" .. it.id))
                    end)
                end
            end
        end)
    end)
    U.Tooltip(c.pick, "Choose an item",
        "Pick something out of your bags. You can also drag one onto the slot, or shift-click "
        .. "one in your bags.")

    -- Wanting something means naming something you have not got, so this searches what the
    -- professions make and what they are made from - which is where "400 Linen Cloth" lives.
    c.find = U.EditBox(comp, 150, "Search for an item...")
    c.find:SetPoint("TOPRIGHT", -10, -42)
    c.find:SetScript("OnEnterPressed", function(self)
        local matches = I.SearchItems(self:GetText(), 20)
        if #matches == 0 then
            GH.msg("nothing found for \"%s\" - try fewer letters, or a name you have seen in game.",
                self:GetText())
            return
        end
        if #matches == 1 or not (MenuUtil and MenuUtil.CreateContextMenu) then
            SetComposerItem(C.KeyLink(matches[1].id) or ("item:" .. matches[1].id))
            self:ClearFocus()
            return
        end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle("Did you mean")
            for _, m in ipairs(matches) do
                root:CreateButton(("|T%s:14|t %s%s|r"):format(C.KeyIcon(m.id), C.KeyColor(m.id),
                    m.name), function()
                    SetComposerItem(C.KeyLink(m.id) or ("item:" .. m.id))
                end)
            end
        end)
        self:ClearFocus()
    end)
    U.Tooltip(c.find, "Search",
        "Type part of an item's name and press Enter. Searches everything the professions make "
        .. "and everything they are made from.")

    -- And a way OUT. Right-clicking the slot cleared it, which nothing said and nobody found.
    c.clear = U.Button(comp, "Clear", 54, 20)
    c.clear:SetPoint("RIGHT", c.pick, "LEFT", -4, 0)
    c.clear:SetScript("OnClick", ClearComposer)
    U.Tooltip(c.clear, "Clear", "Empty the form and start again.")

    c.countLabel = U.Text(comp, "GameFontNormalSmall")
    c.countLabel:SetPoint("TOPLEFT", 12, -92)
    c.countLabel:SetText("Amount")
    c.count = U.EditBox(comp, 44, nil, true)
    c.count:SetPoint("LEFT", c.countLabel, "RIGHT", 8, 0)

    -- Wanted posts say what they pay; offers put their price in the note.
    c.priceLabel = U.Text(comp, "GameFontNormalSmall")
    c.priceLabel:SetPoint("LEFT", c.count, "RIGHT", 16, 0)
    c.priceLabel:SetText("Price each")
    -- Gold, silver and copper, not a single box multiplied by 10000. Most of what anybody posts
    -- a want for is cloth or ore, and "1 gold each for linen" is not an offer, it is a typo
    -- waiting to happen.
    --
    -- Built from three edit boxes rather than MoneyInputFrameTemplate: the money functions are in
    -- the client's globals but I cannot see from a globals dump whether that XML template is, and
    -- CreateFrame against a template that does not exist is an error on somebody's screen.
    c.priceBoxes = {}
    local function coinBox(after, gap, width, coin)
        local box = U.EditBox(comp, width, nil, true)
        box:SetPoint("LEFT", after, "RIGHT", gap, 0)
        local icon = U.Text(comp, "GameFontHighlightSmall")
        icon:SetText(("|TInterface\\MoneyFrame\\UI-%sIcon:12:12|t"):format(coin))
        icon:SetPoint("LEFT", box, "RIGHT", 2, 0)
        c.priceBoxes[#c.priceBoxes + 1] = box
        c.priceBoxes[#c.priceBoxes + 1] = icon
        return box, icon
    end
    local gIcon, sIcon
    c.priceG, gIcon = coinBox(c.priceLabel, 8, 38, "Gold")
    c.priceS, sIcon = coinBox(gIcon, 4, 26, "Silver")
    c.priceC = coinBox(sIcon, 4, 26, "Copper")

    --- What the three boxes add up to, in copper.
    function c.PriceCopper()
        return (c.priceG:GetNumber() or 0) * 10000 + (c.priceS:GetNumber() or 0) * 100
            + (c.priceC:GetNumber() or 0)
    end
    U.Tooltip(c.priceLabel, "Price each",
        "What you will pay per item, in gold, silver and copper. Leave it empty to just ask.")

    c.note = U.EditBox(comp, 260, "Add a note - trade terms, where to meet...")
    c.note:SetPoint("TOPLEFT", c.countLabel, "BOTTOMLEFT", 2, -10)
    c.note:SetMaxLetters(C.NOTE_LEN)

    c.post = U.Button(comp, "List it", 96, 22)
    c.post:SetPoint("BOTTOMRIGHT", -10, 10)
    c.post:SetScript("OnClick", function()
        if not composer.key then return end
        local ok, err
        if composer.mode == "offer" then
            ok, err = L.Add(composer.link, c.count:GetNumber(), c.note:GetText(), c.PriceCopper())
        else
            ok, err = L.AddWant(composer.key, c.note:GetText(), c.count:GetNumber(),
                c.PriceCopper())
        end
        if ok then
            ClearComposer()
        else
            GH.msg(err or "couldn't post that.")
        end
    end)

    -- Right: your posts
    local listBox = U.Inset(right)
    listBox:SetPoint("TOPLEFT", comp, "BOTTOMLEFT", 0, -10)
    listBox:SetPoint("BOTTOMRIGHT")
    local h2 = U.Heading(listBox, "Your posts")
    h2:SetPoint("TOPLEFT", 10, -10)

    f.list = U.ScrollList(listBox, LIST_ROW_H, LIST_ROWS,
        function(row)
            row.icon = U.KeyIcon(row, 20)
            row.icon:SetPoint("LEFT", 4, 0)
            row.tag = U.Text(row, "GameFontNormalSmall")
            row.tag:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.tag:SetWidth(34)
            row.name = U.Text(row, "GameFontHighlightSmall")
            row.name:SetPoint("LEFT", row.tag, "RIGHT", 4, 0)
            row.name:SetWidth(150)
            row.remove = U.Button(row, "Remove", 58, 18)
            row.remove:SetPoint("RIGHT", -2, 0)
            row.note = U.Text(row, "GameFontDisableSmall")
            row.note:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
            row.note:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
            row:RegisterForClicks("RightButtonUp")
            row:SetScript("OnClick", function(self)
                local id = self.shareId
                if not id or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
                MenuUtil.CreateContextMenu(self, function(_, root)
                    root:CreateTitle(I.Name(id) or ("item " .. id))
                    if GH.IsNoShare(id) then
                        root:CreateButton("Share this item again", function() GH.SetNoShare(id, false) end)
                    else
                        root:CreateButton("Don't share this item", function() GH.SetNoShare(id, true) end)
                    end
                end)
            end)
        end,
        function(row, item)
            local e = item.e
            local id = C.ItemIdFromString(e.item)
            row.shareId = item.kind == "offer" and id or nil
            row.icon:SetKey(id, e.item)
            local name = C.KeyColor(id) .. (I.Name(id) or "...") .. "|r"
            if item.kind == "offer" then
                row.tag:SetText("|cffe6b34dHave|r")
                row.name:SetText(name .. (" |cffffffffx%d|r"):format(e.count or 1))
                local extra = GH.IsNoShare(id) and "|cffff6060on your Don't share list - hidden|r "
                    or e.missing and "|cffff6060not in your bags - hidden|r " or ""
                row.note:SetText(extra .. (e.note ~= "" and e.note or "") .. " |cff6a6a6a" .. GH.Ago(e.posted) .. "|r")
                row.remove:SetScript("OnClick", function() L.Remove(e.id) end)
            else
                row.tag:SetText("|cff7da5ffWant|r")
                row.name:SetText(name .. (" |cffffffffx%d|r"):format(e.qty or 1))
                local pay = (e.price or 0) > 0 and ("|cffffd100" .. GH.Money(e.price) .. " each|r  ") or ""
                row.note:SetText(pay .. (e.note ~= "" and e.note or "") .. " |cff6a6a6a" .. GH.Ago(e.posted) .. "|r")
                row.remove:SetScript("OnClick", function() L.RemoveWant(e.id) end)
            end
        end)
    f.list:SetPoint("TOPLEFT", 4, -30)
    f.list:SetPoint("BOTTOMRIGHT", -4, 4)
    f.listEmpty = U.Text(listBox, "GameFontDisableSmall", "CENTER")
    f.listEmpty:SetPoint("CENTER", 0, -10)
    f.listEmpty:SetText("Nothing posted. Offer a spare BoE, or post something you're looking for.")

    UpdateComposer()
end

GH.RegisterTab("mine", "My Guildhall", Build, Refresh)
