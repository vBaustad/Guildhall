-- Guildhall - main window: header, tabs, and refresh plumbing shared by every tab.
local ADDON, GH = ...
local U = GH.UI

local W, H = 800, 600
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
        win.status:SetText("|cff8a8a8aNot in a guild|r")
    else
        local g = GH.GuildDB()
        local n = 0
        if g then for _ in pairs(g.members) do n = n + 1 end end
        local online = 0
        for full in pairs(GH.Sync.peers) do if GH.IsOnline(full) then online = online + 1 end end
        local shared
        if GH.Sync.syncing then
            shared = ("syncing with your guild... %s online with Guildhall"):format(GH.Count(online, "guildie"))
        elseif n == 0 and online > 0 then
            -- Guildies answered but haven't sent their profile yet: don't claim you're alone.
            shared = ("%s online with Guildhall - waiting for what they share"):format(GH.Count(online, "guildie"))
        elseif n == 0 then
            shared = "only you so far"
        else
            -- Two separate facts: what you have (kept for good) and who happens to be online now.
            shared = ("%s shared with you, %d online with Guildhall"):format(GH.Count(n, "guildie"), online)
        end
        win.status:SetText(("|c%s<%s>|r  |cff8a8a8a%s|r"):format(GH.CREAM, guild, shared))
    end
    local todo = GH.Orders.NewCount() + #GH.Index.WantsICanMake()
    win.tabs:SetLabel("requests", todo > 0 and ("Requests |cffff6060(" .. todo .. ")|r") or "Requests")
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
    win:SetPoint("CENTER")
    -- LibForever handles strata, raising, dragging, the saved position (Settings().pos) and Esc, so our
    -- windows never blend into each other when they overlap.
    local LIB = LibStub and LibStub("LibForever-1.0", true)
    if LIB and LIB.RegisterWindow then LIB.RegisterWindow(win, GH.Settings(), "pos") end

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
    close:SetNormalFontObject("GameFontNormal")
    close:SetHighlightFontObject("GameFontHighlight")
    close:SetScript("OnClick", function() win:Hide() end)

    -- Settings have one home (the YippYapp window, or our own tab without LibForever); this is the
    -- way there from inside Guildhall, so the tab strip stays about the guild.
    local settings = U.Button(win, "Settings", 96, 22)
    settings:SetPoint("RIGHT", close, "LEFT", -8, 0)
    settings:SetNormalFontObject("GameFontNormal")
    settings:SetHighlightFontObject("GameFontHighlight")
    settings:SetScript("OnClick", function() GH.OpenOptions() end)

    win.status = U.Text(win, "GameFontHighlightSmall")
    win.status:SetPoint("LEFT", win, "BOTTOMLEFT", 24, 27)
    win.status:SetPoint("RIGHT", settings, "LEFT", -12, 0)

    -- HookScript: LibForever's RegisterWindow already hooked OnShow (raise, place, Esc).
    win:HookScript("OnShow", RefreshActive)
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

for _, name in ipairs({ "DATA_CHANGED", "ORDERS_CHANGED", "ROSTER", "NAMES_LOADED", "MY_SCANNED", "PEER_SEEN", "GUILD_CHANGED", "SYNC_STATE" }) do
    GH.Listen(name, GH.RefreshWindow)
end
