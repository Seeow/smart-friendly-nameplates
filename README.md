# Smart Friendly Nameplates

A lightweight, standalone **World of Warcraft: Forever** addon that keeps
Blizzard's friendly player health bars for the players you want to see.

## How it works

| Friendly player, with default settings | Display |
| --- | --- |
| In your party or raid | Full nameplate, even out of combat |
| Outside your group, but personally in combat | Full nameplate |
| Outside your group and out of combat | Name only, coloured by class |

The combat check concerns **that unit**, not your own combat state. Group,
combat, current-target, focus and mouseover rules are independent, optional conditions.
**Any enabled condition** keeps the full bar visible; otherwise the unit shows
its name only. Turning all visibility
conditions off shows names only for all eligible units while the master
filter is enabled.

Names return to their normal colour while their health bar is visible. Enemy
units and your personal resource display are left alone. An
optional setting extends the same conditions to friendly players' minions:
pets, guardians and totems. Minion names keep their native colours.

Friendly NPC support has its own display mode: native health bars or names
only, with NPC titles (for example, Weaponsmith) beneath the names when available.
Name-only NPCs use the game's selection colour (green for friendly NPCs), with
an independent switch enabled by default. Full bars retain normal name colours.
The player/minion visibility conditions do not change this NPC mode. A separate,
optional NPC-target rule can temporarily show the selected friendly NPC's full
bar while the other NPCs remain names only. NPC support and the NPC-target rule
are disabled by default.

The addon uses Blizzard's existing nameplate text. It does not recreate the
game engine's native 3D overhead names.

## Compatibility

- Targets **WoW Forever 1.60.1**, interface **16001**.
- No dependencies. Designed for the default Blizzard nameplates.
- Friendly nameplates protected by the game, notably in dungeons and raids,
  remain under Blizzard's control. Per-player filtering and colouring cannot
  be applied to those frames.
- Other WoW clients and nameplate addons are not currently supported.
- Addon text automatically follows the game's display language: English,
  French, German, Spanish (Spain and Latin America), Italian, Brazilian
  Portuguese, Russian, Korean, Simplified Chinese and Traditional Chinese.
  Missing translations fall back to English. The addon name, `/sfn` commands
  and technical diagnostic identifiers remain unchanged.

## Install

1. Download this repository using **Code → Download ZIP**, or clone it.
2. Copy the **`SmartFriendlyNameplates`** folder into:
   ```text
   World of Warcraft/_forever_/Interface/AddOns/
   ```
3. Check the resulting path:
   ```text
   Interface/AddOns/SmartFriendlyNameplates/SmartFriendlyNameplates.toc
   ```
4. Restart the game for the first installation and enable **Smart Friendly
   Nameplates** in the AddOns list. For an update, replace the files and `/reload`.

The addon folder, TOC and saved-variable names use `SmartFriendlyNameplates`.
Replace the existing installation rather than adding a second copy.

The filter, group condition, combat condition and class-coloured name-only text
are enabled by default. Minion support is off by default. Existing users keep
their preferences; use `/sfn on` if needed.
The current-target, focus, mouseover and NPC-target rules and guild labels are
off by default. The addon configures the necessary game options automatically;
no prior visit to the game's nameplate settings is required.

## In-game options

Open **Options → Add-ons → Smart Friendly Nameplates**, or type **`/sfn`**.
The scrollable panel groups profiles, player rules, minions, NPCs,
appearance and diagnostics. A summary shows which player conditions currently
keep bars visible. Preferences whose prerequisites are off are dimmed and
explained; they remain editable for later use.
Settings use the game's two-column layout: labels on the left, controls on the
right, section headings and a highlight on hover. Hover a row or its control for
the description and any prerequisites. Click a checkbox's label or row to toggle
it. The general Restore defaults button is at the top of the panel.

- **Enable friendly nameplate filtering**: master switch. Other preferences are
  kept when it is off.
- **Show health bars for group members**: keep bars for party/raid members,
  including grouped owners' minions when minion support is enabled.
- **Show health bars for units in combat**: use each unit's own combat state.
- **Show health bar for current target**: show a full bar for your selected
  eligible friendly player or minion, even outside your group and out of combat.
- **Show health bar for focus**: keep a full bar for the eligible friendly player
  or minion set as your focus. Off by default.
- **Show health bar on mouseover**: keep a full bar while the pointer is over an
  eligible friendly player or minion. Off by default.
- **Apply filtering to friendly player minions**: extend the same rules to pets,
  guardians and totems, without changing ordinary NPCs.
- **Use class colours for names without health bars**: apply class colours only
  to name-only players while filtering is enabled.
- **Show guild below name-only players**: display the player's guild beneath
  their visible name, when guild information is available. Hide it with full bars.
- **Include friendly NPCs**: enable native friendly NPC nameplates and manage
  their display separately from players and minions.
- **Show health bars for friendly NPCs**: keep native bars when checked; use
  names only when unchecked. Independent of group, combat and target conditions.
