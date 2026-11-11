# Changelog

## 0.1.5

- Fix class-coloured names briefly reverting to the native colour on mouseover.
  A secure post-hook reapplies selective colour in the same native name update.
- Remove the prototype command aliases; `/sfn` is the only addon command.
- Remove French documentation; ship the English README in the installable ZIP.
- Use English for all addon messages, help text and descriptions.

## 0.1.4

- First public release as **Smart Friendly Nameplates**.
- Add `/sfn` as the main command; retain `/bgc` and `/fgc` aliases.
- Preserve the existing addon folder and per-character saved variables.
- Add MIT licensing, English and French documentation, tests and ZIP packaging.

## 0.1.3 — prototype

- Add class-coloured text only when a friendly player's health bar is filtered.
- Restore normal name colours with full nameplates and when disabling the feature.

## 0.1.2 — prototype

- Fix taint errors caused by the previous name-only implementation.
- Use visual opacity changes without calling Blizzard's internal Lua helpers or
  modifying their state.

## 0.1.0–0.1.1 — prototype

- Introduce party/raid-or-individual-combat filtering and name-only display.
