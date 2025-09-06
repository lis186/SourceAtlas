#!/usr/bin/env bash

# SourceAtlas Install Script
# Cross-platform installer for global CLI access

set -e

readonly VERSION="1.0.0"
readonly PROG_NAME="SourceAtlas Installer"

# ANSI color codes for better output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Installation paths
readonly SYSTEM_BIN="/usr/local/bin"
readonly USER_BIN="$HOME/.local/bin"

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BIN_DIR="${SCRIPT_DIR}/bin"

# Default installation mode
INSTALL_MODE=""
INSTALL_PATH=""
UNINSTALL_MODE=false
FORCE_MODE=false
VERBOSE_MODE=false

usage() {
    cat << EOF
${PROG_NAME} v${VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -s, --system        Install system-wide to ${SYSTEM_BIN} (requires sudo)
    -u, --user          Install for current user to ${USER_BIN}
    -p, --path PATH     Install to custom path
    -r, --remove        Uninstall (remove symlinks)
    -f, --force         Force overwrite existing installations
    -v, --verbose       Verbose output
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Interactive installation (prompts for location)
    $0 --system         # Install system-wide
    $0 --user           # Install for current user
    $0 --path ~/bin     # Install to custom path
    $0 --remove         # Uninstall

NOTES:
    - System installation requires sudo privileges
    - User installation may require adding ~/.local/bin to PATH
    - Custom path installation requires the path to be in PATH
EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

check_prerequisites() {
    log_verbose "Checking prerequisites..."
    
    # Check if source executables exist
    if [[ ! -f "${BIN_DIR}/sourceatlas" ]]; then
        log_error "Source executable not found: ${BIN_DIR}/sourceatlas"
        log_error "Make sure you're running this script from the SourceAtlas project root"
        exit 1
    fi
    
    if [[ ! -x "${BIN_DIR}/sourceatlas" ]]; then
        log_error "Source executable is not executable: ${BIN_DIR}/sourceatlas"
        exit 1
    fi
    
    # Check if satlas symlink exists
    if [[ ! -L "${BIN_DIR}/satlas" ]]; then
        log_warning "satlas symlink not found in ${BIN_DIR}, will create during installation"
    fi
    
    log_verbose "Prerequisites check passed"
}

test_installation() {
    local install_path="$1"
    local cmd_name="$2"
    
    log_verbose "Testing ${cmd_name} installation..."
    
    if command -v "${cmd_name}" >/dev/null 2>&1; then
        local version_output
        if version_output=$("${cmd_name}" --version 2>/dev/null); then
            log_success "${cmd_name} is working correctly"
            if [[ "$VERBOSE_MODE" == "true" ]]; then
                echo "  Version: ${version_output}"
            fi
            return 0
        else
            log_warning "${cmd_name} command exists but --version failed"
            return 1
        fi
    else
        log_error "${cmd_name} command not found in PATH"
        return 1
    fi
}

check_path() {
    local target_path="$1"
    
    log_verbose "Checking if ${target_path} is in PATH..."
    
    if echo "$PATH" | grep -q "${target_path}"; then
        log_verbose "${target_path} found in PATH"
        return 0
    else
        log_warning "${target_path} is not in PATH"
        return 1
    fi
}

create_symlinks() {
    local target_dir="$1"
    local force="$2"
    
    log_info "Installing SourceAtlas CLI tools to ${target_dir}..."
    
    # Ensure target directory exists
    if [[ ! -d "$target_dir" ]]; then
        log_info "Creating directory: ${target_dir}"
        mkdir -p "$target_dir" || {
            log_error "Failed to create directory: ${target_dir}"
            exit 1
        }
    fi
    
    # Install sourceatlas
    local sourceatlas_target="${target_dir}/sourceatlas"
    if [[ -e "$sourceatlas_target" ]] && [[ "$force" != "true" ]]; then
        log_error "File already exists: ${sourceatlas_target}"
        log_error "Use --force to overwrite, or --remove to uninstall first"
        exit 1
    fi
    
    log_verbose "Creating symlink: ${sourceatlas_target} -> ${BIN_DIR}/sourceatlas"
    ln -sf "${BIN_DIR}/sourceatlas" "$sourceatlas_target" || {
        log_error "Failed to create symlink for sourceatlas"
        exit 1
    }
    
    # Install satlas
    local satlas_target="${target_dir}/satlas"
    if [[ -e "$satlas_target" ]] && [[ "$force" != "true" ]]; then
        log_error "File already exists: ${satlas_target}"
        log_error "Use --force to overwrite, or --remove to uninstall first"
        exit 1
    fi
    
    log_verbose "Creating symlink: ${satlas_target} -> ${BIN_DIR}/sourceatlas"
    ln -sf "${BIN_DIR}/sourceatlas" "$satlas_target" || {
        log_error "Failed to create symlink for satlas"
        exit 1
    }
    
    log_success "Symlinks created successfully"
}

remove_symlinks() {
    local target_dir="$1"
    
    log_info "Uninstalling SourceAtlas CLI tools from ${target_dir}..."
    
    local removed_count=0
    
    # Remove sourceatlas
    local sourceatlas_target="${target_dir}/sourceatlas"
    if [[ -L "$sourceatlas_target" ]] && [[ "$(readlink "$sourceatlas_target")" == "${BIN_DIR}/sourceatlas" ]]; then
        log_verbose "Removing: ${sourceatlas_target}"
        rm "$sourceatlas_target"
        ((removed_count++))
    elif [[ -e "$sourceatlas_target" ]]; then
        log_warning "Found non-symlink file at ${sourceatlas_target}, skipping removal"
    fi
    
    # Remove satlas
    local satlas_target="${target_dir}/satlas"
    if [[ -L "$satlas_target" ]] && [[ "$(readlink "$satlas_target")" == "${BIN_DIR}/sourceatlas" ]]; then
        log_verbose "Removing: ${satlas_target}"
        rm "$satlas_target"
        ((removed_count++))
    elif [[ -e "$satlas_target" ]]; then
        log_warning "Found non-symlink file at ${satlas_target}, skipping removal"
    fi
    
    if [[ $removed_count -eq 0 ]]; then
        log_warning "No SourceAtlas symlinks found to remove in ${target_dir}"
    else
        log_success "Removed ${removed_count} symlink(s)"
    fi
}

interactive_install() {
    echo
    log_info "SourceAtlas CLI Installer"
    echo
    echo "Choose installation location:"
    echo "  1) System-wide (${SYSTEM_BIN}) - requires sudo"
    echo "  2) User-local (${USER_BIN}) - no sudo required"
    echo "  3) Custom path"
    echo "  4) Exit"
    echo
    
    while true; do
        read -p "Enter choice [1-4]: " choice
        case $choice in
            1)
                INSTALL_MODE="system"
                INSTALL_PATH="$SYSTEM_BIN"
                break
                ;;
            2)
                INSTALL_MODE="user"
                INSTALL_PATH="$USER_BIN"
                break
                ;;
            3)
                read -p "Enter custom path: " custom_path
                if [[ -n "$custom_path" ]]; then
                    INSTALL_MODE="custom"
                    INSTALL_PATH="$(eval echo "$custom_path")"  # Expand ~
                    break
                else
                    log_error "Please enter a valid path"
                fi
                ;;
            4)
                log_info "Installation cancelled"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1, 2, 3, or 4"
                ;;
        esac
    done
}

