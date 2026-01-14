# linux-rebuild-manager — Enterprise Documentation

## Overview

linux-rebuild-manager is a Linux environment migration tool designed to
reconstruct user environments across machines without relying on
disk imaging or filesystem snapshots.

It is suitable for power users, system administrators, academic labs,
and multi-machine Linux setups.

---

## Design Goals

- Environment portability across hardware
- Separation of OS and user environment
- Predictable rebuild workflow
- Human-readable rebuild data
- Minimal system coupling

---

## What the tool migrates

### Applications
- Manually installed APT packages
- User-installed Snap applications
- User-installed Flatpak applications

### User configuration
- Desktop and UI preferences
- Application settings
- Flatpak metadata
- Safe subsets of `~/.config` and `~/.local/share`

---

## What the tool does NOT migrate

- System files
- Kernel or bootloader data
- Disk partitions
- User documents, media, or personal files
- System services

---

## Security & Safety Model

- No destructive operations
- No raw disk access
- No filesystem-level manipulation
- Explicit user action for every step
- Read-only inspection where possible

---

## Typical Rebuild Workflow

1. Perform a fresh Linux installation
2. Install linux-rebuild-manager
3. Import saved application lists
4. Restore user configuration selectively
5. Reboot and verify environment

---

## Comparison with Other Tools

| Tool | Purpose |
|-----|--------|
| Timeshift | Filesystem snapshots |
| Clonezilla | Disk cloning |
| rsync | File-level backup |
| linux-rebuild-manager | User environment reconstruction |

---

## Distribution Formats

- `.deb` for Debian / Ubuntu-based systems
- `.AppImage` for cross-distribution portability
- Source execution for custom setups

---

## License

MIT License
