# ZoneQuestTracker

ZoneQuestTracker groups your watched quests by zone in the right-side Objective Tracker in **World of Warcraft: Forever**. Collapse the zones you’re done with and keep the quests you’re working on in view. Your choices are saved per character.

[**Download ZoneQuestTracker.zip**](https://github.com/ReiTut/Quest-Zone-Logger/releases/latest/download/ZoneQuestTracker.zip) · [Release notes](https://github.com/ReiTut/Quest-Zone-Logger/releases)

## Installation

1. Exit World of Warcraft and extract `ZoneQuestTracker.zip`.
2. Copy the extracted `ZoneQuestTracker` folder into `World of Warcraft/_forever_/Interface/AddOns/`. The addon’s `.toc` should be at `World of Warcraft/_forever_/Interface/AddOns/ZoneQuestTracker/ZoneQuestTracker.toc`.
3. Start WoW Forever and enable **ZoneQuestTracker** under **Quests** in the **AddOns** menu on the character selection screen.

The addon targets **WoW Forever 1.60.1 (Camelot)**, interface `16001`.

## Tracker controls

| Control | What it does |
| --- | --- |
| **Zone header** | Expand or collapse the zone, including during combat. The header and quest count stay visible, and your quests stay tracked. When quests are ready to turn in, the header shows how many, for example **Tanaris (4, 2 ready)**. |
| **Quest title (hover)** | In a group, show your party members’ progress on the quest. A party member’s progress appears when they also run ZoneQuestTracker 1.0.13 or later. |
| **Quest title (left-click)** | Focus the quest and open Blizzard’s map at its location. During combat, a closed map opens immediately and the focus circle moves to the quest; the map moves to the quest when combat ends if it is still open. Click the map pin to see details. The title shows the quest level when available. |
| **Quest title (right-click)** | Open Blizzard’s quest action menu. Out of combat, change tracking, share an eligible quest with your group, or open the confirmation to abandon it. |
| **Circle beside a quest** | Focus the quest on the map out of combat. Click again to clear the focus. The circle follows Blizzard’s **Quest Points of Interest** setting. |
| **Quest-item icon** | Hover over an active shortcut to identify the item. Left-click to use it from the tracker. In combat, existing buttons work while their icon stays in place and the game allows the item. New or moved shortcuts bind after combat. |
| **Mouse wheel** | Scroll when the list fills the available tracker space. |

Use Blizzard’s quest log to track quests that aren’t in the tracker. ZoneQuestTracker updates objective counts and turn-in status during combat. A completed quest shows a single **Ready for turn-in** line, marked with a green check, below its title and is listed first in its zone. Each watched quest appears once, under its quest-log category, its destination zone, or **Other**.

If you use ForeverCore, turn off its **Forever quest list** setting to avoid a duplicate quest list.

For the in-game test checklist and implementation details, see the [addon README](ZoneQuestTracker/README.md).
