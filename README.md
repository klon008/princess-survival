# Princess Survival release tools

## Publishing launcher updates

The launcher is distributed as a self-contained single-file x64 executable. To
publish a new launcher build, run:

```powershell
.\publish-launcher.ps1 -Version 1.0.5
```

The script builds the launcher, creates a `launcher-v<version>` release with
`PrincessLauncher.exe`, its SHA-256 manifest, and the current game manifest and
changelog. It then updates `launcher-manifest.json` on the `main` branch.
Launchers check this stable manifest URL and replace themselves after verifying
the downloaded file. Including game metadata in launcher releases keeps older
launchers working while they still use GitHub's `/releases/latest` URL. The
script uses GitHub CLI authentication and needs write access to the repository.

This repository contains the scripts and the game executable used to publish
stable game updates to GitHub Releases. Release archives and manifests are
uploaded as release assets; `dist/` and ZIP files are excluded from Git history.

## One-time setup

1. Install [7-Zip](https://www.7-zip.org/) and GitHub CLI (`gh`).
2. Run `gh auth login` and authenticate with an account that can publish to
   `klon008/princess-survival`.
3. Clone this repository and keep the game build files beside `pack-release.ps1`.

## Routine game update

Copy the complete Windows export into this repository's root, replacing the
previous game build. If the export has sidecar files (for example a `.pck` or
runtime DLLs), copy those too; the script archives all game files in the folder.
Add the release notes to `changelog/<version>.json`, then run:

```powershell
.\release.ps1 -Version 1.1.0
```

This creates the versioned game release with ZIP, manifest, and changelog, then
updates the stable game metadata on `main`. Keep using a new version each time;
existing release tags are deliberately not overwritten.

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

The current launcher fetches the stable game metadata from the repository's
`main` branch; the manifest points to a ZIP attached to its versioned game tag.
This keeps game downloads working even when a launcher release is newer than
the latest game release:

* `https://raw.githubusercontent.com/klon008/princess-survival/main/manifest.json`
* `https://raw.githubusercontent.com/klon008/princess-survival/main/changelog.json`
* `https://github.com/klon008/princess-survival/releases/download/v<version>/PrincessSurvival-<version>-win64.zip`

To repair an existing game release after publishing launcher releases, run
`repair-game-release.ps1 -Version 1.0.0`. It updates the stable metadata on
`main` and attaches `manifest.json` and `changelog.json` to the current latest
release for compatibility with older launchers that still use GitHub's
`releases/latest/download/` URLs.

For manual use, `pack-release.ps1` builds the files and `publish-release.ps1`
publishes already built files. The combined entry point above is preferred for
normal releases so an old ZIP cannot accidentally be published.
