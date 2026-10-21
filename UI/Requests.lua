-- Guildhall - Orders tab: what guildies have asked of you and what you have asked of them.
-- Two kinds share it: a craft order (please make me one) and an offer (I will buy the one
-- you posted). They differ in a word and a price; everything else - delivery while offline,
-- statuses, the resync - is the same, which is why they are not two tabs.
local ADDON, GH = ...
local U, C, I, O = GH.UI, GH.Codec, GH.Index, GH.Orders

local view
local side = "incoming"
-- A line each for the kind, the note and the materials, so none of them is truncated to make
-- room for the others. ROWS is only a starting guess: FitToHeight decides how many really fit.
local ROWS, ROW_H = 7, 72

local IN_STATUS = {
    new = "|cffffd100new|r",
    accepted = "|cff60d060accepted|r",
    declined = "|cffff6060declined|r",
    done = "|cff8a8a8adone|r",
    cancelled = "|cff8a8a8acancelled by them|r",
}
local OUT_STATUS = {
    sending = "|cffffb040waiting to deliver|r",
    pending = "|cffe6b34ddelivered|r",
    accepted = "|cff60d060accepted|r",
    declined = "|cffff6060declined|r",
    done = "|cff60d060done|r",
    cancelled = "|cff8a8a8acancelled|r",
}

