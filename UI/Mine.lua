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
    c.priceLabel:SetShown(not offer)
    c.price:SetShown(not offer)
    c.post:SetText(offer and "List it" or "Post wanted")
    c.post:SetEnabled(composer.key ~= nil)
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
        view.composer.price:SetText("")
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
    view.composer.note:SetFocus()
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
    for i, row in ipairs(view.profRows) do
        local id = ids[i]
        if id then
            local p = d.profs[id]
            local name = GH.ProfName(id)
            row.icon:SetTexture(GH.ProfIcon(name))
            row.name:SetText(("|c%s%s|r  |cffffffff%d|r|cff8a8a8a/%d|r"):format(GH.CREAM, name, p.rank or 0, p.max or 0))
            if gathering[id] then
                row.status:SetText("|cff8a8a8agathering - skill shared|r")
            elseif GH.Scan.HasStaticRecipes(id) or p.recipes then
                row.status:SetText(("|cff60d060%s shared|r"):format(
                    GH.Count(GH.Scan.CountSet(p.recipes), "recipe")))
            else
                -- No built-in data for this profession: only its window can tell which recipes you know.
                row.status:SetText("|cffffb040open your " .. name .. " window once to share recipes|r")
            end
            row:Show()
        else
            row:Hide()
        end
    end
    view.noProfs:SetShown(#names == 0)
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
    if not GH.GuildDB() then
        view.guildNote:SetText("|cffff6060You're not in a guild - nothing is being shared.|r")
    else
        view.guildNote:SetText("")
    end
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
        local row = CreateFrame("Frame", nil, left)
        row:SetHeight(30)
        row:SetPoint("TOPLEFT", 8, -32 - (i - 1) * 30)
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
        f.profRows[i] = row
    end
    f.noProfs = U.Text(left, "GameFontDisableSmall")
    f.noProfs:SetPoint("TOPLEFT", 12, -40)
    f.noProfs:SetText("No professions found yet.")

    local hint = left:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 10, 10)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Your professions and recipes are shared with the guild automatically, and updated whenever you learn something new.")
    f.guildNote = U.Text(left, "GameFontHighlightSmall")
    f.guildNote:SetPoint("BOTTOMLEFT", hint, "TOPLEFT", 0, 6)

    -- Right: composer
    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)

    local comp = U.Inset(right)
    comp:SetPoint("TOPLEFT")
    comp:SetPoint("TOPRIGHT")
    comp:SetHeight(146)
    local c = {}
    f.composer = c

    c.mode = U.Segmented(comp, {
        { value = "offer", label = "Offer an item" },
        { value = "want", label = "Want an item" },
    }, 250, function(v)
        composer.mode = v
        UpdateComposer()
    end)
    c.mode:SetPoint("TOPLEFT", 10, -10)

    c.slot = U.KeyIcon(comp, 38)
    c.slot:SetPoint("TOPLEFT", 10, -42)
    local border = c.slot:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetPoint("TOPLEFT", -12, 12)
    border:SetPoint("BOTTOMRIGHT", 12, -12)
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

    c.countLabel = U.Text(comp, "GameFontNormalSmall")
    c.countLabel:SetPoint("TOPLEFT", 12, -92)
    c.countLabel:SetText("Amount")
    c.count = U.EditBox(comp, 44, nil, true)
    c.count:SetPoint("LEFT", c.countLabel, "RIGHT", 8, 0)

    -- Wanted posts say what they pay; offers put their price in the note.
    c.priceLabel = U.Text(comp, "GameFontNormalSmall")
    c.priceLabel:SetPoint("LEFT", c.count, "RIGHT", 16, 0)
    c.priceLabel:SetText("Gold each")
    c.price = U.EditBox(comp, 52, nil, true)
    c.price:SetPoint("LEFT", c.priceLabel, "RIGHT", 8, 0)
    U.Tooltip(c.price, "Gold each", "What you'll pay per item. Leave it empty to just ask for it.")

    c.note = U.EditBox(comp, 260, "Note - trade terms, where to meet...")
    c.note:SetPoint("TOPLEFT", c.countLabel, "BOTTOMLEFT", 2, -10)
    c.note:SetMaxLetters(C.NOTE_LEN)

    c.post = U.Button(comp, "List it", 96, 22)
    c.post:SetPoint("BOTTOMRIGHT", -10, 10)
    c.post:SetScript("OnClick", function()
        if not composer.key then return end
        local ok, err
        if composer.mode == "offer" then
            ok, err = L.Add(composer.link, c.count:GetNumber(), c.note:GetText())
        else
            ok, err = L.AddWant(composer.key, c.note:GetText(), c.count:GetNumber(),
                c.price:GetNumber() * 10000)
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
        end,
        function(row, item)
            local e = item.e
            local id = C.ItemIdFromString(e.item)
            row.icon:SetKey(id, e.item)
            local name = C.KeyColor(id) .. (I.Name(id) or "...") .. "|r"
            if item.kind == "offer" then
                row.tag:SetText("|cffe6b34dHave|r")
                row.name:SetText(name .. (" |cffffffffx%d|r"):format(e.count or 1))
                local extra = e.missing and "|cffff6060not in your bags - hidden|r " or ""
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
