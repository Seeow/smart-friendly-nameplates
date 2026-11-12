# CurseForge releases

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
  README.md
  LICENSE
```

Tests, scripts, artwork and development files are excluded. `CHANGELOG.md` is
used as the Markdown file changelog. The packager's release type follows the
tag: names containing `alpha` or `beta` use that channel; a stable version tag
uses Release.

## Publish a version

1. Update the version in both `SmartFriendlyNameplates.toc` and the Lua `VERSION`
   constant, and add the version's notes to `CHANGELOG.md`.
2. Run the Lua checks and build locally. The packaging script verifies that the
   two version values match. For example, after changing them to `0.1.15`:

   ```powershell
   ./scripts/package.ps1 -Tag v0.1.15
   ```

3. Commit and push the changes to `main`, and wait for its checks to pass.
4. Create and push the matching annotated tag:

   ```sh
   git tag -a v0.1.15 -m "Release 0.1.15"
   git push origin v0.1.15
   ```

For test releases, use matching versions/tags such as `0.1.15-beta.1` /
`v0.1.15-beta.1`, or `0.1.15-alpha.1` / `v0.1.15-alpha.1`. The current prepared
version is `0.1.15`; use its matching tag only if intentionally publishing it.

5. Check the CurseForge file, its game version (**Forever 1.60.1**) and channel.
   File moderation still applies. Existing users receive the file according to
   their selected release channel.

The native webhook starts independently of GitHub Actions; it does not wait for
tag checks. Always tag an already tested commit, and validate the proposed tag
with `package.ps1 -Tag` before pushing it. Automatic CurseForge packaging does
not create a GitHub Release; that can be added separately if desired.

## Validation

CI performs a no-upload packaging run with the compatible BigWigs packager,
then checks the output with `scripts/check-curseforge-package.ps1`. This catches
nested folders and missing addon files without triggering a release. It is not
a live test of CurseForge's own service.

Official guide:
<https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging>.