local function MaterialsText(o)
    -- An offer to buy is for an item that already exists in somebody's bags. Listing what it
    -- would take to craft one tells the holder to go and gather reagents for a potion they are
    -- being offered money for, which is the exact confusion the separate message kind exists to
    -- avoid - and it reached the screen anyway, in the row rather than on the wire.
    if o.kind == "buy" then return "" end
    local reagents = O.Reagents(o)
    if not reagents then return "" end
    local parts = {}
    for _, r in ipairs(reagents) do
        local need = r[2] * (o.qty or 1)
        local text = ("%dx %s"):format(need, I.Name(r[1]) or "?")
        if side == "incoming" and type(r[1]) == "number" then
            local have = GH.API.GetItemCount(r[1], true) or 0
            text = text .. ((have >= need) and (" |cff60d060(%d)|r") or (" |cffff6060(%d)|r")):format(have)
        end
        parts[#parts + 1] = text
    end
    return "|cffe6b34dMaterials:|r |cffbbbbbb" .. table.concat(parts, ", ") .. "|r"
end

-- Facts fill the lines from the top in the order given, and anything empty is skipped rather
-- than left as a blank line. Without this an order with no note would show a hole where one would
-- have been, and the materials would sit one line lower than on the row above it.
local function SetLines(row, ...)
    local at = 0
    for i = 1, select("#", ...) do
        local text = select(i, ...)
        if text and text ~= "" then
            at = at + 1
            if row.lines[at] then row.lines[at]:SetText(text) end
        end
    end
    for i = at + 1, #row.lines do row.lines[i]:SetText("") end
end

local function SetButton(b, text, fn)
    if not text then
        b:Hide()
        return
    end
    b:SetText(text)
    b:SetScript("OnClick", fn)
    b:Show()
end

local function Refresh()
    if not view then return end
    if not GH.GuildDB() then
        view.list:SetData({})
        view.empty:SetText("Orders work with your guild.\n\n|cff8a8a8aJoin a guild to ask guildies to "
            .. "craft for you or to sell you what they have spare, and to get their orders.|r")
        view.empty:Show()
        return
    end
    local newCount = O.NewCount()
    view.sides:SetLabel("incoming", newCount > 0 and ("Asked of you |cffff6060(" .. newCount .. ")|r") or "Asked of you")
    local data = side == "incoming" and O.Incoming() or O.Outgoing()
    if side == "incoming" then
        -- Wanted posts you can craft sit under the direct requests, so they can't be missed.
        local wants = I.WantsICanMake()
        if #wants > 0 then
            local rows = {}
            for _, o in ipairs(data) do rows[#rows + 1] = o end
            rows[#rows + 1] = { heading = "Wanted by guildies - you can make these" }
            for _, w in ipairs(wants) do rows[#rows + 1] = { want = w } end
            data = rows
        end
    end
    -- Grow into the box before filling it: the rows are tall enough now that how many fit is
    -- worth asking rather than assuming, and an order list that runs off the bottom hides orders.
    view.list:FitToHeight()
    view.list:SetData(data)
    if #data == 0 then
        view.empty:SetText(side == "incoming"
            and "Nothing yet. Guildies can ask you to craft what you've shared, or offer to buy what you've posted."
            or "You haven't asked anyone for anything. Find an item in Browse and press Request or Offer.")
        view.empty:Show()
    else
        view.empty:Hide()
    end
end

local function Build(f)
    view = f
    f.sides = U.Segmented(f, {
        -- "Asked of you", not "For you to craft": half of what lands here is somebody offering
        -- to buy something you already have, which involves no crafting at all.
        { value = "incoming", label = "Asked of you" },
        { value = "outgoing", label = "Your orders" },
    }, 320, function(v)
        side = v
        Refresh()
    end)
    f.sides:SetPoint("TOPLEFT", 0, -2)

    local hint = U.Text(f, "GameFontDisableSmall", "RIGHT")
    hint:SetPoint("TOPRIGHT", -4, -6)
    hint:SetText("No gold or items move through Guildhall - trade or mail as usual.")

    local box = U.Inset(f)
    box:SetPoint("TOPLEFT", 0, -30)
    box:SetPoint("BOTTOMRIGHT")

    f.list = U.ScrollList(box, ROW_H, ROWS,
        function(row)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, 0.03)
            row:RegisterForClicks("RightButtonUp")
            row:SetScript("OnClick", function(self) U.PersonMenu(self, self.owner) end)
            row.icon = U.KeyIcon(row, 32)
            row.icon:SetPoint("TOPLEFT", 6, -6)
            row.b1 = U.Button(row, "", 70, 20)
            row.b1:SetPoint("RIGHT", -4, 0)
            row.b2 = U.Button(row, "", 70, 20)
            row.b2:SetPoint("RIGHT", row.b1, "LEFT", -3, 0)
            row.b3 = U.Button(row, "", 70, 20)
            row.b3:SetPoint("RIGHT", row.b2, "LEFT", -3, 0)
            row.title = U.Text(row, "GameFontHighlight")
            row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
            row.title:SetPoint("RIGHT", row.b3, "LEFT", -8, 0)
            row.line2 = U.Text(row, "GameFontHighlightSmall")
            row.line2:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
            row.line2:SetPoint("RIGHT", row.b3, "LEFT", -8, 0)
            row.line3 = U.Text(row, "GameFontHighlightSmall")
            row.line3:SetPoint("TOPLEFT", row.line2, "BOTTOMLEFT", 0, -3)
            row.line3:SetPoint("RIGHT", row.b3, "LEFT", -8, 0)
            row.line4 = U.Text(row, "GameFontHighlightSmall")
            row.line4:SetPoint("TOPLEFT", row.line3, "BOTTOMLEFT", 0, -3)
            row.line4:SetPoint("RIGHT", row.b3, "LEFT", -8, 0)
            -- Every line is bounded on the right by the buttons, so none of them can run underneath
            -- one and come back out the other side.
            row.lines = { row.line2, row.line3, row.line4 }
            -- What the offer comes to, over the button that accepts it. One point, so it sizes to
            -- its text and grows left from the right edge - it cannot reach the lines, which all
            -- stop short of the buttons.
            row.total = U.Text(row, "GameFontNormal")
            row.total:SetPoint("BOTTOMRIGHT", row.b1, "TOPRIGHT", 0, 3)
        end,
        function(row, o, index)
            row.bg:SetShown(index % 2 == 0)
            row.owner = nil
            -- Rows are reused, so last row's money must not sit over this row's Accept.
            row.total:SetText("")
            if o.heading then
                row.icon:Hide()
                row.title:SetText("|cffe6b34d" .. o.heading .. "|r")
                SetLines(row, "|cff8a8a8aGuildies posted these under Wanted, and one of your recipes makes them.|r")
                SetButton(row.b1, nil); SetButton(row.b2, nil); SetButton(row.b3, nil)
                return
            end
            row.icon:Show()
            if o.want then
                local w = o.want
                row.owner = w.owner
                row.icon:SetKey(w.key)
                row.title:SetText(GH.Listings.WantText(w.w, C.KeyColor(w.key) .. (I.Name(w.key) or "...") .. "|r"))
                local who = GH.IsOnline(w.owner) and GH.ColorName(w.owner, w.class)
                    or ("|cff8a8a8a" .. GH.Short(w.owner) .. "|r")
                local note = (w.w.note and w.w.note ~= "") and ("|cffbbbbbb\"" .. w.w.note .. "\"|r") or ""
                SetLines(row,
                    ("wanted by %s  |cff6a6a6a%s|r"):format(who, GH.Ago(w.w.posted)),
                    note,
                    ("|cff60d060You can make it (%s).|r"):format(w.prof))
                local online = GH.IsOnline(w.owner)
                SetButton(row.b1, online and "Whisper" or "Offline", online and function() U.Whisper(w.owner, w.key) end or nil)
                row.b1:SetEnabled(online)
                SetButton(row.b2, "Show item", function() GH.ShowWanted(w.key) end)
                SetButton(row.b3, "I'll make it", function() GH.Listings.OfferWant(w.owner, w.key, w.w) end)
                return
            end
            row.icon:SetKey(o.item)
            row.title:SetText(("%s%s|r |cffffffffx%d|r"):format(C.KeyColor(o.item), I.Name(o.item) or "...", o.qty or 1))
            local incoming = side == "incoming"
            local other = incoming and o.requester or o.crafter
            row.owner = other
            local roster = GH.roster[other]
            local who = GH.IsOnline(other) and GH.ColorName(other, roster and roster.class) or ("|cff8a8a8a" .. GH.Short(other) .. "|r")
            local status = (incoming and IN_STATUS or OUT_STATUS)[o.status] or o.status
            if not incoming and o.status == "sending" and (o.tries or 0) >= 3 then
                status = status .. " |cff8a8a8a(they may not have Guildhall)|r"
            end
            local note = (o.note and o.note ~= "") and ("|cffbbbbbb\"" .. o.note .. "\"|r") or ""
            -- Which kind, on the line that already says who and when. A craft order reads as it
            -- always did; an offer says so, and says what for. The note is NOT on this line: it is
            -- the one part written by a person, and sharing a line with five generated facts is
            -- what left it as "demo - nobody really s...".
            local what = ""
            if o.kind == "buy" then
                what = (o.price or 0) > 0
                    and ("|cffffd100offer %s each|r  "):format(GH.Money(o.price))
                    or "|cffffd100offer to buy|r  "
            end
            SetLines(row,
                ("%s%s %s  |cff6a6a6a%s|r  %s"):format(what, incoming and "from" or "to", who,
                    GH.Ago(o.created), status),
                note,
                MaterialsText(o))
            -- The number the decision is actually made on. For a single item "each" already is the
            -- total, so it says the price plainly rather than the same figure labelled twice.
            if o.kind == "buy" and (o.price or 0) > 0 then
                local qty = o.qty or 1
                row.total:SetText(qty > 1
                    and ("|cffffd100%s|r |cff8a8a8atotal|r"):format(GH.Money(o.price * qty))
                    or ("|cffffd100%s|r"):format(GH.Money(o.price)))
            end

            local finished = O.FINISHED[o.status]
            local whisper = GH.IsOnline(other) and function() U.Whisper(other, o.item) end or nil
            if incoming then
                if o.status == "new" then
                    SetButton(row.b3, "Accept", function() O.SetStatus(o.oid, "accepted") end)
                    SetButton(row.b2, "Decline", function() O.SetStatus(o.oid, "declined") end)
                elseif o.status == "accepted" then
                    SetButton(row.b3, "Done", function() O.SetStatus(o.oid, "done") end)
                    SetButton(row.b2, "Decline", function() O.SetStatus(o.oid, "declined") end)
                else
                    SetButton(row.b3, nil)
                    SetButton(row.b2, "Remove", function() O.Remove(o.oid) end)
                end
            else
                SetButton(row.b3, nil)
                if finished then
                    SetButton(row.b2, "Remove", function() O.Remove(o.oid) end)
                else
                    SetButton(row.b2, "Cancel", function() O.Cancel(o.oid) end)
                end
            end
            -- Label first, then enable state, so a disabled button still reads.
            SetButton(row.b1, whisper and "Whisper" or "Offline", whisper)
            row.b1:SetEnabled(whisper ~= nil)
        end)
    f.list:SetPoint("TOPLEFT", 4, -4)
    f.list:SetPoint("BOTTOMRIGHT", -4, 4)

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("CENTER", box, "CENTER")
    f.empty:SetWidth(420)
end

-- "Orders", not "Requests" and no longer "Craft orders": a wanted post is a request too, so
-- that name made it look as though it belonged here, and this tab now holds offers to buy as
-- well as jobs to craft. The id stays - it is what /gh requests, GH.ShowTab and the minimap
-- button all ask for, and renaming an identifier to match a label breaks three things to
-- tidy one.
GH.RegisterTab("requests", "Orders", Build, Refresh)
