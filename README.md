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
combat and current-target rules are independent, optional conditions.
**Any enabled condition** keeps the full bar visible; otherwise the unit shows
its name only. Turning all three
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
The player/minion visibility conditions do
not change this NPC mode. NPC support is disabled by default.

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
2. Copy the **`FriendlyGroupCombat`** folder into:
   ```text
   World of Warcraft/_forever_/Interface/AddOns/
   ```
3. Check the resulting path:
   ```text
   Interface/AddOns/FriendlyGroupCombat/FriendlyGroupCombat.toc
   ```
4. Restart the game for the first installation and enable **Smart Friendly
   Nameplates** in the AddOns list. For an update, replace the files and `/reload`.

The folder and saved-variable names are kept from the prototype so existing
settings survive this rename. Replace an existing `FriendlyGroupCombat`
installation; do not install a second copy under another folder name.

The filter, group condition, combat condition and class-coloured name-only text
are enabled by default. Minion support is off by default. Existing users keep
their preferences; use `/sfn on` if needed.
The current-target rule and guild labels are off by default.

## In-game options

Open **Options → Add-ons → Smart Friendly Nameplates**, or type **`/sfn`**.

- **Enable friendly nameplate filtering**: master switch. Other preferences are
  kept when it is off.
- **Show health bars for group members**: keep bars for party/raid members,
  including grouped owners' minions when minion support is enabled.
- **Show health bars for units in combat**: use each unit's own combat state.
- **Show health bar for current target**: show a full bar for your selected
  eligible friendly player or minion, even outside your group and out of combat.
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
- **Show title below name-only NPCs**: display the NPC's localized title beneath
  its visible name, when available. Requires NPC support and hidden health bars.
- **Use native colours for name-only NPCs**: use the game's selection colour,
  green for friendly NPCs, while their health bar is hidden. Enabled by default.
- **Restore defaults**: enable filtering, group/combat conditions and class
  colours; disable minions, target, guild and NPC support. NPC preferences default
  to names only with titles when support is subsequently enabled.
- **Print status** and **Inspect target**: print diagnostics in chat.

Changes apply immediately and are saved in the active profile. Changes to protected
game settings wait until combat ends; the panel shows when changes are pending.
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

- Game-setting changes requested during combat wait until combat ends.
- Other players' combat and group changes are checked about every 0.2 seconds.
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
- Unknown or secret group/combat information leaves the full nameplate visible.
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
luac5.1 -p FriendlyGroupCombat/*.lua
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
`/sfn debug` to inspect their group/combat state.

## References

- [Forever unit API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Blizzard nameplate implementation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua)
- [Forever tooltip API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua)
- [NPC title extraction used by ElvUI](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/Tags/API.lua)
- [Friendly frame restrictions documented by Dynamic Display Nameplate](https://github.com/rubens-lopes/DynamicDisplayNameplate#inside-dungeons-and-raids)

This is an independent addon; it does not depend on Dynamic Display Nameplate.

## Licence

[MIT](LICENSE) © 2026 Seeow.
