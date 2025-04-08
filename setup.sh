#!/usr/bin/env bash

set -euo pipefail

# Constants
readonly DOWNLOAD_DIR="$HOME/.AppImage"
readonly ICON_DIR="$HOME/.local/share/icons"
readonly USER_DESKTOP_FILE="$HOME/Desktop/cursor.desktop"
readonly APPLICATION_DESKTOP_FILE="$HOME/.local/share/applications/cursor.desktop"
readonly API_URL="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=latest"
readonly ICON_URL="https://mintlify.s3.us-west-1.amazonaws.com/cursor/images/logo/app-logo.svg"

# Variables
local_name=""
local_size=""
local_version=""
local_path=""
local_hash=""
remote_name=""
remote_size=""
remote_version=""
remote_hash=""
download_url=""

# Set log level (0=error, 1=warn, 2=info, 3=debug)
LOG_LEVEL=2

# Function Definitions
log() {
  local level=$1
  local msg=$2
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  case $level in
    0) [[ $LOG_LEVEL -ge 0 ]] && echo -e "[$timestamp] ERROR: $msg" ;;
    1) [[ $LOG_LEVEL -ge 1 ]] && echo -e "[$timestamp] WARNING: $msg" ;;
    2) [[ $LOG_LEVEL -ge 2 ]] && echo -e "[$timestamp] INFO: $msg" ;;
    3) [[ $LOG_LEVEL -ge 3 ]] && echo -e "[$timestamp] DEBUG: $msg" ;;
  esac
}

