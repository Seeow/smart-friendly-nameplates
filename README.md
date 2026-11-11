# Smart Friendly Nameplates

A lightweight, standalone **World of Warcraft: Forever** addon that keeps
Blizzard's friendly player health bars for the players you want to see.

## How it works

| Friendly player | Display |
| --- | --- |
| In your party or raid | Full nameplate, even out of combat |
| Outside your group, but personally in combat | Full nameplate |
| Outside your group and out of combat | Name only, coloured by class |

The combat check concerns **that player**, not your own combat state. Names
return to their normal colour while their health bar is visible. Enemy units,
NPCs, and your personal resource display are left alone.

The addon uses Blizzard's existing nameplate text. It does not recreate the
game engine's native 3D overhead names.

## Compatibility

- Targets **WoW Forever 1.60.1**, interface **16001**.
- No dependencies. Designed for the default Blizzard nameplates.
- Friendly nameplates protected by the game, notably in dungeons and raids,
  remain under Blizzard's control. Per-player filtering and colouring cannot
  be applied to those frames.
- Other WoW clients and nameplate addons are not currently supported.
- Addon text is in English. Names and other text supplied by Blizzard follow
  the game's language settings.

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

The filter and class-coloured name-only text are enabled by default. Existing
users keep their enabled/disabled settings; use `/sfn on` if needed.

## Commands

| Command | Action |
| --- | --- |
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

- Game-setting changes requested during combat wait until combat ends.
- Other players' combat and group changes are checked about every 0.2 seconds.
- Name colours are reapplied immediately after Blizzard updates names, including
  when hovering players or NPCs, so the periodic check does not cause a colour flash.
- Unknown or secret group/combat information leaves the full nameplate visible.
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
luac5.1 -p FriendlyGroupCombat/FriendlyGroupCombat.lua
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

For bug reports, include the client version, zone/instance type, `/sfn status`,
and the first Lua error if present. Target the affected player and use
`/sfn debug` to inspect their group/combat state.

## References

- [Forever unit API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Blizzard nameplate implementation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua)
- [Friendly frame restrictions documented by Dynamic Display Nameplate](https://github.com/rubens-lopes/DynamicDisplayNameplate#inside-dungeons-and-raids)

This is an independent addon; it does not depend on Dynamic Display Nameplate.

## Licence

[MIT](LICENSE) © 2026 Seeow.
