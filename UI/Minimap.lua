-- Guildhall - minimap button (no library), with a badge for new craft requests.
local ADDON, GH = ...

local mmb

local function UpdatePosition()
    if not mmb then return end
    local angle = math.rad(GH.Settings().minimapAngle or 200)
    local r = (Minimap:GetWidth() / 2) + 5
    mmb:ClearAllPoints()
    mmb:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(angle), r * math.sin(angle))
end

function GH.UpdateMinimap()
    if not mmb then return end
    mmb:SetShown(not GH.Settings().hideMinimap)
    local n = GH.Orders.NewCount()
    mmb.badge:SetShown(n > 0)
    mmb.badgeText:SetText(n > 9 and "9+" or tostring(n))
end

local function Build()
    if mmb then return end
    mmb = CreateFrame("Button", "GuildhallMinimapButton", Minimap)
    mmb:SetSize(31, 31)
    mmb:SetFrameStrata("MEDIUM")
    mmb:SetFrameLevel(8)
    mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mmb:RegisterForDrag("LeftButton")

    local icon = mmb:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_02")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ring = mmb:CreateTexture(nil, "OVERLAY")
    ring:SetSize(53, 53)
    ring:SetPoint("TOPLEFT")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local badge = CreateFrame("Frame", nil, mmb)
    badge:SetSize(14, 14)
    badge:SetPoint("TOPRIGHT", -1, -1)
    badge:SetFrameLevel(mmb:GetFrameLevel() + 2)
    local dot = badge:CreateTexture(nil, "ARTWORK")
    dot:SetAllPoints()
    dot:SetColorTexture(0.8, 0.1, 0.1, 1)
    mmb.badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mmb.badgeText:SetPoint("CENTER", 0, 0)
    mmb.badge = badge

    mmb:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            GH.OpenOptions()
        elseif GH.Orders.NewCount() > 0 then
            GH.ShowTab("requests")
        else
            GH.ToggleWindow()
        end
    end)
    mmb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Guildhall", 1, 0.82, 0.3)
        local n = GH.Orders.NewCount()
        if n > 0 then GameTooltip:AddLine(("%d new craft request%s"):format(n, n == 1 and "" or "s"), 1, 0.4, 0.4) end
        GameTooltip:AddLine("Left-click: open", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move around the minimap", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mmb:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            GH.Settings().minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition()
        end)
    end)
    mmb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    UpdatePosition()
    GH.UpdateMinimap()
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
    if n > 0 then GameTooltip:AddLine(("%d new craft request%s"):format(n, n == 1 and "" or "s"), 1, 0.4, 0.4) end
    GameTooltip:AddLine("Left-click: open", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function Guildhall_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-- The shared launcher notch (LibForever): one bar on the screen edge for all our addons.
local LIB = LibStub and LibStub("LibForever-1.0", true)
local function RegisterNotch()
    if not LIB or not LIB.RegisterLauncher then return end
    LIB.RegisterLauncher({
        id = "Guildhall", label = "Guildhall", order = 10,
        icon = "Interface\\AddOns\\Guildhall\\Media\\notch",
        onClick = function(button) Guildhall_OnAddonCompartmentClick(nil, button) end,
        status = function()
            local n = GH.Orders.NewCount()
            return n > 0 and ("|cffff6060%d new craft request%s|r"):format(n, n == 1 and "" or "s") or nil
        end,
        tooltip = { "Left-click: open", "Right-click: settings" },
    }, GH.DB())
    LIB.SetLauncherBadge("Guildhall", GH.Orders.NewCount())
end

GH.Listen("LOGIN", Build)
GH.Listen("LOGIN", RegisterNotch)
GH.Listen("ORDERS_CHANGED", function()
    if LIB and LIB.SetLauncherBadge then LIB.SetLauncherBadge("Guildhall", GH.Orders.NewCount()) end
end)
GH.Listen("ORDERS_CHANGED", function() GH.UpdateMinimap() end)
GH.Listen("GUILD_CHANGED", function() GH.UpdateMinimap() end)
