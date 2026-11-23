# Working Instructions

## Releases and Issue Closure

Follow [docs/RELEASING.md](docs/RELEASING.md) for the full workflow.

- Feature and fix branches keep the current addon version. Add their changelog
  entries under `Unreleased`; leave them there when merging the PR.
- Prepare versions only on `main`, after the relevant PRs have merged. A release
  can include several PRs. Only then update the TOC and Lua versions and move
  the accumulated `Unreleased` entries into the new version's changelog section.
- Keep issues open through implementation and PR merge. Use `Related to #N`
  or `Refs #N` in PR descriptions and commit messages; avoid closing keywords
  such as `Fixes`, `Closes` and `Resolves`, or links that auto-close on merge.
- Close each included issue only after the release is publicly available and
  its release announcement comment has been successfully posted on that issue.
  A merged PR, pushed tag, draft release or unposted comment is insufficient.
- The issue comment must link to the published release and accurately state
  CurseForge availability. If publication is still processing, say so. Respect
  any user-requested review of the comment and keep the issue open while the
  comment is awaiting approval or publication.

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
