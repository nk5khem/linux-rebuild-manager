## [1.0.3] – 2026-01-15

### Fixed
- Automatic Flatpak installation during restore if missing
- Flathub remote setup even when Flatpak is already installed
- Flatpak restore skipping due to snapshot path mismatches
- DEB package version mismatch with CLI version
- Improved robustness of Flatpak restore on fresh systems


## v1.0.2
- Fix Flatpak restore using application IDs instead of display names

## v1.0.1
- Added Zenity-based GUI (no terminal required)
- Guaranteed GNOME application menu entry
- Snapshot file chooser support
- CLI and GUI modes both supported

# Changelog

All notable changes to linux-rebuild-manager are documented in this file.

The format is based on Keep a Changelog and follows Semantic Versioning.

---

## [1.0.0] - Initial stable release

### Added
- Migration of installed applications (APT, Snap, Flatpak)
- User configuration collection
- Menu-based interface
- Debian (.deb) packaging
- AppImage packaging
