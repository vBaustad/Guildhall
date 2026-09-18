-- Guildhall - main window: header, tabs, and refresh plumbing shared by every tab.
local ADDON, GH = ...
local U = GH.UI

local W, H = 800, 580
local win
local tabs = {}         -- ordered { id, label, frame, build, refresh }
local tabById = {}
local activeTab

function GH.RegisterTab(id, label, build, refresh)
    local t = { id = id, label = label, build = build, refresh = refresh }
    tabs[#tabs + 1] = t
    tabById[id] = t
end

local function RefreshActive()
    if not win or not win:IsShown() then return end
    local t = tabById[activeTab]
    if t and t.frame and t.refresh then t.refresh(t.frame) end
    -- Header status line
    local guild = GH.GuildName()
    if not guild then
        win.status:SetText("|cffff6060Not in a guild|r")
    else
        local g = GH.GuildDB()
        local n = 0
        if g then for _ in pairs(g.members) do n = n + 1 end end
        local online = 0
        for full in pairs(GH.Sync.peers) do if GH.IsOnline(full) then online = online + 1 end end
        win.status:SetText(("|c%s<%s>|r  |cff8a8a8a%d guildies shared, %d online|r"):format(GH.CREAM, guild, n, online))
    end
    local newCount = GH.Orders.NewCount()
    win.tabs:SetLabel("requests", newCount > 0 and ("Requests |cffff6060(" .. newCount .. ")|r") or "Requests")
end

function GH.RefreshWindow()
    GH.Coalesce("uiRefresh", 0.2, RefreshActive)
end

local function SelectTab(id)
    activeTab = id
    for _, t in ipairs(tabs) do
        if t.id == id then
            if not t.frame then
                t.frame = CreateFrame("Frame", nil, win.body)
                t.frame:SetAllPoints()
                t.build(t.frame)
            end
            t.frame:Show()
        elseif t.frame then
            t.frame:Hide()
        end
    end
    win.tabs:Select(id)
    RefreshActive()
end

local function Build()
    if win then return end
    -- Laid out like Blizzard's Options panel: title bar, tabs, content, red Close button.
    win = U.Window("GuildhallFrame", UIParent, W, H, "Guildhall")
    win:SetFrameStrata("HIGH")
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        GH.Settings().pos = { x = self:GetLeft(), y = self:GetTop() }
    end)

    local pos = GH.Settings().pos
    if pos and pos.x then
        win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        win:SetPoint("CENTER")
    end

    local items = {}
    for _, t in ipairs(tabs) do items[#items + 1] = { value = t.id, label = t.label } end
    win.tabs = U.Tabs(win, items, SelectTab)
    win.tabs:SetPoint("TOPLEFT", 32, -27)

    local divider = win:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 18, -64)
    divider:SetPoint("TOPRIGHT", -20, -64)

    win.body = CreateFrame("Frame", nil, win)
    win.body:SetPoint("TOPLEFT", 22, -74)
    win.body:SetPoint("BOTTOMRIGHT", -24, 48)

    local close = U.Button(win, CLOSE or "Close", 96, 22)
    close:SetPoint("BOTTOMRIGHT", -16, 16)
    close:GetFontString():SetFontObject("GameFontNormal")
    close:SetScript("OnClick", function() win:Hide() end)

    win.status = U.Text(win, "GameFontHighlightSmall")
    win.status:SetPoint("LEFT", win, "BOTTOMLEFT", 24, 27)
    win.status:SetPoint("RIGHT", close, "LEFT", -12, 0)

    win:SetScript("OnShow", function()
        GH.RequestRoster()
        RefreshActive()
    end)
    win:Hide()
end

function GH.ShowTab(id)
    Build()
    win:Show()
    SelectTab(tabById[id] and id or tabs[1].id)
end

function GH.ToggleWindow()
    Build()
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
        SelectTab(activeTab or tabs[1].id)
    end
end

function GH.WindowShown(tabId)
    return win and win:IsShown() and (not tabId or activeTab == tabId)
end

for _, name in ipairs({ "DATA_CHANGED", "ORDERS_CHANGED", "ROSTER", "NAMES_LOADED", "MY_SCANNED", "PEER_SEEN", "GUILD_CHANGED" }) do
    GH.Listen(name, GH.RefreshWindow)
end
