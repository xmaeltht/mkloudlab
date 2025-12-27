#!/bin/bash

# K9s Plugin Installation Script
# This script installs Flux CD keyboard shortcuts for K9s

set -e

echo "🎨 Installing K9s Plugins for Flux CD"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_SOURCE="$PROJECT_ROOT/config/k9s/plugin.yml"
PLUGIN_DEST="$HOME/.k9s/plugin.yml"

# Check if source file exists
if [ ! -f "$PLUGIN_SOURCE" ]; then
    print_error "Plugin source file not found: $PLUGIN_SOURCE"
    exit 1
fi

# Create .k9s directory if it doesn't exist
if [ ! -d "$HOME/.k9s" ]; then
    print_status "Creating ~/.k9s directory..."
    mkdir -p "$HOME/.k9s"
fi

# Check if plugin.yml already exists
if [ -f "$PLUGIN_DEST" ]; then
    print_warning "Plugin file already exists at $PLUGIN_DEST"
    echo ""
    echo "Options:"
    echo "  1. Backup existing file and install new one"
    echo "  2. Merge with existing file (manual merge required)"
    echo "  3. Skip installation"
    echo ""
    read -p "Choose an option (1-3): " choice
    
    case $choice in
        1)
            BACKUP_FILE="${PLUGIN_DEST}.backup.$(date +%Y%m%d-%H%M%S)"
            print_status "Backing up existing plugin file to $BACKUP_FILE"
            cp "$PLUGIN_DEST" "$BACKUP_FILE"
            print_status "Installing new plugin file..."
            cp "$PLUGIN_SOURCE" "$PLUGIN_DEST"
            print_status "✅ Plugin file installed (backup saved)"
            ;;
        2)
            print_warning "Manual merge required. Please review and merge:"
            echo "  Source: $PLUGIN_SOURCE"
            echo "  Destination: $PLUGIN_DEST"
            echo ""
            echo "You can use:"
            echo "  diff $PLUGIN_DEST $PLUGIN_SOURCE"
            echo "  vimdiff $PLUGIN_DEST $PLUGIN_SOURCE"
            exit 0
            ;;
        3)
            print_status "Skipping installation"
            exit 0
            ;;
        *)
            print_error "Invalid option. Exiting."
            exit 1
            ;;
    esac
else
    print_status "Installing plugin file to $PLUGIN_DEST"
    cp "$PLUGIN_SOURCE" "$PLUGIN_DEST"
    print_status "✅ Plugin file installed"
fi

# Check if flux CLI is available (for plugin functionality)
if ! command -v flux &> /dev/null; then
    print_warning "Flux CLI not found. Plugins require Flux CLI to function."
    echo "   Install with: curl -s https://fluxcd.io/install.sh | sudo bash"
else
    print_status "✅ Flux CLI detected"
fi

# Check if jq is available (required for some plugins)
if ! command -v jq &> /dev/null; then
    print_warning "jq not found. Some plugins (trace, get-suspended-*) require jq."
    echo "   Install with: brew install jq (macOS) or apt-get install jq (Linux)"
else
    print_status "✅ jq detected"
fi

echo ""
print_status "🎉 K9s plugins installation completed!"
echo ""
echo "📖 Usage in K9s:"
echo "   - Shift-T: Toggle suspend/resume (HelmRelease/Kustomization)"
echo "   - Shift-R: Reconcile resource (Git/HelmRelease/Kustomization/ImageRepository)"
echo "   - Shift-Z: Reconcile Helm/OCI repository"
echo "   - Shift-S: List suspended HelmReleases/Kustomizations"
echo "   - Shift-P: Trace resource dependencies"
echo ""
echo "💡 Restart K9s to load the new plugins:"
echo "   k9s"

