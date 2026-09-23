# EasyDisenchant

EasyDisenchant is a Retail World of Warcraft addon for quickly handling `Disenchant`, `Mill`, and `Prospect` actions from one compact window.

## Features

- One window for `Disenchant`, `Mill`, and `Prospect`
- Fast item list with search and action-specific filters
- `Rarity` and `Bind` filters for disenchanting
- Compact `Use` button per row for direct action
- Per-item blacklist button in the main list
- Separate blacklist management window
- Minimap button, with a visibility checkbox under Settings > AddOns > EasyDisenchant
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

## Action macro

The main action button can be clicked from a macro:

```text
/click EasyDisenchant_Action
```

Select an item and action in the EasyDisenchant window first. Each macro activation uses the current selection, just like clicking the main action button; it does not process all items automatically.

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
- Under Settings > AddOns > EasyDisenchant, uncheck `Show minimap icon` to hide it immediately. The preference is saved between sessions.
- Shift-click the EasyDisenchant entry in the Addon Compartment to toggle the minimap icon, or use `/sde minimap` to restore it.

## Installation

1. Place the addon in:
   `World of Warcraft\_retail_\Interface\AddOns\EasyDisenchant\`
2. Make sure the `.toc` file is directly inside the `EasyDisenchant` folder
3. Restart WoW or reload the UI

## Version

Current release: `1.0.12`
