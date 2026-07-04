#!/bin/bash
# ============================================================================
# install-codemaat.sh - SourceAtlas code-maat Installation Script
# ============================================================================
#
# This script downloads and installs code-maat for SourceAtlas git history
# analysis (/atlas.history command).
#
# Usage:
#   ./install-codemaat.sh           # Install to default location
#   ./install-codemaat.sh --check   # Check if already installed
#   ./install-codemaat.sh --remove  # Remove installation
#
# Requirements:
#   - Java 8+ (JRE or JDK)
#   - curl or wget
#
# ============================================================================

set -euo pipefail

# Configuration
CODEMAAT_VERSION="1.0.4"
CODEMAAT_JAR="code-maat-${CODEMAAT_VERSION}-standalone.jar"
CODEMAAT_URL="https://github.com/adamtornhill/code-maat/releases/download/v${CODEMAAT_VERSION}/${CODEMAAT_JAR}"
INSTALL_DIR="${HOME}/.sourceatlas/bin"
JAR_PATH="${INSTALL_DIR}/${CODEMAAT_JAR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored message
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "    $1"
}

# Check Java installation
check_java() {
    if ! command -v java &> /dev/null; then
        print_error "Java is required but not found"
        print_info "Please install Java 8+ first:"
        print_info "  macOS:   brew install openjdk@11"
        print_info "  Ubuntu:  sudo apt install openjdk-11-jre"
        return 1
    fi

    # Check Java version (need 8+)
    local java_version
    java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)

    # Handle both "1.8" style and "11" style versions
    if [[ "$java_version" == "1" ]]; then
        java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f2)
    fi

    if [[ "$java_version" -lt 8 ]]; then
        print_error "Java 8+ is required (found Java $java_version)"
        return 1
    fi

    print_status "Java $java_version found"
    return 0
}

# Check if code-maat is already installed
check_installation() {
    if [ -f "$JAR_PATH" ]; then
        # Verify JAR works
        if java -jar "$JAR_PATH" -h &> /dev/null; then
            print_status "code-maat v${CODEMAAT_VERSION} is installed at:"
            print_info "$JAR_PATH"
            return 0
        else
            print_warning "code-maat JAR found but may be corrupted"
            return 1
        fi
    else
        print_warning "code-maat is not installed"
        return 1
    fi
}

# Download code-maat
download_codemaat() {
    print_status "Downloading code-maat v${CODEMAAT_VERSION}..."

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Download using curl or wget
    if command -v curl &> /dev/null; then
        curl -L -o "$JAR_PATH" "$CODEMAAT_URL" --progress-bar
    elif command -v wget &> /dev/null; then
        wget -O "$JAR_PATH" "$CODEMAAT_URL"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        return 1
    fi

    # Verify download
    if [ -f "$JAR_PATH" ]; then
        print_status "Downloaded to $JAR_PATH"
        return 0
    else
        print_error "Download failed"
        return 1
    fi
}

# Configure environment
configure_environment() {
    print_status "Configuring environment..."

    # Detect shell config file
    local shell_config
    if [ -f "${HOME}/.zshrc" ]; then
        shell_config="${HOME}/.zshrc"
    elif [ -f "${HOME}/.bashrc" ]; then
        shell_config="${HOME}/.bashrc"
    elif [ -f "${HOME}/.bash_profile" ]; then
        shell_config="${HOME}/.bash_profile"
    else
        shell_config="${HOME}/.profile"
    fi

    # Check if already configured
    if grep -q "CODEMAAT_JAR" "$shell_config" 2>/dev/null; then
        print_info "Environment already configured in $shell_config"
        return 0
    fi

    # Add configuration
    cat >> "$shell_config" << EOF

# SourceAtlas code-maat configuration
export CODEMAAT_JAR="$JAR_PATH"
alias maat='java -jar \$CODEMAAT_JAR'
EOF

    print_status "Added to $shell_config"
    print_info "Run 'source $shell_config' or restart terminal to apply"

    # Also export for current session
    export CODEMAAT_JAR="$JAR_PATH"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."

    if java -jar "$JAR_PATH" -h &> /dev/null; then
        print_status "code-maat is working correctly!"
        echo ""
        echo "Usage examples:"
        echo "  # Generate git log for analysis"
        echo "  git log --all --numstat --date=short --pretty=format:'--%h--%ad--%an' > git.log"
        echo ""
        echo "  # Run code-maat analysis"
        echo "  java -jar \$CODEMAAT_JAR -l git.log -c git2 -a revisions"
        echo "  java -jar \$CODEMAAT_JAR -l git.log -c git2 -a coupling"
        echo ""
        echo "Or use the SourceAtlas command:"
        echo "  /atlas.history"
        return 0
    else
        print_error "Installation verification failed"
        return 1
    fi
}

# Remove installation
remove_installation() {
    print_warning "Removing code-maat installation..."

    if [ -f "$JAR_PATH" ]; then
        rm "$JAR_PATH"
        print_status "Removed $JAR_PATH"
    fi

    # Note: Don't remove shell config entries automatically
    print_info "Note: Shell configuration entries were not removed."
    print_info "You may want to manually remove CODEMAAT_JAR from your shell config."

    return 0
}

# Show help
show_help() {
    echo "SourceAtlas code-maat Installer"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  (none)     Install code-maat to ~/.sourceatlas/bin/"
    echo "  --check    Check if code-maat is already installed"
    echo "  --remove   Remove code-maat installation"
    echo "  --help     Show this help message"
    echo ""
    echo "code-maat is required for /atlas.history command."
    echo "Learn more: https://github.com/adamtornhill/code-maat"
}

# Main
main() {
    case "${1:-}" in
        --check)
            check_java && check_installation
            ;;
        --remove)
            remove_installation
            ;;
        --help|-h)
            show_help
            ;;
        "")
            echo "=== SourceAtlas code-maat Installer ==="
            echo ""

            # Step 1: Check Java
            if ! check_java; then
                exit 1
            fi

            # Step 2: Check if already installed
            if check_installation; then
                print_info "To reinstall, first run: $0 --remove"
                exit 0
            fi

            # Step 3: Download
            if ! download_codemaat; then
                exit 1
            fi

            # Step 4: Configure environment
            configure_environment

            # Step 5: Verify
            echo ""
            if verify_installation; then
                echo ""
                print_status "Installation complete!"
            else
                exit 1
            fi
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
