# Guildhall

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
