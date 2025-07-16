
# Cursor Linux Installer

**Installation script for Cursor on Linux**

This repository provides a simple Bash script to install and keep [Cursor](https://www.cursor.so/) up to date on Linux.  
The script automatically checks for updates and can also uninstall Cursor if needed.

---

## Usage

### 1. Download the script

```bash
curl -O https://raw.githubusercontent.com/ali6parmak/cursor-linux-installer/main/cursor-linux-installer.sh
chmod +x cursor-linux-installer.sh
```

### 2. Run the installer

```bash
./cursor-linux-installer.sh
```

- If Cursor is already installed, the script will check for updates and prompt you if a new version is available.
- If up to date, it will let you know and exit.

### 3. Uninstall Cursor

```bash
./cursor-linux-installer.sh --uninstall
```

---

## Requirements

- **Linux** (tested on Ubuntu/Debian, should work on most distributions)
- `curl`, `jq`, and `sudo` must be available
- `libfuse2` (the script will prompt to install if missing)

---

## What the script does

- Downloads the latest Cursor AppImage and icon
- Installs them to `/opt/cursor`
- Creates a symlink at `/usr/local/bin/cursor`
- Adds a desktop entry for easy launching
- Checks for updates on every run

---

**Feel free to open issues or pull requests for improvements!**
