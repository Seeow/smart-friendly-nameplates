# Releases and issue lifecycle

Project ID: **1798982**. Repository:
<https://github.com/Seeow/smart-friendly-nameplates>.

The repository is prepared for CurseForge's native automatic packager. GitHub
Actions checks packaging without uploading. CurseForge builds and publishes the
files after it receives the configured webhook.

## One-time connection

1. In the CurseForge project's repository settings, link the external Git
   repository `https://github.com/Seeow/smart-friendly-nameplates.git`.
2. Select packaging for tagged versions rather than every branch commit. Ordinary
   development pushes should not create alpha uploads.
3. Create a token at <https://www.curseforge.com/account/api-tokens> for the
   packaging integration.
4. In GitHub repository **Settings → Webhooks → Add webhook**, use this payload
   URL, replacing the placeholder with the token:

   ```text
   https://www.curseforge.com/api/projects/1798982/package?token=<CURSEFORGE_API_TOKEN>
   ```

5. Use the **push** event and the other defaults specified in the official
   CurseForge guide. Check recent webhook deliveries after the first tag.

Keep the actual token out of repository files, issues and release notes. It is
only needed in the webhook configuration. Do not configure a second uploader
for the same tag, which would duplicate releases.

Creating this configuration does not publish a file by itself. The initial
project/file approval still applies; wait for the project to be ready before
pushing the first release tag. The live CurseForge service has not yet been
tested against this repository.

## Package layout

From 0.1.15, `.pkgmeta` uses `SmartFriendlyNameplates` as the installation folder.
It lifts the nested addon folder into the package root and keeps the
repository README and MIT licence alongside it:

```text
SmartFriendlyNameplates/
  SmartFriendlyNameplates.toc
  SmartFriendlyNameplates.lua
  Options.lua
  Localization.lua
  LocalesEurope.lua
  LocalesAsia.lua
  DiagnosticsLocalization.lua
  OptionsLocalization.lua
  README.md
  LICENSE
```

Tests, scripts, artwork and development files are excluded. `CHANGELOG.md` is
used as the Markdown file changelog. The packager's release type follows the
tag: names containing `alpha` or `beta` use that channel; a stable version tag
uses Release.

## Development and PR merge

Feature and fix branches do not prepare versions or releases. Keep both the TOC
version and Lua `VERSION` constant at the current published version. Add the
changes to `CHANGELOG.md` under `Unreleased`, creating that section if needed.

Merge tested PRs into `main` with their entries still under `Unreleased`. Merging
a PR does not assign a version or publish a release. Several PRs may accumulate
on `main` and ship together in one release.

Keep the related issues open. Reference them with `Related to #N` or `Refs #N`
in PR descriptions and commit messages. Do not use automatic closing keywords
such as `Fixes #N`, `Closes #N` or `Resolves #N`, or configure a link that closes
the issue when the PR merges. Issue closure happens after publication and the
issue announcement, as described below.

## Publish a version from main

1. Start from a clean, up-to-date `main` after the relevant PRs have merged.
   Review all accumulated `Unreleased` entries and choose the version. The
   release includes the unreleased changes already merged into `main`.
2. Update the version in both `SmartFriendlyNameplates.toc` and the Lua `VERSION`
   constant. Move the accumulated `Unreleased` entries into a new version section
   in `CHANGELOG.md`, retaining an `Unreleased` section for future changes.
3. Run the Lua checks and build locally. The packaging script verifies that the
   two version values match. The commands below use `0.2.4` as an example;
   substitute the version actually being prepared:

   ```powershell
   ./scripts/package.ps1 -Tag v0.2.4
   ```

4. Commit and push the release preparation changes to `main`, and wait for its
   checks to pass. Install the final version locally and verify the copied
   files as required by `AGENTS.md`.
5. Create and push the matching annotated tag on that tested `main` commit:

   ```sh
   git tag -a v0.2.4 -m "Release 0.2.4"
   git push origin v0.2.4
   ```

6. Publish the GitHub Release with its release notes and installable ZIP. Verify
   that the release is public, the tag targets the tested commit and the uploaded
   archive matches the local package. A draft release or a tag alone does not
   count as publication for issue closure.
7. Check the CurseForge webhook delivery, file, game version (**Forever 1.60.1**)
   and channel. If the file is not public yet, report publication as still in
   progress instead of claiming it is available or starting a second uploader.
   File moderation still applies. Existing users receive the file according to
   their selected release channel.

For test releases, use matching versions/tags such as `0.2.4-beta.1` /
`v0.2.4-beta.1`, or `0.2.4-alpha.1` / `v0.2.4-alpha.1`, and mark the GitHub
Release as a prerelease. These examples do not indicate a prepared version.

The native webhook starts independently of GitHub Actions; it does not wait for
tag checks. Always tag an already tested commit, and validate the proposed tag
with `package.ps1 -Tag` before pushing it. Automatic CurseForge packaging does
not create a GitHub Release; publish that separately as part of this workflow.

## Announce the release, then close issues

For every issue addressed by the release:

1. Confirm that the GitHub Release is public and its downloadable package is
   available. Keep the issue open until this is true.
2. Prepare a comment linking to that release, explaining how to use the change
   when relevant, and stating the actual CurseForge status. It is fine to say
   that CurseForge publication is still processing while the GitHub download
   is already available. Respect any requested user review before posting.
3. Post the release announcement on the issue and verify that it was published.
   If approval is pending or posting fails, leave the issue open.
4. Only after both the release and its issue comment are published, close the
   issue as completed. Repeat this for each included issue when a release
   contains several changes.

## Validation

CI performs a no-upload packaging run with the compatible BigWigs packager,
then checks the output with `scripts/check-curseforge-package.ps1`. This catches
nested folders and missing addon files without triggering a release. It is not
a live test of CurseForge's own service.

Official guide:
<https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging>.
