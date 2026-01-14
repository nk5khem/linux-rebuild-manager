# linux-rebuild-manager — Roadmap

This document outlines the planned enhancements and long-term direction
of the linux-rebuild-manager project.

The roadmap is intentionally incremental, focusing on stability,
clarity, and professional-grade usability.

---

## Phase 1 — Distribution & Releases

### 1. 📦 Create GitHub Releases (.deb + AppImage)
Publish official, versioned releases using GitHub Releases so users can
download prebuilt `.deb` and `.AppImage` artifacts without cloning the repository.

Goals:
- Provide a stable download location
- Reduce friction for new users
- Establish release history

---

## Phase 2 — Versioning & Change Tracking

### 2. 🏷️ Add versioning & changelog
Introduce semantic versioning (`vMAJOR.MINOR.PATCH`) and maintain a
`CHANGELOG.md` documenting:
- New features
- Behavioral changes
- Bug fixes

Goals:
- Predictable upgrade path
- Clear communication with users
- Professional release discipline

---

## Phase 3 — Platform Awareness

### 3. ⚙️ Add auto-detection for distro support
Automatically detect:
- Linux distribution
- Available package managers (APT, Snap, Flatpak)

Based on detection:
- Enable supported features
- Gracefully skip unsupported ones
- Avoid runtime errors

Goals:
- Better cross-distribution behavior
- Clear user feedback
- Reduced manual configuration

---

## Phase 4 — Automation & CI

### 4. 🤖 Add GitHub Actions for builds
Set up GitHub Actions workflows to:
- Build `.deb` packages
- Build `.AppImage` artifacts
- Attach outputs to GitHub Releases

Goals:
- Reproducible builds
- Reduced manual effort
- Consistent release quality

---

## Phase 5 — Documentation Enhancements

### 5. 📖 Add a man page section to README
Expand documentation to include:
- `man rebuild-manager` overview
- Command synopsis
- Option descriptions
- Usage examples

Goals:
- Better CLI discoverability
- Stronger terminal-first user support

---

## Phase 6 — Repository Polish & Presentation

### 6. 🧹 Repo polish (badges, screenshots, releases page)
Improve project presentation by adding:
- Status badges (license, latest release)
- Screenshots of the menu-based interface
- Structured GitHub Releases page

Goals:
- Improve first impressions
- Increase trust and clarity
- Make the project easier to evaluate

---

## Guiding Principles

- Stability over feature count
- Explicit behavior over hidden automation
- Clear scope (environment rebuild, not backups)
- Documentation as a first-class feature

---

## Status

This roadmap is a living document and may evolve as the project grows.

