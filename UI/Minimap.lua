-- Guildhall - minimap button, through LibForever's LibDBIcon helper (standard ring geometry).
local ADDON, GH = ...
local LIB = LibStub and LibStub("LibForever-1.0", true)

local function OnClick(_, button)
    if button == "RightButton" then
        GH.OpenOptions()
    elseif GH.Orders.NewCount() > 0 then
        GH.ShowTab("requests")
    else
        GH.ToggleWindow()
    end
end

local function OnTooltipShow(tt)
    tt:AddLine("Guildhall", 1, 0.82, 0.3)
    -- LibDBIcon has no badge, so new craft requests are counted here (and on the Requests tab).
    local n = GH.Orders.NewCount()
    if n > 0 then tt:AddLine(GH.Count(n, "new craft request"), 1, 0.4, 0.4) end
    tt:AddLine("Left-click: open", 0.8, 0.8, 0.8)
    tt:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
    tt:AddLine("Drag: move around the minimap", 0.6, 0.6, 0.6)
end

local function Build()
    if not (LIB and LIB.RegisterMinimapButton) then return end
    local settings = GH.Settings()
    local ok = LIB.RegisterMinimapButton("Guildhall", {
        icon = "Interface\\AddOns\\Guildhall\\Media\\minimap",
        label = "Guildhall",
        OnClick = OnClick,
        OnTooltipShow = OnTooltipShow,
        migrateAngle = settings.minimapAngle,  -- the old hand-made button's angle, same convention
    }, settings)
    if not ok then return end   -- LibDBIcon missing: keep the old values for next time
    settings.minimapAngle = nil   -- migrated into settings.minimap
    -- One-time move of the old show/hide setting into LibDBIcon's saved state.
    if settings.hideMinimap ~= nil then
        LIB.SetMinimapButtonShown("Guildhall", not settings.hideMinimap)
        settings.hideMinimap = nil
    end
end

-- Addon compartment (the addons button by the minimap on the modern client), wired from the .toc.
function Guildhall_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then
        GH.OpenOptions()
    elseif GH.Orders.NewCount() > 0 then
        GH.ShowTab("requests")
    else
        GH.ToggleWindow()
    end
end

function Guildhall_OnAddonCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip:AddLine("Guildhall", 1, 0.82, 0.3)
    local n = GH.Orders.NewCount()
    if n > 0 then GameTooltip:AddLine(GH.Count(n, "new craft request"), 1, 0.4, 0.4) end
    GameTooltip:AddLine("Left-click: open", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function Guildhall_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-- The shared launcher notch (LibForever): one bar on the screen edge for all our addons.
local function RegisterNotch()
    if not LIB or not LIB.RegisterLauncher then return end
    LIB.RegisterLauncher({
        id = "Guildhall", label = "Guildhall", order = 10,
        icon = "Interface\\AddOns\\Guildhall\\Media\\notch",
        onClick = function(button) Guildhall_OnAddonCompartmentClick(nil, button) end,
        -- The launcher never shows notifications; new craft requests are counted on the Requests tab
        -- and in the minimap button's tooltip.
        tooltip = { "Left-click: open", "Right-click: settings" },
    }, GH.DB())
end

GH.Listen("LOGIN", Build)
GH.Listen("LOGIN", RegisterNotch)
