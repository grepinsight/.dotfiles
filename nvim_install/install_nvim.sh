#!/bin/bash

VERSION="1.0"
INSTALL_DIR="$HOME/src/nvim"

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
    -v, --version     Print script version
    -h, --help        Print this help message
    -V VERSION        Install specific Neovim version (e.g. v0.9.4)

Default installation path: ~/src/nvim
EOF
    exit 0
}

print_version() {
    echo_ts "${BLUE}" "${VERSION}"
    exit 0
}

# Parse command line arguments
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
        *)
            echo_ts "${RED}" "Unknown option: $1"
            print_help
            ;;
    esac
    shift
done

# Create installation directory
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}" || exit 1

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

# Download and install Neovim
case "${OS}" in
    Darwin)
        if [ "${ARCH}" = "arm64" ]; then
            ARCH="aarch64"
        fi
        if [ -n "${NVIM_VERSION}" ]; then
            echo_ts "${BLUE}" "Downloading Neovim ${NVIM_VERSION} for macOS ${ARCH}"
            curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-macos-${ARCH}.tar.gz"
        else
            echo_ts "${BLUE}" "Downloading latest Neovim for macOS ${ARCH}"
            curl -LO "https://github.com/neovim/neovim/releases/latest/download/nvim-macos-${ARCH}.tar.gz"
        fi
        tar xzf "nvim-macos-${ARCH}.tar.gz"
        rm "nvim-macos-${ARCH}.tar.gz"
        ;;
    Linux)
        if [ -n "${NVIM_VERSION}" ]; then
            echo_ts "${BLUE}" "Downloading Neovim ${NVIM_VERSION} for Linux"
            curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz"
        else
            echo_ts "${BLUE}" "Downloading latest Neovim for Linux"
            curl -LO "https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz"
        fi
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