- **Show health bar for targeted NPC**: in names-only NPC mode, temporarily show
  a full bar for the friendly NPC you select. This does not change the separate
  player/minion target rule. Off by default.
- **Show title below name-only NPCs**: display the NPC's localized title beneath
  its visible name, when available. Requires NPC support and hidden health bars.
- **Use native colours for name-only NPCs**: use the game's selection colour,
  green for friendly NPCs, while their health bar is hidden. Enabled by default.
- **Subtitle appearance**: choose font size (8–24, default 12), gap below the
  name (0–12, default 2), colour using the game's native colour picker, and
  whether to wrap the text in `<…>` (on by default). Click the colour swatch
  to preview changes live; Cancel restores the previous colour. The adjacent
  **Default** button resets only the colour (RGB 0.7/0.85/0.7). These
  controls affect the addon's guild and NPC-title subtitles, not native names.
- **Restore defaults**: enable filtering, group/combat conditions and class
  colours; disable minions, target/focus/mouseover rules, guild and NPC support.
  NPC preferences default to names only with titles, with the NPC-target rule off.
  Reset subtitle appearance too. Only the active profile changes.
- **Print status** and **Inspect target**: print diagnostics and the reason for
  a unit's display, including protected or paused nameplates.
- **Retry setup**: reapply required game settings and rescan accessible
  nameplates, including those paused after an earlier visual error.
- **Copyable report**: open a selectable diagnostic report for bug reports.
  Press Ctrl+C to copy it; Escape closes the window.
- **Count work for performance checks**: optionally collect operation counts
  for this session. Refresh or copy a report to read them; reset them before a
  comparison. The counters do not measure FPS or CPU time.

Changes apply immediately and are saved in the active profile. Changes to protected
game settings wait until combat ends. The panel distinguishes that wait from
failed changes, unavailable settings and settings changed elsewhere. It shows
the effective setup state rather than treating every requested change as applied.
The panel scrolls to keep every option accessible and shares saved preferences
with slash commands.
Labels, descriptions, chat messages, warnings and diagnostics follow `GetLocale()`.
There is no separate language preference to keep in sync with the game. Translated
button labels wrap and the panel adjusts its layout to fit them.

## Profiles

Use **Use global profile** at the top of `/sfn` to choose where settings are saved:

- **Unchecked — Character:** use this character's independent preferences.
- **Checked — Global:** share preferences with other characters that also select
  Global, across realms within the same WoW account and installation.

Existing preferences remain in the Character profile, selected by default.
The first time Global is selected, it starts as a copy of that character's
current settings. Later switches preserve both profiles without copying over
either one. All feature switches, including the master filter, belong to the
active profile. **Restore defaults** only resets that profile and does not change
the selection. The panel and `/sfn status` identify the active profile.

**Copy to global** and **Copy to character** replace the destination profile's
feature preferences with those of the active profile. Copying does not switch
the active profile, transfer another character's original game settings, or
change which profile a character selects. Existing destination preferences are
overwritten only when you press the corresponding copy button.

Shared settings become available to the next character after a normal logout or
`/reload` saves them. Each character still keeps its own original game-setting
values so disabling the addon restores the correct values for that character.

## Commands

| Command | Action |
| --- | --- |
| `/sfn` or `/sfn options` | Open the in-game options panel (out of combat) |
| `/sfn on` | Enable the filter and its required game settings |
| `/sfn off` | Restore nameplates and the previous settings still owned by the addon |
| `/sfn colors on` | Use class colours only for name-only players |
| `/sfn colors off` | Stop selective colouring and restore the previous global colour option |
| `/sfn status` | Show version, settings and diagnostic information |
| `/sfn debug` | Inspect group/combat information for your current target |
| `/sfn retry` | Reapply setup and rescan accessible nameplates after an error or external change |
| `/sfn report` | Open a selectable, copyable diagnostic report |
| `/sfn metrics on` or `/sfn metrics off` | Enable or disable optional operation counters for this session |
| `/sfn metrics reset` | Reset the operation counters |

Turn the filter off with `/sfn off` **out of combat before uninstalling**. An
addon that is no longer loaded cannot restore game settings.

## Game settings and limitations

While enabled, the addon turns friendly player nameplates on and the global
name-only option off. Selective colouring also keeps the global **Use Class
Color for Names** option off, applying colour directly to name-only text.
Previous values are saved per character, including across `/reload`.
Minion support also enables Blizzard's friendly player minion nameplates and
restores that setting when disabled. Native minion subtype and distance rules
still apply.
NPC support likewise manages and restores `nameplateShowFriendlyNpcs`.
Changes to these settings made elsewhere are detected without repeatedly forcing
the addon's values back. The panel reports the mismatch; use **Retry setup** or
`/sfn retry` when you want the addon's preferences reapplied. A later explicit
option change or world entry can also reapply the settings it requires.

