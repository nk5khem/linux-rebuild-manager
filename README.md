# linux-rebuild-manager

linux-rebuild-manager is a Linux utility that helps migrate installed applications
and user configurations to rebuild a familiar working environment on a new system.

## What it does
- Records installed applications (APT, Snap, Flatpak)
- Saves user-level configuration data
- Helps recreate the same user environment on another Linux machine

## What it does NOT do
- No disk imaging
- No filesystem snapshots
- No OS backup or restore

## Supported systems
- Ubuntu and Ubuntu-based distributions (full support)
- Debian-based distributions (partial support)
- Other Linux distributions (Flatpak + configs only)
