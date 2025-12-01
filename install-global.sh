#!/bin/bash

# ============================================================================
# SourceAtlas Global Installation Script
# ============================================================================
#
# This script installs SourceAtlas commands globally to ~/.claude/commands/
# allowing you to use /atlas.overview and /atlas.pattern in any project.
#
# Usage:
#   ./install-global.sh          # Install/update commands
#   ./install-global.sh --check  # Check installation status
#   ./install-global.sh --remove # Uninstall global commands
#
# Author: SourceAtlas Team
# License: MIT
# ============================================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_COMMANDS_DIR="$HOME/.claude/commands"
SOURCE_COMMANDS_DIR="$SCRIPT_DIR/.claude/commands"
SOURCE_SCRIPTS_DIR="$SCRIPT_DIR/scripts/atlas"

# Installation method: symlink (default) or copy
INSTALL_METHOD="${INSTALL_METHOD:-symlink}"

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# ============================================================================
# Check Installation Status
# ============================================================================

check_installation() {
    print_header "SourceAtlas Installation Status"

    if [ ! -d "$GLOBAL_COMMANDS_DIR" ]; then
        print_warning "Not installed (directory does not exist)"
        echo ""
        echo "Run './install-global.sh' to install."
        return 1
    fi

    echo ""
    print_info "Global commands directory: $GLOBAL_COMMANDS_DIR"
    echo ""

    # Check each command
    local all_ok=true

    for cmd in atlas.overview atlas.pattern atlas.impact atlas.init atlas.history atlas.flow; do
        local file="$GLOBAL_COMMANDS_DIR/$cmd.md"

        if [ ! -e "$file" ]; then
            print_error "$cmd.md - NOT FOUND"
            all_ok=false
            continue
        fi

        if [ -L "$file" ]; then
            local target=$(readlink "$file")
            if [ -e "$target" ]; then
                print_success "$cmd.md → $target (symlink OK)"
            else
                print_error "$cmd.md → $target (BROKEN SYMLINK)"
                all_ok=false
            fi
        elif [ -f "$file" ]; then
            print_info "$cmd.md (file copy)"
        else
            print_error "$cmd.md (UNKNOWN TYPE)"
            all_ok=false
        fi
    done

    echo ""

    # Check scripts installation
    local scripts_link="$HOME/.claude/scripts/atlas"

    if [ -L "$scripts_link" ]; then
        local target=$(readlink "$scripts_link")
        if [ -d "$target" ]; then
            print_success "scripts/atlas → $target (symlink OK)"
        else
            print_error "scripts/atlas → $target (BROKEN SYMLINK)"
            all_ok=false
        fi
    elif [ -d "$scripts_link" ]; then
        print_info "scripts/atlas (directory copy)"
    else
        print_warning "scripts/atlas (NOT FOUND - commands may not work)"
        all_ok=false
    fi

    echo ""

    if [ "$all_ok" = true ]; then
        print_success "All commands installed and working"
        echo ""
        echo "You can now use these commands in any project:"
        echo "  /atlas.overview [directory]"
        echo "  /atlas.pattern [pattern-type]"
        return 0
    else
        print_error "Some commands have issues"
        echo ""
        echo "Run './install-global.sh' to repair installation."
        return 1
    fi
}

# ============================================================================
# Remove Installation
# ============================================================================

remove_installation() {
    print_header "Uninstalling SourceAtlas Global Commands"

    if [ ! -d "$GLOBAL_COMMANDS_DIR" ]; then
        print_warning "No installation found"
        return 0
    fi

    echo ""
    print_info "Removing: $GLOBAL_COMMANDS_DIR"

    rm -rf "$GLOBAL_COMMANDS_DIR"

    # Also remove scripts symlink if it exists
    local scripts_link="$HOME/.claude/scripts/atlas"
    if [ -L "$scripts_link" ] || [ -d "$scripts_link" ]; then
        print_info "Removing: $scripts_link"
        rm -rf "$scripts_link"
    fi

    echo ""
    print_success "SourceAtlas commands uninstalled successfully"
}

# ============================================================================
# Install Commands
# ============================================================================

