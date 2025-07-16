#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}==>${NC} $1"; }
print_error() { echo -e "${RED}==>${NC} $1"; }
print_warning() { echo -e "${YELLOW}==>${NC} $1"; }

get_latest_url() {
    local api_endpoint="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
    local download_url=$(curl -sL "$api_endpoint" | jq -r '.downloadUrl')
    echo "$download_url"
}

get_latest_version() {
    local url=$(get_latest_url)
    echo "$url" | grep -o 'Cursor-[0-9.]*-x86_64' | cut -d'-' -f2
}

check_fuse() {
    if ! ldconfig -p | grep -q libfuse.so.2; then
        print_warning "libfuse2 is not installed. AppImages may not run without it."
        read -p "Do you want to install libfuse2 now? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            sudo apt update && sudo apt install -y libfuse2
        else
            print_warning "Skipping libfuse2 installation. AppImage may not run."
        fi
    fi
}

uninstall_cursor() {
    print_status "Removing Cursor files and desktop entry..."
    sudo rm -rf /opt/cursor
    sudo rm -f /usr/local/bin/cursor
    sudo rm -f /usr/share/applications/cursor.desktop
    print_success "Cursor has been uninstalled."
    exit 0
}

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Installation failed with exit code $exit_code"
    fi
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    exit $exit_code
}

trap cleanup EXIT

update_cursor() {
    print_status "Updating Cursor to the latest version..."

    # Check for libfuse2
    check_fuse

    if [ "$EUID" -eq 0 ]; then
        print_error "Please run this script as a regular user, not as root."
        exit 1
    fi

    if [ ! -d "/opt/cursor" ]; then
        print_error "Cursor is not installed. Please run the script to install."
        exit 1
    fi

    print_status "Creating temporary directory..."
    TEMP_DIR=$(mktemp -d)

    print_status "Getting download URL..."
    DOWNLOAD_URL=$(get_latest_url)
    if [ -z "$DOWNLOAD_URL" ]; then
        print_error "Failed to get download URL."
        exit 1
    fi

    print_status "Downloading latest Cursor AppImage..."
    curl -L --progress-bar "$DOWNLOAD_URL" -o "$TEMP_DIR/cursor.AppImage"
    if [ $? -ne 0 ]; then
        print_error "Failed to download Cursor."
        exit 1
    fi

    print_status "Downloading Cursor icon..."
    curl -L --progress-bar "https://www.cursor.com/apple-touch-icon.png" -o "$TEMP_DIR/cursor.png"
    if [ $? -ne 0 ]; then
        print_error "Failed to download icon."
        exit 1
    fi

    print_status "Replacing AppImage and icon in /opt/cursor (requires sudo)..."
    sudo mv "$TEMP_DIR/cursor.AppImage" /opt/cursor/
    sudo mv "$TEMP_DIR/cursor.png" /opt/cursor/
    sudo chmod +x /opt/cursor/cursor.AppImage

    VERSION=$(echo "$DOWNLOAD_URL" | grep -o 'Cursor-[0-9.]*-x86_64' | cut -d'-' -f2)
    echo "$VERSION" | sudo tee /opt/cursor/version.txt > /dev/null

    print_success "Cursor has been updated to version $VERSION!"
    print_status "Your settings, themes, and extensions are preserved."
}

main() {
    if [[ "$1" == "--uninstall" ]]; then
        uninstall_cursor
    fi

    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}              ${GREEN}Cursor Installation Script${NC}                  ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}\n"

    check_fuse

    if [ "$EUID" -eq 0 ]; then
        print_error "Please run this script as a regular user, not as root."
        exit 1
    fi

    if [ -d "/opt/cursor" ]; then
        # Check for updates
        if [ -f "/opt/cursor/version.txt" ]; then
            INSTALLED_VERSION=$(cat /opt/cursor/version.txt)
        else
            INSTALLED_VERSION="unknown"
        fi
        LATEST_VERSION=$(get_latest_version)
        if [ "$INSTALLED_VERSION" != "$LATEST_VERSION" ]; then
            print_warning "A new version of Cursor is available! (Installed: $INSTALLED_VERSION, Latest: $LATEST_VERSION)"
            read -p "Do you want to update to the latest version? (Y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                update_cursor
                print_success "Update complete."
                exit 0
            else
                print_status "Skipping update."
                exit 0
            fi
        else
            print_success "Cursor is already up to date (version $INSTALLED_VERSION)."
            exit 0
        fi
    fi

    print_status "Creating temporary directory..."
    TEMP_DIR=$(mktemp -d)

    print_status "Getting download URL..."
    DOWNLOAD_URL=$(get_latest_url)
    if [ -z "$DOWNLOAD_URL" ]; then
        print_error "Failed to get download URL."
        exit 1
    fi

    print_status "Downloading Cursor AppImage..."
    curl -L --progress-bar "$DOWNLOAD_URL" -o "$TEMP_DIR/cursor.AppImage"
    if [ $? -ne 0 ]; then
        print_error "Failed to download Cursor."
        exit 1
    fi

    print_status "Downloading Cursor icon..."
    curl -L --progress-bar "https://www.cursor.com/apple-touch-icon.png" -o "$TEMP_DIR/cursor.png"
    if [ $? -ne 0 ]; then
        print_error "Failed to download icon."
        exit 1
    fi

    print_status "Installing files to /opt/cursor (requires sudo)..."
    sudo mkdir -p /opt/cursor
    sudo mv "$TEMP_DIR/cursor.AppImage" /opt/cursor/
    sudo mv "$TEMP_DIR/cursor.png" /opt/cursor/
    sudo chmod +x /opt/cursor/cursor.AppImage

    print_status "Creating command-line symlink..."
    sudo ln -sf /opt/cursor/cursor.AppImage /usr/local/bin/cursor

    print_status "Creating desktop entry..."
    sudo tee /usr/share/applications/cursor.desktop > /dev/null << EOL
[Desktop Entry]
Name=Cursor
Comment=AI-first code editor
Exec=/opt/cursor/cursor.AppImage --no-sandbox
Icon=/opt/cursor/cursor.png
Terminal=false
Type=Application
Categories=Development;TextEditor;IDE;
StartupWMClass=Cursor
EOL

    VERSION=$(echo "$DOWNLOAD_URL" | grep -o 'Cursor-[0-9.]*-x86_64' | cut -d'-' -f2)
    echo "$VERSION" | sudo tee /opt/cursor/version.txt > /dev/null

    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}              ${GREEN}Installation Complete!${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}\n"

    print_success "Cursor has been successfully installed!"
    print_status "Version: $VERSION"
    print_status "You can now launch Cursor from your applications menu or by typing 'cursor' in your terminal"
    print_status "To uninstall, run: ${YELLOW}bash $0 --uninstall${NC}"
}

main "$@"
