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
./setup.sh [OPTIONS]

Options:
  -h, --help       Show help message
  -a, --all        All-in-one install
  -f, --fetch      Download latest version
  -c, --configure  Configure desktop launcher and CLI
  -s, --status     Check installation status
  -v, --verbose    Increase verbosity
  -q, --quiet      Show only errors
```

## Acknowledgements

This project is based on work by [Jorcelino Junior](https://github.com/jorcelinojunior/cursor-setup-wizard/), adapted under MIT license.

## License

MIT (c) Mablr