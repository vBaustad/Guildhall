# Guildhall

Your guild's crafting directory for WoW Classic Era (and, once it's out, WoW: Forever).

- **Who can make it?** Every guildie with Guildhall shares their professions and recipes automatically. Open a profession window once and you're in; nobody types anything.
- **Search** everything the guild can craft, filter by profession, show only people who are online.
- **Tooltips** on any item show which guildies can craft it, who has one, and who wants one.
- **Guildies have it:** offer a spare BoE or anything else from your bags, with a note. Listings hide themselves when the item leaves your bags and expire after a while.
- **Wanted:** post what you're looking for. Guildies who can craft it get a heads-up.
- **Craft requests:** ask a crafter for an item. If they're offline the request is delivered when they log in. They can accept, decline or mark it done, and see the materials and how many they already have.

No gold or items move through the addon. Trade or mail as usual.

## Commands

- `/gh`: open Guildhall
- `/gh search <item>`: search
- `/gh mine`, `/gh requests`: jump to a tab
- `/gh status`: sync status
- `/gh config`: settings

## How sharing works

Everything goes over the guild addon channel, so only your guild sees it. Each character publishes only its own profile, so there are no edit conflicts. When you log in you learn the latest version from online guildies, and they can pass along profiles of guildies who are offline. A passed-along copy is replaced as soon as its owner comes online.

## License

MIT. Bundles LibStub, CallbackHandler-1.0, AceComm-3.0 and ChatThrottleLib (see LICENSE).
