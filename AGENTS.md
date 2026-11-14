# Working Instructions

## Required Local Installation

The user requests that the addon in their game be updated after every change.
After running checks appropriate to the change, run `./scripts/install-local.ps1`
to copy the current version to:

`<GAME_ROOT>/Interface/AddOns/SmartFriendlyNameplates`

Run `./scripts/setup.ps1` to create `.env` from `.env.example` if needed; an existing
configuration is preserved. Configure the local game client directory using
`GAME_ROOT` in the repository-root `.env` file. The installer also accepts the `GAME_ROOT`
environment variable or an explicit `-GameRoot` override. Keep machine-specific
paths in local configuration rather than tracked files.

This copy operation is permanently authorized; use sandbox elevation if necessary.
Verify that the installed files match the sources and report any installation
failure. Remind the user to run `/reload` to load the changes if the game is open.
Preserve the player's saved settings.

## Subagents

The user authorizes autonomous use of subagents when it improves the quality,
speed, or reliability of the work. Avoid unnecessary delegation for simple tasks
and verify the integrated results.
