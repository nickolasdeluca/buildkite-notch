# Buildkite Notch

**English** · [Português (Brasil)](docs/pt-BR/README.md)

A macOS notch that tracks the builds and deploys of your [Buildkite](https://buildkite.com)
pipelines, inspired by [Codenotch](https://github.com/vinzdg/codenotch).

- **Collapsed notch:** one ring per pipeline. The arc shows job progress in the state's color
  (yellow running, red failed, purple waiting for approval, green passed), with the elapsed time or
  how long ago the build finished.
- **Hover:** opens a card with a section per pipeline (progress bar, jobs, branch, commit) and the
  recent builds. Click any item to open the build on Buildkite.
- **Notifications** when a build passes, fails, is canceled or is waiting for approval.
- **Free placement:** top, bottom, left or right edge of any display. On the sides the notch turns
  vertical. Hold **⌥ Option** over the notch and drag it, or adjust it in Settings → Notch Position.
  On Macs with a hardware notch, placed at the top and centered, it merges with the camera housing.
- **Appearance:** Liquid Glass, Dark Glass or Solid Black.
- **Language:** English (US) or Portuguese (Brazil). Follows the macOS language and can be changed
  in Settings → General → Language.

## Installation

### Homebrew

```sh
brew install --cask nickolasdeluca/tap/buildkite-notch
```

### Manual

Download `BuildkiteNotch-<version>.zip` from the [latest release](https://github.com/nickolasdeluca/buildkite-notch/releases/latest),
unzip it and move `BuildkiteNotch.app` to `/Applications`. The app is signed and notarized by Apple.

Requires macOS 14 (Sonoma) or later, Apple Silicon or Intel.

## Setup

On first launch the Settings window opens by itself (later, use the menu bar icon).

1. Create a token at <https://buildkite.com/user/api-access-tokens> with the scopes
   `read_builds`, `read_pipelines` and `read_organizations`.
2. Paste the token and click **Connect**.
3. Pick the organization and check the pipelines you want to follow.
4. Optional: filter by branches (e.g. `main, production`).

The token is stored in the macOS Keychain. Nothing leaves your machine besides the calls to the
Buildkite API. The app polls every 10 s while builds are running and every 60 s when idle; both
intervals can be changed in Settings → Refresh Interval (10–3600 s). It waits at least 60 s after
hitting the rate limit.

## Development

Requires Xcode 16+ (Swift 6). There is no Xcode project: the app is a SwiftPM package and the
`Makefile` assembles the `.app`.

```sh
make run      # debug build, assembles build/BuildkiteNotch.app and opens it
make test     # core module tests
make release  # universal release build (arm64 + x86_64), ad-hoc signed
make install  # release + copy to /Applications
make icon     # regenerates Resources/AppIcon.icns from Scripts/make-icon.swift
```

Local builds are ad-hoc signed, so macOS may ask for Keychain access after each rebuild.

### Layout

```
Sources/BuildkiteNotchCore/   REST API v2, models, notification rules and notch geometry (no UI, testable)
Sources/BuildkiteNotch/       AppKit + SwiftUI app
  Localization/               Interface strings, one file per language
  Notch/                      Notch window, collapsed notch, card, styles
  Services/                   Settings, Keychain, polling (BuildStore), notifications
  Settings/                   Settings window
Tests/BuildkiteNotchCoreTests/
Resources/                    Info.plist and AppIcon.icns
Scripts/                      make-icon.swift, release.sh
docs/pt-BR/                   Portuguese (Brazil) translation of this README
```

## Distribution

Releases are signed with **Developer ID**, notarized and published on GitHub. The Homebrew cask
lives in [`nickolasdeluca/homebrew-tap`](https://github.com/nickolasdeluca/homebrew-tap).

One-time setup per machine:

1. **Developer ID Application certificate:** Xcode → Settings → Accounts → your team →
   Manage Certificates → **+** → *Developer ID Application*. Only the account's Account Holder can
   create it.
2. **Notarization credentials:** copy `Scripts/release.env.example` to `Scripts/release.env`
   (ignored by git) and fill in **one** of the options:
   - `NOTARY_PROFILE`: a profile saved with `xcrun notarytool store-credentials`. Profiles are per
     team, so one created for another project works here.
   - `APPLE_API_KEY_PATH`, `APPLE_API_KEY_ID` and `APPLE_API_ISSUER_ID`: an App Store Connect API
     key (Users and Access → Integrations → Keys).
3. **Homebrew tap:** a public `nickolasdeluca/homebrew-tap` repository (it can start empty).

To publish a version:

```sh
make bump VERSION=0.2.0   # updates Info.plist
# update CHANGELOG.md and commit
make dist                 # only builds a signed, notarized build/BuildkiteNotch-0.2.0.zip
make publish              # dist + tag + GitHub Release + cask update
```

Every variable is documented in `Scripts/release.env.example`. Variables exported in the shell take
precedence over the file.
