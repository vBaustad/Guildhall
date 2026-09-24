# Guildhall

## 0.2.0-beta5

- **BagWarden won't suggest deleting anything Guildhall is using.** Items you've listed for your guild,
  items a guildie has posted as wanted, and anything you've taken on in a craft request are held back,
  each with a short reason in BagWarden's tooltip.
- Housekeeping: removed leftovers from the data-resilience work (two unused helpers and an unused table).

## 0.2.0-beta4

- **Tougher against a guildie who sends nonsense.** Names that carry chat escape codes are rejected, a
  profile can't claim an impossible skill, quantity, date or size, the number of profiles and reminders
  Guildhall stores is capped, and a client that floods the channel is ignored instead of answered. A
  profile sent by its own owner always wins over a copy passed on by someone else.
- Guildhall rebuilds its search index less often while a login sync is still arriving.
- WoW: Forever currently forgets addon settings when you restart the game - a known client bug, not
  something an addon can prevent. Guildhall now rebuilds what it can from your guildies, and a session
  that started without its saved data never replaces what they hold.
- **Guildhall data doesn't disappear any more.**
  - Guildies' professions and posts are never deleted because someone is missing from the guild roster.
    Before, a profile was dropped after 3 days off the roster, and on Forever the roster is often empty or
    partial.
  - Open craft requests never expire. Finished ones are kept for 30 days before they're cleaned up.
    Removing one from your list only hides it, so it can't come back.
  - If your saved data is lost, guildies who are online send back what they have. That covers your
    listings and wanted posts, and every craft request between you and them, in both directions. Your
    professions come back from the automatic scan. Until that happens (even over several sessions),
    your profile can't replace the posts guildies hold for you. Posting or removing something yourself
    ends that, and from then on your own list counts.
  - A status only changes on the side that owns it. The requester cancels; the crafter accepts, declines
    or finishes. If one side missed an update, it's sent again.
- A craft request sent to a guildie who was offline is now delivered as soon as their Guildhall says hello.
  Before, it waited until the guild roster showed them online, which on Forever may never happen.
- **What a guildie shared stays, whether or not they're online.** Their professions, recipes and offers are
  kept for good and shown in Browse, on tooltips and in search even if they haven't logged in for months.
  An offer older than 30 days is no longer hidden: it says "last confirmed 2 months ago" and "old - ask
  before counting on it" instead of quietly disappearing.
- The window's status line now keeps the two numbers apart: how many guildies have shared with you, and how
  many are online with Guildhall right now.
- **The count of guildies online with Guildhall no longer falls back to zero.** Anyone whose Guildhall has
  answered in the last hour counts as online, so a guild roster that is empty or lists only some members
  can't make it look like you're alone. While guildies have answered but haven't sent anything yet, the
  window says so instead of "only you so far".
- If this character has used Guildhall before but the saved data didn't load (this can happen after an
  addon update until the game is fully restarted), one chat line says so.
- **No more "Profession 356" card.** Fishing, Herbalism, Mining and Skinning were missing their names, so a
  guildie's Fishing showed up on the professions overview as an unnamed card with a question-mark icon.
  They're named now, and the overview sorts professions by skill line instead of by name. Fishing counts as
  a secondary profession like Cooking and First Aid: it's hidden unless you tick "Show secondary
  professions", and it never appears under "not covered yet". A profession Guildhall can't name at all is
  left out rather than shown as a number. Names come from the game itself, so professions we don't ship
  data for are named properly too.
- **A crafter is listed once per item.** The same character could appear twice under "Can craft it", once
  for each of their professions, which also made the item header count them as two crafters. Each character
  now gets one row, naming the profession that actually teaches the recipe.
- Recipes are no longer filed under the wrong profession: an open profession window sometimes lists more
  than its own recipes. Anything saved that way is moved to the right profession, or dropped, at login.
- **Settings live in one place.** Guildhall's options are now a page in the YippYapp window, reached from the
  Settings button in Guildhall's own window, from `/gh config`, from the minimap button, or from Blizzard's
  Options → AddOns → YippYapp. The separate Settings tab is gone (it stays only if LibForever isn't
  installed).
- **Don't share list.** In My Guildhall, right-click an item under Your posts and pick "Don't share this item".
  The listing stays on your list but is no longer offered to the guild, and guildies drop it. The item can't
  be offered again until you take it off the list, either from the same right-click menu or under
  Settings → Private lists.
- **Block a player.** Right-click a name in Browse or on the Requests tab and pick "Block". Their listings,
  wanted posts and craft requests are hidden from you everywhere: lists, tooltips, chat lines and counts.
  Nothing is sent and they can't tell: new requests from them are answered as usual but never stored. Their
  data is still kept and shared with other guildies. Unblock from the same menu or under Settings → Private
  lists. Both lists apply to all your characters.
- `/gh status` shows how many requests are stored and how many posts and requests guildies restored
  this session.

## 0.2.0-beta3

- **Wanted posts you can craft are easy to find.** The Requests tab lists them under your craft requests
  ("Wanted by guildies - you can make these") with Whisper and "Show item", the tab shows how many things
  are waiting for you, and the minimap tooltip counts them too.