validate_os() {
  log 2 "Checking system compatibility..."
  if ! command -v apt &> /dev/null; then
    os_name=$(grep -i '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "Unknown")
    log 0 "This script requires the APT package manager. Detected: $os_name. Exiting..."
    exit 1
  fi
  os_name=$(grep -i '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo "Debian-based")
  log 2 "Detected $os_name with APT package manager. System is compatible."
}

check_dependencies() {
  log 2 "Checking dependencies..."
  local missing=()
  
  # List of required commands and their corresponding packages
  local deps=(
    "curl:curl"
    "jq:jq"
    "xxd:vim-common"
    "libfuse2:libfuse2"
  )
  
  for dep in "${deps[@]}"; do
    local cmd="${dep%%:*}"
    local pkg="${dep#*:}"
    
    if ! command -v "$cmd" > /dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log 1 "Installing missing dependencies: ${missing[*]}"
    sudo apt update -y && sudo apt install -y "${missing[@]}"
  fi
  
  log 2 "All dependencies are installed."
}

extract_version() {
  [[ "$1" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]] && { echo "${BASH_REMATCH[1]}"; return 0; }
  echo "0.0.0" >&2; return 1
}

convert_to_mb() { 
  printf "%.2f MB" "$(echo "scale=2; $1 / 1048576" | bc)"
}

find_remote_version() {
  log 2 "Looking for the latest version online..."
  local api_response
  
  api_response=$(timeout "5" curl -s "$API_URL")
  if [[ $? -ne 0 ]]; then
    log 0 "Failed to fetch data from the API server. Check your internet connection."
    return 1
  fi
  
  download_url=$(echo "$api_response" | jq -r '.downloadUrl')
  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    log 0 "Failed to extract download URL from API response. Response: $api_response"
    return 1
  fi
  
  log 2 "Latest version details retrieved successfully."
  
  headers=$(timeout "5" curl -s -I "$download_url")
  if [[ -z "$headers" ]]; then
    log 0 "Failed to fetch file details from the download server."
    return 1
  fi
  
  remote_name=$(basename "$download_url")
  remote_size=$(echo "$headers" | grep -i 'Content-Length:' | awk '{print $2}' | tr -d '\r\n') || remote_size="0"
  remote_version=$(extract_version "$remote_name")
  remote_hash=$(echo "$headers" | grep -i 'etag:' | sed 's/etag: //;s/"//g' | tr -d '\r\n' || echo "unknown")
  
  if [[ -z "$remote_name" ]]; then
    log 0 "Could not determine the filename from download URL."
    return 1
  fi
  
  log 2 "Latest version online: $remote_name (v$remote_version, $(convert_to_mb "$remote_size"))"
  return 0
}

find_local_version() {
  mkdir -p "$DOWNLOAD_DIR"
  local_path=$(find "$DOWNLOAD_DIR" -maxdepth 1 -type f -name 'Cursor-*.AppImage' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
  
  if [[ -n "$local_path" ]]; then
    local_name=$(basename "$local_path")
    local_size=$(stat -c %s "$local_path" 2>/dev/null || echo "0")
    local_version=$(extract_version "$local_path")
    local_hash=$(calculate_etag "$local_path")
    log 2 "Local version found: $local_name (v$local_version, $(convert_to_mb "$local_size"))"
    return 0
  fi
  
  log 2 "No local version found in $DOWNLOAD_DIR"
  return 1
}

calculate_etag() {
  local chunk_size=5 # Cursor appimage uses 5MB chunks 
  local file_size=$(du -b "$1" | cut -f 1)
  local chunks=$((file_size / (chunk_size * 1024 * 1024)))
  
  if [[ $((file_size % (chunk_size * 1024 * 1024))) -gt 0 ]]; then 
    chunks=$((chunks + 1))
  fi
  
  local tmp_file=$(mktemp -t cursor-local-etag.XXXXXXXXXXXXX)
  for (( chunk=0; chunk<$chunks; chunk++ )); do
    dd bs=1M count=$chunk_size skip=$((chunk_size * chunk)) if="$1" 2> /dev/null | md5sum >> $tmp_file
  done
  
  local etag=$(echo "$(xxd -r -p "$tmp_file" | md5sum | cut -f 1 -d ' ')"-$chunks)
  rm "$tmp_file"
  echo "$etag"
}

download_logo() {
  log 2 "Downloading Cursor logo..."
  mkdir -p "$ICON_DIR"
  
  if curl -s -o "$ICON_DIR/cursor-icon.svg" "$ICON_URL"; then
    log 2 "Logo successfully downloaded to: $ICON_DIR/cursor-icon.svg"
    return 0
  else
    log 0 "Failed to download the logo. Please check your connection."
    return 1
  fi
}

download_appimage() {
  log 2 "Starting the download of the latest version..."
  local output_document="$DOWNLOAD_DIR/$remote_name"
  
  if [[ -z "$download_url" ]]; then
    log 0 "Download URL is empty. Please fetch the remote version first."
    return 1
  fi
  
  log 2 "Downloading AppImage to $output_document"
  
  if curl -L --progress-bar -o "$output_document" "$download_url"; then
    log 2 "Download completed successfully"
  else
    log 0 "AppImage download failed."
    return 1
  fi
  
  log 2 "Adjusting permissions for the AppImage..."
  if chmod +x "$output_document"; then
    log 2 "Permissions updated for the new AppImage."
  else
    log 0 "Failed to set executable permissions for $output_document"
    return 1
  fi
  
  local_path="$output_document"
  return 0
}

setup_launchers() {
  log 2 "Creating launchers for Cursor..."
  
  for launcher_path in "$USER_DESKTOP_FILE" "$APPLICATION_DESKTOP_FILE"; do
    local dir_path=$(dirname "$launcher_path")
    [[ ! -d "$dir_path" ]] && mkdir -p "$dir_path"
    
    cat > "$launcher_path" << EOF
[Desktop Entry]
Type=Application
Name=Cursor
GenericName=Intelligent, fast, and familiar, Cursor is the best way to code with AI.
Exec=$local_path --no-sandbox
Icon=$ICON_DIR/cursor-icon.svg
X-AppImage-Version=$local_version
Categories=Utility;Development
StartupWMClass=Cursor
Terminal=false
Comment=Cursor is an AI-first coding environment for software development.
Keywords=cursor;ai;code;editor;ide;artificial;intelligence;learning;programming;developer;development;software;engineering;productivity;vscode;sublime;coding;gpt;openai;copilot;
MimeType=x-scheme-handler/cursor;
EOF
    
    if chmod +x "$launcher_path"; then
      log 2 "Launcher set as executable: $launcher_path"
    else
      log 1 "Failed to set permissions for $launcher_path"
    fi
    
    # Make launcher trusted if gio is available
    if command -v gio > /dev/null 2>&1; then
      if gio set "$launcher_path" "metadata::trusted" true 2>/dev/null; then
        log 2 "Launcher marked as trusted: $launcher_path"
      else
        log 1 "Failed to mark $launcher_path as trusted"
      fi
    fi
  done
  
  log 2 "Launchers setup completed"
  return 0
}

add_cli_command() {
  log 2 "Adding the 'cursor' command to your system..."
  
  local script_content="#!/bin/bash

APPIMAGE_PATH=\"$local_path\"

if [[ ! -f \"\$APPIMAGE_PATH\" ]]; then
   echo \"Error: Cursor AppImage not found at \$APPIMAGE_PATH\" >&2;
   exit 1;
fi

\"\$APPIMAGE_PATH\" --no-sandbox \"\$@\" &> /dev/null &
"
  
  if echo "$script_content" | sudo tee /usr/local/bin/cursor > /dev/null; then
    if sudo chmod +x /usr/local/bin/cursor; then
      log 2 "CLI command 'cursor' successfully installed."
      return 0
    else
      log 0 "Failed to set permissions for /usr/local/bin/cursor"
      return 1
    fi
  else
    log 0 "Failed to create CLI command."
    return 1
  fi
}

print_usage() {
  cat << EOF
Usage: $0 [OPTIONS]

A command-line installer for Cursor AppImage on Debian/Ubuntu based Linux distributions.

Options:
  -a, --all             All-in-one Cursor installation (Recommended)

  -f, --fetch           Only fetch latest Cursor AppImage 
  -c, --configure       Configure desktop launcher and CLI

  -s, --status          Check Cursor installation status

  -h, --help            Show help message
  -v, --verbose         Increase verbosity
  -q, --quiet           Show only errors

Examples:
  $0 --all               # Complete installation
  $0 --fetch             # Only fetch latest version, existing configuration will be preserved
  $0 --configure         # Configure desktop launcher and CLI for latest downloaded version
  $0 --status            # Check the status of installed Cursor version

Report bugs to: https://github.com/mablr/cursor-installer/issues
EOF
}

print_status() {
  log 2 "Checking Cursor installation status..."
  
  # Check if Cursor is installed
  if ! find_local_version; then
    echo "Cursor is not installed."
    echo "Run '$0 --all' to install Cursor."
    return 1
  fi
  
  # Show basic installation info
  echo "Cursor is installed:"
  echo "  Version: $local_version"
  echo "  Location: $local_path"
  echo "  Size: $(convert_to_mb "$local_size")"
  
  # Initialize configuration status flag
  local config_needs_update=false
  
  # Check launchers (desktop and application)
  echo -n "  Launcher: "
  
  if [[ ! -f "$USER_DESKTOP_FILE" || ! -f "$APPLICATION_DESKTOP_FILE" ]]; then
    echo "No [NEEDS CONFIGURATION]"
    config_needs_update=true
  else
    local desktop_exec=$(grep -oP '^Exec=\K.*AppImage' "$USER_DESKTOP_FILE" 2>/dev/null)
    local application_exec=$(grep -oP '^Exec=\K.*AppImage' "$APPLICATION_DESKTOP_FILE" 2>/dev/null)
    if [[ -n "$desktop_exec" && "$desktop_exec" == "$local_path" && -n "$application_exec" && "$application_exec" == "$local_path" ]]; then
      echo "Yes [VALID]"
    else
      echo "Yes [NEEDS RECONFIGURATION]"
      config_needs_update=true
    fi
  fi
  
  # Check CLI command
  echo -n "  CLI command: "
  
  if ! command -v cursor &> /dev/null; then
    echo "No [NEEDS CONFIGURATION]"
    config_needs_update=true
  else
    local cli_path=$(grep -oP 'APPIMAGE_PATH="\K[^"]*' "$(which cursor)" 2>/dev/null)
    if [[ -n "$cli_path" && "$cli_path" == "$local_path" ]]; then
      echo "Yes ($(which cursor)) [VALID]"
    else
      echo "Yes ($(which cursor)) [NEEDS RECONFIGURATION]"
      config_needs_update=true
    fi
  fi

  # Show recommendation if any configuration needs update
  if [[ "$config_needs_update" == true ]]; then
    echo ""
    echo "Some configuration needs to be updated. Run '$0 --configure' to fix."
  fi
  
  return 0
}

# Main logic
main() {
  if [[ $# -eq 0 ]]; then
    print_usage
    exit 0
  fi
  
  local do_fetch=false
  local do_download=false
  local do_logo=false
  local do_desktop=false
  local do_cli=false
  local do_status=false
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        print_usage
        exit 0
        ;;
      -a|--all)
        do_fetch=true
        do_download=true
        do_logo=true
        do_desktop=true
        do_cli=true
        shift
        ;;
      -f|--fetch)
        do_fetch=true
        do_download=true
        shift
        ;;
      -c|--configure)
        do_logo=true
        do_desktop=true
        do_cli=true
        shift
        ;;
      -s|--status)
        do_status=true
        shift
        ;;
      -v|--verbose)
        LOG_LEVEL=3
        shift
        ;;
      -q|--quiet)
        LOG_LEVEL=0
        shift
        ;;
      *)
        echo "Unknown option: $1"
        print_usage
        exit 1
        ;;
    esac
  done
  
  # Validate operating system
  validate_os
  
  # Check status if requested
  if [[ "$do_status" == true ]]; then
    print_status
    exit $?
  fi
  
  # Check and install dependencies
  check_dependencies
  
  # Fetch remote version if requested
  if [[ "$do_fetch" == true ]]; then
    find_remote_version || exit 1
  
    # Download if requested
    if [[ "$do_download" == true ]]; then
      if ! find_local_version || [[ "$local_hash" != "$remote_hash" ]]; then
        download_appimage || exit 1
      else
        log 2 "Latest version already downloaded. No need to download again."
      fi
    fi
  fi
  
  # If we need to configure but have no local version, try to find it
  if [[ "$do_desktop" == true || "$do_cli" == true || "$do_logo" == true ]]; then
    if ! find_local_version; then
      log 0 "No local Cursor AppImage found. Use --fetch to download."
      exit 1
    fi
  fi
  
  # Download logo if needed
  if [[ "$do_logo" == true ]]; then
    download_logo
  fi
  
  # Set up desktop entries if requested
  if [[ "$do_desktop" == true ]]; then
    setup_launchers
  fi
  
  # Add CLI command if requested
  if [[ "$do_cli" == true ]]; then
    add_cli_command
  fi
  
  log 2 "Cursor installation/configuration completed successfully!"
  return 0
}

main "$@"
