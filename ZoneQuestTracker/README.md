# ZoneQuestTracker

ZoneQuestTracker groups watched quests by zone in the right-side Objective Tracker in **World of Warcraft: Forever 1.60.1 (Camelot)**. Click a zone header to toggle that zone or click a quest title to open its details. Click the circle beside a quest to focus it on the map, or click the focused circle again to clear the focus. The circle follows Blizzard’s Quest Points of Interest setting. Use Blizzard’s quest log to track or untrack quests. If the section fills the available tracker height, use the mouse wheel over the list.

## Install

1. Exit World of Warcraft and copy the entire `ZoneQuestTracker` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
2. Check that `World of Warcraft/_forever_/Interface/AddOns/ZoneQuestTracker/ZoneQuestTracker.toc` exists.
3. Start Forever and enable **ZoneQuestTracker** in the character selection screen’s **AddOns** list. If ForeverCore’s **Forever quest list** is enabled, turn it off to avoid displaying a second quest list.

## Tracker behavior

The addon uses the quest log’s category, then the quest’s destination zone, then **Other**. Each watched quest has one row even if it sends you to several zones. Zone collapse state is saved per character. The display refreshes after combat. Click quest titles out of combat.

The grouped display takes the place of Blizzard’s quest and campaign watch sections. When Blizzard provides a quest item, its icon appears to the right of the first objective or status line. Hover over it for the tooltip. An item button already in place when combat begins can still be left-clicked during combat. Button placement and item assignments refresh after combat. The icon turns gray when the client reports the item is unavailable, on cooldown, or out of range. The game still checks quest-specific conditions when you use the item, such as whether the target is wounded enough for the Phantasmal Blade.

The grouped display supports mouse controls. Blizzard’s auto-quest popups, quest-row context menus, and gamepad navigation for quest rows are unavailable in this display.

## In-game test checklist

- [ ] Track quests from two categories, such as The Barrens and Stonetalon Mountains. Confirm the two headers show the right counts and a multi-zone quest appears only once, under its quest-log category.
- [ ] Collapse one zone and confirm its header, count, and `+` stay visible while the other zone stays open. Reverse the two states and confirm they remain independent.
- [ ] Progress a quest in a closed zone. After combat, check that the zone is still closed. Expand it to check the new progress and confirm the ready-for-turn-in line appears when the quest is complete.
- [ ] Click a quest title to open that quest’s details. Track and untrack from the quest log and confirm counts update. Remove the last watched quest in a zone, then track it again to check that its prior collapse state returns.
- [ ] With Quest Points of Interest enabled, click the circles beside two watched quests in turn and check that focus and the highlighted circle follow the selection. Click the focused circle again to clear it. Turn the setting off and on to check that the circles hide and return.
- [ ] Focus the first quest in a zone and check that its circle and glow clear the zone header. Track a quest with a usable item and check its right-side tooltip. For Tempered Expectations, weaken eligible Shen’dralas wildlife, move into melee range, and left-click the Phantasmal Blade while still in combat. Verify the quest counter increases and the icon grays during cooldown, then returns to color when usable. Check that the icon disappears when Blizzard stops offering the item.
- [ ] Leave one zone closed and the other open, run `/reload`, and check both states. Repeat after logging out and in. Check that another character can set its own states.
- [ ] With quests as the only tracker content, use Blizzard’s main tracker minimize button and expand it again. Then track an achievement or another nonquest objective to check that it still uses its own section.
- [ ] With the tracker crowded, scroll over the grouped list and check that the last quest is reachable. Enter and exit combat and check for Lua errors or blocked-action messages.
- [ ] With several zones expanded and enough quests to fill the tracker, exit WoW and log in again. Verify the tracker uses the available height and the last quest is reachable without `/reload`. Repeat after changing the tracker height in Edit Mode or changing the UI scale.

## Compatibility review

The original quest and tracker contracts were checked against build **1.60.1.70888**. Item use and the tracker’s layout order were checked against build **1.60.1.70938**. [Quest API](https://github.com/Gethe/wow-ui-source/blob/4cd0ab7/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) · [Tracker container](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.lua#L59-L123) · [Quest item lookup](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua#L337-L343) · [Click-to-use template](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.xml#L3-L8)

Offline Lua 5.1 checks passed for quest grouping and fallback, deduplication, independent collapse, progress and turn-in status, detail clicks, watch changes, simulated reload and character isolation, combat deferral, tracker minimization, scrolling, and recovery to Blizzard’s quest display on error. The in-game checklist is pending.
