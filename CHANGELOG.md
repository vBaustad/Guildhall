# Guildhall

## 0.2.0 (unreleased)

Rebuilt for the modern game client that WoW: Forever runs on.

- Professions are read through the modern profession API. Every known Forever recipe is checked directly, so collapsed categories or window filters no longer hide recipes.
- Built-in recipe data from the Forever client: required skill, reagents, yield and crafting station (including camp stations like the Master Forge) show in Browse and on craft requests, even when nobody has shared them yet.
- Item tooltips use the modern tooltip system.
- Messages to guildies wait while addon chat is locked down and send once it lifts.
- Addon compartment entry next to the minimap.
- Sync protocol 2: not compatible with 0.1.0. Guildies need the same version to see each other.

## 0.1.0 (unreleased)

First version.

- Recipes and profession skill are shared automatically when you open a profession window (Enchanting included).
- Browse tab: search what the guild can craft, has, or wants; filter by profession and online status.
- Item tooltips list guild crafters, guildies who have the item, and who wants it.
- My Guildhall tab: your shared professions, offer items from your bags, post wanted items.
- Requests tab: ask guildies to craft something; delivered when they come online; accept, decline, done.
- Minimap button with a badge for new craft requests; settings page.
