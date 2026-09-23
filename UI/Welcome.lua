-- Guildhall - intro page in LibForever's shared YippYapp welcome window.
local ADDON, GH = ...
local U = GH.UI
local LIB = LibStub and LibStub("LibForever-1.0", true)

local POINTS = {
    { "Your recipes are shared on their own",
      "When you log in, Guildhall shares your professions and recipes with your guild. Every guildie with "
      .. "Guildhall does the same. There's nothing to fill in." },
    { "Find who can make it",
      "Search anything the guild can craft, has or wants. Item tooltips list guild crafters too." },
    { "Ask for a craft",
      "Send a craft request, even to someone offline: it is delivered when they log in. "
      .. "Offer spares under \"Guildies have it\" and post what you need under \"Wanted\"." },
}

-- What still keeps Guildhall from being useful: no guild to share with, or a crafting profession whose
-- recipes only its own window can list. Listings and wanted posts are optional, so they don't count.
-- Returns the reason for the card, and the action to put on its button.
local function SetupState()
    if not IsInGuild() then return "join a guild to share with", "Join a guild" end
    local d = GH.MyData()
    for id in pairs(d and d.profs or {}) do
        if not GH.Scan.GATHERING_LINES[id] and not GH.Scan.HasStaticRecipes(id) and not d.profs[id].recipes then
            local name = GH.ProfName(id)
            return ("open your %s window once"):format(name), ("Open your %s window"):format(name)
        end
    end
    return nil
end

local function Build(page)
    local width = page:GetWidth() - 16
    local y = -4
    for _, point in ipairs(POINTS) do
        local head = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        head:SetPoint("TOPLEFT", 8, y)
        head:SetText(point[1])
        local body = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
        body:SetWidth(width)
        body:SetJustifyH("LEFT")
        body:SetText(point[2])
        y = y - 26 - body:GetStringHeight() - 10
    end

    local where = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    where:SetPoint("TOPLEFT", 8, y - 4)
    where:SetWidth(width)
    where:SetJustifyH("LEFT")
    where:SetText("Click the Guildhall icon on the minimap - behind the YippYapp button if you use several "
        .. "YippYapp addons - or type |cffffd100/gh|r. Only your guild sees what you share.")

    local open = U.Button(page, "Open Guildhall", 140, 24)
    open:SetNormalFontObject("GameFontNormal")
    open:SetHighlightFontObject("GameFontHighlight")
    open:SetPoint("TOPLEFT", where, "BOTTOMLEFT", 0, -14)
    open:SetScript("OnClick", function() GH.ShowTab("browse") end)
end

GH.Listen("LOGIN", function()
    if not (LIB and LIB.RegisterWelcome) then return end
    LIB.RegisterWelcome({
        id = "Guildhall", title = "Guildhall", version = 1, order = 10,
        icon = "Interface\\AddOns\\Guildhall\\Media\\icon",
        subtitle = "Your guild's crafting directory: who can make what, and a way to ask them.",
        blurb = "See who in your guild can craft what, who has a spare, and ask them - without asking in chat.",
        needsSetup = function() return SetupState() ~= nil end,
        reason = function() return (SetupState()) end,
        -- The button names the step that's actually missing, matching the reason next to it.
        setupLabel = function() return select(2, SetupState()) end,
        onOpen = function() GH.ShowTab("browse") end,
        build = Build,
    }, GH.DB())
end)
