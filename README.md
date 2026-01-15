## Supported Application Sources

linux-rebuild-manager can back up and restore applications installed via:

- **APT** (manual packages)
- **Snap**
- **Flatpak**

### Flatpak Restore Behavior
- Flatpak is automatically installed during restore if it is missing
- Flathub repository is automatically enabled if not present
- Flatpak applications are restored using stable application IDs
- Works on fresh Ubuntu installs and partially configured systems

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
## AppImage notes

On some Ubuntu systems with Secure Boot or kernel security restrictions,
AppImages may not run directly.

If execution is blocked, extract and run manually:

./linux-rebuild-manager_1.0.0_x86_64.AppImage --appimage-extract
cd squashfs-root
./AppRun

For Ubuntu users, the .deb package is recommended.
