# Guildhall

## 1.0.1

- **The Guildhall button on Blizzard's guild window no longer covers Invite Member.** It was
  placed once, when the window opened, so opening it on a tab without Invite Member and then
  clicking over to Chat brought Invite Member up underneath it. It now moves every time the
  window changes its own buttons. It also no longer lands on Guild Control, which officers see
  on the Roster tab, and it is hidden in the small chat-only window, where there is no room.

## 1.0.0

- **Out of beta, for the launch of WoW: Forever.** Checked against the game's newest client, build 1.60.1.70707.
- **The recipe list now comes from the live game** (build 1.60.1.70707; it was from a beta build).
  - Three enchants were missing: Enchant Boots - Speed, Enchant Gloves - Holy Power and Enchant Gloves - Arcane Power. Guildhall now finds them at login like any other recipe and shows the skill and materials they need, instead of waiting for the enchanter to open their profession window.
  - The camp recipes First Aid Kit and Lodestone showed "?" for the skill they need. They show 20.
  - 37 recipes taught by plans, patterns and formulas showed a skill 5 to 20 points too high. They now show the skill needed to learn them.
  - Disorienting Smog Potion is no longer a recipe in the game, so it is gone from the list.

## 0.2.0-beta11

- **You can offer to buy something a guildie has posted.** Before, the only thing you could do with
  a spare somebody listed was whisper them or tell the whole guild you wanted one. There is an
  Offer button on their row now: name a price, and it is sent the same way a craft order is.
  Offers and craft orders share one tab, now called **Orders**, with what people have asked of you
  on one side and what you have asked of them on the other.
- **What "sent while they are offline" actually means**, because earlier releases put it too
  strongly. An order you make while the other side is offline is kept in your own saved data and
  goes out the next time the two of you are online together. No other guildie carries it for you -
  recipes and skill levels are passed around the guild, orders never are, since that would mean
  somebody with no part in the order holding it. You will not miss one by logging off: it waits.
  But it needs you both there once, so the help text and the message in Browse now say so.
- Guildies on an older Guildhall will not receive offers at all - they will not see them mislabelled
  as something else.

- **An order's note is readable.** A row in Orders gave its second line to the kind, the price, who
  sent it, when, the status and the note, in that order - so the note, the one part a person wrote,
  got whatever was left and usually ended as "please can you make...". Rows are taller now and each
  of those gets a line, with the note on its own. Orders are rare enough to afford the room.

- **You can put a price on something you offer**, in gold, silver and copper rather than whole gold
  - a leather is not worth a gold piece. Wanted posts take the same three boxes. Guildies on an
  older Guildhall still see the offer; they just will not see the price. An order you have been
  sent shows what it comes to in total, above the Accept button, so the figure you decide on is not
  one you have to work out yourself.
- **The "Crafts" filter is gone.** It showed almost exactly what "Everything" shows, because most
  of what a guild knows is crafts. "Guildies have" and "Wanted" are the two that narrow anything.

- **Asking the guild for something and asking one person to craft it now have different names.**
  Both used to be called requests, and the tab holding only the second was called Requests, so the
  other looked like it belonged there. Posting to the whole guild is "Ask the guild"; a job sent to
  one crafter is a craft order, and that is what the tab is called. `/gh requests` still works.

- **Browse tells you where you are, and the way back is an arrow.** The "< All professions" button
  in the top right is gone; there is a back arrow in the top left with the profession's name beside
  it, where the game's own journals put one. The profession icons sit at the right edge now so they
  stop moving about, and the one you picked stands out properly.
- **Your professions in My Guildhall are one line now**, saying how much is shared, with a row only
  for a profession whose recipes Guildhall cannot see yet - and clicking that row opens it, which is
  exactly what it is asking you to do.
- Soulbound, bind-on-pickup and quest items are left out of the bag list. You cannot hand them to a
  guildie, so offering one was never going to work.
