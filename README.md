# EasyDisenchant

EasyDisenchant is a Retail World of Warcraft addon for quickly handling `Disenchant`, `Mill`, and `Prospect` actions from one compact window.

## Features

- One window for `Disenchant`, `Mill`, and `Prospect`
- Fast item list with search and action-specific filters
- `Rarity` and `Bind` filters for disenchanting
- Compact `Use` button per row for direct action
- Per-item blacklist button in the main list
- Separate blacklist management window
- Minimap button
- Addon Compartment support
- Keybindings under `EasyDisenchant`
- Combat lock overlay to prevent protected-action issues
- Tooltips on items, blacklist entries, and column headers
- Secure action buttons for profession spell targeting

## Commands

- `/sde`
- `/sde blacklist`
- `/sde minimap`
- `/sde resetpos`
- `/sde help`

## Keybindings

EasyDisenchant registers these bindings in WoW's Key Bindings UI:

- `Toggle Window`
- `Toggle Blacklist`
- `Use Selected Action`
- `Toggle All Windows`

Note: profession spell-on-item actions are performed through the secure in-window `Use` buttons. This keeps disenchanting, milling, and prospecting safe from accidental item use or equip attempts.

## Notes

- `Rarity`, `Bind`, and `Item level` are only shown for `Disenchant`
- White and gray items are hidden from excluded results for disenchanting
- Use the row-level `Use` button or the main action button to perform the selected profession action
- The minimap button supports:
  - Left-click: toggle main window
  - Right-click: toggle blacklist
  - Shift-click: reset minimap button position

## Installation

1. Place the addon in:
   `World of Warcraft\_retail_\Interface\AddOns\EasyDisenchant\`
2. Make sure the `.toc` file is directly inside the `EasyDisenchant` folder
3. Restart WoW or reload the UI

## Version

Current release: `1.0.3`
