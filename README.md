# Guildhall

**Your guild's crafting directory for WoW: Forever.**

Search for any item and Guildhall tells you who in your guild can craft it. It also shows who already has one
to spare and who is looking for one. You can then ask a crafter for it, even if they're offline.

Nobody has to fill in a spreadsheet or type anything in guild chat. Guildhall builds the directory from the
professions and recipes of every guildie who has it installed.

> **Status: beta (0.2.0-beta1).** Built for the WoW: Forever beta. Expect rough edges, and please report what
> you find.

## What it does

- **Who can make it?** Your professions and recipes are shared with the guild automatically when you log in,
  and again whenever you learn something new. Every guildie with Guildhall shows up in the directory.
  Opening a profession window only adds recipes Guildhall's built-in data doesn't know yet.
- **Search the whole guild.** Search everything the guild can craft, has or wants. You can filter by
  profession or show only people who are online. Each item shows who can craft it, which profession and skill
  level it needs, and whether it needs a crafting station.
- **Item tooltips.** Hover any item in the game to see which guildies can craft it, who has one and who wants
  one.
- **Guildies have it.** Offer a spare BoE or anything else from your bags, with a note. A listing disappears
  when the item leaves your bags, and it expires after a set number of days that you choose.
- **Wanted.** Post what you're looking for. Guildies who can craft it get a quiet heads-up.
- **Craft requests.** Ask a crafter for an item and add an optional note. If they're offline, the request is
  delivered when they log in. The crafter can accept, decline or mark it done, and sees the materials and how
  many they already have.

Guildhall never moves gold or items. Once you've agreed, trade or use the mail as usual.

## Getting started

1. Install Guildhall. Guildies who also want to show up in the directory install it too.
2. Log in. Your professions and recipes are shared on their own.
3. Type `/gh`, or click the Guildhall icon on the minimap. If you use several YippYapp addons, it sits
   behind the YippYapp button there.

### Commands

| Command | What it does |
|---|---|
| `/gh` | Open or close Guildhall |
| `/gh search <item>` | Search the guild for an item |
| `/gh mine` | Your professions, listings and wanted posts |
| `/gh requests` | Craft requests sent to you and by you |
| `/gh status` | Sync status |
| `/gh config` | Settings |

Left-click the minimap icon to open Guildhall, right-click it for settings. Settings are in Guildhall's
**Settings** tab and under **Options → AddOns → YippYapp → Guildhall**. Minimap and launcher buttons for all
YippYapp addons are set on the **YippYapp** page itself.

## How sharing works

- **Guild only.** Everything travels over the guild addon channel, so only your guild sees it.
- **No edit conflicts.** Each character publishes only its own profile.
- **Catching up.** When you log in, Guildhall fetches the latest profiles from guildies who are online.
  Online guildies also pass along the profiles of guildies who are offline. A passed-along copy is replaced as
  soon as its owner comes online.
- **Chat lockdown.** While the game restricts chat, messages wait and are sent afterwards.

## Part of YippYapp

Guildhall is part of **YippYapp**, a set of addons for WoW: Forever that work even better together. Each one
works fully on its own. With more of them installed:

- **One minimap button.** Their minimap buttons can be grouped behind a single YippYapp button: click it for
  a row with each addon's icon. There is also an optional launcher bar at the screen edge. It's off by
  default, and you can turn it on under Options → AddOns → YippYapp.
- **One settings page.** Shared settings live on the YippYapp page in Options → AddOns, and each addon has
  its own page under it.
- **One welcome window.** `/yippyapp` shows a short introduction to each YippYapp addon you have.
- **One group in the AddOn list.** They appear together under **YippYapp** in the in-game AddOn list.
- **Campfire** shows which guildies are nearby: find who can craft an item in Guildhall, then see in
  Campfire how far away they are and whisper them to meet up.

Other YippYapp addons:
- **Skillwright** plans the cheapest or fastest route to max skill in a profession.
- **AutoFeed** keeps one-button macros for your best food, water, potions, scrolls and bandages.
- **BuffWarden** shows the buffs you and your group are missing, and casts or requests them in one click.

## Installing from source

Releases will come through CurseForge. To run the source directly:

1. Clone this repo into `Interface\AddOns\Guildhall`.
2. Clone [LibForever-1.0](https://github.com/vBaustad/LibForever-1.0) into `Guildhall\Libs\LibForever-1.0`.
   The packaged releases include it automatically.

## License

MIT. Bundles LibStub, CallbackHandler-1.0, AceComm-3.0 and ChatThrottleLib (see LICENSE).
