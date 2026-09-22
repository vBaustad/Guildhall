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

    -- Bottom: the shared YippYapp settings link, welcome, and the family footer.
    if LIB and LIB.LauncherOptions then
        place(LIB.LauncherOptions(f, "Guildhall"), SECTION_GAP + 14, 8)
    end
    local buttons = {}
    if LIB and LIB.OpenWelcome then
        local welcome = U.Button(f, "Welcome / what's new", 170, 22)
        welcome:SetScript("OnClick", function() LIB.OpenWelcome("Guildhall") end)
        buttons[#buttons + 1] = welcome
    end
    if extraButton then buttons[#buttons + 1] = extraButton(f) end
    for i, b in ipairs(buttons) do
        if i == 1 then place(b, 4, 8) else b:SetPoint("LEFT", buttons[i - 1], "RIGHT", 8, 0) end
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
end

function GH.OpenOptions()
    GH.ShowTab("settings")
end

GH.RegisterTab("settings", "Settings", Build, Refresh)

-- Blizzard's Options -> AddOns -> Guildhall: the same page, plus a way into the window.
local function OpenGuildhallButton(parent)
    local open = U.Button(parent, "Open Guildhall", 130, 22)
    -- Only opens our window. Never close Blizzard's Settings from here: SettingsPanel:Close() goes back
    -- to the game menu through the protected SpellStopCasting (ADDON_ACTION_FORBIDDEN). LibForever
    -- lays our window over Settings instead.
    open:SetScript("OnClick", function() GH.ShowTab("browse") end)
    return open
end

local function RegisterBlizzardPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", -10, 10)
    Build(page, OpenGuildhallButton)
    panel:SetScript("OnShow", function() Refresh(page) end)
    -- Under YippYapp in Options -> AddOns (the lib also links it to the YippYapp page's Settings button).
    if LIB and LIB.RegisterOptionsPage then
        LIB.RegisterOptionsPage("Guildhall", panel)
    else
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "Guildhall"))
    end
end

GH.Listen("LOGIN", RegisterBlizzardPanel)
