-- Guildhall - Browse tab: search everything the guild can make, has, or wants.
local ADDON, GH = ...
local U, C, I = GH.UI, GH.Codec, GH.Index

local state = { query = "", source = "all", prof = nil, online = false, selected = nil }
local view      -- the tab frame
local LIST_ROWS, LIST_ROW_H = 15, 22
local DETAIL_ROW_H = 36

-- ---------------------------------------------------------------------------
-- Request popup
-- ---------------------------------------------------------------------------
local popup
local function BuildPopup()
    if popup then return end
    popup = U.Window("GuildhallRequestPopup", UIParent, 340, 196)
    popup:SetPoint("CENTER", 0, 80)
    popup:SetFrameStrata("DIALOG")
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

    popup.send = U.Button(popup, "Send request", 110, 22)
    popup.send:SetPoint("BOTTOMRIGHT", -16, 16)
    local cancel = U.Button(popup, "Cancel", 80, 22)
    cancel:SetPoint("RIGHT", popup.send, "LEFT", -6, 0)
    cancel:SetScript("OnClick", function() popup:Hide() end)

    popup.send:SetScript("OnClick", function()
        local ok, err = GH.Orders.Request(popup.crafter, popup.key, popup.qty:GetNumber(), popup.note:GetText())
        if ok then
            if GH.IsOnline(popup.crafter) then
                GH.msg("request sent to %s.", GH.Short(popup.crafter))
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
    r.meta:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.note = U.Text(r, "GameFontDisableSmall")
    r.note:SetPoint("TOPLEFT", 6, -20)
    r.b1 = U.Button(r, "Whisper", 62, 18)
    r.b1:SetPoint("RIGHT", -4, 0)
    r.b2 = U.Button(r, "Request", 62, 18)
    r.b2:SetPoint("RIGHT", r.b1, "LEFT", -3, 0)
    r.note:SetPoint("RIGHT", r.b2, "LEFT", -6, 0)
    r:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i, line in ipairs(self.tip) do
            if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function PersonLabel(owner, class)
    if owner == GH.Me() then return "|c" .. GH.ClassColor(class) .. "You|r" end
    if GH.IsOnline(owner) then return GH.ColorName(owner, class) end
    return "|cff8a8a8a" .. GH.Short(owner) .. "|r"
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
        d.mats:SetText("")
        d.empty:Show()
        content:SetHeight(10)
        return
    end
    d.empty:Hide()
    local key = e.key
    d.icon:Show()
    d.icon:SetKey(key)
    d.name:SetText(C.KeyColor(key) .. (I.Name(key) or "Loading...") .. "|r")
    d.wantBtn:SetShown(type(key) == "number")

    local reagents = I.ReagentsFor(key)
    if reagents then
        local parts = {}
        for _, rg in ipairs(reagents) do
            parts[#parts + 1] = ("%dx %s"):format(rg[2], I.Name(rg[1]) or "?")
        end
        d.mats:SetText("|cffe6b34dMaterials:|r " .. table.concat(parts, ", "))
    else
        d.mats:SetText("")
    end

    local crafters = I.SortPeople({ unpack(e.crafters) })
    local listings = I.SortPeople({ unpack(e.listings) })
    local wants = I.SortPeople({ unpack(e.wants) })
    local sub = ("%d crafter%s, %d listed, %d wanted"):format(#crafters, #crafters == 1 and "" or "s", #listings, #wants)
    local recipe = I.RecipeInfoFor(key)
    if recipe then
        local req = { ("%s %s"):format(GH.ProfName(recipe.prof), recipe.learn or recipe.yellow or "?") }
        local station = C.StationName(recipe.station)
        if station then req[#req + 1] = recipe.camp and ("|cffff9d3f" .. station .. "|r") or station end
        if recipe.qty and recipe.qty > 1 then req[#req + 1] = ("makes %d"):format(recipe.qty) end
        sub = sub .. "  |cff8a8a8a-|r  " .. table.concat(req, ", ")
    end
    d.sub:SetText(sub)

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
        r:Show()
        y = y - DETAIL_ROW_H
        return r
    end

    if #crafters > 0 then
        heading("Can craft it")
        for _, c in ipairs(crafters) do
            local r = row()
            local isMe = c.owner == GH.Me()
            r.name:SetText(PersonLabel(c.owner, c.class))
            r.meta:SetText(("|cff8a8a8a%s %d|r"):format(c.prof, c.rank or 0))
            r.note:SetText(isMe and "" or (GH.IsOnline(c.owner) and "|cff60d060online|r" or "offline - requests wait until they log in"))
            r.tip = { GH.Short(c.owner), ("%s, skill %d"):format(c.prof, c.rank or 0) }
            r.b1:SetShown(not isMe)
            r.b2:SetShown(not isMe)
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
            r.name:SetText(PersonLabel(l.owner, l.class))
            r.meta:SetText(("|cffffffffx%d|r  |cff8a8a8a%s|r"):format(l.l.count or 1, GH.Ago(l.l.posted)))
            r.note:SetText(l.l.note ~= "" and l.l.note or "|cff6a6a6ano note|r")
            r.tip = { GH.Short(l.owner), l.l.note ~= "" and l.l.note or nil }
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
            r.name:SetText(PersonLabel(w.owner, w.class))
            r.meta:SetText("|cff8a8a8a" .. GH.Ago(w.w.posted) .. "|r")
            r.note:SetText(w.w.note ~= "" and w.w.note or "|cff6a6a6ano note|r")
            r.tip = { GH.Short(w.owner), w.w.note ~= "" and w.w.note or nil }
            r.b1:SetShown(not isMe)
            r.b1:SetEnabled(GH.IsOnline(w.owner))
            r.b2:Hide()
            r.b1:SetScript("OnClick", function() U.Whisper(w.owner, key) end)
        end
    end
    content:SetHeight(-y + 8)
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------
local function Refresh()
    if not view then return end
    if not GH.GuildDB() then
        view.list:SetData({})
        view.loading:SetText("|cffff6060Join a guild to use Guildhall.|r")
        RenderDetail()
        return
    end
    local results, loading = I.Search(state.query, state)
    view.results = results
    view.list:SetData(results)
    if loading > 0 then
        view.loading:SetText(("|cff8a8a8aloading %d item names...|r"):format(loading))
    elseif #results == 0 then
        view.loading:SetText(state.query ~= "" and "|cff8a8a8ano matches|r" or "|cff8a8a8anothing shared yet|r")
    else
        view.loading:SetText(("|cff8a8a8a%d items|r"):format(#results))
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
        { value = "all", label = "Everything" },
        { value = "crafts", label = "Crafts" },
        { value = "listings", label = "Guildies have" },
        { value = "wants", label = "Wanted" },
    }, 340, function(v)
        state.source = v
        Refresh()
    end)
    source:SetPoint("LEFT", search, "RIGHT", 14, 0)

    local online = U.Checkbox(f, "Online only")
    online:SetPoint("LEFT", source, "RIGHT", 12, 0)
    online:SetScript("OnClick", function(self)
        state.online = self:GetChecked() and true or false
        Refresh()
    end)

    -- Profession filter icons
    f.profButtons = {}
    local lbl = U.Text(f, "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 6, -36)
    lbl:SetText("Profession:")
    local prev
    for _, name in ipairs(GH.PROFESSIONS) do
        if not GH.GATHERING[name] then
            local b = CreateFrame("Button", nil, f, "BackdropTemplate")
            b:SetSize(22, 22)
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) else b:SetPoint("LEFT", lbl, "RIGHT", 8, 0) end
            b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetPoint("TOPLEFT", 1, -1)
            t:SetPoint("BOTTOMRIGHT", -1, 1)
            t:SetTexture(GH.ProfIcon(name))
            t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.tex, b.prof = t, name
            b:SetScript("OnClick", function()
                state.prof = (state.prof ~= name) and name or nil
                for _, other in ipairs(f.profButtons) do
                    local on = other.prof == state.prof
                    other:SetBackdropBorderColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0.3 or 0.3, 1)
                    other.tex:SetDesaturated(state.prof ~= nil and not on)
                end
                Refresh()
            end)
            b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            U.Tooltip(b, name, "Click to show only " .. name .. " crafts. Click again to clear.")
            f.profButtons[#f.profButtons + 1] = b
            prev = b
        end
    end

    f.loading = U.Text(f, "GameFontHighlightSmall", "RIGHT")
    f.loading:SetPoint("TOPRIGHT", -6, -40)

    -- Results list
    local listBox = U.Inset(f)
    listBox:SetPoint("TOPLEFT", 0, -62)
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
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                C.SetTooltip(GameTooltip, self.key)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end,
        function(row, r)
            row.key = r.key
            row.icon:SetTexture(C.KeyIcon(r.key))
            row.name:SetText(C.KeyColor(r.key) .. r.name .. "|r")
            local parts = {}
            if #r.crafters > 0 then
                local on = 0
                for _, c in ipairs(r.crafters) do if GH.IsOnline(c.owner) then on = on + 1 end end
                parts[#parts + 1] = (on > 0 and "|cff60d060" or "|cff8a8a8a") .. #r.crafters .. " craft|r"
            end
            if #r.listings > 0 then parts[#parts + 1] = "|cffe6b34d" .. #r.listings .. " have|r" end
            if #r.wants > 0 then parts[#parts + 1] = "|cff7da5ff" .. #r.wants .. " want|r" end
            row.info:SetText(table.concat(parts, "  "))
            row.sel:SetShown(r.key == state.selected)
        end)
    f.list:SetPoint("TOPLEFT", 4, -4)
    f.list:SetPoint("BOTTOMRIGHT", -4, 4)

    -- Detail pane
    local detailBox = U.Inset(f)
    detailBox:SetPoint("TOPLEFT", listBox, "TOPRIGHT", 10, 0)
    detailBox:SetPoint("BOTTOMRIGHT", 0, 0)
    local d = { rows = {}, headings = {} }
    f.detail = d

    d.icon = U.KeyIcon(detailBox, 36)
    d.icon:SetPoint("TOPLEFT", 10, -10)
    d.name = U.Text(detailBox, "GameFontNormalLarge")
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2)
    d.name:SetPoint("RIGHT", -110, 0)
    d.sub = U.Text(detailBox, "GameFontHighlightSmall")
    d.sub:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
    d.wantBtn = U.Button(detailBox, "I want this", 96, 20)
    d.wantBtn:SetPoint("TOPRIGHT", -10, -12)
    d.wantBtn:SetScript("OnClick", function()
        if state.selected and GH.StartWant then GH.StartWant(state.selected) end
    end)
    U.Tooltip(d.wantBtn, "Post a wanted note", "Lets the guild know you're looking for this item.")
    d.mats = U.Text(detailBox, "GameFontHighlightSmall")
    d.mats:SetPoint("TOPLEFT", 10, -54)
    d.mats:SetPoint("RIGHT", -10, 0)
    d.empty = U.Text(detailBox, "GameFontDisable", "CENTER")
    d.empty:SetPoint("CENTER")
    d.empty:SetText("Pick an item to see who can make it.")

    local scroll = CreateFrame("ScrollFrame", nil, detailBox, "UIPanelScrollFrameTemplate")
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

function GH.ShowSearch(text)
    GH.ShowTab("browse")
    if view and text and text ~= "" then
        view.search:SetText(text)
    end
end
