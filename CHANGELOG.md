# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-09-25

### Added

- Configurable polling intervals in Settings → Refresh Interval, one while builds run (default
  10 s) and one when idle (default 60 s), each from 10 to 3600 s.

### Changed

- The idle polling interval defaults to 60 s instead of 30 s.

## [0.2.0] - 2026-09-24

### Added

- English (en-US) interface alongside Portuguese (pt-BR). The app follows the macOS language and
  can be switched in Settings → General → Language.

### Fixed

- The Homebrew cask uses the current `depends_on macos` syntax, with no deprecation warning.

## [0.1.0] - 2026-09-24

### Added

- Notch with one progress ring per pipeline and a card that expands on hover.
- Placement on any edge of any display, with ⌥ Option drag.
- Notifications for builds that passed, failed, were canceled or are waiting for approval.
- Settings: token in the Keychain, organization, pipelines, branch filter, placement, appearance
  (Liquid Glass, Dark Glass, Solid Black), notifications and open at login.
- Dock icon while Settings is open.
- Distribution signed with Developer ID, notarized and installable via Homebrew.