- The bag list fills the panel instead of stopping part way down it, and its group headings match
  the rest of Guildhall: they fold away when you click them, and it remembers which you closed.
- **My Guildhall shows what is in your bags**, in the space under your professions that was empty,
  grouped into materials, gear and consumables with the best things first. Click one to offer it or
  post it as wanted; shift-click links it in chat.
- **You can search for something to want.** Posting a wanted item offered you your own bags, which
  is the one place the thing you are looking for is not. Wanting now has a search over everything
  the professions make and everything they are made from - so you can ask the guild for 400 Linen
  Cloth. Offering still picks from your bags, which is the only place an offer can come from.
- **You can put an item into My Guildhall without opening your bags.** Offering something or
  posting a want needed you to drag the item onto the slot or shift-click it in your bags - with
  your bags shut there was no way in at all. There is a "Choose an item" button that lists what you
  are carrying, and a Clear button to empty the form.
- Items only you can make are dimmed in Browse rather than standing out in green. They are still
  listed - hiding them would make something you can make yourself look like something nobody can.
- **Materials are items you can hover and link.** The list of reagents under an item used to be
  one line of text that ran off the edge - you could not see the last one, let alone what it was.
  Each material is its own entry now, wrapping onto as many lines as it needs, with the game's own
  tooltip on hover and shift-click to link it in chat.
- The recipe you had open is cleared when you switch profession, instead of staying on screen
  beside a list it no longer belongs to.
- **Less text is cut off.** The people list under an item has taller rows, so "offline - requests
  wait until they log in" fits instead of ending in a stub, and each row shows the crafter's skill
  rather than repeating the profession named directly above the list. A long item name wraps onto a
  second line instead of being cut. A list that is all one profession no longer carries a heading
  saying so.

- **Guildhall uses far less memory in a large guild.** It was storing each crafter's name, class,
  profession and skill once per item they can make, rather than once per person - so in a big
  guild the same name was held a million times. Measured, a 150-guildie guild drops from about
  38 MB to 5 MB, and a very large one from around 300 MB to 28 MB. Nothing about what you see
  changes.
- `/gh status` now reports how much memory Guildhall is using, next to the total across every addon
  you have loaded. If an addon is eating your memory, that tells you which one it is.

## 0.2.0-beta10

- **A Guildhall button on Blizzard's own guild window**, next to Invite Member, because that is
  where you already are when you are thinking about your guild. Asked for on CurseForge. It keeps
  out of the way of whatever else that window is showing - which buttons it has depends on your
  rank in the guild - and if you would rather not have it, turn it off under "Where Guildhall
  appears" in the settings. That takes effect straight away, no reload.

## 0.2.0-beta9

- **Recipe data updated to Forever build 1.60.1.70334.** Raging Raptor Ribs needs Cooking 180, not
  275. Nothing was added or removed - 31 recipes have new skill thresholds, and all but three of
  them are numbers Guildhall never shows you.
- An item whose recipe carries no skill requirement in the game data now says so, instead of
  stating that you can make it at skill 0. Blizzard zeroed the thresholds on fifteen crafts in
  build 1.60.1.70170 - mostly camp objects like the First Aid Kit and the Fish Bowl - so Guildhall
  says "?" for those rather than inventing a number for them.

## 0.2.0-beta8

- **A guildie showing up twice in your guild is folded back into one.** The same guildie could be
  saved under both spellings of their name - "Bremse" and "Bremse Kloss" - and then appear twice in
  a profession list, with two different skill levels. New profiles no longer arrive that way, but
  nothing had ever cleaned up the ones already saved, and Guildhall does not throw anything away on
  its own. They are merged at login under the name the server uses: the higher skill wins, every
  recipe either copy knew is kept, and their craft requests come with them. If two guildies really
  do share a first name there is no way to tell which a stray record belongs to, so those are left
  exactly as they are and named in `/gh selftest` instead of being guessed at.