- The chat line about a wanted item has an "[Open in Guildhall]" link that opens it in Browse.
- "I'll make it" on a guildie's wanted post you can craft opens a whisper that's already written ("I can make
  [item] for you - 1x for 3g each?"), in Browse and on the Requests tab.
- Without a guild, Browse shows one clear message instead of empty lists stacked on top of each other, and
  My Guildhall and Requests explain that offering, wanting and craft requests work with a guild. Joining or
  leaving a guild switches the window over without a reload.
- Browse's overview and item list can never show at the same time any more.
- "I want this" is a quiet link now, and only shows when it makes sense: not for things you can craft, and
  on your own wanted post it becomes "You want this - remove".
- Picking "Crafts", "Guildies have" or "Wanted" in Browse now opens the list straight away. Before, the
  overview stayed up and a wanted post could only be found by searching for it.
- A profession's item list also shows wanted and offered items that profession makes, not only its crafts.
- Guildhall notices when the game refuses an addon message (for example in restricted content), sends it
  again when it can, and never stores a profile that arrived damaged. /gh status shows what was refused.

## 0.2.0-beta2

- **Guild sharing works.** Messages were held back during the game's chat lockdown, so nothing reached guildies. They're sent straight away now.
- Sharing starts right at login and no longer waits for the guild roster.
- Your saved guild directory is no longer wiped on login.
- Browse opens on an overview: one card per profession with who has it and how far they've got, plus the professions nobody in the guild covers yet.
- Items are grouped by profession with collapsible headings, and a minimum-quality filter.
- Cooking, First Aid and Fishing are hidden unless you tick "Show secondary professions".
- The crafter column names the crafter ("you", "Nokk", "3 crafters") instead of "1 craft".
- Wanted posts take an amount and a price each ("100x Copper Bar - 3g each").
- Soulbound and quest items can't be listed any more.
- Craft requests and whispers reach players on your own realm.
- The window says "syncing with your guild..." while profiles arrive, and shows last session's data meanwhile.
- /gh status shows messages sent and received, and how many profiles are stored.

## 0.2.0-beta1

The first beta for WoW: Forever. Guildhall is now part of **YippYapp**, a set of addons for Forever that work
even better together.

**Built for Forever**
- Your professions and recipes are shared automatically: Guildhall checks every known Forever recipe when you
  log in and whenever you learn something new. There's no need to open profession windows or expand their
  categories; opening one only adds recipes the built-in data doesn't know yet.
- Built-in recipe data from the game: required skill, reagents, yield and crafting station (including camp
  stations like the Master Forge) show in Browse and on craft requests, even before anyone has shared them.
- No more "blocked from an action only available to the Blizzard UI" pop-ups. Guildhall no longer asks the game
  for the guild roster or for protected profession info.
- Sync protocol 2: not compatible with 0.1.0. Guildies need this version to see each other.

**A new look**
- The window uses Forever's own bronze style: the same frame, tabs and buttons as the game's Options window.
- New round emblem for the minimap button and the AddOn list.
- The window stays in front when you click it, no longer blends into other YippYapp windows, and remembers where
  you put it.
- Escape closes one thing at a time: the craft-request pop-up first, then the window. The X and Close buttons
  work in combat too.

**Minimap, settings and welcome**
- The minimap button sits properly in its ring and can be dragged around the minimap. With several YippYapp
  addons, their minimap buttons can be grouped behind one YippYapp button.
- Settings are in a Settings tab in the window, and under Options → AddOns → YippYapp → Guildhall. Shared
  settings for all YippYapp addons (minimap buttons, the optional launcher bar) are on the YippYapp page.
- The launcher bar at the screen edge is optional and off unless you turn it on.
- A short introduction to Guildhall in the YippYapp welcome window (/yippyapp).
- The number of new craft requests shows on the Requests tab and in the minimap button's tooltip.
- A disabled Whisper button now says "Offline" instead of showing a blank button.
- Browse filters show how many items each one holds, only the active filter looks selected, and empty
  filters say how to fill them.
- Your own crafts are in Browse too, marked "(you)" and listed after your guildies.

**Smoother in big guilds**
- Item tooltips no longer rebuild the guild directory while you hover, and never in combat, so large guilds
  don't cause hitches.
- Listing updates that happen on their own, like items leaving your bags or posts expiring, are sent to the
  guild at most every two minutes. Changes you make yourself still go out within seconds.
- `/gh sync` can be used once a minute.

## 0.1.0 (unreleased)

First version.

- Recipes and profession skill are shared automatically when you open a profession window (Enchanting included).
- Browse tab: search what the guild can craft, has, or wants; filter by profession and online status.
- Item tooltips list guild crafters, guildies who have the item, and who wants it.
- My Guildhall tab: your shared professions, offer items from your bags, post wanted items.
- Requests tab: ask guildies to craft something; delivered when they come online; accept, decline, done.
- Minimap button with a badge for new craft requests; settings page.
