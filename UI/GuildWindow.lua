-- Guildhall - a way in from Blizzard's own guild window, which is where somebody thinking about
-- their guild already is. Asked for on CurseForge, and it is the one obvious place a guild addon
-- belongs that this one was not.
--
-- Blizzard's window is load-on-demand (Blizzard_Communities), so it usually does not exist when we
-- load and we wait for it. Everything here is guarded: on a client with no such window, or one
-- shaped differently from what we anchor to, this does nothing rather than erroring on somebody's
-- screen. A button that fails to appear is a disappointment; a Lua error every time you open your
-- guild is a reason to uninstall.
local ADDON, GH = ...
local U = GH.UI

local button

local function Wanted()
    return GH.Settings().guildWindowButton ~= false
end

-- The button to sit beside, which is "Invite Member" when the window has one. It is not always
-- there - it depends on your guild rank - and it is not always alone, so this answers "none"
-- rather than assuming, and finds it by WHERE IT IS rather than by what Blizzard calls it.
-- I had `parent.InviteButton` checked first and took it out: it is probably the right name, but
-- it makes the answer wrong in the case this function exists for. If Invite Member has something
-- beside it, the name hands back Invite Member and we land on its neighbour; the measurement
-- hands back the leftmost of the row and we land outside both. A name that is right about the
-- button and wrong about the position is worse than no name.
local function BottomRightButton(parent)
    local best, bestLeft
    local left, right, bottom = parent:GetLeft(), parent:GetRight(), parent:GetBottom()
    if not (left and right and bottom) then return nil end
    local middle = (left + right) / 2
    for _, child in ipairs({ parent:GetChildren() }) do
        if child ~= button and child.GetObjectType and child:GetObjectType() == "Button"
            and child:IsShown() and child:GetLeft() then
            -- Along the bottom edge, in the right-hand half. Not "nearest the right corner": that
            -- finds only the outermost button, and this window can have a ROW of them - Invite
            -- Member with something beside it - so anchoring to the outermost one would sit us on
            -- top of its neighbour. Taking the LEFTMOST of the row puts us outside the whole group.
            if child:GetLeft() > middle and (child:GetBottom() - bottom) < 40 then
                if not bestLeft or child:GetLeft() < bestLeft then
                    best, bestLeft = child, child:GetLeft()
                end
            end
        end
    end
    return best
end

local function Place()
    if not button then return end
    button:ClearAllPoints()
    local sibling = BottomRightButton(button:GetParent())
    if sibling then
        -- Beside it, sharing its baseline: nothing here guesses a height, so it lines up whatever
        -- the window's padding turns out to be.
        button:SetPoint("BOTTOMRIGHT", sibling, "BOTTOMLEFT", -4, 0)
    else
        -- No invite button on this window, so take the corner it would have had.
        button:SetPoint("BOTTOMRIGHT", -8, 4)
    end
end

local function Attach()
    if button then return end
    local parent = _G.CommunitiesFrame
    if not (parent and parent.GetObjectType) then return end

    button = U.Button(parent, "Guildhall", 100, 22)
    button:SetScript("OnClick", GH.OpenMain)
    -- Placed on every show, not once: which buttons that window has depends on the tab you are on
    -- and on your rank in the guild, and both change while it is open.
    parent:HookScript("OnShow", Place)
    Place()
    U.Tooltip(button, "Guildhall",
        "Who in your guild can craft what, who has a spare, and what people are after.")
    button:SetShown(Wanted())
end

-- Either can be the one that happens first: the window may already be loaded when we start, because
-- something else pulled it in, or it may load later when the player opens it.
GH.Listen("LOGIN", Attach)
GH.On("ADDON_LOADED", function(name)
    if name == "Blizzard_Communities" then Attach() end
end)

-- The settings page calls this: switching the button on should not need a reload, and by now the
-- guild window may exist even though it did not at login.
function GH.RefreshGuildWindowButton()
    Attach()
    if button then
        button:SetShown(Wanted())
        Place()
    end
end
