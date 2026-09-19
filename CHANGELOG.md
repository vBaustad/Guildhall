# Guildhall

## 0.2.0-beta1

The first beta for WoW: Forever. Guildhall is now part of **YippYapp**, a set of addons for Forever that work
even better together.

**Built for Forever**
- Your professions and recipes are shared automatically: Guildhall checks every known Forever recipe when you
  log in and whenever you learn something new. There's no need to open profession windows or expand their
  categories; opening one only adds recipes the built-in data doesn't know yet.
- Built-in recipe data from the game: required skill, reagents, yield and crafting station (including camp
  stations like the Master Forge) show in Browse and on craft requests, even before anyone has shared them.
- Messages to guildies wait while the game locks addon chat, and go out once it lifts.
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
