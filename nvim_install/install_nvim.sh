#!/bin/bash

VERSION="1.0"
INSTALL_DIR="$HOME/src/nvim"
PURGE=false

# Colors for echo output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Custom echo function with timestamp
echo_ts() {
    local color=$1
    shift
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${color}$*${NC}"
}

print_help() {
    cat << EOF
Install Neovim script ${VERSION}

Usage: ./install_nvim.sh [options]

Options:
    -v, --version       Print script version
    -h, --help          Print this help message
    -V VERSION          Install specific Neovim version (e.g. v0.9.4)
    --nightly          Install nightly version of Neovim
    --stable-latest    Install latest stable version of Neovim
    --check-exists     Check if download links are valid without installing
    --install-dir DIR  Specify custom installation directory (default: ~/src/nvim)
    --purge           Remove existing installation before installing

Default installation path: ~/src/nvim
EOF
    exit 0
}

print_version() {
    echo_ts "${BLUE}" "${VERSION}"
    exit 0
}

# Parse command line arguments
CHECK_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_help
            ;;
        -v|--version)
            print_version
            ;;
        -V)
            NVIM_VERSION="$2"
            shift
            ;;
        --nightly)
            NVIM_VERSION="nightly"
            ;;
        --stable-latest)
            NVIM_VERSION="stable"
            ;;
        --check-exists)
            CHECK_ONLY=true
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift
            ;;
        --purge)
            PURGE=true
            ;;
        *)
            echo_ts "${RED}" "Unknown option: $1"
            print_help
            ;;
    esac
    shift
done

# Check if installation directory exists and handle purge
if [ -d "${INSTALL_DIR}" ]; then
    if [ "$PURGE" = true ]; then
        echo_ts "${YELLOW}" "Existing installation found at ${INSTALL_DIR}"
        read -p "Are you sure you want to remove it? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo_ts "${BLUE}" "Removing existing installation..."
            rm -rf "${INSTALL_DIR}"
        else
            echo_ts "${RED}" "Aborting installation"
            exit 1
        fi
    elif [ "$(ls -A "${INSTALL_DIR}")" ]; then
        echo_ts "${RED}" "Installation directory ${INSTALL_DIR} exists and is not empty"
        echo_ts "${RED}" "Use --purge to remove existing installation"
        exit 1
    fi
fi

# Create installation directory if not just checking
if [ "$CHECK_ONLY" = false ]; then
    mkdir -p "${INSTALL_DIR}"
    cd "${INSTALL_DIR}" || exit 1
fi

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo_ts "${BLUE}" "OS: ${OS}"

# Function to check URL exists
check_url() {
    local url="$1"
    if curl --output /dev/null --silent --head --fail "$url"; then
        echo_ts "${GREEN}" "Download link is valid: $url"
        return 0
    else
        echo_ts "${RED}" "Download link is invalid: $url"
        return 1
    fi
}

# Download and install Neovim
case "${OS}" in
    Darwin)
        if [ "${NVIM_VERSION}" = "nightly" ]; then
            URL="https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-${ARCH}.tar.gz"
        elif [ "${NVIM_VERSION}" = "stable" ]; then
            URL="https://github.com/neovim/neovim/releases/latest/download/nvim-macos-${ARCH}.tar.gz"
        elif [ -n "${NVIM_VERSION}" ]; then
            URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-macos-${ARCH}.tar.gz"
        else
            URL="https://github.com/neovim/neovim/releases/latest/download/nvim-macos-${ARCH}.tar.gz"
        fi
        
        if [ "$CHECK_ONLY" = true ]; then
            check_url "$URL"
            exit $?
        fi
        
        echo_ts "${BLUE}" "Downloading Neovim for macOS ${ARCH}"
        curl -LO "$URL"
        tar xzf "nvim-macos-${ARCH}.tar.gz"
        rm "nvim-macos-${ARCH}.tar.gz"
        ;;
    Linux)
        if [ "${NVIM_VERSION}" = "nightly" ]; then
            URL="https://github.com/neovim/neovim/releases/download/nightly/nvim-linux64.tar.gz"
        elif [ "${NVIM_VERSION}" = "stable" ]; then
            URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz"
        elif [ -n "${NVIM_VERSION}" ]; then
            URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz"
        else
            URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz"
        fi
        
        if [ "$CHECK_ONLY" = true ]; then
            check_url "$URL"
            exit $?
        fi
        
        echo_ts "${BLUE}" "Downloading Neovim for Linux"
        curl -LO "$URL"
        tar xzf nvim-linux64.tar.gz
        rm nvim-linux64.tar.gz
        ;;
    *)
        echo_ts "${RED}" "Unsupported operating system: ${OS}"
        exit 1
        ;;
esac

# Add to PATH if not already present
NVIM_BIN="${INSTALL_DIR}/nvim-${OS}/bin"
if [[ ":$PATH:" != *":${NVIM_BIN}:"* ]]; then
    echo_ts "${YELLOW}" "Adding Neovim to PATH in ~/.bashrc"
    echo "export PATH=\"\${PATH}:${NVIM_BIN}\"" >> "${HOME}/.bashrc"
    echo_ts "${YELLOW}" "Please restart your shell or run: source ~/.bashrc"
fi

echo_ts "${GREEN}" "Neovim has been installed successfully!"