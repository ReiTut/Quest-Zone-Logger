# ZoneQuestTracker

ZoneQuestTracker groups watched quests by zone in the right-side Objective Tracker in **World of Warcraft: Forever 1.60.1 (Camelot)**. Click a zone header to toggle that zone or left-click a quest title to see its details beside its location in Blizzard’s Map & Quest Log. Right-click a quest title for **Track** or **Untrack**, **Share**, and **Abandon**. Click the circle beside a quest to focus it on the map, or click the focused circle again to clear the focus. The circle follows Blizzard’s Quest Points of Interest setting. If the section fills the available tracker height, use the mouse wheel over the list.

## Install

1. Exit World of Warcraft and copy the entire `ZoneQuestTracker` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
2. Check that `World of Warcraft/_forever_/Interface/AddOns/ZoneQuestTracker/ZoneQuestTracker.toc` exists.
3. Start Forever and enable **ZoneQuestTracker** in the character selection screen’s **AddOns** list. If ForeverCore’s **Forever quest list** is enabled, turn it off to avoid displaying a second quest list.

## Tracker behavior

The addon uses the quest log’s category, then the quest’s destination zone, then **Other**. Each watched quest has one row even if it sends you to several zones. Zone collapse state is saved per character. You can expand, collapse, and scroll zones during combat using the last loaded quest list. Quest progress refreshes after combat.

A quest title opens the map out of combat. During combat, clicking a title queues the map and details for the most recently clicked quest. The map opens after combat if the quest is still tracked. Quest menu actions are available out of combat. **Share** requires a group and a shareable quest. **Abandon** opens Blizzard’s confirmation dialog. You can track a quest again from Blizzard’s quest log.

The grouped display follows Blizzard’s quest and campaign watch sections. Blizzard continues to lay out its tracker while ZoneQuestTracker fades the stock quest rows out of combat. Edit Mode shows the stock tracker so you can adjust it there.

When Blizzard provides a quest item, its icon appears to the right of the first objective or status line. Hover over an active shortcut for the tooltip. An item button already in place when combat begins stays clickable while its quest and position match. Newly shown or moved item icons stay gray until their buttons can be placed after combat. The icon also turns gray when the client reports the item is unavailable, on cooldown, or out of range. The game still checks quest-specific conditions when you use the item, such as whether the target is wounded enough for the Phantasmal Blade.

The grouped display supports mouse controls. Blizzard’s auto-quest popups and gamepad navigation for quest rows are unavailable in this display.

## In-game test checklist

- [ ] Track quests from two categories, such as The Barrens and Stonetalon Mountains. Confirm the two headers show the right counts and a multi-zone quest appears only once, under its quest-log category.
- [ ] Collapse one zone and confirm its header, count, and `+` stay visible while the other zone stays open. Reverse the two states and confirm they remain independent.
- [ ] Progress a quest in a closed zone. After combat, check that the zone is still closed. Expand it to check the new progress and confirm the ready-for-turn-in line appears when the quest is complete.
- [ ] Click quest titles from two zones with the map closed and already open. Confirm the Map & Quest Log shows each quest’s details and location. Repeat with the standalone quest popup open. Enter combat after opening the map from a quest title and check for protected-action errors. In combat, expand a closed zone, scroll to its quests, and click a title. Test with the map open and closed. Confirm the details switch to the most recently clicked tracked quest after combat. Make quest progress and check for errors during and after combat.
- [ ] Right-click a quest title and check that only the menu opens. Untrack the quest, then track it again from Blizzard’s quest log. Check that the count and rows update, including when removing the last quest in a zone and then restoring it. Verify **Share** is disabled solo and enabled for a shareable quest in a group. Open **Abandon** and cancel Blizzard’s confirmation. Use a disposable quest if confirming abandonment. Verify menu actions stay disabled in combat.
- [ ] With Quest Points of Interest enabled, click the circles beside two watched quests in turn and check that focus and the highlighted circle follow the selection. Click the focused circle again to clear it. Turn the setting off and on to check that the circles hide and return.
- [ ] Focus the first quest in a zone and check that its circle and glow clear the zone header. Track a quest with a usable item and check its right-side tooltip. For Tempered Expectations, weaken eligible Shen’dralas wildlife, move into melee range, and left-click the Phantasmal Blade while still in combat. Verify the quest counter increases and the icon grays during cooldown, then returns to color when usable. In combat, collapse the item’s zone or scroll its icon out of view and check that the old position cannot use the item. Verify displaced and newly visible shortcuts bind after combat. Check that the icon disappears when Blizzard stops offering the item.
- [ ] Leave one zone closed and the other open, run `/reload`, and check both states. With a quest item on the tracker, check for blocked-action errors on reload. Repeat after logging out and in. Check that another character can set its own states.
- [ ] With quests as the only tracker content, use Blizzard’s main tracker minimize button and expand it again. Then track an achievement or another nonquest objective to check that it still uses its own section.
- [ ] With the tracker crowded, scroll over the grouped list and check that the last quest is reachable. Enter and exit combat and check for Lua errors or blocked-action messages.
- [ ] With several zones expanded and enough quests to fill the tracker, exit WoW and log in again. Verify the tracker uses the available height and the last quest is reachable without `/reload`. Repeat after changing the tracker height in Edit Mode or changing the UI scale.
- [ ] Track a quest that has a clickable item and progress a quest during combat. Confirm the tracker can update without a blocked `QuestObjectiveTracker:SetHeight()` action and that the grouped rows resume when combat ends. Switch stance or form and check for blocked actions during the action-bar update. Open Edit Mode out of combat, move the tracker, then exit and confirm the grouped list follows it.

## Compatibility review

The original quest and tracker contracts were checked against build **1.60.1.70888**. Item use and the tracker’s layout order were checked against build **1.60.1.70938**. [Quest API](https://github.com/Gethe/wow-ui-source/blob/4cd0ab7/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) · [Tracker container](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.lua#L59-L123) · [Quest item lookup](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua#L337-L343) · [Click-to-use template](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.xml#L3-L8)

Offline Lua 5.1 checks passed for quest grouping and fallback, deduplication, independent collapse, progress and turn-in status, detail clicks, watch changes, simulated reload and character isolation, combat deferral, tracker minimization, scrolling, and recovery to Blizzard’s quest display on error. The in-game checklist is pending.
