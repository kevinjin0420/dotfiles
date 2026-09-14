#!/bin/bash
set -euxo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

DOTFILES_REPO="https://github.com/kevinjin0420/dotfiles"
DOTFILES_DIR="${HOME}/dotfiles"

echo -e "${BLUE}Bootstrapping${NC}"

if [ ! -d "$DOTFILES_DIR/.git" ]; then
    echo -e "${BLUE}Cloning dotfiles...${NC}"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

echo -e "${BLUE}Running local setup...${NC}"
"$DOTFILES_DIR/setup/local.sh"

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${BLUE}Running macOS setup...${NC}"
    "$DOTFILES_DIR/setup/macos.sh"
fi

if command -v kwriteconfig6 &>/dev/null; then
    echo -e "${BLUE}Running KDE setup...${NC}"
    "$DOTFILES_DIR/setup/kde.sh"
fi

echo -e "${GREEN}Setup complete!${NC}"
