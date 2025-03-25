# Cursor AppImage Installer

A bash script for installing and managing [Cursor](https://cursor.sh/) on Debian/Ubuntu-based Linux distributions.

## Features

- Downloads the latest Cursor AppImage
- Creates desktop launcher
- Adds `cursor` command to system path
- Checks installation status
- Easy to use command-line interface

## Usage

```bash
$ ./setup.sh --help

Usage: ./setup.sh [OPTIONS]

Options:
  -a, --all             All-in-one Cursor installation (Recommended)

  -f, --fetch           Only fetch latest Cursor AppImage 
  -c, --configure       Configure desktop launcher and CLI

  -s, --status          Check Cursor installation status

  -h, --help            Show help message
  -v, --verbose         Increase verbosity
  -q, --quiet           Show only errors

Examples:
  ./setup.sh --all               # Complete installation
  ./setup.sh --fetch             # Only fetch latest version, existing configuration will be preserved
  ./setup.sh --configure         # Configure desktop launcher and CLI for latest downloaded version
  ./setup.sh --status            # Check the status of installed Cursor version
```

## Acknowledgements

This project is based on work by [Jorcelino Junior](https://github.com/jorcelinojunior/cursor-setup-wizard/), adapted under MIT license.

## License

MIT (c) Mablr