- Game-setting changes requested during combat wait until combat ends.
- Other players' combat and group changes are checked about every 0.2 seconds.
- Unchanged visual values are not rewritten on every check. The periodic check
  remains in place to repair native alpha resets; events for unrelated units do
  not trigger a full update of every tracked nameplate.
- Group owner tokens are reused where possible. A previously found minion owner
  is checked again against current information; protected ownership data still
  leaves the full bar visible.
- Name colours are reapplied immediately after Blizzard updates names, including
  when hovering players or NPCs, so the periodic check does not cause a colour flash.
- Name width and truncation remain under the game's control.
- Guild labels use available, non-secret guild text only. Missing information
  displays no guild line. Guild labels follow native name visibility and do not
  appear for minions or ordinary NPCs.
- NPC titles use the expected title line in `C_TooltipInfo.GetUnit`, accounting
  for colourblind mode. There is no dedicated title API; this position-based
  extraction must be verified in game. Missing or protected text and typed
  level/type/quest lines produce no subtitle. A title is cached until the
  nameplate is removed or its name changes; missing data is retried every 2 s.
- Unknown or secret group/combat or selected-unit comparison information leaves
  the full nameplate visible when an enabled rule requires that information.
- Only enabled conditions are checked. A disabled condition's restricted data
  does not affect visibility.
- Health-based filtering is unavailable on this client: the unit API declares
  current health as a secret value. No below-full-health option is provided.
- Minion group membership uses pet membership and, for guardians/totems, guarded
  ownership checks against party/raid members. Restricted ownership leaves the
  full bar visible.
- Unknown or secret class/colour information leaves the native colour intact.
- Hidden health bars can still occupy stacking space and retain their normal
  click area. Native name-display, distance and simplified-style rules apply.
- Avoid other addons that also change friendly nameplate visibility or opacity.

Only visual C API methods are used to filter plates and colour text. A secure
post-hook keeps colours in sync after native name updates. The addon does not
read health values, call/replace Blizzard's name updater, or modify its Lua
health/layout state.
Automated checks simulate the event loop; actual client restrictions and visual
behaviour still require in-game testing.

## Development

Run the integration checks and Lua syntax check from the repository root:

```sh
lua5.1 tests/test_addon.lua
luac5.1 -p SmartFriendlyNameplates/*.lua
```

Lua 5.1 is the compatibility target. The test harness also runs on newer Lua
interpreters or Fengari; those do not reproduce WoW's secure execution engine.
GitHub Actions runs the tests using Lua 5.1.

Build an installable ZIP with PowerShell:

```powershell
pwsh -File scripts/package.ps1
```

The archive is written to `dist/` and contains the correctly named addon folder
and the MIT licence. Build output and local test tools are not committed.

CurseForge's native packager is configured through `.pkgmeta` for project
**1798982**. See [Releasing](docs/RELEASING.md) for the one-time webhook setup,
version/tag checks and the release process. The webhook connection is configured
separately; normal CI packaging runs never upload a release.

For bug reports, include the client version, zone/instance type, `/sfn status`,
and the first Lua error if present. Target the affected player and use
`/sfn debug` to inspect their state and the reason for their display, or attach the
text from **Copyable report**. Reports contain diagnostic settings and current
target state.

### In-game verification

The automated tests simulate APIs and events; they cannot validate the client's
secure execution engine or the rendered result. Before treating a new build as
verified in game, check:

1. Fresh setup with friendly player, minion and NPC plates initially disabled in
   the game options. Enable each corresponding addon option and check the actual
   game setting and panel state; disable it and check restoration.
2. Group/combat/target/focus/mouseover rules separately and together. Confirm
   mouseover and focus exceptions affect eligible players/minions only, and the
   NPC-target exception follows its independent switch.
3. A game setting changed manually while the addon is active. Confirm a conflict
   is reported without a repeated fight over the setting, then try **Retry setup**.
   Repeat setup changes in combat and verify that only game-setting writes wait.
4. Guild and NPC-title appearance at different interface scales, through bar
   visibility changes and nameplate reuse. Check the report dialog with a long
   report and a narrow or scaled interface.
5. Town crowds, pets/guardians/totems, party/raid changes and protected nameplates
   in instances. Protected plates must remain under the game's control.

For repeatable performance checks, use the same scene, options and observation
duration. Enable counters, reset them, wait without changing the setup, and copy
the report. Compare operation counts between builds in a quiet area, a crowded
town and a group with minions. Use the game's profiling tools separately if CPU
or FPS measurements are needed. No FPS improvement is claimed from counter or
simulated-test results alone.

## References

- [Forever unit API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Blizzard nameplate implementation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua)
- [Forever tooltip API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua)
- [NPC title extraction used by ElvUI](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/Tags/API.lua)
- [Friendly frame restrictions documented by Dynamic Display Nameplate](https://github.com/rubens-lopes/DynamicDisplayNameplate#inside-dungeons-and-raids)

This is an independent addon; it does not depend on Dynamic Display Nameplate.

## Licence

[MIT](LICENSE) © 2026 Seeow.
