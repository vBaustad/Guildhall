-- Guildhall - settings. The same page is built twice: as the Settings tab in Guildhall's own
-- window, and in Blizzard's Options -> AddOns -> Guildhall.
local ADDON, GH = ...
local U = GH.UI


local function Build(f)
    local checks = {}
    f.checks = checks
    local head = U.Heading(f, "Guildhall")
    head:SetFontObject("GameFontNormalLarge")
    head:SetPoint("TOPLEFT", 8, -6)
    local sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
    sub:SetWidth(600)
    sub:SetJustifyH("LEFT")
    sub:SetText("Your guild's crafting directory: who can make what, items guildies have, wanted posts and craft requests.")

    local y = -52
    local function checkbox(label, get, set)
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("TOPLEFT", 8, y)
        local l = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        l:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        l:SetText(label)
        cb.get = get
        cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
        checks[#checks + 1] = cb
        y = y - 28
        return cb
    end
    local function setting(key)
        return function() return GH.Settings()[key] end, function(v) GH.Settings()[key] = v end
    end

    local h1 = U.Heading(f, "Tooltips & notifications")
    h1:SetPoint("TOPLEFT", 8, y)
    y = y - 24
    checkbox("Show guild crafters and listings on item tooltips", setting("tooltip"))
    checkbox("Notify me when a guildie asks me to craft something", setting("notifyRequests"))
    checkbox("Tell me when a guildie wants something I can craft", setting("notifyWanted"))

    y = y - 8
    local h3 = U.Heading(f, "Minimap & launcher")
    h3:SetPoint("TOPLEFT", 8, y - 102)
    local listingsY = y
    y = y - 126
    checkbox("Show the minimap button",
        function() return not GH.Settings().hideMinimap end,
        function(v)
            GH.Settings().hideMinimap = not v
            GH.UpdateMinimap()
        end)
    local LIB = LibStub and LibStub("LibForever-1.0", true)
    if LIB and LIB.LauncherOptions then
        local launcher = LIB.LauncherOptions(f, "Guildhall")
        launcher:SetPoint("TOPLEFT", 8, y)
    end

    y = listingsY
    local h2 = U.Heading(f, "Listings")
    h2:SetPoint("TOPLEFT", 8, y)
    y = y - 50

    -- A template-free slider: OptionsSliderTemplate is deprecated on the modern client.
    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetSize(260, 16)
    s:SetPoint("TOPLEFT", 14, y)
    s:SetOrientation("HORIZONTAL")
    s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(3, 30)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 6)
    local low = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
    low:SetText("3 days")
    local high = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
    high:SetText("30 days")
    local function label(v) title:SetText(("Listings expire after %d days"):format(v)) end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        GH.Settings().listingDays = v
        label(v)
    end)
    f.slider, f.sliderLabel = s, label

    local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 8, 6)
    hint:SetPoint("RIGHT", f, "RIGHT", -150, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("|cffffd100/gh|r opens Guildhall.  |cffffd100/gh search <item>|r searches.  |cffffd100/gh status|r shows sync status.\n"
        .. "Everything is shared only with your guild, over the guild addon channel.")
end

local function Refresh(f)
    for _, cb in ipairs(f.checks) do cb:SetChecked(cb.get() and true or false) end
    local days = GH.Settings().listingDays or 14
    f.slider:SetValue(days)
    f.sliderLabel(days)
end

function GH.OpenOptions()
    GH.ShowTab("settings")
end

GH.RegisterTab("settings", "Settings", Build, Refresh)

-- Blizzard's Options -> AddOns -> Guildhall.
local function RegisterBlizzardPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", -10, 10)
    Build(page)
    local open = GH.UI.Button(page, "Open Guildhall", 130, 22)
    open:SetPoint("BOTTOMRIGHT", -4, 4)
    open:SetScript("OnClick", function()
        -- The Options panel is protected in combat; leave it open then.
        if SettingsPanel and SettingsPanel:IsShown() and not InCombatLockdown() then SettingsPanel:Close() end
        GH.ShowTab("browse")
    end)
    panel:SetScript("OnShow", function() Refresh(page) end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Guildhall")
    Settings.RegisterAddOnCategory(category)
end

GH.Listen("LOGIN", RegisterBlizzardPanel)