install_commands() {
    print_header "Installing SourceAtlas Global Commands"

    # Validate source directory
    if [ ! -d "$SOURCE_COMMANDS_DIR" ]; then
        print_error "Source commands directory not found: $SOURCE_COMMANDS_DIR"
        print_error "Please run this script from the SourceAtlas project root."
        exit 1
    fi

    # Create global commands directory
    echo ""
    print_info "Creating directory: $GLOBAL_COMMANDS_DIR"
    mkdir -p "$GLOBAL_COMMANDS_DIR"

    # Install each command
    echo ""

    for cmd in atlas.overview atlas.pattern atlas.impact atlas.init atlas.history atlas.flow; do
        local source="$SOURCE_COMMANDS_DIR/$cmd.md"
        local target="$GLOBAL_COMMANDS_DIR/$cmd.md"

        if [ ! -f "$source" ]; then
            print_error "$cmd.md not found in source"
            continue
        fi

        # Remove existing file/link
        [ -e "$target" ] && rm -f "$target"

        if [ "$INSTALL_METHOD" = "symlink" ]; then
            ln -s "$source" "$target"
            print_success "Linked: $cmd.md"
        else
            cp "$source" "$target"
            print_success "Copied: $cmd.md"
        fi
    done

    # Install scripts (always symlink for live updates)
    echo ""
    local scripts_target="$HOME/.claude/scripts"
    mkdir -p "$scripts_target"

    local scripts_link="$scripts_target/atlas"

    if [ -e "$scripts_link" ]; then
        rm -rf "$scripts_link"
    fi

    ln -s "$SOURCE_SCRIPTS_DIR" "$scripts_link"
    print_success "Linked: scripts/atlas"

    echo ""
    print_success "Installation complete!"

    echo ""
    echo -e "${GREEN}You can now use these commands in any project:${NC}"
    echo ""
    echo -e "  ${BLUE}/atlas.init${NC}"
    echo "    - Initialize SourceAtlas in current project"
    echo "    - Injects auto-trigger rules into CLAUDE.md"
    echo "    - Run this first in new projects!"
    echo ""
    echo -e "  ${BLUE}/atlas.overview${NC} [directory]"
    echo "    - Rapid project fingerprint (Stage 0)"
    echo "    - Scans <5% of files for 70-80% understanding"
    echo "    - Completes in 10-15 minutes"
    echo ""
    echo -e "  ${BLUE}/atlas.pattern${NC} [pattern-type]"
    echo "    - Learn design patterns from codebase"
    echo "    - Examples: \"api endpoint\", \"background job\", \"swiftui view\""
    echo "    - Completes in 5-10 minutes"
    echo ""
    echo -e "  ${BLUE}/atlas.impact${NC} [target]"
    echo "    - Analyze impact scope of code changes"
    echo "    - Examples: \"User model\", \"api /users\", \"authentication\""
    echo "    - Static dependency analysis"
    echo ""
    echo -e "  ${BLUE}/atlas.history${NC} [scope]"
    echo "    - Smart temporal analysis using git history"
    echo "    - Hotspots, Coupling, Recent Contributors"
    echo "    - Requires code-maat (auto-installs if needed)"
    echo ""
    echo -e "  ${BLUE}/atlas.flow${NC} [entry point or query]"
    echo "    - Trace code execution flow and data flow"
    echo "    - Examples: \"用戶登入流程\", \"handleSubmit\", \"API 錯誤處理\""
    echo "    - Supports 11 analysis modes (forward, reverse, error, data...)"
    echo ""

    if [ "$INSTALL_METHOD" = "symlink" ]; then
        echo -e "${YELLOW}Note:${NC} Commands are symlinked. Updates to this repo will"
        echo "      automatically apply to all projects."
        echo ""
        echo "      To use copies instead: INSTALL_METHOD=copy ./install-global.sh"
    else
        echo -e "${YELLOW}Note:${NC} Commands were copied. To get updates, re-run this script."
    fi

    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    case "${1:-}" in
        --check|-c)
            check_installation
            ;;
        --remove|--uninstall|-r)
            remove_installation
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (no args)          Install or update SourceAtlas commands"
            echo "  --check, -c        Check installation status"
            echo "  --remove, -r       Uninstall global commands"
            echo "  --help, -h         Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  INSTALL_METHOD     'symlink' (default) or 'copy'"
            echo ""
            echo "Examples:"
            echo "  ./install-global.sh                 # Install with symlinks"
            echo "  INSTALL_METHOD=copy ./install-global.sh  # Install with copies"
            echo "  ./install-global.sh --check         # Check status"
            echo "  ./install-global.sh --remove        # Uninstall"
            ;;
        "")
            install_commands
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
}

main "$@"
