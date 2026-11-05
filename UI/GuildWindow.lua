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
-- there - it is on the Chat tab only, and it depends on your guild rank - and it is not always
-- alone, so this answers "none" rather than assuming, and finds it by WHERE IT IS rather than by
-- what Blizzard calls it.
-- I had `parent.InviteButton` checked first and took it out: it is probably the right name, but
-- it makes the answer wrong in the case this function exists for. If Invite Member has something
-- beside it, the name hands back Invite Member and we land on its neighbour; the measurement
-- hands back the leftmost of the row and we land outside both. A name that is right about the
-- button and wrong about the position is worse than no name.
local function BottomRightButton(parent)
    local left, right, bottom = parent:GetLeft(), parent:GetRight(), parent:GetBottom()
    if not (left and right and bottom) then return nil end
    local middle = (left + right) / 2
    local best, bestLeft
    local function Consider(frame, nested)
        for _, child in ipairs({ frame:GetChildren() }) do
            -- Visible, not just shown: a button on a strip that is itself hidden says it is shown.
            if child ~= button and child.GetObjectType and child:IsVisible() then
                local kind = child:GetObjectType()
                local childLeft, childBottom = child:GetLeft(), child:GetBottom()
                if childLeft and childBottom and (childBottom - bottom) < 40 then
                    if kind == "Button" and childLeft > middle then
                        -- Along the bottom edge, in the right-hand half. Not "nearest the right
                        -- corner": that finds only the outermost button, and this window can have
                        -- a ROW of them, so anchoring to the outermost one would sit us on top of
                        -- its neighbour. Taking the LEFTMOST of the row puts us outside the group.
                        if not bestLeft or childLeft < bestLeft then
                            best, bestLeft = child, childLeft
                        end
                    elseif kind == "Frame" and not nested and (child:GetHeight() or 40) < 40 then
                        -- A low strip along the bottom edge holding buttons of its own. Blizzard
                        -- keeps Guild Control and Guild Recruitment on one, so a row read only
                        -- from the window's own children misses half of what is in it.
                        Consider(child, true)
                    end
                end
            end
        end
    end
    Consider(parent, false)
    return best
end

-- The small chat-only window (Blizzard's minimise button) has no room for us: its chat box runs
-- the whole width of the bottom edge, which is exactly where we would go.
local function Minimised(parent)
    local modes = _G.COMMUNITIES_FRAME_DISPLAY_MODES
    return modes ~= nil and parent.GetDisplayMode ~= nil
        and parent:GetDisplayMode() == modes.MINIMIZED
end

local function Place()
    if not button then return end
    local parent = button:GetParent()
    button:SetShown(Wanted() and not Minimised(parent))
    button:ClearAllPoints()
    local sibling = BottomRightButton(parent)
    if sibling then
        -- Beside it, sharing its baseline: nothing here guesses a height, so it lines up whatever
        -- the window's padding turns out to be.
        button:SetPoint("BOTTOMRIGHT", sibling, "BOTTOMLEFT", -4, 0)
    else
        -- No button in that row on this tab, so take the corner, where Invite Member sits.
        button:SetPoint("BOTTOMRIGHT", -5, 5)
    end
end

local function Attach()
    if button then return end
    local parent = _G.CommunitiesFrame
    if not (parent and parent.GetObjectType) then return end

    -- The height of Blizzard's buttons along that edge, so it reads as one row with them.
    button = U.Button(parent, "Guildhall", 100, 20)
    button:SetScript("OnClick", GH.OpenMain)
    U.Tooltip(button, "Guildhall",
        "Who in your guild can craft what, who has a spare, and what people are after.")
    -- Placed again every time Blizzard re-decides its own buttons, and not only when the window
    -- opens. Which ones it shows depends on the tab and on your rank, and both change while the
    -- window is open. Placing on open alone put us in the empty corner of a tab with no Invite
    -- Member and left us there, on top of it, once the player clicked over to Chat. A tab click, a
    -- change of guild or community and the window opening all end in UpdateCommunitiesButtons,
    -- after Blizzard has shown, hidden and anchored every button in that row.
    if type(parent.UpdateCommunitiesButtons) == "function" then
        hooksecurefunc(parent, "UpdateCommunitiesButtons", Place)
    end
    parent:HookScript("OnShow", Place)
    Place()
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
    Place()
end
