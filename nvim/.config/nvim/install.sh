#!/usr/bin/env bash

# Default Neovim version
NEOVIM_VERSION="nightly"

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize flags
INSTALL_COPY_FLAG=false
INSTALL_SYMLINK_FLAG=false

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --install-copy)
            INSTALL_COPY_FLAG=true
            ;;
        --install-symlink)
            INSTALL_SYMLINK_FLAG=true
            ;;
        -v|--version)
            shift
            if [[ -n "$1" ]]; then
                NEOVIM_VERSION="$1"
            else
                echo -e "${RED}Error: --version requires an argument.${NC}"
                exit 1
            fi
            ;;
        -h|--help)
            echo -e "${YELLOW}Usage: $0 [options]${NC}"
            echo -e "${YELLOW}  --install-copy           Copy Neovim files to /usr/local directories${NC}"
            echo -e "${YELLOW}  --install-symlink        Create symlinks to Neovim files in /usr/local directories${NC}"
            echo -e "${YELLOW}  -v, --version VERSION    Specify Neovim version (default: nightly)${NC}"
            echo -e "${YELLOW}  -h, --help               Display this help message${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo -e "${YELLOW}Use --help to see available options.${NC}"
            exit 1
            ;;
    esac
    shift
done

# Check for conflicting options
if [[ "$INSTALL_COPY_FLAG" == true && "$INSTALL_SYMLINK_FLAG" == true ]]; then
    echo -e "${RED}Error: --install-copy and --install-symlink cannot be used together.${NC}"
    exit 1
fi

# Determine OS
if [[ "$(uname)" == "Darwin" ]]; then
    echo -e "${GREEN}Detected macOS.${NC}"
    ARCH=$(uname -m)
    if [[ $ARCH == "x86_64" ]]; then
        NEOVIM_DIST="nvim-macos-x86_64"
        echo -e "${GREEN}Architecture is x86_64.${NC}"
    elif [[ $ARCH == "arm64" ]]; then
        NEOVIM_DIST="nvim-macos-arm64"
        echo -e "${GREEN}Architecture is arm64.${NC}"
    else
        echo -e "${RED}Unknown architecture: $ARCH${NC}"
        exit 1
    fi
elif [[ "$(uname)" == "Linux" ]]; then
    echo -e "${GREEN}Detected Linux.${NC}"
    NEOVIM_DIST="nvim-linux64"
else
    echo -e "${RED}Unsupported operating system.${NC}"
    exit 1
fi

# Create directory and download Neovim
mkdir -p "$HOME/src"
cd "$HOME/src" || exit

DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/${NEOVIM_VERSION}/${NEOVIM_DIST}.tar.gz"

echo -e "${YELLOW}Downloading Neovim from ${DOWNLOAD_URL}...${NC}"
curl -O -L "${DOWNLOAD_URL}"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to download Neovim. Please check the version and try again.${NC}"
    exit 1
fi

echo -e "${YELLOW}Extracting ${NEOVIM_DIST}.tar.gz...${NC}"
tar xvzf "${NEOVIM_DIST}.tar.gz"

# Installation directories
BIN_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib"
SHARE_DIR="/usr/local/share"

if [[ "$INSTALL_COPY_FLAG" == true || "$INSTALL_SYMLINK_FLAG" == true ]]; then
    # Install Neovim
    echo -e "${YELLOW}Preparing to install Neovim...${NC}"
    cd "$HOME/src/${NEOVIM_DIST}" || exit

    # Create target directories if they don't exist
    sudo mkdir -p "${BIN_DIR}"
    sudo mkdir -p "${LIB_DIR}"
    sudo mkdir -p "${SHARE_DIR}"

    if [[ "$INSTALL_COPY_FLAG" == true ]]; then
        echo -e "${YELLOW}Copying Neovim files to /usr/local directories...${NC}"
        sudo cp -r bin/*   "${BIN_DIR}/"
        sudo cp -r lib/*   "${LIB_DIR}/"
        sudo cp -r share/* "${SHARE_DIR}/"
        echo -e "${GREEN}Neovim installed successfully by copying files.${NC}"
    elif [[ "$INSTALL_SYMLINK_FLAG" == true ]]; then
        echo -e "${YELLOW}Creating symlinks to Neovim files in /usr/local directories...${NC}"

        # Symlink bin files
        for file in bin/*; do
            filename=$(basename "$file")
            sudo ln -sf "$PWD/bin/$filename" "${BIN_DIR}/$filename"
        done

        # Symlink lib files
        for file in lib/*; do
            filename=$(basename "$file")
            sudo ln -sf "$PWD/lib/$filename" "${LIB_DIR}/$filename"
        done

        # Symlink share files (need to link directories)
        for dir in share/*; do
            dirname=$(basename "$dir")
            sudo ln -sfn "$PWD/share/$dirname" "${SHARE_DIR}/$dirname"
        done

        echo -e "${GREEN}Neovim installed successfully by creating symlinks.${NC}"
    fi
else
    echo -e "${YELLOW}Skipping installation to /usr/local directories.${NC}"
    echo -e "${YELLOW}Use --install-copy or --install-symlink to perform installation.${NC}"
fi