check_sudo_requirement() {
    local target_path="$1"
    
    if [[ "$target_path" == "/usr/local/bin" ]] || [[ "$target_path" == "/usr/bin" ]] || [[ "$target_path" =~ ^/usr/ ]]; then
        if [[ $EUID -ne 0 ]] && [[ -z "$SUDO_USER" ]]; then
            log_error "System installation requires sudo privileges"
            log_info "Please run: sudo $0 --system"
            exit 1
        fi
    fi
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--system)
                INSTALL_MODE="system"
                INSTALL_PATH="$SYSTEM_BIN"
                shift
                ;;
            -u|--user)
                INSTALL_MODE="user"
                INSTALL_PATH="$USER_BIN"
                shift
                ;;
            -p|--path)
                INSTALL_MODE="custom"
                INSTALL_PATH="$2"
                shift 2
                ;;
            -r|--remove)
                UNINSTALL_MODE=true
                shift
                ;;
            -f|--force)
                FORCE_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    # Handle uninstall mode
    if [[ "$UNINSTALL_MODE" == "true" ]]; then
        if [[ -z "$INSTALL_PATH" ]]; then
            interactive_install
        fi
        
        check_sudo_requirement "$INSTALL_PATH"
        remove_symlinks "$INSTALL_PATH"
        exit 0
    fi
    
    # Handle interactive mode
    if [[ -z "$INSTALL_MODE" ]]; then
        interactive_install
    fi
    
    # Validate install path
    if [[ -z "$INSTALL_PATH" ]]; then
        log_error "Installation path not specified"
        exit 1
    fi
    
    # Expand relative paths
    INSTALL_PATH="$(eval echo "$INSTALL_PATH")"
    
    # Check sudo requirement
    check_sudo_requirement "$INSTALL_PATH"
    
    # Create symlinks
    create_symlinks "$INSTALL_PATH" "$FORCE_MODE"
    
    # Check PATH and test installation
    if ! check_path "$INSTALL_PATH"; then
        log_warning "Installation directory is not in PATH"
        case "$INSTALL_MODE" in
            user)
                log_info "To add ~/.local/bin to PATH, add this line to your shell profile:"
                log_info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
                ;;
            custom)
                log_info "To add ${INSTALL_PATH} to PATH, add this line to your shell profile:"
                log_info "  export PATH=\"${INSTALL_PATH}:\$PATH\""
                ;;
        esac
        log_info "Then reload your shell or run: source ~/.bashrc (or ~/.zshrc)"
    else
        # Test the installation
        if test_installation "$INSTALL_PATH" "sourceatlas" && test_installation "$INSTALL_PATH" "satlas"; then
            log_success "Installation completed successfully!"
            log_info "You can now use 'sourceatlas' or 'satlas' commands from anywhere"
        else
            log_error "Installation may have issues. Please check your PATH configuration."
            exit 1
        fi
    fi
}

# Run main function
main "$@"