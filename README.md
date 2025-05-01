<p align="center">
  <img src="https://raw.githubusercontent.com/mablr/cursor-installer/refs/heads/master/cursor-icon.svg" alt="Cursor Icon" width="100"/>
</p>

<h1 align="center">Cursor Installer</h1>

![GitHub issues](https://img.shields.io/github/issues/mablr/cursor-installer)
![GitHub contributors](https://img.shields.io/github/contributors/mablr/cursor-installer)
![Licence MIT](https://img.shields.io/badge/License-MIT-blue)


**A bash script for installing and managing [Cursor](https://cursor.sh/) on Debian/Ubuntu-based Linux distributions.**

## Quickstart

Run the setup script to install and configure Cursor:
```bash
curl -sSL https://raw.githubusercontent.com/mablr/cursor-installer/master/setup.sh | bash -s -- -a
```

Or clone the repository and run the setup script:
```bash
git clone https://github.com/mablr/cursor-installer
cd cursor-installer
chmod +x setup.sh
./setup.sh -a
```

## Features

- **Automated Installation**: Downloads the latest Cursor AppImage from official sources
- **System Integration**: 
  - Creates desktop launcher for easy access
  - Adds `cursor` command to system PATH
- **Management Tools**:
  - Status checking to verify installation integrity
  - Clean uninstallation option
- **Update Handling**: Seamless integration with Cursor's built-in auto-update system

## Project Status

### Completed
- ✅ Feature parity with the original [`cursor-setup-wizard`](https://github.com/jorcelinojunior/cursor-setup-wizard/)
- ✅ Direct integration with Cursor's official API for reliable downloads
- ✅ Broad compatibility across Debian-based distributions
- ✅ Complete uninstallation capability
- ✅ Proper handling of Cursor's native update mechanism

### Coming Soon
- 🔄 Fully unprivileged installation mode (no sudo required except for dependency installation)
- 🔄 Improved error handling and recovery

## Limitations

- ℹ️ **AppImageLauncher Conflict**: This installer is not compatible with AppImageLauncher. If you have AppImageLauncher installed, it may interfere with the proper functioning of Cursor. It is recommended to remove AppImageLauncher before using this installer.

## Usage

```bash
$ ./setup.sh --help

Usage: ./setup.sh [OPTIONS]

Options:
  -a, --all             All-in-one Cursor installation (Recommended)

  -f, --fetch           Only fetch latest Cursor AppImage 
  -c, --configure       Configure desktop launcher and CLI

  -s, --status          Check Cursor installation status

  -r, --remove          Uninstall Cursor (remove icon, desktop launcher, and CLI command)
  -p, --remove-purge    Uninstall Cursor and purge all AppImages

  -h, --help            Show help message
  -q, --quiet           Show only errors and warnings
```

## Acknowledgements

This project is based on work by [Jorcelino Junior](https://github.com/jorcelinojunior/cursor-setup-wizard/), adapted under MIT license.

## License

MIT (c) Mablr