- **A guildie who hasn't updated yet is still part of your guild.** A Guildhall older than
  0.2.0-beta7 tells everyone its own name without the surname - "Morgan" where the server says
  "Morgan Smith" - and an updated Guildhall was throwing those profiles away, because the name in
  them is not the name the guild roster uses. The guildie simply vanished: no professions, no
  listings, nothing. That meant the first person in a guild to update went blind to everyone who
  had not. Their profile is now recognised as theirs and filed under the name the server uses, so
  the guild agrees on one spelling and nobody disappears while an update works its way round.
  Two guildies who really do share a first name are never merged: it takes an exact match on the
  sender's own first name, and a different surname is a different player.

- **A guildie running an older Guildhall is named, instead of being invisible.** Two Guildhalls that
  speak different protocol versions cannot read each other at all - nothing you share reaches them,
  nothing they share reaches you, and each of you is simply missing from the other's guild. On the
  newer side that was completely silent: somebody still on an old version looked exactly like
  somebody with no addon installed. From their side you came online once and then never said
  anything again. Guildhall now says who it is and that they need to update - once per guildie, not
  once per message - and `/gh status` lists them for anyone who missed it at login.
- A version number sent by another player is stripped to letters, digits, dots and dashes before it
  is printed in your chat, so it cannot carry a colour code or a fake item link.

- **A guildie who is talking to you is online, whatever the roster thinks.** Forever never lets an
  addon ask for a fresh guild roster - asking pops the "blocked from an action" dialog - so the copy
  Guildhall holds is whatever the server last pushed, and it can be an hour old. It was allowed to
  overrule a guildie whose message had just arrived. That is the sync that finds your guild, says
  "2 online with Guildhall", and then drops back to "you're the only one here" a moment later: the
  guildies answered first and the stale roster arrived second. A message on the guild channel in the
  last few minutes now counts as proof of who is here; after that the roster decides again, so
  somebody who logs out is wrong about for a few minutes rather than for the rest of your session.

- **One way in: the settings window.** The YippYapp welcome window is gone, and so is Guildhall's
  page in it. Everything that page explained now sits at the bottom of Guildhall's own settings,
  under headings, where somebody looking for help actually goes - scroll past the switches. The one
  thing that does not move is the line about opening a profession window once, because that is only
  true of some professions some of the time: My Guildhall says it against the profession it applies
  to, which is where it was always more use.
- **The launcher bar is gone**, along with the YippYapp settings page that configured it. The
  minimap row stays and is now always grouped - one YippYapp button holding one icon per addon.
  Whether Guildhall is one of them is a switch on Guildhall's own settings page now, under
  "Minimap". Turning it off still leaves `/gh` and the addons button.
- The "Psst - you have all 6 YippYapp addons" line at the bottom of the settings page is gone.
  Nothing replaces it; the page ends with the help text instead.

## 0.2.0-beta7

- **The rarity filter no longer empties a profession page.** Picking Uncommon+, Rare+ or Epic used to
  drop every row Guildhall couldn't put an item quality on - and an enchant makes no item, so it has
  none. The Enchanting page went completely blank. The same took out any craft whose recipe isn't in
  the bundled data, on any profession page. A quality Guildhall can't read is now "not yet", never
  "Common": the row stays, and the list settles on the real answer once the game has one. Enchants
  show whatever the filter is set to, since there is nothing to compare them with.
- **Names fit their slots now that everyone has two of them.** In the people list beside an item the
  name has a column of its own, so a long "Firstname Surname" is cut short instead of pushing the
  skill level out under the buttons, and the skill lines up down the list. Hover a row and the
  tooltip gives the name in full, surname included, whether or not you have surnames switched on.
  The blocked and don't-share summaries in Settings list four entries and then a count, rather than
  six that ran off the end mid-name.
