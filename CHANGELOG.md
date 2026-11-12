# Changelog

## 0.1.13

- Use the game's native selection colour for name-only friendly NPCs (green),
  with an independent option enabled by default. Preserve vertex alpha and
  restore native nameplate colours on full bars, disabling and frame reuse.
- Reapply NPC colours immediately after native name updates, including hover.
- Leave names unchanged when selection colour information is unavailable or
  protected. Player class colours and minion names retain their existing rules.

## 0.1.12

- Add friendly NPC support with a separate choice of native health bars or
  names only, independent of player/minion group, combat and target rules.
- Add NPC titles beneath name-only NPCs, using available localized tooltip
  text. Reject protected data and non-title line types; cache per plate lifetime
  and retry missing data without scanning every update.
- Keep NPC support disabled by default. Save and restore the native friendly
  NPC nameplate setting, deferring protected changes until combat ends.
- Translate all new settings and diagnostics into every supported language.

## 0.1.11

- Automatically localize the in-game panel, chat messages, warnings, diagnostics
  and AddOns-list descriptions using the client's display language.
- Add French, German, Spanish (Spain and Latin America), Italian, Brazilian
  Portuguese, Russian, Korean, Simplified Chinese and Traditional Chinese.
- Fall back to English for unknown locales or missing translation keys. Keep
  addon branding, slash commands and technical diagnostic identifiers stable.
- Measure and wrap translated button labels to fit narrower options panels.

## 0.1.10

- Remove the experimental name-width slider and all name geometry overrides.
- Remove its saved preference on load and leave name width under native control.
- Retain the in-game options, group/combat/target rules, minion support and guild
  labels from the preceding local versions.

## 0.1.9

- Fix the width slider doing nothing for centered names with a single anchor
  or names constrained by an explicit FontString width.
- Resize both the anchor span and the text width; restore the original explicit
  width on full bars, disabling and frame reuse.
- Measure native width with the addon's own constraints removed so the slider
  follows native resizing without compounding on each update.
- Report unavailable or restricted name layouts in `/sfn status`.

## 0.1.8

- Add an optional current-target condition to show a full friendly health bar.
- Add optional guild text below name-only players, following native name
  visibility and clearing on full bars, disabling and frame reuse.
- Add a 100–500% name-only text-width slider, with the game default identified
  as 100% of the current native width. Preserve vertical placement and alignment.
- Securely reapply width after native anchor updates and restore native anchors
  on full bars, disabling and reuse. Leave unconstrained layouts unchanged.
- Keep new options off/native by default and save them per character.

## 0.1.7

- Keep the master filter and add independent group and combat visibility rules.
- Add optional friendly player minion filtering for pets, guardians and totems,
  including guarded group ownership checks. Keep their native name colours.
- Own and restore the native friendly player minion nameplate setting only while
  minion support is enabled.
- Make the options panel scrollable with responsive text and button layout.
- Preserve current behaviour by default: group/combat on, minions off.
- Omit health-based filtering because this client's current-health API returns
  secret values that cannot drive addon visibility decisions.

## 0.1.6

- Add an in-game panel under Options → Add-ons → Smart Friendly Nameplates.
- Expose filter and name-only class-colour settings, per-character persistence,
  restore defaults, and status/target diagnostic buttons.
- Keep panel controls and slash commands in sync, including pending game-setting
  changes that must wait until combat ends.
- Open the options panel with `/sfn` or `/sfn options`.

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
