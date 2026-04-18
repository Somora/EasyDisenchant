# EasyDisenchant Changelog
All notable changes to this project will be documented in this file.

## Version 1.0.3 (18/04/2026)

- Fixed an additional protected-action warning caused by enabling or disabling secure action buttons during refresh

## Version 1.0.2 (15/04/2026)

- Fixed a protected-action warning caused by hiding rows containing secure action buttons
- Empty rows are now cleared visually instead of hidden during list refreshes

## Version 1.0.1 (15/04/2026)

- Fixed profession action buttons by using secure spell-on-item targeting
- Removed obsolete action-flow fallback code
- Removed obsolete vendor-price filter internals
- Updated documentation for the secure in-window `Use` flow

## Version 1.0.0 (07/04/2026)

- First public-ready release
- Added a compact main window for `Disenchant`, `Mill`, and `Prospect`
- Added action-aware filters and search
- Added row-level `Use` and blacklist controls
- Added blacklist management window with tooltips
- Added minimap and Addon Compartment integration
- Added keybindings under the `EasyDisenchant` category
- Added saved window positions and `/sde resetpos`
- Added scroll support for the main list and blacklist
- Refined layout, footer, headers, and item-row alignment
- Improved Retail `120001` compatibility