- **Item tooltips no longer say who can craft something unless you ask them to.** That line is off by
  default now - a tooltip turns up over everything, whether or not you wanted it. Turn it on under
  Settings, where it sits next to the line about who has one to spare and who wants one, which is
  unchanged. If you had already turned tooltips on, that choice is kept; only the crafter line is new
  and off. Browse and search show crafters either way - this is only about the tooltip.
- `/gh names` now also reports what the guild roster calls you. If that differs from the name Guildhall
  uses, it says so plainly: everything saved under ours moves across once the name is right. The
  "everything is under one name" line says which name it means, instead of reading as "all is well".
- Fixed a Lua error at login from the character-name merge below: it reached for the item helper
  through a name that doesn't exist in that file. If the helper isn't ready yet it now waits for the
  next login instead of failing.
- **One character, one record.** Everyone on WoW: Forever is "First Last", and Guildhall saved you
  under your first name alone while your guild knew you by both - so the same character ended up with
  two sets of professions, posts and craft requests, and each session wrote to whichever one it
  happened to produce. Two separate things were wrong. Guildhall asks the shared library for your
  name, but the line that fetches that library sat lower in the file than the function using it, so
  the function never saw it and fell back to working the name out itself - which on Forever gives the
  first name and drops the surname. Silently, every session. Your name now comes from the same place
  your guildies' names come from. The records are then merged at login: the highest skill and the
  newest revision win, no post or request is thrown away, and your craft requests keep working under
  your full name. If two characters share a first name, Guildhall leaves both alone and says so in
  `/gh selftest` rather than guessing which is which.
  `/gh names` answers the question directly afterwards: it says whether anything of yours is still
  saved under another spelling of your name, and `/gh selftest` fails if it is.
- **Your first login doesn't look like a disaster any more.** An empty Guildhall used to mean "something
  was lost", which on a fixed client is simply a new player: no warning is shown, nothing is asked of
  your guild, and your profile is published normally from the start. The warning is still there for the
  clients that really do drop addon settings, and for a character that has used Guildhall here before.
- **Taking down one of your own posts always reaches your guildies.** While Guildhall is waiting for
  guildies to send back posts it may have lost, it asks them to keep what they hold for you - but that
  never applies to something you removed by hand: that travels with your profile and is dropped
  everywhere. A post you make in the meantime shows up for them straight away too, instead of waiting.
  As a backstop, the waiting ends a couple of minutes after login in any case.
- Herbalism, Mining, Fishing and Skinning keep their names, even though the recipe data no longer lists
  the professions that teach no recipes.
- **The Whisper buttons work with two-part names.** Every name on WoW: Forever is "First Last", and
  Guildhall opened whispers by typing "/w Name Surname ..." into the chat box - so the surname was read
  as the start of the message and the whisper went to the first name. It now hands the name to the chat
  box as a target, the way the game's own UI does.
- Guildhall follows your "show surnames" setting when it shows a name. It is a display choice only -
  it changes nothing about what Guildhall stores or compares, so hiding surnames can never split a
  guildie into two. A guildie running an older build can still announce themselves under a short
  name; `/gh selftest` says so if anyone has ended up stored both ways.
- `/gh selftest` checks that nobody is stored under both a short and a full name, and the new
  `/gh names` shows what the game, the guild roster and the addon channel each call people.
- **A guild is one guild, under one key.** Guildhall built the key it stores your guild's data under
  from the realm name, and spelled that name two different ways depending on which way in it took
  ("Bleeding Hollow" one way, "BleedingHollow" the other), so the same guild could end up saved twice
  and two members wouldn't recognise each other's data.
  Anything saved under the old spelling is merged into one store at login - nothing is replaced, and
  whichever copy knows more about a guildie or a request is the one kept.

## 0.2.0-beta6

- Keeping BagWarden's suggestions honest no longer gets slower as your guild grows: the list of items
  guildies want is gathered while Guildhall builds its search index, instead of being worked out again
  from the whole index each time something changes.

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
