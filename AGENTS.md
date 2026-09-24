# AGENTS.md

Rules for AI agents (and humans) working on this repository. Read this before changing code or committing.

## Project

macOS menu-bar/notch app that tracks Buildkite builds. Swift 6, SwiftPM only (no `.xcodeproj`),
macOS 14+. The `Makefile` assembles the `.app` bundle from the SwiftPM executable.

- `Sources/BuildkiteNotchCore` — pure logic: Buildkite REST v2 client, models, build transitions
  (what triggers a notification), notch geometry. No AppKit/SwiftUI. Everything here must be unit-tested.
- `Sources/BuildkiteNotch` — the app: `NotchController` (AppKit panel, mouse monitors, layout),
  `NotchViews`/`NotchSurface` (SwiftUI), `BuildStore` (polling), `AppSettings` (UserDefaults + Keychain),
  `Notifier`, `SettingsView`.
- `Scripts/make-icon.swift` draws the icon; `Scripts/release.sh` signs, notarizes and publishes.

## Commands

```sh
make run     # debug build + launch (kills the running instance first)
make test    # swift test — must pass before every commit
make release # universal release build, ad-hoc signed
```

`swift build` must produce **zero warnings**. Keep Swift 6 strict concurrency clean; UI and state
types are `@MainActor`.

## Conventions

- Code, identifiers and code comments in **English**. User-facing strings (UI, notifications,
  errors) in **Brazilian Portuguese**.
- Put decision logic in `BuildkiteNotchCore` with tests; keep the app target thin.
- Geometry works in edge-relative terms (`ScreenEdge` + 0…1 position). Never assume the notch is on
  the top edge or that the screen has a hardware notch.
- All three appearance styles (Liquid Glass, Dark Glass, Solid Black) must stay legible on light and
  dark wallpapers. Use the fixed `Palette` colors in the card, not `.secondary`/`.tertiary`.
- Never log or persist the API token outside the Keychain.
- Respect Buildkite rate limits: don't add per-build or per-job requests to the polling loop.
- No new dependencies without asking the maintainer.

## Verifying UI changes

The sandbox usually lacks Screen Recording permission, so `screencapture` fails. Build, launch with
`make run`, and ask the maintainer for screenshots. Don't claim a visual change works without seeing it.

## Commits

- Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `build:`), imperative, English.
- **No `Co-Authored-By` trailers or "generated with" footers.** Authorship belongs to the human.
- Commit only when asked. Don't push to `main` or publish releases without explicit approval.
- User-visible changes get a line under `## [Unreleased]` in `CHANGELOG.md` (in Portuguese) in the
  same commit.

## Versioning and releases

The version lives in `Resources/Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`).

1. `make bump VERSION=x.y.z` (SemVer; also increments the build number).
2. Rename `## [Unreleased]` in `CHANGELOG.md` to `## [x.y.z] - YYYY-MM-DD` and open a new empty
   `## [Unreleased]` above it.
3. Commit: `chore: release x.y.z`.
4. `make publish` — builds universal, signs with Developer ID (hardened runtime), notarizes, staples,
   tags `vx.y.z`, creates the GitHub release with the changelog section as notes, and updates
   `Casks/buildkite-notch.rb` in `nickolasdeluca/homebrew-tap`.

Publishing is outward-facing and irreversible. Only the maintainer triggers it, or an agent with
explicit approval for that specific release. It needs the Developer ID certificate and
notarization credentials in `Scripts/release.env` (gitignored; see `release.env.example`). Never read,
print or commit that file or any `.p8` key.
