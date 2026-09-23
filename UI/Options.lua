-- Guildhall - settings. The same page is built twice: as the Settings tab in Guildhall's own
-- window, and in Blizzard's Options -> AddOns -> Guildhall. Minimap and launcher buttons are not
-- here: they live on the shared YippYapp page (LibForever), linked at the bottom.
local ADDON, GH = ...
local U = GH.UI
local LIB = LibStub and LibStub("LibForever-1.0", true)

local SECTION_GAP = 8   -- extra air above each heading

local function Build(f, extraButton)
    local checks = {}
    f.checks = checks
    -- Everything stacks under the previous element; x is the left edge within the page.
    local last, lastX
    local function place(region, gap, x)
        region:SetPoint("TOPLEFT", last, "BOTTOMLEFT", x - lastX, -gap)
        last, lastX = region, x
    end

    -- Title, version and what Guildhall does.
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetText("Guildhall")
    local version = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. GH.VERSION)
    local sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("Your guild's crafting directory: who can make what, items guildies have, wanted posts and "
        .. "craft requests. Open it with |cffffd100/gh|r.")
    last, lastX = sub, 8

    local function heading(text)
        place(U.Heading(f, text), SECTION_GAP + 6, 8)
    end

    -- Checkbox with its explanation in the tooltip.
    local function checkbox(label, tip, key)
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        local follows = last.isCheck
        place(cb, follows and 2 or 6, 4)
        cb.isCheck = true
        local l = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        l:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        l:SetText(label)
        cb.get = function() return GH.Settings()[key] end
        cb:SetScript("OnClick", function(self) GH.Settings()[key] = self:GetChecked() and true or false end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label, 1, 0.82, 0.3)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        checks[#checks + 1] = cb
    end

    -- Most-used first: what you see on items, then what pings you, then your own listings.
    heading("Item tooltips")
    checkbox("Show guild crafters and listings on item tooltips",
        "Hover any item to see which guildies can craft it, who has one to spare and who wants one.", "tooltip")

    heading("Notifications")
    checkbox("Notify me when a guildie asks me to craft something",
        "A chat line and a sound when a craft request arrives, including requests sent while you were offline.",
        "notifyRequests")
    checkbox("Tell me when a guildie wants something I can craft",
        "A chat line when someone posts a wanted item that one of your recipes makes.", "notifyWanted")

    heading("Your listings")
    -- A template-free slider: OptionsSliderTemplate is deprecated on the modern client.
    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetSize(260, 16)
    place(s, 30, 14)
    s:SetOrientation("HORIZONTAL")
    s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(3, 30)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 6)
    local low = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
    low:SetText("3 days")
    local high = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
    high:SetText("30 days")
    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", s, "RIGHT", 16, 0)
    hint:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Offers you post under \"Guildies have it\" disappear after this long. They also go away "
        .. "once the item leaves your bags.")
    local function setLabel(v) label:SetText(("Listings expire after %d days"):format(v)) end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        GH.Settings().listingDays = v
        setLabel(v)
    end)
    f.slider, f.sliderLabel = s, setLabel
    last = low  -- same left edge as the slider

    -- Personal lists: one summary line each, and a menu to take entries off.
    heading("Private lists")
    local function listLine(label, tip, entries, removeLabel, remove)
        local b = U.Button(f, label, 150, 22)
        place(b, 8, 8)
        local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", b, "RIGHT", 10, 0)
        text:SetPoint("RIGHT", f, "RIGHT", -8, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        b:SetScript("OnClick", function(self)
            local list = entries()
            if #list == 0 or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle(removeLabel)
                for _, e in ipairs(list) do
                    root:CreateButton(e.label, function()
                        remove(e.value)
                        for _, update in ipairs(f.lists) do update() end
                    end)
                end
            end)
        end)
        U.Tooltip(b, label, tip)
        f.lists = f.lists or {}
        f.lists[#f.lists + 1] = function()
            local list = entries()
            local names = {}
            for i, e in ipairs(list) do
                if i > 6 then names[#names + 1] = ("and %d more"):format(#list - 6) break end
                names[#names + 1] = e.label
            end
            text:SetText(#list == 0 and "|cff8a8a8anone|r" or table.concat(names, ", "))
            b:SetEnabled(#list > 0)
        end
    end
    listLine("Blocked players...", "Right-click a name in Browse or Requests to block someone. Their posts and "
        .. "craft requests are hidden from you. Nothing is sent - they can't tell.",
        function()
            local out = {}
            for _, full in ipairs(GH.BlockedList()) do out[#out + 1] = { label = GH.Short(full), value = full } end
            return out
        end, "Unblock", function(full) GH.SetBlocked(full, false) end)
    listLine("Don't share...", "Right-click an item under Your posts in My Guildhall. Items on this list are "
        .. "never offered to the guild. Take one off to offer it again.",
        function()
            local out = {}
            for _, id in ipairs(GH.NoShareList()) do
                out[#out + 1] = { label = GH.Index.Name(id) or ("item " .. id), value = id }
            end
            return out
        end, "Share again", function(id) GH.SetNoShare(id, false) end)

    -- Bottom: a way into Guildhall and the family footer. The minimap and launcher choices live in the
    -- YippYapp window's own settings view, so they aren't repeated here.
    -- No "Welcome / what's new" button here: this page lives in the YippYapp window, which has one.
    local buttons = {}
    if extraButton then buttons[#buttons + 1] = extraButton(f) end
    for i, b in ipairs(buttons) do
        if i == 1 then place(b, SECTION_GAP + 14, 8) else b:SetPoint("LEFT", buttons[i - 1], "RIGHT", 8, 0) end
    end
    if LIB and LIB.WelcomePsstText then
        local psst = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        place(psst, 14, 10)
        psst:SetPoint("RIGHT", f, "RIGHT", -8, 0)
        psst:SetJustifyH("LEFT")
        psst:SetSpacing(2)
        f.psst = psst
    end
end

local function Refresh(f)
    for _, cb in ipairs(f.checks) do cb:SetChecked(cb.get() and true or false) end
    local days = GH.Settings().listingDays or 14
    f.slider:SetValue(days)
    f.sliderLabel(days)
    if f.psst then f.psst:SetText(LIB.WelcomePsstText("Guildhall")) end
    for _, update in ipairs(f.lists or {}) do update() end
end

-- Settings live in one place: the YippYapp window. Only if that page can't be hosted does Guildhall
-- fall back to a Settings tab of its own, so the options are never out of reach.
local hosted = false

local function UseOwnTab()
    GH.RegisterTab("settings", "Settings", Build, Refresh)
end

function GH.OpenOptions()
    if hosted then
        LIB.OpenAddonSettings("Guildhall")
    else
        GH.ShowTab("settings")
    end
end

-- Blizzard's Options -> AddOns -> Guildhall: the same page, plus a way into the window.
local function OpenGuildhallButton(parent)
    local open = U.Button(parent, "Open Guildhall", 130, 22)
    -- Only opens our window. Never close Blizzard's Settings from here: SettingsPanel:Close() goes back
    -- to the game menu through the protected SpellStopCasting (ADDON_ACTION_FORBIDDEN). LibForever
    -- lays our window over Settings instead.
    open:SetScript("OnClick", function() GH.ShowTab("browse") end)
    return open
end

-- Taller than the YippYapp window's page area, so the lib gives it a scroll bar.
local PAGE_HEIGHT = 500

local function RegisterBlizzardPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        UseOwnTab()
        return
    end
    local panel = CreateFrame("Frame")
    -- The lib reparents and sizes this page inside the YippYapp window; everything inside anchors to
    -- it, so it follows whatever width it's given.
    panel:SetHeight(PAGE_HEIGHT)
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", -10, 10)
    Build(page, OpenGuildhallButton)
    -- The canvas can already count as shown when Settings adopts it, so its own OnShow may never fire:
    -- fill the values now, on Settings' own refresh, and whenever the inner page is shown.
    local function refresh() Refresh(page) end
    refresh()
    panel.OnRefresh = refresh
    panel:HookScript("OnShow", refresh)
    page:HookScript("OnShow", refresh)
    -- Hosted in the YippYapp window (Blizzard's Options -> AddOns -> YippYapp is one button now).
    -- The handle's GetID() is nil on purpose: never pass it to Settings.OpenToCategory.
    local handle = LIB and LIB.RegisterOptionsPage
        and LIB.RegisterOptionsPage("Guildhall", panel, "Guildhall", PAGE_HEIGHT)
    hosted = handle ~= nil and LIB.OpenAddonSettings ~= nil
    if not hosted then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "Guildhall"))
        UseOwnTab()
    end
end

GH.Listen("LOGIN", RegisterBlizzardPanel)
