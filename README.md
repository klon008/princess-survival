# Princess Survival release tools

This repository contains the scripts and the game executable used to publish
stable game updates to GitHub Releases. Release archives and manifests are
uploaded as release assets; `dist/` and ZIP files are excluded from Git history.

## One-time setup

1. Install [7-Zip](https://www.7-zip.org/) and GitHub CLI (`gh`).
2. Run `gh auth login` and authenticate with an account that can publish to
   `klon008/princess-survival`.
3. Clone this repository and keep the game build files beside `pack-release.ps1`.

## Publish a game release

From this directory, run:

```powershell
.\release.ps1 -Version 1.2.3 -Notes "What's new in this version"
```

The script rebuilds the ZIP, validates its entries, writes `dist/manifest.json`
(including the archive SHA-256, size, version, and stable download URL), then
builds `dist/changelog.json` from `changelog/*.json` and creates GitHub Release
`v1.2.3` with all three files attached. Existing releases are
not overwritten. To retain only the newest three releases, add
`-PruneOld -Keep 3`.

To attach changelog data to an already published release without replacing its
game archive, run `.\publish-changelog.ps1 -Version 1.0.0`.

The launcher can fetch the current stable files from:

* `https://github.com/klon008/princess-survival/releases/latest/download/manifest.json`
* `https://github.com/klon008/princess-survival/releases/latest/download/PrincessSurvival-<version>-win64.zip`
* `https://github.com/klon008/princess-survival/releases/latest/download/changelog.json`

For manual use, `pack-release.ps1` builds the files and `publish-release.ps1`
publishes already built files. The combined entry point above is preferred for
normal releases so an old ZIP cannot accidentally be published.
