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

local function Attach()
    if button then return end
    local parent = _G.CommunitiesFrame
    if not (parent and parent.GetObjectType) then return end

    button = U.Button(parent, "Guildhall", 100, 22)
    -- Bottom left, under the community list. The right-hand side of this window is Blizzard's own
    -- buttons and the first place another addon would put something of its own.
    button:SetPoint("BOTTOMLEFT", 12, 10)
    button:SetScript("OnClick", GH.OpenMain)
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
    if button then button:SetShown(Wanted()) end
end
