-- Guildhall - Requests tab: craft requests made to you, and the ones you've sent.
local ADDON, GH = ...
local U, C, I, O = GH.UI, GH.Codec, GH.Index, GH.Orders

local view
local side = "incoming"
local ROWS, ROW_H = 7, 54

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
    local newCount = O.NewCount()
    view.sides:SetLabel("incoming", newCount > 0 and ("For you to craft |cffff6060(" .. newCount .. ")|r") or "For you to craft")
    local data = side == "incoming" and O.Incoming() or O.Outgoing()
    view.list:SetData(data)
    if #data == 0 then
        view.empty:SetText(side == "incoming"
            and "No requests yet. Guildies can ask you to craft anything you've shared."
            or "You haven't asked anyone to craft something. Find an item in Browse and press Request.")
        view.empty:Show()
    else
        view.empty:Hide()
    end
end

local function Build(f)
    view = f
    f.sides = U.Segmented(f, {
        { value = "incoming", label = "For you to craft" },
        { value = "outgoing", label = "Your requests" },
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
        end,
        function(row, o, index)
            row.bg:SetShown(index % 2 == 0)
            row.icon:SetKey(o.item)
            row.title:SetText(("%s%s|r |cffffffffx%d|r"):format(C.KeyColor(o.item), I.Name(o.item) or "...", o.qty or 1))
            local incoming = side == "incoming"
            local other = incoming and o.requester or o.crafter
            local roster = GH.roster[other]
            local who = GH.IsOnline(other) and GH.ColorName(other, roster and roster.class) or ("|cff8a8a8a" .. GH.Short(other) .. "|r")
            local status = (incoming and IN_STATUS or OUT_STATUS)[o.status] or o.status
            if not incoming and o.status == "sending" and (o.tries or 0) >= 3 then
                status = status .. " |cff8a8a8a(they may not have Guildhall)|r"
            end
            local note = (o.note and o.note ~= "") and ("  |cffbbbbbb\"" .. o.note .. "\"|r") or ""
            row.line2:SetText(("%s %s  |cff6a6a6a%s|r  %s%s"):format(incoming and "from" or "to", who, GH.Ago(o.created), status, note))
            row.line3:SetText(MaterialsText(o))

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
            SetButton(row.b1, "Whisper", whisper)
            row.b1:SetShown(true)
            row.b1:SetEnabled(whisper ~= nil)
        end)
    f.list:SetPoint("TOPLEFT", 4, -4)
    f.list:SetPoint("BOTTOMRIGHT", -4, 4)

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("CENTER", box, "CENTER")
    f.empty:SetWidth(420)
end

GH.RegisterTab("requests", "Requests", Build, Refresh)
