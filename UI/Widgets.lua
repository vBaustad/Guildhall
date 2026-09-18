-- Guildhall - shared UI building blocks, in the style of Blizzard's Options panel.
local ADDON, GH = ...
local C = GH.Codec
local U = {}
GH.UI = U


-- Windows wear the same frame as Blizzard's Options panel. Forever swaps the art behind
-- Blizzard's atlas names, so these templates come out in Forever's bronze automatically.
function U.Window(name, parent, w, h, title)
    local f = CreateFrame("Frame", name, parent or UIParent, "SettingsFrameTemplate")
    f:SetSize(w, h)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f.NineSlice.Text:SetText(title or "")
    -- The template's own backdrop is a flat translucent grey; give it Forever's stained-wood
    -- panel instead (the Options panel gets the same look from its inner-frame art).
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 7, -18)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)
    bg:SetAtlas("heavybronze-frame-background")
    f.Bg:Hide()
    if name then tinsert(UISpecialFrames, name) end
    return f
end

-- Recessed box with the Options panel's bronze inset border.
function U.Inset(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.03, 0.02, 0.01, 0.4)
    f:SetBackdropBorderColor(0.85, 0.80, 0.70, 1)
    return f
end

-- Tabs like the Options panel's Game / AddOns tabs. items = { { value, label } };
-- returns a control with :Select(value, fire) and :SetLabel(value, text).
function U.Tabs(parent, items, onSelect)
    local ctl = { buttons = {} }
    local prev
    for _, item in ipairs(items) do
        local b = CreateFrame("Button", nil, parent, "MinimalTabTemplate")
        b:SetHeight(37)
        b.value = item.value
        b.Text:SetText(item.label)
        b:SetWidth(b.Text:GetStringWidth() + 40)
        if prev then b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 5, 0) end
        b:SetScript("OnClick", function() ctl:Select(item.value, true) end)
        ctl.buttons[#ctl.buttons + 1] = b
        prev = b
    end
    function ctl:SetPoint(...) self.buttons[1]:SetPoint(...) end
    function ctl:Select(value, fire)
        self.value = value
        for _, b in ipairs(self.buttons) do b:SetSelected(b.value == value) end
        if fire and onSelect then onSelect(value) end
    end
    function ctl:SetLabel(value, text)
        for _, b in ipairs(self.buttons) do
            if b.value == value then
                b.Text:SetText(text)
                b:SetWidth(b.Text:GetStringWidth() + 40)
            end
        end
    end
    return ctl
end

function U.Text(parent, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function U.Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 80, h or 20)
    b:SetText(text)
    local fs = b:GetFontString()
    if fs then fs:SetFontObject("GameFontNormalSmall") end
    return b
end

function U.Tooltip(widget, title, ...)
    local lines = { ... }
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 0.82, 0.3)
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function U.EditBox(parent, w, placeholder, numeric)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetAutoFocus(false)
    e:SetFontObject("ChatFontSmall")
    if numeric then e:SetNumeric(true) end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if placeholder then
        local ph = e:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        ph:SetPoint("LEFT", 2, 0)
        ph:SetText(placeholder)
        e.placeholder = ph
        local function update() ph:SetShown(e:GetText() == "" and not e:HasFocus()) end
        e:HookScript("OnTextChanged", update)
        e:HookScript("OnEditFocusGained", update)
        e:HookScript("OnEditFocusLost", update)
    end
    return e
end

function U.Checkbox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local l = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    l:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    l:SetText(label)
    cb.label = l
    return cb
end

-- Row of choices styled like the Options panel's category list: the selected one gets the
-- list's highlight bar. onSelect(value). Returns control with :Select(value), :SetLabel(value, text).
function U.Segmented(parent, items, width, onSelect)
    local ctl = CreateFrame("Frame", nil, parent)
    local segW = math.floor(width / #items)
    ctl:SetSize(segW * #items, 22)
    ctl.buttons = {}
    for i, item in ipairs(items) do
        local b = CreateFrame("Button", nil, ctl)
        b:SetSize(segW - 2, 22)
        b:SetPoint("LEFT", (i - 1) * segW, 0)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetAtlas("Options_List_Active")
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetAtlas("Options_List_Hover")
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        fs:SetText(item.label)
        b.fs = fs
        b.value = item.value
        b:SetScript("OnClick", function() ctl:Select(item.value, true) end)
        ctl.buttons[i] = b
    end
    function ctl:Select(value, fire)
        self.value = value
        for _, b in ipairs(self.buttons) do
            local on = b.value == value
            b.bg:SetShown(on)
            b.fs:SetFontObject(on and "GameFontHighlightSmall" or "GameFontNormalSmall")
        end
        if fire and onSelect then onSelect(value) end
    end
    function ctl:SetLabel(value, text)
        for _, b in ipairs(self.buttons) do
            if b.value == value then b.fs:SetText(text) end
        end
    end
    ctl:Select(items[1].value)
    return ctl
end

-- Square icon button that shows the key's tooltip and shift-click links it.
function U.KeyIcon(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.tex = t
    b:SetScript("OnEnter", function(self)
        if not self.key and not self.itemString then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        C.SetTooltip(GameTooltip, self.key, self.itemString)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local link = self.itemString and select(2, GH.API.GetItemInfo(self.itemString)) or (self.key and C.KeyLink(self.key))
        if link and IsModifiedClick() then HandleModifiedItemClick(link) end
    end)
    function b:SetKey(key, itemString)
        self.key, self.itemString = key, itemString
        self.tex:SetTexture(key and C.KeyIcon(key) or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    end
    return b
end

-- Open a whisper to someone, optionally with an item link typed in.
function U.Whisper(full, key)
    local target = GH.Short(full)
    local link = key and C.KeyLink(key)
    local text = "/w " .. target .. " " .. (link and (link .. " ") or "")
    if ChatFrameUtil and ChatFrameUtil.OpenChat then
        ChatFrameUtil.OpenChat(text)
    elseif ChatFrame_OpenChat then
        ChatFrame_OpenChat(text)
    end
end

-- Fixed pool of rows inside a FauxScrollFrame. build(row) makes one; fill(row, data) paints it.
function U.ScrollList(parent, rowHeight, numRows, build, fill)
    local list = CreateFrame("Frame", nil, parent)
    local scroll = CreateFrame("ScrollFrame", nil, list, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    list.rows = {}
    for i = 1, numRows do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
        build(row, i)
        list.rows[i] = row
    end
    list.data = {}
    function list:Refresh()
        local offset = FauxScrollFrame_GetOffset(scroll)
        FauxScrollFrame_Update(scroll, #self.data, numRows, rowHeight)
        for i, row in ipairs(self.rows) do
            local item = self.data[i + offset]
            if item then
                row:Show()
                fill(row, item, i + offset)
            else
                row:Hide()
            end
        end
    end
    function list:SetData(data)
        self.data = data or {}
        self:Refresh()
    end
    scroll:SetScript("OnVerticalScroll", function(self, value)
        FauxScrollFrame_OnVerticalScroll(self, value, rowHeight, function() list:Refresh() end)
    end)
    list.scroll = scroll
    return list
end

-- Gold section heading with the Options panel's divider under it.
function U.Heading(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetAtlas("Options_HorizontalDivider")
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    fs.line = line
    return fs
end
